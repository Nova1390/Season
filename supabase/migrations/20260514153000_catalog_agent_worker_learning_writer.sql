begin;

-- Worker jobs are delegated operational acts. When they fail or complete with
-- failed items, the manager agent must turn that signal into learning memory
-- instead of leaving it as an isolated log row.

create or replace function public.complete_catalog_agent_worker_job(
  p_job_id bigint,
  p_summary jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_job public.catalog_agent_worker_jobs%rowtype;
  v_summary jsonb := case
    when jsonb_typeof(coalesce(p_summary, '{}'::jsonb)) = 'object' then coalesce(p_summary, '{}'::jsonb)
    else jsonb_build_object('raw_summary', p_summary)
  end;
  v_failed_count integer := 0;
  v_event_id bigint;
  v_learning_type text := 'other';
  v_learning_result jsonb;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role' then
    perform public.assert_catalog_admin(v_user);
  end if;

  if coalesce(v_summary->>'failed', '') ~ '^[0-9]+$' then
    v_failed_count := (v_summary->>'failed')::integer;
  end if;

  update public.catalog_agent_worker_jobs j
  set
    status = 'completed',
    finished_at = now(),
    summary = v_summary,
    updated_at = now()
  where j.id = p_job_id
  returning * into v_job;

  if not found then
    raise exception 'catalog_agent_worker_job_not_found: %', p_job_id
      using errcode = 'P0002';
  end if;

  if v_job.agent_run_id is not null then
    insert into public.catalog_agent_proposal_events (
      proposal_id,
      run_id,
      event_type,
      event_payload,
      created_by,
      created_at
    )
    values (
      null,
      v_job.agent_run_id,
      case
        when v_failed_count > 0 then 'worker_job_completed_with_failures'
        else 'worker_job_completed'
      end,
      jsonb_build_object(
        'worker_job_id', v_job.id,
        'worker_name', v_job.worker_name,
        'worker_function', v_job.worker_function,
        'requested_action', v_job.requested_action,
        'dry_run', v_job.dry_run,
        'failed_count', v_failed_count,
        'summary', v_summary
      ),
      v_user,
      now()
    )
    returning id into v_event_id;
  end if;

  if v_failed_count > 0 then
    v_learning_type := case
      when v_job.worker_name = 'low_risk_apply_batch' then 'manual_apply_failure'
      when v_job.worker_name = 'ingredient_creation_batch' then 'catalog_gap'
      else 'other'
    end;

    begin
      v_learning_result := public.record_catalog_agent_learning(
        p_proposal_id => null,
        p_run_id => v_job.agent_run_id,
        p_learning_type => v_learning_type,
        p_observed_problem => 'Worker completed with failed items: ' || left(v_summary::text, 1200),
        p_severity => case when v_job.dry_run then 'medium' else 'high' end,
        p_corrected_decision => 'Do not expand worker autonomy until failed items are explained and replayed safely.',
        p_policy_implication => 'Worker failures are manager-level learning signals and must influence future delegation.',
        p_evaluation_recommendation => 'Add this worker failure pattern to catalog-agent worker evaluation cases.',
        p_prompt_recommendation => 'Prefer smaller worker batches or human review when similar worker preconditions are uncertain.',
        p_validator_recommendation => 'Tighten pre-worker eligibility diagnostics for this failure pattern.',
        p_source_event_id => v_event_id,
        p_status => 'needs_review'
      );
    exception
      when others then
        raise notice 'catalog_agent_worker_learning_record_skipped: %', sqlerrm;
        v_learning_result := jsonb_build_object('ok', false, 'error', sqlerrm);
    end;
  end if;

  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'status', v_job.status,
    'failed_count', v_failed_count,
    'event_id', v_event_id,
    'learning', coalesce(v_learning_result, '{}'::jsonb)
  );
end;
$$;

create or replace function public.fail_catalog_agent_worker_job(
  p_job_id bigint,
  p_failure_reason text,
  p_summary jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_job public.catalog_agent_worker_jobs%rowtype;
  v_failure_reason text := nullif(btrim(coalesce(p_failure_reason, '')), '');
  v_summary jsonb := case
    when jsonb_typeof(coalesce(p_summary, '{}'::jsonb)) = 'object' then coalesce(p_summary, '{}'::jsonb)
    else jsonb_build_object('raw_summary', p_summary)
  end;
  v_event_id bigint;
  v_learning_type text := 'other';
  v_learning_result jsonb;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role' then
    perform public.assert_catalog_admin(v_user);
  end if;

  update public.catalog_agent_worker_jobs j
  set
    status = 'failed',
    finished_at = now(),
    failure_reason = v_failure_reason,
    summary = v_summary,
    updated_at = now()
  where j.id = p_job_id
  returning * into v_job;

  if not found then
    raise exception 'catalog_agent_worker_job_not_found: %', p_job_id
      using errcode = 'P0002';
  end if;

  if v_job.agent_run_id is not null then
    insert into public.catalog_agent_proposal_events (
      proposal_id,
      run_id,
      event_type,
      event_payload,
      created_by,
      created_at
    )
    values (
      null,
      v_job.agent_run_id,
      'worker_job_failed',
      jsonb_build_object(
        'worker_job_id', v_job.id,
        'worker_name', v_job.worker_name,
        'worker_function', v_job.worker_function,
        'requested_action', v_job.requested_action,
        'dry_run', v_job.dry_run,
        'failure_reason', coalesce(v_failure_reason, 'unspecified_worker_failure'),
        'summary', v_summary
      ),
      v_user,
      now()
    )
    returning id into v_event_id;
  end if;

  v_learning_type := case
    when v_job.worker_name = 'low_risk_apply_batch' then 'manual_apply_failure'
    when v_job.worker_name = 'ingredient_creation_batch' then 'catalog_gap'
    else 'other'
  end;

  begin
    v_learning_result := public.record_catalog_agent_learning(
      p_proposal_id => null,
      p_run_id => v_job.agent_run_id,
      p_learning_type => v_learning_type,
      p_observed_problem => 'Worker job failed: '
        || coalesce(v_failure_reason, 'unspecified_worker_failure')
        || '. Summary: '
        || left(v_summary::text, 1200),
      p_severity => 'high',
      p_corrected_decision => 'Do not retry this worker path until the failure is understood and the preconditions are repaired.',
      p_policy_implication => 'Worker failures must feed the agent delegation policy before autonomy is expanded.',
      p_evaluation_recommendation => 'Add this failed worker path to the catalog-agent regression suite.',
      p_prompt_recommendation => 'When delegating similar work, require explicit precondition evidence and a bounded fallback.',
      p_validator_recommendation => 'Add a worker preflight check for this failure mode where possible.',
      p_source_event_id => v_event_id,
      p_status => 'needs_review'
    );
  exception
    when others then
      raise notice 'catalog_agent_worker_learning_record_skipped: %', sqlerrm;
      v_learning_result := jsonb_build_object('ok', false, 'error', sqlerrm);
  end;

  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'status', v_job.status,
    'event_id', v_event_id,
    'learning', coalesce(v_learning_result, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.complete_catalog_agent_worker_job(bigint, jsonb) from public, anon;
grant execute on function public.complete_catalog_agent_worker_job(bigint, jsonb) to authenticated, service_role;

revoke all on function public.fail_catalog_agent_worker_job(bigint, text, jsonb) from public, anon;
grant execute on function public.fail_catalog_agent_worker_job(bigint, text, jsonb) to authenticated, service_role;

comment on function public.complete_catalog_agent_worker_job(bigint, jsonb) is
  'Completes a Catalog Governance Agent worker job and records learning memory when the worker completed with failed items.';

comment on function public.fail_catalog_agent_worker_job(bigint, text, jsonb) is
  'Fails a Catalog Governance Agent worker job and records manager-level learning memory for future delegation policy.';

commit;
