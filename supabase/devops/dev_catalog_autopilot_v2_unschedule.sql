-- DEV-ONLY kill switch for catalog autopilot v2 scheduler.
-- Reversible: rerun dev_catalog_autopilot_v2_schedule.sql to enable again.

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'dev_catalog_autopilot_v2_q6h';

SELECT jobid, jobname, schedule
FROM cron.job
WHERE jobname = 'dev_catalog_autopilot_v2_q6h';
