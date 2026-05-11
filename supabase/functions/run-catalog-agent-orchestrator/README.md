# run-catalog-agent-orchestrator

Manager-level Catalog Governance Agent orchestrator.

This Edge Function does not reason with an LLM and does not mutate catalog data directly. It creates an agent run, creates a bounded worker-job ledger row, and invokes an approved Autopilot worker with that parent context.

## Current Worker

Only `enrichment_draft_batch` is supported in v1.

The worker function is:

- `run-catalog-enrichment-draft-batch`

## Safety

- Disabled unless `CATALOG_AGENT_ORCHESTRATOR_ENABLED=true`.
- Dev-only until promoted intentionally.
- Requires catalog admin, service role, or operator token.
- Caps worker item count through `CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN`.
- Writes `catalog_agent_runs`.
- Writes `catalog_agent_worker_jobs`.
- Worker LLM calls write `catalog_ai_usage_events`.
- `dry_run=true` is rejected until the enrichment worker supports true dry-run semantics.

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

Disable after smoke tests unless intentionally testing:

```bash
supabase secrets set CATALOG_AGENT_ORCHESTRATOR_ENABLED=false --project-ref gyuedxycbnqljryenapx
```
