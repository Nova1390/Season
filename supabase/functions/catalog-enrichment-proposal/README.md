# `catalog-enrichment-proposal`

Dedicated Supabase Edge Function for Catalog Intelligence ingredient enrichment proposals.

## Purpose
- Decouples enrichment from `parse-recipe-caption`.
- Provides a strict JSON proposal contract for unresolved ingredient candidates.
- Uses server-side OpenAI with deterministic validation and fallback.

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
