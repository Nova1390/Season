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
- `triage_enabled = false`;
- `low_risk_dry_run_enabled = true`;
- `low_risk_apply_enabled = false`;
- `CATALOG_AGENT_ORCHESTRATOR_ENABLED = false`;
- no scheduler cron is active.

In this state, a manual function call should return `skipped=true` and `reason=schedule_disabled`.

The admin console should show:

- `Guard`: `Schedule disabled`;
- `Kill switch`: `On`;
- `Shift health`: `Green` after a clean skipped shift, or `Idle` before any shift attempts;
- `Shift runs today`: count of attempts in `catalog_agent_dev_shift_runs`.

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

During the window:

- keep `triage_enabled=false` unless the purpose is explicitly to test LLM triage;
- keep `low_risk_apply_enabled=false` unless running a separate approved Level 5.0 real-apply window;
- keep `limit` at `1` unless the runbook for that exact test says otherwise;
- watch the console `Shift health` and `Recent dev shifts` panel.

After the window:

- set `enabled=false`;
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
    updated_at = now()
where environment = 'dev';
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
