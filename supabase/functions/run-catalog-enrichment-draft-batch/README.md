# `run-catalog-enrichment-draft-batch`

Admin-only batch orchestrator for pending enrichment drafts.

## What it does
1. Reads top `status='pending'` drafts (ordered by occurrence signal first).
2. Calls `catalog-enrichment-proposal` for each draft.
3. Writes proposal into draft via `upsert_catalog_ingredient_enrichment_draft(...)`.
4. Validates via `validate_catalog_ingredient_enrichment_draft(...)`.
5. If validation has no errors, attempts `status='ready'` upsert.
6. Returns per-item summary (`succeeded/failed/skipped`) without creating ingredients.

## Request
`POST /functions/v1/run-catalog-enrichment-draft-batch`

```json
{
  "limit": 20
}
```

## Response
```json
{
  "summary": {
    "total": 20,
    "succeeded": 18,
    "failed": 1,
    "skipped": 1,
    "ready": 12,
    "pending": 8
  },
  "items": [
    {
      "normalized_text": "farina 00",
      "result_status": "succeeded",
      "detail": "proposal_applied_and_marked_ready",
      "error_message": null,
      "validation_errors": [],
      "validation_passed": true,
      "final_status": "ready"
    }
  ],
  "metadata": {
    "mode": "user",
    "limit": 20,
    "generated_at": "2026-04-10T00:00:00.000Z"
  }
}
```

## Security
- Accepts service-role or authenticated user token.
- User-token callers must pass backend admin check (`is_current_user_catalog_admin`).
- No canonical ingredient creation occurs in this function.
