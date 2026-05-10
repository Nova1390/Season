-- STAGING-ONLY scheduler setup for catalog autopilot v2.
-- This is intentionally NOT a migration: run only against STAGING.
--
-- Required input:
--   Replace STAGING_SERVICE_ROLE_KEY with the STAGING service role key before execution.
--
-- Conservative TestFlight policy (every 6 hours):
--   recovery_limit=1000, enrich_limit=20, create_limit=10,
--   apply_aliases=true, apply_localizations=true, apply_reconciliation=true,
--   dry_run=false, debug=false

DO $$
DECLARE
  v_service_key text := 'STAGING_SERVICE_ROLE_KEY';
  v_command text;
  v_job_id bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE EXCEPTION 'pg_cron extension is required for scheduler setup';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE EXCEPTION 'pg_net extension is required for scheduler setup';
  END IF;

  -- Sanitize accidental wrapper quotes from shell/env injection.
  v_service_key := replace(v_service_key, chr(8220), '');
  v_service_key := replace(v_service_key, chr(8221), '');
  v_service_key := trim(both '"' from v_service_key);
  v_service_key := trim(both '''' from v_service_key);
  v_service_key := btrim(v_service_key);

  IF coalesce(trim(v_service_key), '') = ''
     OR trim(v_service_key) = 'STAGING_SERVICE_ROLE_KEY' THEN
    RAISE EXCEPTION 'Replace STAGING_SERVICE_ROLE_KEY with STAGING service role key before running this script';
  END IF;

  -- Idempotent replace.
  FOR v_job_id IN
    SELECT jobid
    FROM cron.job
    WHERE jobname = 'staging_catalog_autopilot_v2_q6h'
  LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;

  v_command := format($cmd$
    SELECT net.http_post(
      url := 'https://czdsnnsizyhldiurlmxd.supabase.co/functions/v1/run-catalog-automation-cycle',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', %1$L,
        'Authorization', 'Bearer ' || %1$L,
        'x-season-autopilot', 'staging-v2-q6h'
      ),
      body := jsonb_build_object(
        'recovery_limit', 1000,
        'enrich_limit', 20,
        'create_limit', 10,
        'apply_aliases', true,
        'apply_localizations', true,
        'apply_reconciliation', true,
        'dry_run', false,
        'debug', false
      ),
      timeout_milliseconds := 60000
    ) AS request_id;
  $cmd$, v_service_key);

  PERFORM cron.schedule(
    'staging_catalog_autopilot_v2_q6h',
    '15 */6 * * *',
    v_command
  );
END $$;

SELECT jobid, jobname, schedule, command
FROM cron.job
WHERE jobname = 'staging_catalog_autopilot_v2_q6h';
