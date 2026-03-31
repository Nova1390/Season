# Catalog Intelligence Candidate Decision Policy

This document defines the backend-first triage policy used by `catalog_resolution_candidate_policy` and `catalog_resolution_candidate_decisions(...)`.

## Purpose

Before any batch reconciliation, we need a conservative and auditable way to triage unresolved ingredient candidates.  
This policy provides **recommended actions**, not automatic writes.

## Minimal Ops Write Workflow

Manual operational decisions are persisted through:

- `apply_catalog_candidate_decision(...)`

Supported actions:

- `approve_alias`
- `reject_alias`
- `create_new_ingredient`
- `ignore`

Canonical ingredient creation (after `create_new_ingredient` review):

- `create_catalog_ingredient_from_candidate(...)`

### What Each Action Writes

- `approve_alias`
  - Creates or updates `ingredient_aliases_v2` with governed approved metadata (`status=approved`, `approval_source=manual`, `approved_at`, optional reviewer note/confidence).
  - Marks `custom_ingredient_observations.status = 'resolved_alias'`.
  - Appends an audit row in `catalog_candidate_decisions`.

- `reject_alias`
  - Marks matching alias (if alias text is provided) as rejected and inactive.
  - Marks `custom_ingredient_observations.status = 'rejected'`.
  - Appends an audit row in `catalog_candidate_decisions`.

- `create_new_ingredient`
  - Marks `custom_ingredient_observations.status = 'create_new_candidate'`.
  - Appends an audit row in `catalog_candidate_decisions`.
  - Does **not** create a new ingredient automatically.

- `ignore`
  - Marks `custom_ingredient_observations.status = 'ignored'`.
  - Appends an audit row in `catalog_candidate_decisions`.

### Creating A Canonical Ingredient From A Candidate

Use `create_catalog_ingredient_from_candidate(...)` when ops has reviewed a candidate and confirmed it should become a real ingredient.

What it writes:

- creates a row in `ingredients` (unless an existing canonical match is detected),
- creates at least one `ingredient_localizations` row,
- optionally creates/updates an approved alias in `ingredient_aliases_v2`,
- marks `custom_ingredient_observations.status = 'ingredient_created'`,
- appends an audit row in `catalog_candidate_decisions` with resulting `ingredient_id`.

Safety behavior:

- duplicate prevention checks run before insert (slug, normalized localization, approved alias coverage),
- if a canonical match already exists, no duplicate ingredient is created and the decision is still logged.

## Recommended Actions

- `alias_existing`
  - Use when candidate text is already covered by alias governance signals (especially approved aliases).
  - Also used for non-approved alias coverage (`suggested` / `deprecated`) to route to alias review rather than new ingredient creation.

- `create_new_ingredient`
  - Use only when there is no alias coverage and recurrence signal is strong (`occurrence_count` + `priority_score` threshold).
  - This is still a recommendation; final decision remains manual.

- `ignore`
  - Use for likely noise or very low-signal candidates.
  - Typical cases: malformed tokens, URL-ish strings, punctuation/numeric-only strings, one-off low-priority rows.

- `unknown`
  - Use when signal is insufficient or conflicting.
  - Requires manual review before any follow-up action.

## Supporting Fields

- `decision_reason`: short explainable reason for the recommendation.
- `decision_confidence`: policy confidence (deterministic, rule-based).
- `meets_create_new_threshold`: explicit threshold flag for potential new ingredient creation.
- `is_likely_noise`: explicit noise flag.
- `observation_status`: current observation status (used for `only_status_new` filtering).

## Why This Exists Before Batch Reconciliation

Batch reconciliation is intentionally deferred.  
This policy step creates a safer review boundary so ops can:

1. confirm alias coverage quality,
2. distinguish alias opportunities from true catalog gaps,
3. avoid propagating noisy candidates into canonical ingredient decisions.

## Intentionally Manual (Deferred)

- No approval UI in the iOS app.
- No automatic decision execution from policy recommendations.
- No automatic create-new-ingredient generation.
- No automatic batch reconciliation execution.
- No recipe ingredient mutation/write-back.
