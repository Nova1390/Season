begin;

-- Qualify apply-audit status references in the daily digest function. The first
-- implementation joined proposal and audit rows, both of which expose `status`.

create or replace function public.catalog_agent_build_daily_digest(
  p_report_date date default current_date,
  p_environment text default 'dev'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_environment text := lower(btrim(coalesce(p_environment, 'dev')));
  v_report_date date := coalesce(p_report_date, current_date);
  v_window_start timestamptz := v_report_date::timestamptz;
  v_window_end timestamptz := (v_report_date + 1)::timestamptz;
  v_config public.catalog_agent_dev_schedule_config%rowtype;
  v_summary jsonb;
  v_anomalies jsonb := '[]'::jsonb;
  v_status text := 'green';
  v_recommended_next_action text := 'No action required.';
  v_failed_runs integer := 0;
  v_failed_worker_jobs integer := 0;
  v_stale_worker_jobs integer := 0;
  v_revert_failed integer := 0;
  v_total_tokens bigint := 0;
  v_estimated_cost numeric(12, 6) := 0;
  v_agent_runs integer := 0;
  v_worker_jobs integer := 0;
  v_real_applies integer := 0;
  v_digest public.catalog_agent_daily_digests%rowtype;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role' then
    perform public.assert_catalog_admin(v_user);
  end if;

  if v_environment not in ('dev', 'staging', 'production') then
    raise exception 'unsupported_catalog_agent_environment: %', p_environment
      using errcode = '22023';
  end if;

  select *
  into v_config
  from public.catalog_agent_dev_schedule_config c
  where c.environment = v_environment;

  if not found then
    insert into public.catalog_agent_dev_schedule_config (environment)
    values (v_environment)
    on conflict (environment) do nothing;

    select *
    into v_config
    from public.catalog_agent_dev_schedule_config c
    where c.environment = v_environment;
  end if;

  select
    count(*)::integer,
    count(*) filter (where r.status = 'failed')::integer
  into v_agent_runs, v_failed_runs
  from public.catalog_agent_runs r
  where r.environment = v_environment
    and r.created_at >= v_window_start
    and r.created_at < v_window_end;

  select
    count(*)::integer,
    count(*) filter (where w.status = 'failed')::integer,
    count(*) filter (
      where w.status in ('queued', 'running')
        and w.created_at < now() - make_interval(mins => coalesce(v_config.stale_worker_minutes, 30))
    )::integer
  into v_worker_jobs, v_failed_worker_jobs, v_stale_worker_jobs
  from public.catalog_agent_worker_jobs w
  where w.environment = v_environment
    and w.created_at >= v_window_start
    and w.created_at < v_window_end;

  select
    coalesce(sum(u.total_tokens), 0)::bigint,
    coalesce(sum(u.estimated_cost_usd), 0)::numeric(12, 6)
  into v_total_tokens, v_estimated_cost
  from public.catalog_ai_usage_events u
  where u.environment = v_environment
    and u.created_at >= v_window_start
    and u.created_at < v_window_end;

  select
    count(*) filter (where a.status = 'applied')::integer,
    count(*) filter (where a.status = 'revert_failed')::integer
  into v_real_applies, v_revert_failed
  from public.catalog_agent_apply_audit a
  join public.catalog_agent_proposals p on p.id = a.proposal_id
  join public.catalog_agent_runs r on r.id = p.run_id
  where r.environment = v_environment
    and a.created_at >= v_window_start
    and a.created_at < v_window_end;

  if v_failed_runs > coalesce(v_config.anomaly_threshold_failed_runs, 0) then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'failed_agent_runs',
      'severity', 'red',
      'count', v_failed_runs,
      'message', 'One or more catalog agent runs failed during the digest window.'
    ));
  end if;

  if v_failed_worker_jobs > coalesce(v_config.anomaly_threshold_failed_worker_jobs, 0) then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'failed_worker_jobs',
      'severity', 'red',
      'count', v_failed_worker_jobs,
      'message', 'One or more delegated worker jobs failed during the digest window.'
    ));
  end if;

  if v_stale_worker_jobs > 0 then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'stale_worker_jobs',
      'severity', 'yellow',
      'count', v_stale_worker_jobs,
      'message', 'Queued or running worker jobs are older than the configured stale-worker window.'
    ));
  end if;

  if v_agent_runs > coalesce(v_config.max_agent_runs_per_day, 0) then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'agent_run_ceiling_exceeded',
      'severity', 'red',
      'count', v_agent_runs,
      'limit', v_config.max_agent_runs_per_day,
      'message', 'Daily agent run ceiling was exceeded.'
    ));
  end if;

  if v_worker_jobs > coalesce(v_config.max_worker_jobs_per_day, 0) then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'worker_job_ceiling_exceeded',
      'severity', 'red',
      'count', v_worker_jobs,
      'limit', v_config.max_worker_jobs_per_day,
      'message', 'Daily worker job ceiling was exceeded.'
    ));
  end if;

  if v_real_applies > coalesce(v_config.max_real_applies_per_day, 0) then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'real_apply_ceiling_exceeded',
      'severity', 'red',
      'count', v_real_applies,
      'limit', v_config.max_real_applies_per_day,
      'message', 'Daily real apply ceiling was exceeded.'
    ));
  end if;

  if v_total_tokens > coalesce(v_config.max_llm_tokens_per_day, 0) then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'llm_token_ceiling_exceeded',
      'severity', 'red',
      'count', v_total_tokens,
      'limit', v_config.max_llm_tokens_per_day,
      'message', 'Daily LLM token ceiling was exceeded.'
    ));
  end if;

  if v_estimated_cost > coalesce(v_config.max_estimated_cost_usd_per_day, 0) then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'estimated_cost_ceiling_exceeded',
      'severity', 'red',
      'count', v_estimated_cost,
      'limit', v_config.max_estimated_cost_usd_per_day,
      'message', 'Daily estimated AI cost ceiling was exceeded.'
    ));
  end if;

  if v_revert_failed > 0 then
    v_anomalies := v_anomalies || jsonb_build_array(jsonb_build_object(
      'code', 'rollback_failure',
      'severity', 'red',
      'count', v_revert_failed,
      'message', 'At least one auto-apply rollback failed and requires immediate operator review.'
    ));
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_anomalies) anomaly(item)
    where anomaly.item->>'severity' = 'red'
  ) then
    v_status := 'red';
    v_recommended_next_action := 'Pause scheduled autonomy and review red anomalies before the next run.';
  elsif jsonb_array_length(v_anomalies) > 0 then
    v_status := 'yellow';
    v_recommended_next_action := 'Review yellow anomalies before increasing autonomy limits.';
  end if;

  v_summary := jsonb_build_object(
    'environment', v_environment,
    'report_date', v_report_date,
    'window_start', v_window_start,
    'window_end', v_window_end,
    'config', jsonb_build_object(
      'enabled', coalesce(v_config.enabled, false),
      'triage_enabled', coalesce(v_config.triage_enabled, false),
      'low_risk_dry_run_enabled', coalesce(v_config.low_risk_dry_run_enabled, false),
      'low_risk_apply_enabled', coalesce(v_config.low_risk_apply_enabled, false),
      'max_agent_runs_per_day', v_config.max_agent_runs_per_day,
      'max_worker_jobs_per_day', v_config.max_worker_jobs_per_day,
      'max_real_applies_per_day', v_config.max_real_applies_per_day,
      'max_llm_tokens_per_day', v_config.max_llm_tokens_per_day,
      'max_estimated_cost_usd_per_day', v_config.max_estimated_cost_usd_per_day
    ),
    'agent_runs', jsonb_build_object(
      'total', v_agent_runs,
      'failed', v_failed_runs,
      'by_status', coalesce((
        select jsonb_object_agg(run_status, run_count)
        from (
          select r.status as run_status, count(*)::integer as run_count
          from public.catalog_agent_runs r
          where r.environment = v_environment
            and r.created_at >= v_window_start
            and r.created_at < v_window_end
          group by r.status
        ) run_rollup
      ), '{}'::jsonb)
    ),
    'worker_jobs', jsonb_build_object(
      'total', v_worker_jobs,
      'failed', v_failed_worker_jobs,
      'stale', v_stale_worker_jobs,
      'by_status', coalesce((
        select jsonb_object_agg(worker_status, worker_count)
        from (
          select w.status as worker_status, count(*)::integer as worker_count
          from public.catalog_agent_worker_jobs w
          where w.environment = v_environment
            and w.created_at >= v_window_start
            and w.created_at < v_window_end
          group by w.status
        ) worker_rollup
      ), '{}'::jsonb)
    ),
    'proposals', jsonb_build_object(
      'created', coalesce((
        select count(*)::integer
        from public.catalog_agent_proposals p
        join public.catalog_agent_runs r on r.id = p.run_id
        where r.environment = v_environment
          and p.created_at >= v_window_start
          and p.created_at < v_window_end
      ), 0),
      'by_status', coalesce((
        select jsonb_object_agg(proposal_status, proposal_count)
        from (
          select p.status as proposal_status, count(*)::integer as proposal_count
          from public.catalog_agent_proposals p
          join public.catalog_agent_runs r on r.id = p.run_id
          where r.environment = v_environment
            and p.created_at >= v_window_start
            and p.created_at < v_window_end
          group by p.status
        ) proposal_status_rollup
      ), '{}'::jsonb),
      'by_risk', coalesce((
        select jsonb_object_agg(proposal_risk_level, proposal_count)
        from (
          select p.risk_level as proposal_risk_level, count(*)::integer as proposal_count
          from public.catalog_agent_proposals p
          join public.catalog_agent_runs r on r.id = p.run_id
          where r.environment = v_environment
            and p.created_at >= v_window_start
            and p.created_at < v_window_end
          group by p.risk_level
        ) proposal_risk_rollup
      ), '{}'::jsonb),
      'low_risk_apply_ready', coalesce((
        select count(*)::integer
        from public.catalog_agent_proposals p
        join public.catalog_agent_runs r on r.id = p.run_id
        where r.environment = v_environment
          and p.status = 'validated'
          and p.risk_level = 'low'
          and p.auto_apply_eligible
      ), 0)
    ),
    'apply_audit', jsonb_build_object(
      'real_applies', v_real_applies,
      'rollback_failures', v_revert_failed,
      'by_status', coalesce((
        select jsonb_object_agg(apply_status, apply_count)
        from (
          select a.status as apply_status, count(*)::integer as apply_count
          from public.catalog_agent_apply_audit a
          join public.catalog_agent_proposals p on p.id = a.proposal_id
          join public.catalog_agent_runs r on r.id = p.run_id
          where r.environment = v_environment
            and a.created_at >= v_window_start
            and a.created_at < v_window_end
          group by a.status
        ) apply_rollup
      ), '{}'::jsonb)
    ),
    'ai_usage', jsonb_build_object(
      'total_tokens', v_total_tokens,
      'estimated_cost_usd', v_estimated_cost,
      'by_function', coalesce((
        select jsonb_object_agg(function_name, totals)
        from (
          select
            u.function_name,
            jsonb_build_object(
              'calls', count(*)::integer,
              'total_tokens', coalesce(sum(u.total_tokens), 0)::bigint,
              'estimated_cost_usd', coalesce(sum(u.estimated_cost_usd), 0)::numeric(12, 6)
            ) as totals
          from public.catalog_ai_usage_events u
          where u.environment = v_environment
            and u.created_at >= v_window_start
            and u.created_at < v_window_end
          group by u.function_name
        ) usage_rollup
      ), '{}'::jsonb)
    )
  );

  insert into public.catalog_agent_daily_digests (
    environment,
    report_date,
    window_start,
    window_end,
    status,
    anomaly_count,
    summary,
    anomalies,
    recommended_next_action,
    created_at,
    updated_at
  )
  values (
    v_environment,
    v_report_date,
    v_window_start,
    v_window_end,
    v_status,
    jsonb_array_length(v_anomalies),
    v_summary,
    v_anomalies,
    v_recommended_next_action,
    now(),
    now()
  )
  on conflict (environment, report_date) do update
  set
    window_start = excluded.window_start,
    window_end = excluded.window_end,
    status = excluded.status,
    anomaly_count = excluded.anomaly_count,
    summary = excluded.summary,
    anomalies = excluded.anomalies,
    recommended_next_action = excluded.recommended_next_action,
    updated_at = now()
  returning * into v_digest;

  return jsonb_build_object(
    'ok', true,
    'digest_id', v_digest.id,
    'environment', v_digest.environment,
    'report_date', v_digest.report_date,
    'status', v_digest.status,
    'anomaly_count', v_digest.anomaly_count,
    'recommended_next_action', v_digest.recommended_next_action,
    'summary', v_digest.summary,
    'anomalies', v_digest.anomalies
  );
end;
$$;

comment on function public.catalog_agent_build_daily_digest(date, text) is
  'Builds and stores the daily scheduled-autonomy digest with anomaly classification.';

commit;
