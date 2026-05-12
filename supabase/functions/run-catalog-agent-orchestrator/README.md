# run-catalog-agent-orchestrator

Manager-level Catalog Governance Agent orchestrator.

This Edge Function does not reason with an LLM and does not mutate catalog data directly. It creates an agent run, creates a bounded worker-job ledger row, and invokes an approved Autopilot worker with that parent context.

## Supported Workers

The orchestrator supports three bounded workers:

- `enrichment_draft_batch` -> `run-catalog-enrichment-draft-batch`
- `ingredient_creation_batch` -> `run-catalog-ingredient-creation-batch`
- `low_risk_apply_batch` -> `catalog-low-risk-apply-batch`

`low_risk_apply_batch` defaults to dry-run mode. Real apply requires both:

- request payload `dry_run=false` and `action=apply_low_risk`;
- `CATALOG_AGENT_LOW_RISK_APPLY_ENABLED=true`.

`ingredient_creation_batch` has no dry-run mode. It only consumes enrichment drafts that are already `ready`; real creation requires `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=true` in the target Supabase project.

## Safety

- Disabled unless `CATALOG_AGENT_ORCHESTRATOR_ENABLED=true`.
- Dev-only until promoted intentionally.
- Requires catalog admin, service role, or operator token.
- Supports browser invocation from the admin console through CORS preflight.
- Caps worker item count through `CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN`.
- Writes `catalog_agent_runs`.
- Writes `catalog_agent_worker_jobs`.
- Worker LLM calls write `catalog_ai_usage_events`.
- `dry_run=true` is rejected for `enrichment_draft_batch`.
- `dry_run=true` is rejected for `ingredient_creation_batch`.
- `ingredient_creation_batch` requires `action=create_ingredient`.
- `dry_run=true` is the default for `low_risk_apply_batch`.
- `low_risk_apply_batch` only accepts `risk_ceiling=low`.

## Request

```json
{
  "worker_name": "enrichment_draft_batch",
  "action": "run",
  "limit": 3,
  "source_domain": null,
  "risk_ceiling": "low",
  "dry_run": false,
  "debug": false
}
```

Low-risk apply dry-run:

```json
{
  "worker_name": "low_risk_apply_batch",
  "action": "dry_run",
  "limit": 3,
  "risk_ceiling": "low",
  "dry_run": true,
  "debug": false
}
```

Ingredient creation from ready drafts:

```json
{
  "worker_name": "ingredient_creation_batch",
  "action": "create_ingredient",
  "limit": 1,
  "source_domain": null,
  "risk_ceiling": "low",
  "dry_run": false,
  "debug": false
}
```

Low-risk apply real mode, disabled unless explicitly enabled:

```json
{
  "worker_name": "low_risk_apply_batch",
  "action": "apply_low_risk",
  "limit": 3,
  "risk_ceiling": "low",
  "dry_run": false,
  "debug": false
}
```

## Response

```json
{
  "ok": true,
  "run_id": 12,
  "worker_job_id": 3,
  "summary": {
    "worker_job_id": 3,
    "worker_name": "enrichment_draft_batch",
    "worker_function": "run-catalog-enrichment-draft-batch",
    "dry_run": false
  }
}
```

## Manual Dev Invocation

```bash
curl -X POST 'https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-agent-orchestrator' \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "x-season-catalog-agent-token: ${CATALOG_AGENT_OPERATOR_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"worker_name":"enrichment_draft_batch","limit":1,"dry_run":false}'
```

Dry-run the low-risk apply worker:

```bash
curl -X POST 'https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-agent-orchestrator' \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "x-season-catalog-agent-token: ${CATALOG_AGENT_OPERATOR_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"worker_name":"low_risk_apply_batch","action":"dry_run","limit":3,"risk_ceiling":"low","dry_run":true}'
```

Run ingredient creation for one ready draft, only after enabling the creation flag:

```bash
curl -X POST 'https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-agent-orchestrator' \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "x-season-catalog-agent-token: ${CATALOG_AGENT_OPERATOR_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"worker_name":"ingredient_creation_batch","action":"create_ingredient","limit":1,"dry_run":false}'
```

Disable after smoke tests unless intentionally testing:

```bash
supabase secrets set CATALOG_AGENT_ORCHESTRATOR_ENABLED=false --project-ref gyuedxycbnqljryenapx
```
