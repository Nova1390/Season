# Catalog Admin Ops Read Contract

Season now exposes a single backend read contract for internal catalog/admin screens:

- RPC: `public.get_catalog_admin_ops_snapshot(...)`

This consolidates four existing read surfaces into one payload:

- candidate queue (from `catalog_resolution_candidates(...)`)
- coverage blockers (from `top_catalog_coverage_blockers(...)`)
- ready enrichment drafts (from `list_ready_catalog_enrichment_drafts(...)`)
- observed term coverage clarity (from `catalog_observation_coverage_state(...)`)

## Why

This reduces app-side fragmentation.  
`CatalogCandidatesDebugView` can load one payload instead of stitching multiple reads.

## Payload shape

```json
{
  "candidates": [
    {
      "normalized_text": "olio evo",
      "occurrence_count": 14,
      "suggested_resolution_type": "alias_existing",
      "existing_alias_status": "none",
      "priority_score": 8.42
    }
  ],
  "coverage_blockers": [
    {
      "normalized_text": "zucchine",
      "row_count": 9,
      "recipe_count": 5,
      "occurrence_count": 12,
      "priority_score": 7.3,
      "likely_fix_type": "localization",
      "canonical_candidate_ingredient_id": "uuid-or-null",
      "canonical_candidate_slug": "zucchini",
      "canonical_candidate_name": "Zucchini",
      "suggested_resolution_type": "alias_existing",
      "blocker_reason": "no_match",
      "recommended_next_action": "add_alias"
    }
  ],
  "ready_enrichment_drafts": [
    {
      "normalized_text": "cicoria",
      "ingredient_type": "produce",
      "canonical_name_it": "Cicoria",
      "canonical_name_en": "Chicory",
      "suggested_slug": "cicoria",
      "confidence_score": 0.8,
      "needs_manual_review": true,
      "updated_at": "..."
    }
  ],
  "observation_coverage": [
    {
      "normalized_text": "milk",
      "observation_status": "new",
      "occurrence_count": 1,
      "last_seen_at": "...",
      "coverage_state": "covered_by_canonical",
      "coverage_reason": "canonical_exact_match",
      "canonical_target_ingredient_id": "uuid-or-null",
      "canonical_target_slug": "milk",
      "canonical_target_name": "Milk",
      "alias_target_ingredient_id": null,
      "alias_target_slug": null,
      "alias_target_name": null
    }
  ],
  "metadata": {
    "generated_at": "...",
    "counts": {
      "candidates": 50,
      "coverage_blockers": 30,
      "ready_enrichment_drafts": 6,
      "observation_coverage": 100
    },
    "source": "catalog_admin_ops_snapshot_v2"
  }
}
```

## Coverage states

`observation_coverage` explains why terms from observations are or are not entering unresolved candidate queue:

- `unresolved_candidate`: term currently passes queue filters
- `covered_by_alias`: excluded because alias coverage exists
- `covered_by_canonical`: excluded because canonical localization/slug exact match exists
- `other_excluded`: excluded for other reasons (for example non-`new` observation status)

## Authorization

The RPC is admin-guarded in SQL via `assert_catalog_admin(auth.uid())`.  
Non-admin callers are rejected by backend authorization.
