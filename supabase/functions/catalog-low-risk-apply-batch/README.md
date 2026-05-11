# catalog-low-risk-apply-batch

Bounded worker for low-risk Catalog Governance Agent auto-apply.

Status: deployed on dev, disabled by default unless `CATALOG_AGENT_LOW_RISK_APPLY_ENABLED=true`.

## Purpose

This worker applies only proposals that are already proven safe by the backend:

- `status = validated`;
- `risk_level = low`;
- `auto_apply_eligible = true`;
- empty validation errors;
- proposal type is `approve_alias` or `add_localization`.

It delegates mutation to `apply_catalog_agent_low_risk_proposal_batch(...)`, which writes audit and rollback state to `catalog_agent_apply_audit`.

## Request

```json
{
  "limit": 5,
  "dry_run": true,
  "agent_run_id": 123,
  "agent_worker_job_id": 456,
  "debug": false
}
```

## Modes

- `dry_run=true`: previews eligible proposals, completes the worker job, and does not mutate catalog data.
- `dry_run=false`: requires `CATALOG_AGENT_LOW_RISK_APPLY_ENABLED=true`; applies eligible proposals through guarded RPCs.

Dry-run readiness is sourced from `get_catalog_agent_auto_apply_diagnostics()`, so previews match the same backend criteria used by the real batch apply path.

## Safety

- No service-role key is exposed to the browser.
- The worker is callable by service role or catalog admin only.
- The feature flag is separate from the orchestrator flag.
- Rollback stays in `rollback_catalog_agent_apply(...)`.
