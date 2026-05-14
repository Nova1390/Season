# parse-recipe-caption (Edge Function)

Secure server-side boundary for Smart Import recipe drafting.

The function supports:

- authenticated caption/URL parsing;
- Swift-provided ingredient candidates;
- candidate deduplication that prefers the version with explicit quantity/unit;
- targeted LLM fallback for ambiguous ingredient candidates;
- full recipe-caption LLM parsing when no candidate packet is available;
- one bounded schema-repair retry when provider JSON fails the runtime contract;
- compact Catalog Agent learning-memory context before targeted ingredient reasoning;
- draft-quality metadata for the creator UI.

## Request

`POST` with `application/json` + `Authorization: Bearer <supabase_access_token>`:

```json
{
  "caption": "...",
  "url": "...",
  "languageCode": "en",
  "ingredientCandidates": [
    {
      "raw_text": "pomodorini 200g",
      "normalized_text": "pomodorini",
      "possible_quantity": 200,
      "possible_unit": "g",
      "catalog_match": {
        "matchType": "none",
        "matchedIngredientId": null,
        "confidence": 0
      }
    }
  ]
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
    "servings": null,
    "confidence": "high",
    "inferredDish": null,
    "smartImportAgent": {
      "version": "smart_import_agent_v1",
      "draftQuality": "needs_creator_review",
      "nextAction": "resolve_ingredients",
      "actionReason": "Some ingredients remain unresolved against the catalog and should be checked before publishing.",
      "operationalSignals": ["catalog_identity_review_needed"],
      "scorecard": {
        "blockingIssues": ["unresolved_ingredients_present"],
        "niceToFix": ["quantities_missing"],
        "autoFixable": []
      },
      "autoFixPlan": {
        "safeFixes": [],
        "deferredFixes": [
          {
            "issue": "unresolved_ingredients_present",
            "action": "route_to_catalog_resolution",
            "reason": "Catalog identity needs reconciliation or creator review before unattended publishing."
          }
        ]
      },
      "appliedAutoFixes": [],
      "reviewHints": ["unresolved_ingredients_present"],
      "unresolvedIngredients": ["pomodorini"],
      "passes": [
        {
          "name": "swift_preparse_catalog_memory",
          "usedLLM": false,
          "reason": "Swift extracted ingredient candidates and local catalog matches before calling the server.",
          "candidateCount": 1
        }
      ]
    }
  },
  "meta": {
    "languageCode": "en",
    "usedServerLLM": false,
    "smart_import_audit": {
      "total_candidates": 1,
      "resolved_locally": 0,
      "sent_to_llm": 1,
      "final_unknown": 1
    }
  }
}
```

Error responses are JSON-only (`ok: false`) with `error.code` and `error.message`.

## Security notes

- External provider keys are read server-side only via env var:
  - `OPENAI_API_KEY`
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
  - `PARSE_RECIPE_PROVIDER_TIMEOUT_MS`
  - `PARSE_RECIPE_LLM_ENABLED=false` to disable provider calls in emergency cost-control mode.
  - `PARSE_RECIPE_PROVIDER_MAX_OUTPUT_TOKENS` to cap provider output tokens per call; default `1800`, clamped between `256` and `4000`.
- No provider secret is exposed to iOS.
- The function uses `SUPABASE_SERVICE_ROLE_KEY` only server-side for quota and read-only learning context.
- Learning-memory lookup is best-effort; failures do not block creator import.

## LLM and learning memory

- File: `llm_contract.ts`
- Contains:
  - `RECIPE_IMPORT_LLM_SYSTEM_PROMPT` (strict JSON-only prompt with examples)
  - `INGREDIENT_RESOLUTION_LLM_SYSTEM_PROMPT` (targeted candidate normalization prompt)
  - `LLM_RECIPE_IMPORT_JSON_SCHEMA` (contract)
  - `validateLLMRecipeImportOutput(...)` (runtime shape/type validator)
- Runtime usage:
  - targeted LLM is used only for ambiguous, unknown, or low-confidence candidate matches;
  - full recipe parse is used when no Swift candidate packet is available;
  - `get_catalog_agent_learning_context(...)` supplies compact advisory memory for targeted candidate resolution;
  - the targeted prompt explicitly distinguishes product family, meaningful variants, preparation/freshness state, product form, and ambiguity;
  - provider JSON is validated before returning to the app;
  - full recipe parse gets one schema-repair retry if the first provider JSON is valid JSON but fails the strict recipe contract;
  - exact-candidate responses are deduped before the quality gate, so duplicate preparsed candidates such as `riso` + `riso 180g` preserve the measured candidate and do not create duplicate draft rows.

The schema-repair retry is deliberately narrow: it only receives validation errors and the original caption context, then must return the same strict JSON shape. If the repair also fails, the function still returns `VALIDATION_FAILED` instead of inventing a partial response.

## Smoke tests

- `scripts/smart_import_learning_cases/run_edge_contract.py` verifies the authenticated Edge contract and learning-memory pass without using LLM when exact candidates are supplied.
- `scripts/smart_import_learning_cases/run_exact_caption_probe.py` verifies the risotto-style creator caption case: quantities are preserved from preparsed candidates and lower-quality duplicate candidates are collapsed without an LLM call.

`smartImportAgent.operationalSignals` is a machine-readable learning/eval layer for batches. It turns recurring creator-caption patterns into compact labels such as:

- `ingredients_only_caption`
- `low_signal_caption`
- `method_without_amounts`
- `missing_servings_metadata`
- `missing_timing_metadata`
- `catalog_identity_review_needed`
- `low_confidence_parse`

These signals are not catalog truth. They are used to decide whether Smart Import should ask the creator for more recipe detail, whether a regression fixture should be added, or whether Catalog Governance should later inspect unresolved ingredient observations.

Smart Import must not create catalog records, approve aliases, or reconcile recipes. Unresolved custom ingredients are handled later by Catalog Governance observations.
