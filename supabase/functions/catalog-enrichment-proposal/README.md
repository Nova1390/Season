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
  "normalized_text": "cicoria"
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
- Authenticated user calls (`Authorization: Bearer <user_jwt>`)
- Service-role calls (`apikey: <service_role_key>`)

## Environment
Required:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OPENAI_API_KEY`

Optional:
- `CATALOG_ENRICHMENT_PROVIDER_TIMEOUT_MS` (default: `15000`)

## Deploy
```bash
supabase functions deploy catalog-enrichment-proposal
```

## Local test
Authenticated user:
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
