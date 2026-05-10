-- Make the dev autopilot cron invocation compatible with the real automation
-- runtime. The default pg_net timeout is 5s, while enrichment + creation can
-- legitimately take longer.

do $$
declare
  v_job_id bigint;
  v_command text;
  v_updated_command text;
begin
  if to_regclass('cron.job') is null then
    raise notice 'cron.job relation not found; skipping dev autopilot timeout update';
    return;
  end if;

  select jobid, command
  into v_job_id, v_command
  from cron.job
  where jobname = 'dev_catalog_autopilot_v2_q6h'
  limit 1;

  if v_job_id is null then
    raise notice 'dev_catalog_autopilot_v2_q6h cron job not found; skipping timeout update';
    return;
  end if;

  if v_command ilike '%timeout_milliseconds%' then
    v_updated_command := regexp_replace(
      v_command,
      'timeout_milliseconds\s*:=\s*[0-9]+',
      'timeout_milliseconds := 60000',
      'gi'
    );
  else
    v_updated_command := regexp_replace(
      v_command,
      '\n\s*\)\s+AS request_id;',
      ',\n      timeout_milliseconds := 60000\n    ) AS request_id;',
      'i'
    );
  end if;

  perform cron.alter_job(
    job_id => v_job_id,
    command => v_updated_command,
    active => true
  );
end $$;
