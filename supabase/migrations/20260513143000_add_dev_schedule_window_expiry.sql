begin;

alter table public.catalog_agent_dev_schedule_config
  add column if not exists enabled_until timestamptz,
  add column if not exists window_label text;

comment on column public.catalog_agent_dev_schedule_config.enabled_until is
  'Required expiry for any enabled scheduled-dev autonomy window. Null is allowed only while enabled=false.';

comment on column public.catalog_agent_dev_schedule_config.window_label is
  'Human-readable reason for the current temporary scheduler window.';

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
  v_worker_jobs integer := 0;
  v_real_applies integer := 0;
  v_total_tokens bigint := 0;
  v_estimated_cost numeric(12, 6) := 0;
  v_reasons text[] := array[]::text[];
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

  if v_agent_runs >= v_config.max_agent_runs_per_day then
    v_reasons := array_append(v_reasons, 'agent_run_limit_reached');
  end if;

  if v_worker_jobs >= v_config.max_worker_jobs_per_day then
    v_reasons := array_append(v_reasons, 'worker_job_limit_reached');
  end if;

  if v_real_applies >= v_config.max_real_applies_per_day then
    v_reasons := array_append(v_reasons, 'real_apply_limit_reached');
  end if;

  if v_total_tokens >= v_config.max_llm_tokens_per_day then
    v_reasons := array_append(v_reasons, 'llm_token_limit_reached');
  end if;

  if v_estimated_cost >= v_config.max_estimated_cost_usd_per_day then
    v_reasons := array_append(v_reasons, 'estimated_cost_limit_reached');
  end if;

  return jsonb_build_object(
    'ok', cardinality(v_reasons) = 0,
    'environment', v_environment,
    'report_date', v_today,
    'reasons', to_jsonb(v_reasons),
    'enabled_until', v_config.enabled_until,
    'window_label', v_config.window_label,
    'allowed', jsonb_build_object(
      'triage', coalesce(v_config.triage_enabled, false) and cardinality(v_reasons) = 0,
      'low_risk_dry_run', coalesce(v_config.low_risk_dry_run_enabled, false) and cardinality(v_reasons) = 0,
      'low_risk_apply', coalesce(v_config.low_risk_apply_enabled, false) and cardinality(v_reasons) = 0
    ),
    'usage', jsonb_build_object(
      'agent_runs', v_agent_runs,
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

drop view if exists public.catalog_agent_dev_schedule_status;

create view public.catalog_agent_dev_schedule_status
with (security_invoker = true)
as
select
  c.environment,
  c.enabled,
  c.enabled_until,
  c.window_label,
  case
    when not coalesce(c.enabled, false) then 'disabled'
    when c.enabled_until is null then 'missing_expiry'
    when now() >= c.enabled_until then 'expired'
    else 'open'
  end as window_status,
  c.triage_enabled,
  c.low_risk_dry_run_enabled,
  c.low_risk_apply_enabled,
  c.max_agent_runs_per_day,
  c.max_worker_jobs_per_day,
  c.max_real_applies_per_day,
  c.max_llm_tokens_per_day,
  c.max_estimated_cost_usd_per_day,
  d.report_date as latest_report_date,
  d.status as latest_digest_status,
  d.anomaly_count as latest_anomaly_count,
  d.recommended_next_action as latest_recommended_next_action,
  d.updated_at as latest_digest_updated_at
from public.catalog_agent_dev_schedule_config c
left join lateral (
  select *
  from public.catalog_agent_daily_digests d
  where d.environment = c.environment
  order by d.report_date desc
  limit 1
) d on true;

grant select on public.catalog_agent_dev_schedule_status to authenticated, service_role;

comment on view public.catalog_agent_dev_schedule_status is
  'Read model for admin console schedule configuration, window expiry, and latest digest status.';

commit;
