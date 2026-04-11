# Reconciliation Safety Preview (Phase 1)

This document defines the conservative `safe_to_apply` policy used by:

- `recipe_ingredient_reconciliation_safety_preview`
- `preview_recipe_ingredient_reconciliation_safety(...)`
- `preview_safe_recipe_ingredient_reconciliation(...)` (operator-focused preview with recipe title + proposed target context)
- `apply_recipe_ingredient_reconciliation(...)` (phase-1 apply, gated by preview safety)

## What `safe_to_apply` Means

`safe_to_apply = true` means a recipe ingredient row is considered low-risk for **future** automatic reconciliation to the unified catalog.  
This step is preview-only: no recipe ingredient rows are mutated.

## Phase-1 Allowed Matching

Only exact normalized matches are allowed:

1. approved + active alias exact match (`approved_alias`)
2. canonical localization exact match (`canonical_localization`)

## Phase-1 Required Safety Conditions

A row is safe only when all are true:

1. not already resolved in the recipe row (`produce_id` / `basic_ingredient_id` / `ingredient_id` absent)
2. exactly one canonical target (`canonical_target_count = 1`)
3. match source is exact and high-confidence (approved alias or localization exact match)
4. source text is not likely noise
5. candidate/observation status does not indicate conflicting ops signals (e.g. rejected/ignored/conflict/deprecated)

## Phase-1 Exclusions (Intentional)

- no suggested/deprecated/rejected alias matching
- no fuzzy or partial text matching
- no LLM-based matching
- no policy-only inference without exact catalog support
- no mass apply updates to recipes

## Safety Reasons

The preview exposes explainable reasons, including:

- `approved_alias_exact_match`
- `canonical_localization_exact_match`
- `already_resolved`
- `no_match`
- `multiple_matches`
- `alias_not_approved`
- `alias_inactive`
- `text_is_noise`
- `candidate_rejected_or_ignored`

## Why This Step Exists

Before any apply phase, this preview ensures we only consider deterministic, governed exact matches.  
It reduces reconciliation risk and keeps the process auditable.

## Phase-1 Apply Behavior

`apply_recipe_ingredient_reconciliation(...)` applies updates only to rows already marked `safe_to_apply = true` in the preview view.

What it updates:

- only the targeted ingredient object inside `recipes.ingredients` for each selected row
- only legacy reference keys (`produce_id`, `basic_ingredient_id`) using `legacy_ingredient_mapping`

What it preserves:

- ingredient text (`name`)
- quantity fields (`quantity_value`, `quantity_unit`)
- unrelated ingredient objects in the same recipe

What it does not do:

- no fuzzy matching
- no LLM decisions
- no updates for non-safe/ambiguous rows
- no recipe-wide rewrite
- no batch reconciliation expansion beyond the provided apply limit/filter

### Idempotency

Re-running `apply_recipe_ingredient_reconciliation(...)` is safe:

- it only selects rows still `safe_to_apply = true`
- rows already mapped (`produce_id`, `basic_ingredient_id`, or `ingredient_id` present) are skipped as `already_resolved`
- already-updated rows therefore do not keep mutating on repeated runs

## Operator Preview Surface

Use:

- `preview_safe_recipe_ingredient_reconciliation(...)`

This preview is read-only and includes:

- `recipe_id`
- `recipe_title`
- `recipe_ingredient_row_id`
- `ingredient_index`
- `ingredient_raw_name`
- `current_mapping_state`
- `proposed_ingredient_id`
- `proposed_ingredient_slug`
- `proposed_ingredient_name`
- `confidence_source`
- `safe_to_apply`
- `safety_reason`

## Audit and Rollback Approach

Every applied row is logged in `recipe_ingredient_reconciliation_audit` with:

- `recipe_id`
- `recipe_ingredient_row_id`
- `ingredient_index`
- `matched_ingredient_id`
- `match_source`
- full `previous_ingredient_json`
- full `updated_ingredient_json`
- `batch_id`, `applied_at`, `applied_by`, `mechanism`

Rollback strategy is intentionally operational and audit-driven:

1. query a `batch_id`
2. restore `previous_ingredient_json` for affected rows if needed
3. do not run broad rollback without batch scoping

## Impact Measurement Layer

Use these read-only analytics artifacts:

- `recipe_reconciliation_impact_summary`
- `recipe_reconciliation_blockers`
- `recipe_reconciliation_match_source_breakdown`
- `top_unreconciled_recipe_ingredients(...)`

### Metrics Exposed

- total ingredient rows inspected
- total `safe_to_apply` rows
- total rows applied via phase-1 apply
- safe coverage rate
- applied coverage rate
- applied share within safe rows
- blocked rows by `safety_reason`
- safe rows blocked by missing `legacy_ingredient_mapping`
- top recurring unresolved normalized texts
- top recurring safe-but-not-applied cases
- match source breakdown (`approved_alias`, `canonical_localization`, `none`, `multiple`)

### How To Interpret Results

- **Low safe coverage** usually indicates policy gate blockers:
  - alias governance gaps
  - localization exact-match gaps
  - noisy historical text
  - candidate statuses marked as non-actionable

- **High safe coverage but low applied coverage** usually indicates operational bottlenecks:
  - apply batch size too small
  - apply cadence too low
  - missing legacy bridge mappings for otherwise safe rows

### What This Should Inform Next

Prioritize in this order:

1. alias coverage/backlog for high-frequency blocked texts
2. missing `legacy_ingredient_mapping` bridge entries for safe rows
3. candidate review backlog cleanup for recurring unresolved terms
4. phase-2 reconciliation scope planning (still deferred)

## Legacy Bridge Gap Visibility + Backfill

When safe preview count is much higher than applied count, use:

- `preview_reconciliation_legacy_bridge_gaps(...)`

This read-only report shows canonical targets currently blocked only by missing `legacy_ingredient_mapping`, including:

- matched ingredient id/slug/name
- blocked safe row/recipe counts
- sample recipe/title/raw ingredient text
- whether `legacy_produce_id` or `legacy_basic_id` is missing for that ingredient type

For controlled mapping write-back, use:

- `backfill_reconciliation_legacy_mappings(...)`

This helper is admin-guarded and requires explicit mapping inputs per ingredient (no fuzzy inference).  
It reuses `upsert_legacy_ingredient_mapping(...)` for conflict safety and idempotent writes.

Recommended operator sequence:

1. preview safe reconciliation (`preview_safe_recipe_ingredient_reconciliation(...)`)
2. inspect bridge blockers (`preview_reconciliation_legacy_bridge_gaps(...)`)
3. backfill explicit mappings (`backfill_reconciliation_legacy_mappings(...)`)
4. re-run apply (`apply_recipe_ingredient_reconciliation(...)`)

## Blocker Analysis Layer

For actionable backlog planning, use:

- `recipe_reconciliation_unresolved_text_analysis`
- `top_recipe_reconciliation_blockers(...)`
- `recipe_reconciliation_next_action_summary`

### `recommended_next_action` Meanings

- `add_alias`
  - unresolved text is most likely unlockable by approved alias coverage.

- `add_legacy_mapping`
  - canonical target is available but apply is blocked by missing legacy bridge mapping.

- `create_new_ingredient`
  - recurring unresolved text has strong candidate signal and policy support for canonical creation.

- `review_candidate`
  - candidate trail exists but status/policy signal needs manual ops review before action.

- `ignore_noise`
  - low-quality/noisy text should be deprioritized or ignored.

- `needs_manual_investigation`
  - ambiguous or mixed blockers require manual triage.

### How To Use This For Backlog Prioritization

1. start with `top_recipe_reconciliation_blockers(...)` sorted by `recipe_count` and `row_count`,
2. group expected workload with `recipe_reconciliation_next_action_summary`,
3. execute highest-impact bucket first:
   - `add_alias` + `add_legacy_mapping` (usually fastest unlocks),
   - then `create_new_ingredient`,
   - keep `ignore_noise` and ambiguous cases out of core phase-1 throughput.

This remains phase-1 optimization and does not expand phase-2 reconciliation logic.

## Controlled Alias Expansion Workflow

Use this when top blockers indicate `recommended_next_action = add_alias`.

### 1) Select high-impact alias blockers

Use:

- `top_alias_expansion_blockers(...)`

This keeps selection explicit (not bulk auto-approval).  
Prioritize by highest `recipe_count` and `row_count`.

### 2) Approve one alias with explicit target ingredient

Use:

- `approve_reconciliation_alias(...)`

Required inputs:

- `normalized_text`
- `ingredient_id` (must be chosen manually)

Optional:

- `alias_text`
- `language_code`
- `reviewer_note`
- `confidence_score`

### Safety Rules in Alias Approval

- no `ingredient_id` inference
- conflicts are blocked: an existing active alias cannot be silently re-pointed to a different ingredient
- alias is persisted as governed approved metadata (`status=approved`, `is_active=true`, `approval_source=manual`, `approved_at`, `approved_by`)
- decision is logged in `catalog_candidate_decisions`

### Expected Impact on Reconciliation

High-quality alias expansion should increase:

- safe coverage (`safe_to_apply` share),
- downstream applyable rows for phase-1 reconciliation,
- and reduce high-frequency unresolved blockers in the backlog views.

## Controlled Legacy Mapping Expansion Workflow

Use this when blockers indicate safe matches are blocked by missing bridge mapping.

### 1) Select high-impact missing-bridge blockers

Use:

- `top_legacy_mapping_blockers(...)`

This surfaces canonical `ingredient_id` values with the largest safe-but-not-applied impact.

### 2) Add mapping explicitly per canonical ingredient

Use:

- `upsert_legacy_ingredient_mapping(...)`

Required:

- `ingredient_id`
- exactly one of:
  - `legacy_produce_id` (for produce ingredients)
  - `legacy_basic_id` (for basic ingredients)

Optional:

- `source_domain`
- `reviewer_note`

### Safety Rules in Legacy Mapping

- no fuzzy inference of legacy ids
- ingredient type is validated (`produce` must map to `legacy_produce_id`, `basic` to `legacy_basic_id`)
- conflicting mappings fail explicitly:
  - if legacy id is already mapped to another ingredient
  - if ingredient already has a different legacy mapping
- no recipe rows are mutated by this function

### Expected Impact on Metrics

Adding correct bridge mappings should:

- reduce `missing_legacy_mapping` blockers,
- increase safe rows that can be applied by phase-1 reconciliation,
- improve applied coverage without changing reconciliation matching rules.
