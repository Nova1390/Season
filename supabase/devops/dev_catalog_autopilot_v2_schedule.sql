-- DEV-ONLY scheduler setup for catalog autopilot v2.
-- This is intentionally NOT a migration: run only against DEV.
--
-- Required input:
--   Replace DEV_SERVICE_ROLE_KEY with the DEV service role key before execution.
--
-- Conservative policy (every 6 hours):
--   recovery_limit=1000, enrich_limit=20, create_limit=10,
--   apply_aliases=true, apply_localizations=true, apply_reconciliation=true,
--   dry_run=false, debug=false

DO $$
DECLARE
  v_service_key text := 'DEV_SERVICE_ROLE_KEY';
  v_command text;
  v_job_id bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE EXCEPTION 'pg_cron extension is required for scheduler setup';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE EXCEPTION 'pg_net extension is required for scheduler setup';
  END IF;

  -- sanitize accidental wrapper quotes from shell/env injection
  v_service_key := replace(v_service_key, chr(8220), '');
  v_service_key := replace(v_service_key, chr(8221), '');
  v_service_key := trim(both '"' from v_service_key);
  v_service_key := trim(both '''' from v_service_key);
  v_service_key := btrim(v_service_key);

  IF coalesce(trim(v_service_key), '') = ''
     OR trim(v_service_key) = 'DEV_SERVICE_ROLE_KEY' THEN
    RAISE EXCEPTION 'Replace DEV_SERVICE_ROLE_KEY with DEV service role key before running this script';
  END IF;

  -- idempotent replace
  FOR v_job_id IN
    SELECT jobid
    FROM cron.job
    WHERE jobname = 'dev_catalog_autopilot_v2_q6h'
  LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;

  v_command := format($cmd$
    SELECT net.http_post(
      url := 'https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-automation-cycle',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', %1$L,
        'Authorization', 'Bearer ' || %1$L,
        'x-season-autopilot', 'dev-v2-q6h'
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
      )
    ) AS request_id;
  $cmd$, v_service_key);

  PERFORM cron.schedule(
    'dev_catalog_autopilot_v2_q6h',
    '0 */6 * * *',
    v_command
  );
END $$;

-- quick visibility for operator
SELECT jobid, jobname, schedule, command
FROM cron.job
WHERE jobname = 'dev_catalog_autopilot_v2_q6h';
