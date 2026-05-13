# Catalog Agent Scheduled Dev Autonomy

Status: Level 6.0 foundation, dev-only, disabled by default.

This document describes how Season should let the Catalog Governance Agent work scheduled dev shifts without creating uncontrolled catalog drift or unexpected API spend.

## Operating Model

The scheduled agent is not a free-running bot. It is a bounded shift worker:

- it may run only in `Season-dev`;
- it must pass `catalog_agent_dev_schedule_guard(...)` before doing scheduled work;
- it must respect the kill switch and daily ceilings;
- it must write a daily digest after each shift window;
- it must stop rather than retry blindly when limits or anomalies appear.

The goal is to reduce routine founder review, not to hide risk.

## New Database Objects

`catalog_agent_dev_schedule_config`

- Stores the environment kill switch.
- Stores the expiry and label for temporary scheduler windows.
- Stores daily ceilings for agent runs, worker jobs, real applies, LLM tokens, and estimated AI cost.
- Defaults `dev` to disabled.
- Keeps low-risk dry-run enabled by default.
- Keeps real low-risk apply disabled by default.

`catalog_agent_daily_digests`

- Stores one durable shift report per environment and day.
- Summarizes agent runs, worker jobs, proposals, apply audit, and AI usage.
- Classifies the day as `green`, `yellow`, or `red`.
- Stores actionable anomaly records and a recommended next action.

`catalog_agent_dev_schedule_guard(...)`

- Returns `ok=false` when the kill switch is off.
- Returns `ok=false` when a schedule window is enabled without `enabled_until`.
- Returns `ok=false` when the schedule window has expired.
- Returns `ok=false` when any daily ceiling is reached.
- Returns allowed action flags for triage, dry-run worker, and real low-risk apply.
- Rejects non-dev environments for scheduled autonomy.

`catalog_agent_build_daily_digest(...)`

- Builds and upserts the daily digest.
- Flags failed runs, failed workers, stale workers, exceeded ceilings, token/cost overages, and rollback failures.
- Returns the stored digest payload for console and smoke-test usage.

`catalog_agent_dev_schedule_status`

- Admin-console read model that joins the current schedule config with the latest digest.

`catalog_agent_dev_shift_runs`

- Stores one row for every attempted scheduled dev shift.
- Separates shift-lane health from the broader daily digest.
- Records guard snapshot, worker results, skipped workers, digest snapshot, errors, and duration.
- Lets us prove whether scheduled autonomy itself is healthy even when a manual-heavy dev day makes the global digest red.

`catalog_agent_dev_shift_health`

- Admin-console read model for today's dev-shift lane.
- Reports completed, skipped, failed, and total shift runs.
- Classifies shift health as `green`, `yellow`, `red`, or `idle`.
- Explains the common case where the dev-shift lane is healthy but the daily digest is red because of manual testing noise.

`run-catalog-agent-dev-shift`

- Dev-only Edge Function entrypoint for a future scheduler.
- Calls `catalog_agent_dev_schedule_guard('dev')` before doing any work.
- Returns a skipped shift when the kill switch is off.
- Always refreshes the daily digest.
- Writes `catalog_agent_dev_shift_runs` for skipped, completed, and failed shifts.
- Can run low-risk apply preview only when the guard allows it.
- Does not run real low-risk apply from schedule yet.
- Recognizes but does not yet execute triage scheduling, preventing accidental LLM spend.

## Safety Defaults

The initial dev row is intentionally conservative:

- `enabled = false`
- `triage_enabled = false`
- `low_risk_dry_run_enabled = true`
- `low_risk_apply_enabled = false`
- `max_agent_runs_per_day = 3`
- `max_worker_jobs_per_day = 5`
- `max_real_applies_per_day = 1`
- `max_llm_tokens_per_day = 80000`
- `max_estimated_cost_usd_per_day = 1.000000`

This means the scheduler infrastructure can be deployed and inspected without starting autonomous work.

## Scheduler Policy

Before enabling a real scheduler:

1. Level 5.0 must have more dev low-risk apply history.
2. Rollback smoke must stay green.
3. Supabase lint must stay clean.
4. The admin console must surface the latest digest clearly.
5. The Supabase PAT used during development should be rotated before any staging-facing automation.

The first scheduler should run dry-only:

1. Call `catalog_agent_dev_schedule_guard('dev')`.
2. If `ok=false`, stop and build a digest.
3. If `allowed.triage=true`, run one small triage batch.
4. If `allowed.low_risk_dry_run=true`, run low-risk apply in dry-run mode only.
5. Build `catalog_agent_build_daily_digest(current_date, 'dev')`.

Real low-risk apply remains a separate escalation and should stay disabled until the Level 5.0 gates are stronger.

Operational details live in `docs/catalog-agent-dev-scheduler-runbook.md`.

## Anomaly Semantics

`red` means stop scheduled autonomy and review before the next run:

- failed agent runs exceed threshold;
- failed worker jobs exceed threshold;
- daily run/job/apply/token/cost ceiling exceeded;
- rollback failure detected.

`yellow` means review before increasing autonomy:

- stale queued/running worker jobs;
- non-critical anomalies that do not prove unsafe mutation.

`green` means no detected anomalies in the digest window.

## Current Dev Status

As of 2026-05-13:

- Level 5.0 rollback smoke passed repeatedly.
- One new low-risk apply batch applied `cipolle -> onion` safely on dev.
- The scheduled-autonomy config/digest layer is being introduced.
- No dev schedule is enabled yet.
- No staging schedule exists.
- `run-catalog-agent-dev-shift` exists as a manual/scheduler entrypoint, but default dev config still blocks work through the kill switch.

## Dev Smoke Evidence

2026-05-13:

- applied migration `20260513113000_catalog_agent_dev_schedule_digest.sql` to `Season-dev`;
- applied follow-up migration `20260513114500_fix_catalog_agent_daily_digest_apply_status.sql` after smoke caught an ambiguous `status` reference between proposal and apply-audit rows;
- script `scripts/catalog_agent_daily_digest_smoke.sh` passed;
- guard result: `ok=false`, `reason=schedule_disabled`, `kill_switch=true`;
- digest id: `1`;
- digest date: `2026-05-13`;
- digest status: `red`;
- anomaly count: `4`;
- detected anomalies: failed agent run, agent run ceiling exceeded, worker job ceiling exceeded, and LLM token ceiling exceeded;
- interpretation: expected for a manual development day with many controlled test runs; the important behavior is that scheduled autonomy would stop rather than continue;
- Supabase lint result: `No schema errors found`.
- deployed Edge Function `run-catalog-agent-dev-shift` to `Season-dev`;
- unauthenticated smoke returned `UNAUTHORIZED`;
- temporary operator-token smoke returned `ok=true`, `skipped=true`, `reason=schedule_disabled`, and refreshed digest `1`;
- the temporary operator token was removed immediately after the smoke;
- post-removal smoke with the same token returned `UNAUTHORIZED`.

Controlled dry-shift smoke:

- temporarily enabled only the dev schedule guard path with higher same-day ceilings because manual test activity had already exceeded the default scheduled-day limits;
- kept `triage_enabled=false`;
- kept `low_risk_apply_enabled=false`;
- temporarily set `CATALOG_AGENT_ORCHESTRATOR_ENABLED=true`;
- used a temporary operator token only for the smoke;
- invoked `run-catalog-agent-dev-shift` with `limit=1`, `dry_run=true`, `run_low_risk_preview=true`, and `run_triage=false`;
- guard result before work: `ok=true`;
- allowed actions: `low_risk_dry_run=true`, `triage=false`, `low_risk_apply=false`;
- orchestrator run: `catalog_agent_runs.id = 67`;
- worker job: `catalog_agent_worker_jobs.id = 22`;
- worker: `low_risk_apply_batch`;
- worker mode: `dry_run`;
- eligible preview: `0`;
- applied: `0`;
- failed: `0`;
- no LLM triage was run;
- no catalog mutation was applied;
- daily digest was refreshed after the shift;
- after the smoke, the dev kill switch was restored to `enabled=false`;
- `CATALOG_AGENT_ORCHESTRATOR_ENABLED` was set back to `false`;
- the temporary operator token was removed;
- post-closure token smoke returned `UNAUTHORIZED`;
- post-closure guard smoke returned `schedule_disabled`;
- post-closure Supabase lint result: `No schema errors found`.

Repeatable script:

- script: `scripts/catalog_agent_dev_shift_smoke.sh`;
- first script attempt produced orchestrator run `#68` and worker job `#23`, but the script-level post-cleanup guard verification failed because it did not set the SQL `service_role` claim before calling `catalog_agent_dev_schedule_guard(...)`;
- the script bug was fixed by setting `request.jwt.claim.role = service_role` in the final guard verification query;
- latest passing scripted smoke: orchestrator run `#69`, worker job `#24`;
- latest passing scripted smoke result: `0` eligible preview, `0` applied, `0` failed, no LLM triage, no catalog mutation;
- cleanup verification passed: temporary token returned `UNAUTHORIZED`, and final guard returned `schedule_disabled`.

Controlled dry-shift series:

- ran two additional dry-shift smokes with `scripts/catalog_agent_dev_shift_smoke.sh`;
- stopped after two runs to avoid adding unnecessary dev-run noise on an already manual-heavy test day;
- run `#70`, worker job `#25`: completed, dry-run, `0` eligible preview, `0` applied, `0` failed;
- run `#71`, worker job `#26`: completed, dry-run, `0` eligible preview, `0` applied, `0` failed;
- final guard check returned `schedule_disabled`;
- total catalog AI tokens for the day remained `135813`, confirming the dry-shift series did not trigger new LLM triage calls;
- final Supabase lint result: `No schema errors found`.

Shift-lane health split:

- applied migration `20260513121500_catalog_agent_dev_shift_run_ledger.sql` to `Season-dev`;
- deployed updated `run-catalog-agent-dev-shift` to `Season-dev`;
- smoke with the dev kill switch still disabled created `catalog_agent_dev_shift_runs.id = 1`;
- shift run `#1` finished as `skipped` with `skip_reason = schedule_disabled`;
- `catalog_agent_dev_shift_health` returned `shift_health_status = green`;
- shift-health message explicitly distinguishes a healthy scheduled-shift lane from the red global daily digest caused by manual development history;
- temporary operator token was removed after the smoke, and reuse returned `UNAUTHORIZED`;
- Supabase lint result: `No schema errors found`.

Admin-console readability:

- cache version `20260513-3` adds a `Recent dev shifts` timeline to the scheduled autonomy card;
- the timeline summarizes shift id, status, guard result, skip/error reason, duration, worker result count, and skipped-worker count;
- this keeps routine scheduler checks visual and avoids using raw JSON as the operator interface;
- `docs/catalog-agent-dev-scheduler-runbook.md` now documents safe default state, temporary dry-shift windows, hard stops, and recovery.

Timeline validation series:

- ran two additional controlled dry-shift smokes with `scripts/catalog_agent_dev_shift_smoke.sh`;
- both runs temporarily enabled dev schedule only for low-risk dry-run preview;
- both runs kept `triage_enabled=false` and `low_risk_apply_enabled=false`;
- run `#72`, worker job `#27`: completed, dry-run, `0` eligible preview, `0` applied, `0` failed;
- run `#73`, worker job `#28`: completed, dry-run, `0` eligible preview, `0` applied, `0` failed;
- LLM token usage stayed at `135813`, confirming the dry-shift series did not trigger scheduled triage calls;
- latest shift ledger rows: shift `#3` completed with `1` worker result, shift `#2` completed with `1` worker result, shift `#1` skipped with `schedule_disabled`;
- `catalog_agent_dev_shift_health` returned `green`, with `3` total shift attempts today, `2` completed, `1` skipped, `0` failed, and `2` worker results;
- final guard returned `schedule_disabled`, confirming the kill switch was restored after the smokes;
- stopped after two new runs to avoid unnecessary manual-day noise.

Micro-scheduler install:

- provisioned dedicated dev scheduler secrets in Edge Function secrets and Supabase Vault;
- kept `CATALOG_AGENT_ORCHESTRATOR_ENABLED=false`;
- applied migration `20260513133000_create_dev_catalog_agent_shift_cron.sql` to `Season-dev`;
- installed active pg_cron job `#3`, `dev_catalog_agent_shift_dryrun_q2h`, scheduled at `17 */2 * * *`;
- cron command reads URL, publishable key, and operator token from Vault;
- verification showed `uses_vault=true`, `mentions_service_role=false`, and `leaks_operator_token=false`;
- guard remained `schedule_disabled` after installation;
- first real cron tick succeeded at `2026-05-13 14:17:00 UTC`;
- cron-created shift `#4` was skipped with `schedule_disabled`, with `0` worker results;
- manual scheduler-token verification created shift `#5`, also skipped with `schedule_disabled`, with `0` worker results;
- final `catalog_agent_dev_shift_health` returned `green`, with `5` total shift attempts today, `2` completed, `3` skipped, `0` failed, and `2` worker results;
- Supabase lint result: `No schema errors found`.

Window-expiry guard:

- applied migration `20260513143000_add_dev_schedule_window_expiry.sql` to `Season-dev`;
- added `enabled_until` and `window_label` to `catalog_agent_dev_schedule_config`;
- `catalog_agent_dev_schedule_status` now exposes `window_status`;
- admin console cache version `20260513-4` shows the current scheduler window state;
- guard smoke with `enabled=true` and `enabled_until=null` returned `schedule_window_missing_expiry`;
- final status returned `window_status=disabled`, `enabled=false`, `enabled_until=null`, and `window_label=null`;
- Supabase lint result: `No schema errors found`.
