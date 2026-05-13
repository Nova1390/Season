begin;

-- A scheduled low-risk dry-run is intentionally non-mutating and does not
-- spend LLM tokens. Keep the guard strict for triage and real apply, but do
-- not let manual same-day LLM/reconciliation work block a harmless scheduled
-- dry-run preview.

create or replace function public.catalog_agent_dev_schedule_guard(
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
  v_config public.catalog_agent_dev_schedule_config%rowtype;
  v_today date := current_date;
  v_window_start timestamptz := current_date::timestamptz;
  v_window_end timestamptz := (current_date + 1)::timestamptz;
  v_agent_runs integer := 0;
  v_scheduled_shift_runs integer := 0;
  v_worker_jobs integer := 0;
  v_real_applies integer := 0;
  v_total_tokens bigint := 0;
  v_estimated_cost numeric(12, 6) := 0;
  v_common_reasons text[] := array[]::text[];
  v_dry_run_reasons text[] := array[]::text[];
  v_triage_reasons text[] := array[]::text[];
  v_apply_reasons text[] := array[]::text[];
  v_dry_run_allowed boolean := false;
  v_triage_allowed boolean := false;
  v_apply_allowed boolean := false;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role' then
    perform public.assert_catalog_admin(v_user);
  end if;

  if v_environment <> 'dev' then
    return jsonb_build_object(
      'ok', false,
      'environment', v_environment,
      'reason', 'scheduled_autonomy_dev_only'
    );
  end if;

  select *
  into v_config
  from public.catalog_agent_dev_schedule_config c
  where c.environment = v_environment;

  if not found or not coalesce(v_config.enabled, false) then
    return jsonb_build_object(
      'ok', false,
      'environment', v_environment,
      'reason', 'schedule_disabled',
      'kill_switch', true,
      'enabled_until', v_config.enabled_until,
      'window_label', v_config.window_label
    );
  end if;

  if v_config.enabled_until is null then
    return jsonb_build_object(
      'ok', false,
      'environment', v_environment,
      'reason', 'schedule_window_missing_expiry',
      'kill_switch', true,
      'window_label', v_config.window_label
    );
  end if;

  if now() >= v_config.enabled_until then
    return jsonb_build_object(
      'ok', false,
      'environment', v_environment,
      'reason', 'schedule_window_expired',
      'kill_switch', true,
      'enabled_until', v_config.enabled_until,
      'window_label', v_config.window_label
    );
  end if;

  select count(*)::integer
  into v_agent_runs
  from public.catalog_agent_runs r
  where r.environment = v_environment
    and r.created_at >= v_window_start
    and r.created_at < v_window_end;

  select count(*)::integer
  into v_scheduled_shift_runs
  from public.catalog_agent_dev_shift_runs s
  where s.environment = v_environment
    and s.created_at >= v_window_start
    and s.created_at < v_window_end;

  select count(*)::integer
  into v_worker_jobs
  from public.catalog_agent_worker_jobs w
  where w.environment = v_environment
    and w.created_at >= v_window_start
    and w.created_at < v_window_end;

  select count(*)::integer
  into v_real_applies
  from public.catalog_agent_apply_audit a
  join public.catalog_agent_proposals p on p.id = a.proposal_id
  join public.catalog_agent_runs r on r.id = p.run_id
  where r.environment = v_environment
    and a.status = 'applied'
    and a.created_at >= v_window_start
    and a.created_at < v_window_end;

  select
    coalesce(sum(total_tokens), 0)::bigint,
    coalesce(sum(estimated_cost_usd), 0)::numeric(12, 6)
  into v_total_tokens, v_estimated_cost
  from public.catalog_ai_usage_events u
  where u.environment = v_environment
    and u.created_at >= v_window_start
    and u.created_at < v_window_end;

  if v_worker_jobs >= v_config.max_worker_jobs_per_day then
    v_common_reasons := array_append(v_common_reasons, 'worker_job_limit_reached');
  end if;

  v_dry_run_reasons := v_common_reasons;
  v_triage_reasons := v_common_reasons;
  v_apply_reasons := v_common_reasons;

  if v_scheduled_shift_runs >= v_config.max_agent_runs_per_day then
    v_dry_run_reasons := array_append(v_dry_run_reasons, 'scheduled_shift_limit_reached');
  end if;

  if v_agent_runs >= v_config.max_agent_runs_per_day then
    v_triage_reasons := array_append(v_triage_reasons, 'agent_run_limit_reached');
    v_apply_reasons := array_append(v_apply_reasons, 'agent_run_limit_reached');
  end if;

  if v_real_applies >= v_config.max_real_applies_per_day then
    v_apply_reasons := array_append(v_apply_reasons, 'real_apply_limit_reached');
  end if;

  if v_total_tokens >= v_config.max_llm_tokens_per_day then
    v_triage_reasons := array_append(v_triage_reasons, 'llm_token_limit_reached');
  end if;

  if v_estimated_cost >= v_config.max_estimated_cost_usd_per_day then
    v_triage_reasons := array_append(v_triage_reasons, 'estimated_cost_limit_reached');
  end if;

  v_dry_run_allowed := coalesce(v_config.low_risk_dry_run_enabled, false)
    and cardinality(v_dry_run_reasons) = 0;
  v_triage_allowed := coalesce(v_config.triage_enabled, false)
    and cardinality(v_triage_reasons) = 0;
  v_apply_allowed := coalesce(v_config.low_risk_apply_enabled, false)
    and cardinality(v_apply_reasons) = 0;

  return jsonb_build_object(
    'ok', v_dry_run_allowed or v_triage_allowed or v_apply_allowed,
    'environment', v_environment,
    'report_date', v_today,
    'reasons', jsonb_build_object(
      'low_risk_dry_run', to_jsonb(v_dry_run_reasons),
      'triage', to_jsonb(v_triage_reasons),
      'low_risk_apply', to_jsonb(v_apply_reasons)
    ),
    'enabled_until', v_config.enabled_until,
    'window_label', v_config.window_label,
    'allowed', jsonb_build_object(
      'triage', v_triage_allowed,
      'low_risk_dry_run', v_dry_run_allowed,
      'low_risk_apply', v_apply_allowed
    ),
    'usage', jsonb_build_object(
      'agent_runs', v_agent_runs,
      'scheduled_shift_runs', v_scheduled_shift_runs,
      'worker_jobs', v_worker_jobs,
      'real_applies', v_real_applies,
      'total_tokens', v_total_tokens,
      'estimated_cost_usd', v_estimated_cost
    ),
    'limits', jsonb_build_object(
      'max_agent_runs_per_day', v_config.max_agent_runs_per_day,
      'max_worker_jobs_per_day', v_config.max_worker_jobs_per_day,
      'max_real_applies_per_day', v_config.max_real_applies_per_day,
      'max_llm_tokens_per_day', v_config.max_llm_tokens_per_day,
      'max_estimated_cost_usd_per_day', v_config.max_estimated_cost_usd_per_day
    )
  );
end;
$$;

comment on function public.catalog_agent_dev_schedule_guard(text) is
  'Dev-only scheduled autonomy guard. Action-specific budgets allow harmless low-risk dry-run previews while keeping LLM triage and real apply blocked by their own limits.';

commit;
