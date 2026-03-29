# parse-recipe-caption (Edge Function)

Secure server-side boundary for recipe caption parsing.
Includes future-ready LLM fallback contract assets (prompt + strict JSON schema + validator), currently not wired into runtime.

## Request

`POST` with `application/json` + `Authorization: Bearer <supabase_access_token>`:

```json
{
  "caption": "...",
  "url": "...",
  "languageCode": "en"
}
```

At least one between `caption` or `url` must be non-empty.

## Response (contract)

```json
{
  "ok": true,
  "result": {
    "title": "...",
    "ingredients": [{ "name": "...", "quantity": null, "unit": null }],
    "steps": ["..."],
    "prepTimeMinutes": null,
    "cookTimeMinutes": null,
    "confidence": "high",
    "inferredDish": null
  },
  "meta": {
    "languageCode": "en",
    "usedServerLLM": false
  }
}
```

Error responses are JSON-only (`ok: false`) with `error.code` and `error.message`.

## Security notes

- External provider keys are read server-side only via env var:
  - `RECIPE_IMPORT_PROVIDER_API_KEY`
- Supabase auth is required (unauthenticated requests return `401`).
- Per-user server-side daily limit is enforced via DB-backed quota function:
  - default `20` requests/day/user
  - short cooldown guard to reduce burst spam (default `2s`)
- Required env:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Optional env:
  - `PARSE_RECIPE_DAILY_LIMIT`
  - `PARSE_RECIPE_MIN_COOLDOWN_SECONDS`
- No secret is exposed to iOS.
- Current implementation is deterministic stub logic.
- Future LLM integration should keep the same response shape.

## LLM fallback readiness (not active yet)

- File: `llm_contract.ts`
- Contains:
  - `RECIPE_IMPORT_LLM_SYSTEM_PROMPT` (strict JSON-only prompt with examples)
  - `LLM_RECIPE_IMPORT_JSON_SCHEMA` (contract)
  - `validateLLMRecipeImportOutput(...)` (runtime shape/type validator)
- Intended future usage:
  - trigger only when local confidence is low
  - call provider server-side
  - validate provider JSON before returning it
