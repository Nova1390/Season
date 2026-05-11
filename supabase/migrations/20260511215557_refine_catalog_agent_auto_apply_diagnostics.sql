begin;

create or replace function public.get_catalog_agent_auto_apply_diagnostics()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role text := coalesce(current_setting('request.jwt.claim.role', true), auth.role(), '');
  v_ready_count integer := 0;
  v_total_count integer := 0;
  v_counts jsonb := '{}'::jsonb;
  v_ready_preview jsonb := '[]'::jsonb;
begin
  if v_role is distinct from 'service_role' then
    perform public.assert_catalog_admin(v_user);
  end if;

  select count(*)::integer
  into v_total_count
  from public.catalog_agent_proposals;

  select count(*)::integer
  into v_ready_count
  from public.catalog_agent_proposals p
  where p.status = 'validated'
    and p.risk_level = 'low'
    and coalesce(p.auto_apply_eligible, false)
    and p.proposal_type in ('approve_alias', 'add_localization')
    and jsonb_typeof(p.validation_errors) = 'array'
    and jsonb_array_length(p.validation_errors) = 0
    and not exists (
      select 1
      from public.catalog_agent_apply_audit a
      where a.proposal_id = p.id
        and a.status = 'applied'
    );

  with counts as (
    select 'total_proposals' as key, count(*)::integer as value
    from public.catalog_agent_proposals
    union all
    select 'draft', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'draft'
    union all
    select 'queued_for_validation', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'queued_for_validation'
    union all
    select 'needs_human_review', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'needs_human_review'
    union all
    select 'failed_validation', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'failed_validation'
    union all
    select 'auto_applied', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'auto_applied'
    union all
    select 'rejected', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'rejected'
    union all
    select 'superseded', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'superseded'
    union all
    select 'validated_total', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'validated'
    union all
    select 'validated_not_low_risk', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'validated'
      and p.risk_level <> 'low'
    union all
    select 'validated_not_auto_apply_eligible', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'validated'
      and not coalesce(p.auto_apply_eligible, false)
    union all
    select 'validated_unsupported_type', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'validated'
      and p.proposal_type not in ('approve_alias', 'add_localization')
    union all
    select 'validated_has_validation_errors', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'validated'
      and (
        jsonb_typeof(p.validation_errors) <> 'array'
        or jsonb_array_length(p.validation_errors) <> 0
      )
    union all
    select 'validated_already_applied', count(*)::integer
    from public.catalog_agent_proposals p
    where p.status = 'validated'
      and exists (
        select 1
        from public.catalog_agent_apply_audit a
        where a.proposal_id = p.id
          and a.status = 'applied'
      )
    union all
    select 'ready_for_low_risk_apply', v_ready_count
  )
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  into v_counts
  from counts;

  select coalesce(jsonb_agg(row_to_json(ready_row)::jsonb), '[]'::jsonb)
  into v_ready_preview
  from (
    select
      p.id,
      p.proposal_type,
      p.normalized_text,
      p.target_slug,
      p.confidence_score,
      p.created_at
    from public.catalog_agent_proposals p
    where p.status = 'validated'
      and p.risk_level = 'low'
      and coalesce(p.auto_apply_eligible, false)
      and p.proposal_type in ('approve_alias', 'add_localization')
      and jsonb_typeof(p.validation_errors) = 'array'
      and jsonb_array_length(p.validation_errors) = 0
      and not exists (
        select 1
        from public.catalog_agent_apply_audit a
        where a.proposal_id = p.id
          and a.status = 'applied'
      )
    order by p.created_at asc, p.id asc
    limit 5
  ) ready_row;

  return jsonb_build_object(
    'ok', true,
    'ready_for_low_risk_apply', v_ready_count,
    'total_proposals', v_total_count,
    'counts', v_counts,
    'ready_preview', v_ready_preview,
    'explanation', case
      when v_ready_count > 0 then 'There are validated low-risk proposals ready for dry-run/apply preview.'
      when coalesce((v_counts->>'queued_for_validation')::integer, 0) > 0 then 'No ready proposals yet. Some proposals are queued for deterministic validation.'
      when coalesce((v_counts->>'draft')::integer, 0) > 0 then 'No ready proposals yet. Draft proposals need queueing and deterministic validation.'
      when coalesce((v_counts->>'needs_human_review')::integer, 0) > 0 then 'No ready proposals yet. Current proposals need human review or more evidence.'
      when coalesce((v_counts->>'failed_validation')::integer, 0) > 0 then 'No ready proposals yet. Existing proposals failed deterministic validation.'
      when coalesce((v_counts->>'validated_total')::integer, 0) > 0 then 'Validated proposals exist, but none match all low-risk auto-apply criteria.'
      when v_total_count > 0 then 'No open low-risk apply work. Existing proposals are terminal or already handled.'
      else 'No agent proposals exist yet. Run triage or enrichment first.'
    end
  );
end;
$$;

comment on function public.get_catalog_agent_auto_apply_diagnostics() is
  'Admin-only diagnostics explaining why low-risk auto-apply dry-runs have zero eligible proposals.';

commit;
