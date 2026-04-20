-- DEV-ONLY observability checks for scheduled catalog autopilot runs.

-- 1) Scheduler presence
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'dev_catalog_autopilot_v2_q6h';

-- 2) Recent cron executions for this job (latest first)
WITH target AS (
  SELECT jobid
  FROM cron.job
  WHERE jobname = 'dev_catalog_autopilot_v2_q6h'
)
SELECT
  d.jobid,
  d.runid,
  d.status,
  d.return_message,
  d.start_time,
  d.end_time
FROM cron.job_run_details d
JOIN target t
  ON t.jobid = d.jobid
ORDER BY d.runid DESC
LIMIT 20;

-- 3) Next run quick check
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'dev_catalog_autopilot_v2_q6h';
