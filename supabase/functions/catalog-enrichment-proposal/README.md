# `catalog-enrichment-proposal`

Dedicated Supabase Edge Function for Catalog Intelligence ingredient enrichment proposals.

## Purpose
- Decouples enrichment from `parse-recipe-caption`.
- Provides a strict JSON proposal contract for unresolved ingredient candidates.
- Uses server-side OpenAI with deterministic validation and fallback.
- Reads advisory external catalog evidence when available so Italian-first reviewed sources can improve category/parent hints without becoming catalog truth.

## Request
`POST /functions/v1/catalog-enrichment-proposal`

```json
{
  "normalized_text": "cicoria",
  "agent_run_id": null,
  "agent_worker_job_id": null
}
```

## Success Response (HTTP 200)
```json
{
  "ingredient_type": "produce",
  "canonical_name_it": "Cicoria",
  "canonical_name_en": "Chicory",
  "suggested_slug": "cicoria",
  "default_unit": "g",
  "supported_units": ["g", "piece"],
  "is_seasonal": true,
  "season_months": [10, 11, 12, 1, 2, 3],
  "needs_manual_review": true,
  "reasoning_summary": "Common leafy vegetable; seasonal in cooler months.",
  "confidence_score": 0.82
}
```

If provider fails, times out, or returns invalid JSON/schema, function still returns HTTP 200 with a conservative fallback proposal.

## Auth
No anon access.

Allowed callers:
- Catalog-admin authenticated user calls (`Authorization: Bearer <user_jwt>`)
- Service-role calls (`apikey: <service_role_key>`)

## Environment
Required:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OPENAI_API_KEY`

Optional:
- `CATALOG_ENRICHMENT_PROVIDER_TIMEOUT_MS` (default: `15000`)
- `CATALOG_ENRICHMENT_INPUT_COST_PER_1M_USD`
- `CATALOG_ENRICHMENT_OUTPUT_COST_PER_1M_USD`

When `agent_run_id` or `agent_worker_job_id` is provided, the function records token usage in `catalog_ai_usage_events` so Autopilot worker cost rolls up to the manager-level Catalog Agent run.

Usage metadata includes `external_evidence_count` and `external_parent_hint_count`. Validator failures also include compact `validation_errors`, which is useful when the LLM produced a plausible proposal that failed the strict contract.

## Evidence Grounding

Before calling the provider, the function calls `get_catalog_agent_external_evidence_context(...)` for the cleaned unresolved term.

- Evidence is grounding-only and advisory.
- Evidence can support identity, semantic category, and parent-family hints.
- Evidence never bypasses the enrichment validator or the governed ingredient creation worker.
- Parent hints must still satisfy the strict contract: if `parent_candidate_slug` is set, `variant_kind` and `specificity_rank_suggestion >= 1` are required.

## Deploy
```bash
supabase functions deploy catalog-enrichment-proposal
```

## Local test
Catalog-admin user:
```bash
curl -i --location --request POST 'http://localhost:54321/functions/v1/catalog-enrichment-proposal' \
  --header 'Content-Type: application/json' \
  --header 'Authorization: Bearer <USER_JWT>' \
  --header 'apikey: <ANON_KEY>' \
  --data '{"normalized_text":"cicoria"}'
```

Service-role:
```bash
curl -i --location --request POST 'http://localhost:54321/functions/v1/catalog-enrichment-proposal' \
  --header 'Content-Type: application/json' \
  --header 'apikey: <SERVICE_ROLE_KEY>' \
  --data '{"normalized_text":"cicoria"}'
```
