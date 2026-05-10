-- STAGING-ONLY kill switch for catalog autopilot v2 scheduler.
-- Reversible: rerun staging_catalog_autopilot_v2_schedule.sql to enable again.

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'staging_catalog_autopilot_v2_q6h';

SELECT jobid, jobname, schedule
FROM cron.job
WHERE jobname = 'staging_catalog_autopilot_v2_q6h';
