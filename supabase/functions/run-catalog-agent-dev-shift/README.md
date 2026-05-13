# run-catalog-agent-dev-shift

Dev-only scheduled-autonomy entrypoint for the Catalog Governance Agent.

This function is intentionally conservative. It does not make independent catalog decisions. It:

1. authenticates a catalog admin, service role, or configured operator token;
2. calls `catalog_agent_dev_schedule_guard('dev')`;
3. stops immediately when the guard blocks the shift;
4. always builds `catalog_agent_build_daily_digest(current_date, 'dev')`;
5. may run only the allowed low-risk dry-run worker when the guard allows it;
6. never runs real low-risk apply from the scheduled shift yet;
7. never targets staging.

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
