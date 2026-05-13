# Catalog Agent Dev Scheduler Runbook

Status: dev-only operating guide. Staging is out of scope until Level 6.5.

This runbook explains how to run or enable the Catalog Governance Agent dev-shift lane without creating silent catalog drift or surprise LLM spend.

## Purpose

The dev scheduler is a controlled shift lane for routine catalog work. It is not a free-running agent.

It must always:

- run only against `Season-dev`;
- check `catalog_agent_dev_schedule_guard('dev')` before work;
- keep real low-risk apply disabled unless a separate Level 5.0 window explicitly enables it;
- record every shift in `catalog_agent_dev_shift_runs`;
- refresh `catalog_agent_daily_digests`;
- stop on budget, kill-switch, or anomaly limits.

## Normal Safe State

The expected safe default is:

- `catalog_agent_dev_schedule_config.enabled = false`;
- `enabled_until = null`;
- `window_label = null`;
- `triage_enabled = false`;
- `low_risk_dry_run_enabled = true`;
- `low_risk_apply_enabled = false`;
- `CATALOG_AGENT_ORCHESTRATOR_ENABLED = false`;
- `dev_catalog_agent_shift_dryrun_q2h` cron is active but guarded by the kill switch.

In this state, a scheduled or manual function call should return `skipped=true` and `reason=schedule_disabled`.

If `enabled=true` but `enabled_until` is null, the guard must return `schedule_window_missing_expiry`. This is intentional: every scheduler window needs an expiry.

If `enabled=true` but `enabled_until <= now()`, the guard must return `schedule_window_expired`.

The admin console should show:

- `Guard`: `Schedule disabled`;
- `Kill switch`: `On`;
- `Shift health`: `Green` after a clean skipped shift, or `Idle` before any shift attempts;
- `Shift runs today`: count of attempts in `catalog_agent_dev_shift_runs`.

## Scheduler Job

Current dev scheduler:

- job name: `dev_catalog_agent_shift_dryrun_q2h`;
- schedule: `17 */2 * * *`;
- project: `Season-dev`;
- function: `run-catalog-agent-dev-shift`;
- payload: `limit=1`, `dry_run=true`, `run_low_risk_preview=true`, `run_triage=false`;
- real apply: not wired;
- triage LLM: not wired;
- auth: dedicated operator token.

The cron command reads credentials from Supabase Vault. It must not contain service-role JWTs or literal operator tokens.

Required Vault secret names:

- `season_dev_catalog_agent_project_url`;
- `season_dev_catalog_agent_publishable_key`;
- `season_dev_catalog_agent_shift_operator_token`.

## Manual Dry-Shift Smoke

Use the repeatable script when validating the lane:

```bash
SUPABASE_ACCESS_TOKEN="<pat>" scripts/catalog_agent_dev_shift_smoke.sh
```

Expected behavior:

- temporary operator token is created only for the smoke;
- schedule config is temporarily opened for dry-run preview only;
- `run-catalog-agent-dev-shift` can launch `low_risk_apply_batch` in dry-run mode;
- `applied = 0`;
- no LLM triage is triggered unless an explicit future triage step enables it;
- temporary token is removed;
- final guard returns `schedule_disabled`.

Latest validation evidence:

- 2026-05-13: two controlled dry-shift smokes passed;
- runs: `#72` and `#73`;
- worker jobs: `#27` and `#28`;
- both ran `low_risk_apply_batch` in dry-run mode;
- both returned `0` eligible preview, `0` applied, and `0` failed;
- no scheduled triage LLM call was triggered;
- final `catalog_agent_dev_shift_health` was `green`.

Scheduler install evidence:

- migration `20260513133000_create_dev_catalog_agent_shift_cron.sql` installed cron job `#3`;
- job `#3` is active and uses Vault references;
- cron command does not mention service-role and does not expose the operator token;
- first real cron tick succeeded at `2026-05-13 14:17:00 UTC`;
- cron-created shift `#4` was skipped with `schedule_disabled`;
- manual scheduler-token verification created shift `#5`, also skipped with `schedule_disabled`;
- final shift health remained `green`: `5` shift attempts today, `2` completed, `3` skipped, `0` failed.

Window-expiry validation:

- migration `20260513143000_add_dev_schedule_window_expiry.sql` added `enabled_until` and `window_label`;
- `catalog_agent_dev_schedule_guard('dev')` now blocks enabled windows without expiry;
- missing-expiry smoke returned `schedule_window_missing_expiry`;
- final schedule status returned `disabled` with `enabled_until=null` and `window_label=null`.

## Reading Results

Prefer these read models before inspecting raw tables:

- `catalog_agent_dev_shift_health`: current shift-lane health;
- `catalog_agent_dev_schedule_status`: kill switch plus latest digest summary;
- `catalog_agent_daily_digests`: broader daily anomaly report.

Important distinction:

- `catalog_agent_daily_digests.status = red` can be expected on a manual-heavy development day because total runs, worker jobs, or LLM tokens exceed scheduler limits.
- `catalog_agent_dev_shift_health.shift_health_status = green` means the scheduled-shift lane itself behaved correctly.

## Temporary Enablement Window

Only use a temporary window for a bounded smoke or controlled test.

Before opening:

- confirm the linked Supabase project is `Season-dev`;
- confirm no staging deploy or TestFlight release task depends on this database state;
- confirm budget is acceptable for the intended run;
- confirm the admin console is reachable at `https://catalog.seasonapp.it/`;
- confirm the current PAT is intended for active development and will be rotated later.
- choose a short `enabled_until` before setting `enabled=true`.

During the window:

- keep `triage_enabled=false` unless the purpose is explicitly to test LLM triage;
- keep `low_risk_apply_enabled=false` unless running a separate approved Level 5.0 real-apply window;
- keep `limit` at `1` unless the runbook for that exact test says otherwise;
- set `window_label` to the purpose of the window;
- watch the console `Shift health` and `Recent dev shifts` panel.

After the window:

- set `enabled=false`;
- set `enabled_until=null`;
- set `window_label=null`;
- set `CATALOG_AGENT_ORCHESTRATOR_ENABLED=false`;
- remove any temporary operator token;
- run the final guard check;
- run Supabase lint;
- document run ids, worker ids, and whether any LLM tokens were consumed.

## Hard Stops

Stop immediately and keep the scheduler disabled if any of these happen:

- `catalog_agent_dev_shift_health.shift_health_status = red`;
- latest shift is `started` for more than 15 minutes;
- any real apply happens from the scheduled lane;
- a worker fails repeatedly;
- daily LLM token or cost ceiling is exceeded by scheduled work, not just manual tests;
- rollback fails;
- admin console is not reachable or cannot distinguish digest health from shift health.

## Recovery

First action is always to disable the lane:

```sql
update public.catalog_agent_dev_schedule_config
set enabled = false,
    triage_enabled = false,
    low_risk_apply_enabled = false,
    enabled_until = null,
    window_label = null,
    updated_at = now()
where environment = 'dev';
```

If the scheduler itself needs to be paused, disable the cron job too:

```sql
do $$
declare
  v_job_id bigint;
begin
  select jobid
  into v_job_id
  from cron.job
  where jobname = 'dev_catalog_agent_shift_dryrun_q2h'
  limit 1;

  if v_job_id is not null then
    perform cron.alter_job(job_id => v_job_id, active => false);
  end if;
end $$;
```

Then:

- remove temporary operator tokens from Supabase secrets;
- refresh `catalog_agent_build_daily_digest(current_date, 'dev')`;
- inspect `catalog_agent_dev_shift_runs` for failed or stale rows;
- inspect `catalog_agent_worker_jobs` for unfinished workers;
- inspect `catalog_agent_apply_audit` if any mutation occurred;
- write a learning-memory or docs update for repeated failure classes.

## Promotion Rule

This runbook does not authorize staging.

Staging promotion requires Level 6.5 gates:

- PAT rotation;
- staging-specific secrets;
- staging Security Advisor review;
- staging dry-run only;
- explicit release-governance approval.
