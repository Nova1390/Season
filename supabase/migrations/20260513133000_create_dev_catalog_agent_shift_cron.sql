begin;

-- Level 6.0 micro-scheduler: install a dev-only pg_cron entry that invokes
-- the guarded dev-shift Edge Function. The schedule is safe by construction:
-- when catalog_agent_dev_schedule_config.enabled=false, the function records
-- a skipped shift and exits before workers, LLM triage, or mutations.
--
-- Required Vault secret names, provisioned per environment outside migrations:
-- - season_dev_catalog_agent_project_url
-- - season_dev_catalog_agent_publishable_key
-- - season_dev_catalog_agent_shift_operator_token

do $$
declare
  v_job_id bigint;
  v_required_secret_count integer;
begin
  if to_regclass('cron.job') is null then
    raise notice 'cron.job relation not found; skipping dev catalog agent shift cron install';
    return;
  end if;

  if to_regclass('net.http_request_queue') is null then
    raise notice 'pg_net relation not found; skipping dev catalog agent shift cron install';
    return;
  end if;

  if to_regclass('vault.decrypted_secrets') is null then
    raise notice 'vault.decrypted_secrets relation not found; skipping dev catalog agent shift cron install';
    return;
  end if;

  select count(*)::integer
  into v_required_secret_count
  from vault.decrypted_secrets
  where name in (
    'season_dev_catalog_agent_project_url',
    'season_dev_catalog_agent_publishable_key',
    'season_dev_catalog_agent_shift_operator_token'
  );

  if v_required_secret_count <> 3 then
    raise notice 'required dev catalog agent shift Vault secrets not found; skipping cron install';
    return;
  end if;

  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'dev_catalog_agent_shift_dryrun_q2h';

  select cron.schedule(
    'dev_catalog_agent_shift_dryrun_q2h',
    '17 */2 * * *',
    $cron$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'season_dev_catalog_agent_project_url'
          limit 1
        ) || '/functions/v1/run-catalog-agent-dev-shift',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'apikey', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'season_dev_catalog_agent_publishable_key'
            limit 1
          ),
          'x-season-catalog-agent-token', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'season_dev_catalog_agent_shift_operator_token'
            limit 1
          )
        ),
        body := jsonb_build_object(
          'limit', 1,
          'dry_run', true,
          'run_low_risk_preview', true,
          'run_triage', false,
          'debug', false
        ),
        timeout_milliseconds := 60000
      ) as request_id;
    $cron$
  )
  into v_job_id;

  -- Keep the job active: the Edge Function guard is the safety boundary and
  -- will skip while the dev kill switch is on. This proves the scheduler lane
  -- without allowing work unless the guarded config is deliberately opened.
  perform cron.alter_job(
    job_id => v_job_id,
    active => true
  );
end $$;

commit;
