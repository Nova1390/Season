begin;

-- Backend-first Review Inbox for Catalog Governance Agent proposals.
--
-- This migration adds admin-guarded RPCs to inspect and triage proposals.
-- It deliberately does not add any catalog mutation, alias approval,
-- canonical creation, recipe reconciliation, scheduler, or auto-apply path.

create or replace function public.get_catalog_agent_review_inbox(
  p_statuses text[] default array['needs_human_review', 'draft', 'failed_validation', 'queued_for_validation'],
  p_proposal_type text default null,
  p_risk_levels text[] default null,
  p_source_domain text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_statuses text[] := coalesce(p_statuses, array['needs_human_review', 'draft', 'failed_validation', 'queued_for_validation']);
  v_proposal_type text := nullif(btrim(coalesce(p_proposal_type, '')), '');
  v_source_domain text := nullif(btrim(coalesce(p_source_domain, '')), '');
  v_items jsonb := '[]'::jsonb;
  v_counts_by_status jsonb := '{}'::jsonb;
  v_counts_by_risk jsonb := '{}'::jsonb;
  v_total_count bigint := 0;
begin
  perform public.assert_catalog_admin(v_user);

  with filtered as (
    select p.*
    from public.catalog_agent_proposals p
    join public.catalog_agent_runs r on r.id = p.run_id
    where (cardinality(v_statuses) = 0 or p.status = any(v_statuses))
      and (v_proposal_type is null or p.proposal_type = v_proposal_type)
      and (p_risk_levels is null or cardinality(p_risk_levels) = 0 or p.risk_level = any(p_risk_levels))
      and (v_source_domain is null or r.source_domain = v_source_domain)
  )
  select count(*) into v_total_count
  from filtered;

  with filtered as (
    select p.*
    from public.catalog_agent_proposals p
    join public.catalog_agent_runs r on r.id = p.run_id
    where (cardinality(v_statuses) = 0 or p.status = any(v_statuses))
      and (v_proposal_type is null or p.proposal_type = v_proposal_type)
      and (p_risk_levels is null or cardinality(p_risk_levels) = 0 or p.risk_level = any(p_risk_levels))
      and (v_source_domain is null or r.source_domain = v_source_domain)
  ),
  status_counts as (
    select f.status, count(*)::bigint as item_count
    from filtered f
    group by f.status
  )
  select coalesce(jsonb_object_agg(status, item_count), '{}'::jsonb)
  into v_counts_by_status
  from status_counts;

  with filtered as (
    select p.*
    from public.catalog_agent_proposals p
    join public.catalog_agent_runs r on r.id = p.run_id
    where (cardinality(v_statuses) = 0 or p.status = any(v_statuses))
      and (v_proposal_type is null or p.proposal_type = v_proposal_type)
      and (p_risk_levels is null or cardinality(p_risk_levels) = 0 or p.risk_level = any(p_risk_levels))
      and (v_source_domain is null or r.source_domain = v_source_domain)
  ),
  risk_counts as (
    select f.risk_level, count(*)::bigint as item_count
    from filtered f
    group by f.risk_level
  )
  select coalesce(jsonb_object_agg(risk_level, item_count), '{}'::jsonb)
  into v_counts_by_risk
  from risk_counts;

  with filtered as (
    select p.*
    from public.catalog_agent_proposals p
    join public.catalog_agent_runs r on r.id = p.run_id
    where (cardinality(v_statuses) = 0 or p.status = any(v_statuses))
      and (v_proposal_type is null or p.proposal_type = v_proposal_type)
      and (p_risk_levels is null or cardinality(p_risk_levels) = 0 or p.risk_level = any(p_risk_levels))
      and (v_source_domain is null or r.source_domain = v_source_domain)
  ),
  page as (
    select f.*
    from filtered f
    order by
      case f.status
        when 'needs_human_review' then 0
        when 'failed_validation' then 1
        when 'draft' then 2
        when 'queued_for_validation' then 3
        else 9
      end,
      case f.risk_level
        when 'critical' then 0
        when 'high' then 1
        when 'unknown' then 2
        when 'medium' then 3
        when 'low' then 4
        else 9
      end,
      f.created_at desc,
      f.id desc
    limit v_limit
    offset v_offset
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'proposal_id', p.id,
        'run', jsonb_build_object(
          'id', r.id,
          'environment', r.environment,
          'agent_name', r.agent_name,
          'agent_version', r.agent_version,
          'model', r.model,
          'prompt_version', r.prompt_version,
          'mode', r.mode,
          'source_domain', r.source_domain,
          'status', r.status,
          'created_at', r.created_at,
          'summary', r.summary
        ),
        'proposal', jsonb_build_object(
          'proposal_type', p.proposal_type,
          'normalized_text', p.normalized_text,
          'status', p.status,
          'risk_level', p.risk_level,
          'confidence_score', p.confidence_score,
          'auto_apply_eligible', p.auto_apply_eligible,
          'rationale', p.rationale,
          'evidence', p.evidence,
          'blocking_questions', p.blocking_questions,
          'validation_errors', p.validation_errors,
          'rejection_reason', p.rejection_reason,
          'created_at', p.created_at,
          'updated_at', p.updated_at
        ),
        'target', case
          when target_i.id is null then null
          else jsonb_build_object(
            'ingredient_id', target_i.id,
            'slug', target_i.slug,
            'ingredient_type', target_i.ingredient_type,
            'quality_status', target_i.quality_status,
            'display_name_it', target_it.display_name,
            'display_name_en', target_en.display_name
          )
        end,
        'proposed', jsonb_build_object(
          'target_slug', p.target_slug,
          'proposed_slug', p.proposed_slug,
          'proposed_alias_text', p.proposed_alias_text,
          'proposed_localized_name', p.proposed_localized_name,
          'proposed_language_code', p.proposed_language_code,
          'proposed_parent_ingredient_id', p.proposed_parent_ingredient_id,
          'proposed_specificity_rank', p.proposed_specificity_rank,
          'proposed_variant_kind', p.proposed_variant_kind,
          'proposed_slug_conflict', case
            when proposed_conflict.id is null then null
            else jsonb_build_object(
              'ingredient_id', proposed_conflict.id,
              'slug', proposed_conflict.slug,
              'quality_status', proposed_conflict.quality_status
            )
          end
        ),
        'observations', coalesce(obs.items, '[]'::jsonb),
        'recent_events', coalesce(events.items, '[]'::jsonb)
      )
      order by
        case p.status
          when 'needs_human_review' then 0
          when 'failed_validation' then 1
          when 'draft' then 2
          when 'queued_for_validation' then 3
          else 9
        end,
        p.created_at desc,
        p.id desc
    ),
    '[]'::jsonb
  )
  into v_items
  from page p
  join public.catalog_agent_runs r on r.id = p.run_id
  left join public.ingredients target_i on target_i.id = p.target_ingredient_id
  left join public.ingredient_localizations target_it
    on target_it.ingredient_id = target_i.id
   and target_it.language_code = 'it'
  left join public.ingredient_localizations target_en
    on target_en.ingredient_id = target_i.id
   and target_en.language_code = 'en'
  left join public.ingredients proposed_conflict
    on proposed_conflict.slug = p.proposed_slug
  left join lateral (
    select jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'normalized_text', o.normalized_text,
        'raw_examples', o.raw_examples,
        'occurrence_count', o.occurrence_count,
        'language_code', o.language_code,
        'source', o.source,
        'latest_recipe_id', o.latest_recipe_id,
        'status', o.status,
        'last_seen_at', o.last_seen_at
      )
      order by o.last_seen_at desc
    ) as items
    from public.custom_ingredient_observations o
    where o.id = any(p.source_observation_ids)
  ) obs on true
  left join lateral (
    select jsonb_agg(
      jsonb_build_object(
        'id', e.id,
        'event_type', e.event_type,
        'event_payload', e.event_payload,
        'created_at', e.created_at,
        'created_by', e.created_by
      )
      order by e.created_at desc, e.id desc
    ) as items
    from (
      select ev.*
      from public.catalog_agent_proposal_events ev
      where ev.proposal_id = p.id
      order by ev.created_at desc, ev.id desc
      limit 10
    ) e
  ) events on true;

  return jsonb_build_object(
    'metadata', jsonb_build_object(
      'source', 'catalog_agent_review_inbox_v1',
      'generated_at', now(),
      'limit', v_limit,
      'offset', v_offset,
      'filters', jsonb_build_object(
        'statuses', v_statuses,
        'proposal_type', v_proposal_type,
        'risk_levels', p_risk_levels,
        'source_domain', v_source_domain
      ),
      'counts', jsonb_build_object(
        'total', v_total_count,
        'by_status', v_counts_by_status,
        'by_risk_level', v_counts_by_risk
      )
    ),
    'items', v_items
  );
end;
$$;

create or replace function public.review_catalog_agent_proposal(
  p_proposal_id bigint,
  p_action text,
  p_reviewer_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_note text := nullif(btrim(coalesce(p_reviewer_note, '')), '');
  v_previous_status text;
  v_next_status text;
  v_event_type text;
  v_row public.catalog_agent_proposals%rowtype;
begin
  perform public.assert_catalog_admin(v_user);

  if p_proposal_id is null then
    raise exception 'proposal_id_required'
      using errcode = '22023';
  end if;

  if v_action not in ('reject', 'defer', 'request_more_evidence', 'queue_for_validation', 'mark_needs_human_review') then
    raise exception 'unsupported_review_action: %', v_action
      using errcode = '22023';
  end if;

  if v_action = 'reject' and v_note is null then
    raise exception 'reviewer_note_required_for_rejection'
      using errcode = '22023';
  end if;

  select *
  into v_row
  from public.catalog_agent_proposals p
  where p.id = p_proposal_id
  for update;

  if not found then
    raise exception 'catalog_agent_proposal_not_found: %', p_proposal_id
      using errcode = 'P0002';
  end if;

  v_previous_status := v_row.status;

  case v_action
    when 'reject' then
      v_next_status := 'rejected';
      v_event_type := 'review_rejected';
    when 'queue_for_validation' then
      v_next_status := 'queued_for_validation';
      v_event_type := 'review_queued_for_validation';
    when 'mark_needs_human_review' then
      v_next_status := 'needs_human_review';
      v_event_type := 'review_marked_needs_human_review';
    when 'request_more_evidence' then
      v_next_status := 'needs_human_review';
      v_event_type := 'review_more_evidence_requested';
    else
      v_next_status := coalesce(v_row.status, 'needs_human_review');
      v_event_type := 'review_deferred';
  end case;

  update public.catalog_agent_proposals p
  set
    status = v_next_status,
    rejection_reason = case
      when v_action = 'reject' then v_note
      else p.rejection_reason
    end,
    updated_at = now()
  where p.id = p_proposal_id
  returning *
  into v_row;

  insert into public.catalog_agent_proposal_events (
    proposal_id,
    run_id,
    event_type,
    event_payload,
    created_by
  )
  values (
    v_row.id,
    v_row.run_id,
    v_event_type,
    jsonb_build_object(
      'action', v_action,
      'previous_status', v_previous_status,
      'next_status', v_next_status,
      'reviewer_note', v_note,
      'mutation_scope', 'proposal_status_only'
    ),
    v_user
  );

  return jsonb_build_object(
    'ok', true,
    'proposal_id', v_row.id,
    'run_id', v_row.run_id,
    'previous_status', v_previous_status,
    'status', v_next_status,
    'event_type', v_event_type
  );
end;
$$;

revoke all on function public.get_catalog_agent_review_inbox(text[], text, text[], text, integer, integer) from public;
grant execute on function public.get_catalog_agent_review_inbox(text[], text, text[], text, integer, integer) to authenticated;
grant execute on function public.get_catalog_agent_review_inbox(text[], text, text[], text, integer, integer) to service_role;

revoke all on function public.review_catalog_agent_proposal(bigint, text, text) from public;
grant execute on function public.review_catalog_agent_proposal(bigint, text, text) to authenticated;
grant execute on function public.review_catalog_agent_proposal(bigint, text, text) to service_role;

comment on function public.get_catalog_agent_review_inbox(text[], text, text[], text, integer, integer) is
  'Admin-only read contract for Catalog Governance Agent proposal review. No catalog mutation.';

comment on function public.review_catalog_agent_proposal(bigint, text, text) is
  'Admin-only proposal review transition. Updates proposal status/events only; does not apply catalog changes.';

commit;
