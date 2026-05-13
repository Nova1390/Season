# run-catalog-agent-dev-shift

Dev-only scheduled-autonomy entrypoint for the Catalog Governance Agent.

This function is intentionally conservative. It does not make independent catalog decisions. It:

1. authenticates a catalog admin, service role, or configured operator token;
2. calls `catalog_agent_dev_schedule_guard('dev')`;
3. records the shift attempt in `catalog_agent_dev_shift_runs`;
4. stops immediately when the guard blocks the shift;
5. always builds `catalog_agent_build_daily_digest(current_date, 'dev')`;
6. stores guard, worker, skipped-worker, digest, and duration snapshots on the shift row;
7. may run only the allowed low-risk dry-run worker when the guard allows it;
8. never runs real low-risk apply from the scheduled shift yet;
9. never targets staging.

## Current Status

Level 6.0 foundation only.

The default dev database config has the kill switch enabled, so a normal call currently returns:

```json
{
  "ok": true,
  "skipped": true,
  "reason": "schedule_disabled"
}
```

That is expected until we intentionally enable scheduled dev autonomy.

## Request Body

```json
{
  "limit": 1,
  "source_domain": null,
  "dry_run": true,
  "run_low_risk_preview": true,
  "run_triage": false,
  "debug": false
}
```

Safety notes:

- `limit` is capped by `CATALOG_AGENT_DEV_SHIFT_MAX_ITEMS`, default `1`, max `3`.
- `run_triage` is recognized but not wired yet; this avoids accidental LLM spend from a scheduler.
- `dry_run=false` does not enable real apply; real apply is intentionally skipped from scheduled shifts until Level 5.0 has stronger history.

## Environment

Required:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Optional:

- `CATALOG_AGENT_OPERATOR_TOKEN`
- `CATALOG_AGENT_DEV_SHIFT_MAX_ITEMS`
- `CATALOG_AGENT_DEV_SHIFT_TIMEOUT_MS`

## Deployment

```bash
supabase functions deploy run-catalog-agent-dev-shift --project-ref gyuedxycbnqljryenapx
```

## Manual Smoke

The first smoke should be a blocked shift while the kill switch is still off:

```bash
curl -s \
  -X POST "https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-agent-dev-shift" \
  -H "Authorization: Bearer <service-role-or-admin-jwt>" \
  -H "apikey: <service-role-or-anon-key>" \
  -H "content-type: application/json" \
  --data '{"limit":1,"dry_run":true}'
```

Expected behavior:

- `skipped=true`;
- `reason=schedule_disabled`;
- a daily digest is still built or refreshed.

## Dev Smoke Evidence

2026-05-13:

- deployed to `Season-dev`;
- unauthenticated request returned `UNAUTHORIZED`;
- temporary operator-token request returned `ok=true`, `skipped=true`, and `reason=schedule_disabled`;
- digest id `1` was refreshed;
- temporary operator token was removed immediately;
- post-removal request with the same token returned `UNAUTHORIZED`.

Controlled dry-shift smoke:

- schedule config was temporarily enabled on dev only;
- `triage_enabled=false`;
- `low_risk_apply_enabled=false`;
- `CATALOG_AGENT_ORCHESTRATOR_ENABLED=true` only during the smoke;
- request used `limit=1`, `dry_run=true`, `run_low_risk_preview=true`, and `run_triage=false`;
- guard returned `ok=true`;
- orchestrator run `#67` created worker job `#22`;
- worker `low_risk_apply_batch` ran in dry-run mode;
- eligible preview was `0`;
- applied `0`;
- failed `0`;
- no LLM triage was run;
- config and secrets were restored immediately afterwards;
- post-closure guard returned `schedule_disabled`;
- Supabase lint returned `No schema errors found`.

Repeatable smoke:

- script: `scripts/catalog_agent_dev_shift_smoke.sh`;
- latest passing run: `catalog_agent_runs.id = 69`;
- latest passing worker job: `catalog_agent_worker_jobs.id = 24`;
- result: `0` eligible preview, `0` applied, `0` failed;
- cleanup verification: temporary token returned `UNAUTHORIZED` and the guard returned `schedule_disabled`.

Controlled series:

- runs `#70` and `#71` completed through `scripts/catalog_agent_dev_shift_smoke.sh`;
- worker jobs `#25` and `#26` completed in dry-run mode;
- both runs returned `0` eligible preview, `0` applied, and `0` failed;
- final guard returned `schedule_disabled`;
- daily catalog AI token usage stayed unchanged at `135813`, so no LLM triage was triggered by the series.

Shift-ledger smoke:

- migration `20260513121500_catalog_agent_dev_shift_run_ledger.sql` was applied to `Season-dev`;
- the updated function was deployed to `Season-dev`;
- blocked-shift smoke created `catalog_agent_dev_shift_runs.id = 1`;
- shift `#1` finished as `skipped` with `skip_reason = schedule_disabled`;
- `catalog_agent_dev_shift_health` returned `green`, proving the shift lane is healthy even while the global daily digest stays red from manual dev test history;
- the temporary operator token was removed after the smoke and reuse returned `UNAUTHORIZED`;
- Supabase lint returned `No schema errors found`.
