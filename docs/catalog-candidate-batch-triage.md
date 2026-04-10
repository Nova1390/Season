# Catalog Candidate Batch Triage (Backend-First)

Season now exposes a backend-native batch triage RPC for unresolved catalog terms:

- `public.execute_catalog_candidate_batch_triage(...)`

## Purpose

Process a selected batch of unresolved terms with safe, auditable actions:

- `approve_alias`
- `ignore`
- `prepare_enrichment_draft`

This is read/write **admin-only** and replaces ad hoc script-driven mutation as the primary workflow.

## Input

```json
{
  "p_items": [
    {
      "normalized_text": "olio evo",
      "action": "approve_alias",
      "ingredient_id": "uuid"
    },
    {
      "normalized_text": "frutti di cappero per decorare",
      "action": "ignore"
    },
    {
      "normalized_text": "cicoria",
      "action": "prepare_enrichment_draft"
    }
  ],
  "p_default_language_code": "it",
  "p_reviewer_note": "batch triage run"
}
```

## Output

```json
{
  "summary": {
    "total": 3,
    "succeeded": 2,
    "failed": 0,
    "skipped": 1
  },
  "items": [
    {
      "normalized_text": "olio evo",
      "intended_action": "approve_alias",
      "result_status": "succeeded",
      "detail": "alias_approved"
    }
  ],
  "metadata": {
    "processed_at": "...",
    "processed_by": "...",
    "source": "catalog_candidate_batch_triage_v1"
  }
}
```

## Safety and Idempotency

- Admin authorization is enforced via `assert_catalog_admin(...)`.
- Items are processed one-by-one; one failure does not stop the batch.
- `approve_alias` requires explicit `ingredient_id` (no fuzzy targeting).
- `prepare_enrichment_draft` only creates/upserts a draft; no canonical ingredient is created.
- Existing approved aliases / existing drafts are reported as `skipped` where applicable.

## Reused Governance Artifacts

- Alias approval: `approve_reconciliation_alias(...)`
- Decision/audit trail: `apply_catalog_candidate_decision(...)`
- Enrichment preparation: `upsert_catalog_ingredient_enrichment_draft(...)`
