begin;

-- Keep rollback failures visible to operators. The previous implementation
-- recorded a failure inside the exception handler and then re-raised, which
-- aborts the RPC transaction and can hide the failure audit update.

create or replace function public.rollback_catalog_agent_apply(
  p_apply_audit_id bigint,
  p_revert_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role text := coalesce(current_setting('request.jwt.claim.role', true), auth.role(), '');
  v_audit public.catalog_agent_apply_audit%rowtype;
  v_current_alias jsonb;
  v_current_localization jsonb;
  v_before_alias jsonb;
  v_after_alias jsonb;
  v_before_observation jsonb;
  v_reason text := nullif(btrim(coalesce(p_revert_reason, '')), '');
begin
  if v_role is distinct from 'service_role' then
    perform public.assert_catalog_admin(v_user);
  end if;

  if p_apply_audit_id is null then
    raise exception 'apply_audit_id_required'
      using errcode = '22023';
  end if;

  if v_reason is null then
    raise exception 'revert_reason_required'
      using errcode = '22023';
  end if;

  select *
  into v_audit
  from public.catalog_agent_apply_audit a
  where a.id = p_apply_audit_id
  for update;

  if not found then
    raise exception 'catalog_agent_apply_audit_not_found: %', p_apply_audit_id
      using errcode = 'P0002';
  end if;

  if v_audit.status <> 'applied' then
    raise exception 'catalog_agent_apply_not_revertible: status=%', v_audit.status
      using errcode = '22023';
  end if;

  if v_audit.mutation_type = 'approve_alias' then
    v_before_alias := v_audit.before_state->'alias_row';
    v_after_alias := v_audit.after_state->'alias_row';
    v_before_observation := v_audit.before_state->'observation_row';

    select to_jsonb(a)
    into v_current_alias
    from public.ingredient_aliases_v2 a
    where a.id = (v_audit.rollback_plan->>'alias_id')::bigint
    limit 1;

    if v_current_alias is distinct from v_after_alias then
      raise exception 'rollback_current_alias_changed: %', v_audit.rollback_plan->>'alias_id'
        using errcode = '40001';
    end if;

    if v_audit.rollback_plan->>'action' = 'delete_inserted_alias' then
      delete from public.ingredient_aliases_v2 a
      where a.id = (v_audit.rollback_plan->>'alias_id')::bigint;
    elsif v_audit.rollback_plan->>'action' = 'restore_previous_alias_row' then
      update public.ingredient_aliases_v2 a
      set
        ingredient_id = (v_before_alias->>'ingredient_id')::uuid,
        alias_text = v_before_alias->>'alias_text',
        normalized_alias_text = v_before_alias->>'normalized_alias_text',
        language_code = v_before_alias->>'language_code',
        source = v_before_alias->>'source',
        confidence = nullif(v_before_alias->>'confidence', '')::double precision,
        confidence_score = nullif(v_before_alias->>'confidence_score', '')::double precision,
        is_active = coalesce((v_before_alias->>'is_active')::boolean, true),
        status = v_before_alias->>'status',
        approval_source = v_before_alias->>'approval_source',
        approved_at = nullif(v_before_alias->>'approved_at', '')::timestamptz,
        approved_by = nullif(v_before_alias->>'approved_by', '')::uuid,
        review_notes = v_before_alias->>'review_notes',
        created_at = (v_before_alias->>'created_at')::timestamptz,
        updated_at = (v_before_alias->>'updated_at')::timestamptz
      where a.id = (v_before_alias->>'id')::bigint;
    else
      raise exception 'rollback_unsupported_alias_action: %', v_audit.rollback_plan->>'action'
        using errcode = '22023';
    end if;

    if jsonb_typeof(v_before_observation) = 'object' and v_before_observation ? 'id' then
      update public.custom_ingredient_observations o
      set
        status = v_before_observation->>'status',
        updated_at = (v_before_observation->>'updated_at')::timestamptz
      where o.id = (v_before_observation->>'id')::bigint;
    end if;
  elsif v_audit.mutation_type = 'add_localization' then
    if v_audit.rollback_plan->>'action' = 'delete_inserted_localization' then
      select to_jsonb(l)
      into v_current_localization
      from public.ingredient_localizations l
      where l.ingredient_id = (v_audit.rollback_plan->>'ingredient_id')::uuid
        and l.language_code = v_audit.rollback_plan->>'language_code'
      limit 1;

      if v_current_localization is distinct from (v_audit.after_state->'localization_row') then
        raise exception 'rollback_current_localization_changed: %', v_audit.rollback_plan->>'language_code'
          using errcode = '40001';
      end if;

      delete from public.ingredient_localizations l
      where l.ingredient_id = (v_audit.rollback_plan->>'ingredient_id')::uuid
        and l.language_code = v_audit.rollback_plan->>'language_code';
    elsif v_audit.rollback_plan->>'action' = 'none_existing_same_localization' then
      null;
    else
      raise exception 'rollback_unsupported_localization_action: %', v_audit.rollback_plan->>'action'
        using errcode = '22023';
    end if;
  else
    raise exception 'rollback_unsupported_mutation_type: %', v_audit.mutation_type
      using errcode = '22023';
  end if;

  update public.catalog_agent_proposals p
  set
    status = 'validated',
    applied_at = null,
    applied_by = null,
    updated_at = now()
  where p.id = v_audit.proposal_id
    and p.status = 'auto_applied';

  update public.catalog_agent_apply_audit a
  set
    status = 'reverted',
    reverted_at = now(),
    reverted_by = v_user,
    revert_reason = v_reason,
    updated_at = now()
  where a.id = v_audit.id
  returning * into v_audit;

  insert into public.catalog_agent_proposal_events (
    proposal_id,
    run_id,
    event_type,
    event_payload,
    created_by
  )
  values (
    v_audit.proposal_id,
    v_audit.run_id,
    'auto_apply_rollback_succeeded',
    jsonb_build_object(
      'apply_audit_id', v_audit.id,
      'worker_job_id', v_audit.worker_job_id,
      'mutation_type', v_audit.mutation_type,
      'rollback_action', v_audit.rollback_plan->>'action',
      'revert_reason', v_reason
    ),
    v_user
  );

  return jsonb_build_object(
    'ok', true,
    'apply_audit_id', v_audit.id,
    'proposal_id', v_audit.proposal_id,
    'status', v_audit.status,
    'reverted_at', v_audit.reverted_at
  );
exception
  when others then
    if v_audit.id is not null then
      update public.catalog_agent_apply_audit a
      set
        status = 'revert_failed',
        revert_reason = coalesce(v_reason, sqlerrm),
        updated_at = now()
      where a.id = v_audit.id;

      insert into public.catalog_agent_proposal_events (
        proposal_id,
        run_id,
        event_type,
        event_payload,
        created_by
      )
      values (
        v_audit.proposal_id,
        v_audit.run_id,
        'auto_apply_rollback_failed',
        jsonb_build_object(
          'apply_audit_id', v_audit.id,
          'error', sqlerrm,
          'sqlstate', sqlstate,
          'rollback_action', v_audit.rollback_plan->>'action'
        ),
        v_user
      );

      return jsonb_build_object(
        'ok', false,
        'apply_audit_id', v_audit.id,
        'proposal_id', v_audit.proposal_id,
        'status', 'revert_failed',
        'error', sqlerrm,
        'sqlstate', sqlstate
      );
    end if;

    raise;
end;
$$;

comment on function public.rollback_catalog_agent_apply(bigint, text) is
  'Reverts a still-current Catalog Agent auto-apply audit record; records guarded rollback failures instead of hiding them behind an aborted RPC transaction.';

commit;
