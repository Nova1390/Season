begin;

-- Manual apply adapter for validated Catalog Governance Agent proposals.
--
-- This is not auto-apply. It only lets a catalog admin apply already validated
-- low-risk alias/localization proposals through existing governed RPCs.

alter table public.catalog_agent_proposals
  drop constraint if exists catalog_agent_proposals_status_check;

alter table public.catalog_agent_proposals
  add constraint catalog_agent_proposals_status_check
  check (
    status in (
      'draft',
      'queued_for_validation',
      'validated',
      'applied',
      'auto_applied',
      'needs_human_review',
      'rejected',
      'failed_validation',
      'superseded'
    )
  );

alter table public.catalog_agent_proposals
  drop constraint if exists catalog_agent_proposals_applied_requires_status;

alter table public.catalog_agent_proposals
  add constraint catalog_agent_proposals_applied_requires_status
  check (
    applied_at is null
    or status in ('applied', 'auto_applied')
  );

create or replace function public.apply_catalog_agent_proposal(
  p_proposal_id bigint,
  p_apply_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_row public.catalog_agent_proposals%rowtype;
  v_note text := nullif(btrim(coalesce(p_apply_note, '')), '');
  v_target_ingredient_id uuid;
  v_alias_text text;
  v_language_code text;
  v_apply_result jsonb := '{}'::jsonb;
  v_event_payload jsonb;
begin
  perform public.assert_catalog_admin(v_user);

  if p_proposal_id is null then
    raise exception 'proposal_id_required'
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

  if v_row.status <> 'validated' then
    raise exception 'proposal_not_validated: status=%', v_row.status
      using errcode = '22023';
  end if;

  if v_row.risk_level <> 'low' then
    raise exception 'manual_apply_v1_requires_low_risk: risk_level=%', v_row.risk_level
      using errcode = '22023';
  end if;

  if v_row.proposal_type not in ('approve_alias', 'add_localization') then
    raise exception 'manual_apply_v1_unsupported_proposal_type: %', v_row.proposal_type
      using errcode = '22023';
  end if;

  v_target_ingredient_id := v_row.target_ingredient_id;
  if v_target_ingredient_id is null and nullif(btrim(coalesce(v_row.target_slug, '')), '') is not null then
    select i.id
    into v_target_ingredient_id
    from public.ingredients i
    where i.slug = btrim(v_row.target_slug)
      and coalesce(i.quality_status, '') = 'active'
    limit 1;
  end if;

  if v_target_ingredient_id is null then
    raise exception 'manual_apply_target_required'
      using errcode = '22023';
  end if;

  if v_row.proposal_type = 'approve_alias' then
    v_alias_text := coalesce(
      nullif(btrim(coalesce(v_row.proposed_alias_text, '')), ''),
      nullif(btrim(coalesce(v_row.normalized_text, '')), '')
    );

    if v_alias_text is null then
      raise exception 'manual_apply_alias_text_required'
        using errcode = '22023';
    end if;

    select to_jsonb(result_row)
    into v_apply_result
    from public.apply_catalog_candidate_decision(
      p_normalized_text => v_row.normalized_text,
      p_action => 'approve_alias',
      p_ingredient_id => v_target_ingredient_id,
      p_alias_text => v_alias_text,
      p_language_code => v_row.proposed_language_code,
      p_confidence_score => v_row.confidence_score,
      p_reviewer_note => coalesce(v_note, 'Applied from validated Catalog Governance Agent proposal.')
    ) as result_row;
  elsif v_row.proposal_type = 'add_localization' then
    v_language_code := coalesce(
      nullif(btrim(coalesce(v_row.proposed_language_code, '')), ''),
      'it'
    );

    if nullif(btrim(coalesce(v_row.proposed_localized_name, '')), '') is null then
      raise exception 'manual_apply_localized_name_required'
        using errcode = '22023';
    end if;

    select to_jsonb(result_row)
    into v_apply_result
    from public.add_ingredient_localization(
      p_ingredient_id => v_target_ingredient_id,
      p_text => v_row.proposed_localized_name,
      p_language_code => v_language_code
    ) as result_row;
  end if;

  v_event_payload := jsonb_build_object(
    'apply_mode', 'manual',
    'proposal_type', v_row.proposal_type,
    'target_ingredient_id', v_target_ingredient_id,
    'apply_note', v_note,
    'apply_result', coalesce(v_apply_result, '{}'::jsonb),
    'mutation_scope', case
      when v_row.proposal_type = 'approve_alias' then 'governed_alias_rpc'
      when v_row.proposal_type = 'add_localization' then 'governed_localization_rpc'
      else 'unknown'
    end
  );

  update public.catalog_agent_proposals p
  set
    status = 'applied',
    applied_at = now(),
    applied_by = v_user,
    updated_at = now()
  where p.id = v_row.id
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
    'manual_apply_succeeded',
    v_event_payload,
    v_user
  );

  return jsonb_build_object(
    'ok', true,
    'proposal_id', v_row.id,
    'run_id', v_row.run_id,
    'status', v_row.status,
    'applied_at', v_row.applied_at,
    'apply_result', coalesce(v_apply_result, '{}'::jsonb)
  );
exception
  when others then
    if v_row.id is not null then
      update public.catalog_agent_proposals p
      set
        validation_errors = coalesce(p.validation_errors, '[]'::jsonb) || jsonb_build_array(
          public.catalog_agent_validation_error(
            'manual_apply_failed',
            sqlerrm,
            'error'
          )
        ),
        updated_at = now()
      where p.id = v_row.id;

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
        'manual_apply_failed',
        jsonb_build_object(
          'error', sqlerrm,
          'sqlstate', sqlstate,
          'apply_mode', 'manual',
          'mutation_scope', 'governed_rpc_only'
        ),
        v_user
      );
    end if;

    raise;
end;
$$;

create or replace function public.apply_catalog_agent_proposal_batch(
  p_limit integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 25);
  v_proposal_id bigint;
  v_result jsonb;
  v_results jsonb := '[]'::jsonb;
  v_applied_count integer := 0;
  v_failed_count integer := 0;
begin
  perform public.assert_catalog_admin(v_user);

  for v_proposal_id in
    select p.id
    from public.catalog_agent_proposals p
    where p.status = 'validated'
      and p.risk_level = 'low'
      and p.proposal_type in ('approve_alias', 'add_localization')
    order by p.created_at asc, p.id asc
    limit v_limit
  loop
    begin
      v_result := public.apply_catalog_agent_proposal(
        p_proposal_id => v_proposal_id,
        p_apply_note => 'Manual batch apply from validated Catalog Governance Agent proposal.'
      );
      v_applied_count := v_applied_count + 1;
    exception
      when others then
        v_failed_count := v_failed_count + 1;
        v_result := jsonb_build_object(
          'ok', false,
          'proposal_id', v_proposal_id,
          'error', sqlerrm,
          'sqlstate', sqlstate
        );
    end;

    v_results := v_results || jsonb_build_array(v_result);
  end loop;

  return jsonb_build_object(
    'ok', true,
    'applied', v_applied_count,
    'failed', v_failed_count,
    'results', v_results
  );
end;
$$;

revoke all on function public.apply_catalog_agent_proposal(bigint, text) from public;
grant execute on function public.apply_catalog_agent_proposal(bigint, text) to authenticated;
grant execute on function public.apply_catalog_agent_proposal(bigint, text) to service_role;

revoke all on function public.apply_catalog_agent_proposal_batch(integer) from public;
grant execute on function public.apply_catalog_agent_proposal_batch(integer) to authenticated;
grant execute on function public.apply_catalog_agent_proposal_batch(integer) to service_role;

comment on function public.apply_catalog_agent_proposal(bigint, text) is
  'Admin-only manual apply adapter for validated low-risk Catalog Governance Agent alias/localization proposals. Uses governed RPCs only.';

comment on function public.apply_catalog_agent_proposal_batch(integer) is
  'Admin-only batch manual apply adapter for validated low-risk Catalog Governance Agent alias/localization proposals. Uses governed RPCs only.';

commit;
