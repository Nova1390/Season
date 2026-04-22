# Smart Import + Catalog Pipeline

## 1. Purpose

This pipeline lets creators import recipes quickly from captions or URLs without polluting the canonical ingredient catalog.

The core tension is speed vs safety:
- Smart Import should help users create a usable draft fast.
- Catalog Intelligence should decide what becomes catalog truth.
- Canonical ingredients must stay clean, reviewed, and deduplicated.

Key invariant: **canonical ingredients must not be polluted by noisy import text.**

## 2. End-to-End Flow

User provides a caption and/or URL.

Flow:
- Swift Smart Import parses the input locally.
- Swift extracts candidate ingredient lines, quantities, and units.
- Swift matches candidates against existing produce/basic catalog knowledge.
- If needed, `parse-recipe-caption` uses LLM help for unresolved or ambiguous candidates only.
- The app creates a draft recipe from resolved, inferred, and unknown ingredients.
- Unknown/custom ingredients can become unresolved observations.
- Catalog Intelligence reviews observations through governance.
- Enrichment drafts can become canonical ingredients through the canonical writer.
- Approved aliases map noisy text to existing ingredients.
- Safe reconciliation can update existing recipes when rules allow it.

Short form:

`caption/url -> Swift parse/match -> optional Edge parse -> draft recipe -> unresolved observations -> governance -> enrichment -> canonical creation / alias approval -> reconciliation`

## 3. Core Separation

### Smart Import: Consumer

Smart Import may:
- Parse captions and URLs.
- Normalize ingredient text for draft use.
- Recover quantities and units.
- Match against existing catalog items and existing alias knowledge.
- Produce draft ingredients.
- Emit unresolved observations for later review.

Smart Import must not:
- Create canonical ingredients.
- Approve aliases.
- Mutate catalog governance state.
- Treat LLM output as catalog truth.

### Catalog Intelligence: Governance

Catalog Intelligence may:
- Review unresolved candidates.
- Create enrichment drafts.
- Create canonical ingredients through the canonical writer.
- Approve aliases through governed SQL paths.
- Apply safe recipe reconciliation.

Key rule: **Smart Import must never create or approve catalog entities.**

## 4. Key Components

### Frontend

- `Season/Services/SocialImportParser.swift`
  - Local caption parsing, candidate extraction, quantity recovery, audit metrics.
- `Season/Views/CreateRecipeView.swift`
  - Smart Import UI flow, local parse, optional server fallback, draft mapping.
- `ProduceViewModel.resolveIngredientForImport`
  - Runtime ingredient resolution helper used by import/draft flows.

### Edge

- `supabase/functions/parse-recipe-caption`
  - Consumer-side import assistance.
  - Uses targeted LLM help only for candidates that need it.
  - Must preserve client response compatibility.

### Backend

- `catalog_resolution_candidate_queue`
  - Review queue for unresolved/custom ingredient observations.
- `apply_catalog_candidate_decision`
  - Admin decision RPC for candidate handling.
- `catalog-enrichment-proposal`
  - Generates enrichment proposals for unresolved candidates.
- `run-catalog-enrichment-draft-batch`
  - Batch creation/update of enrichment drafts.
- `run-catalog-ingredient-creation-batch`
  - Batch creation of canonical ingredients from ready drafts.
- `run-catalog-automation-cycle`
  - Orchestrates backend catalog automation steps.

### Core SQL

- `create_catalog_ingredient_from_candidate(...)`
  - Single canonical writer for new ingredients.
- `create_catalog_ingredient_from_enrichment_draft(...)`
  - Wrapper around the canonical writer for ready enrichment drafts.
- `approve_reconciliation_alias(...)`
  - Governed alias approval path.
- `apply_recipe_ingredient_reconciliation_modern(...)`
  - Safe recipe reconciliation apply path.

## 5. Canonical Writer Rule

There is exactly one place where canonical ingredients are created:

`create_catalog_ingredient_from_candidate(...)`

Everything else must delegate to it.

Examples:
- Batch creation -> OK, if it delegates to `create_catalog_ingredient_from_candidate(...)`.
- Enrichment draft creation -> OK, via `create_catalog_ingredient_from_enrichment_draft(...)`.
- Edge Function direct insert into `ingredients` -> NOT OK.
- Swift client insert into `ingredients` -> NOT OK.

Why this matters:
- Prevents duplicate canonical ingredients.
- Keeps validation, localization, alias creation, and audit behavior consistent.
- Makes retries and automation safer.

## 6. Alias Rule

Aliases map input text to an existing canonical ingredient.

Use aliases for:
- Linguistic variation.
- Formatting differences.
- Noisy creator input.
- Common alternate names.

Do not use aliases when:
- The ingredient is actually new.
- The text represents a distinct canonical concept.
- The match is only a weak guess.

Rules:
- `approve_reconciliation_alias(...)` is the safest alias approval path.
- Alias approval must not create new ingredients.
- Alias conflicts must be checked before approval.
- A proposal is not approval.

## 7. Autopilot

`run-catalog-automation-cycle` is a backend ops pipeline.

It can:
- Collect unresolved observations.
- Generate enrichment drafts.
- Create canonical ingredients through the canonical writer.
- Apply safe aliases.
- Run safe reconciliation.

It is not part of the user import path.

Smart Import helps the user create a recipe now. Autopilot improves catalog quality later.

## 8. Safety Guarantees

Current guarantees:
- Canonical ingredient creation flows through `create_catalog_ingredient_from_candidate(...)`.
- Enrichment draft creation delegates to the canonical writer.
- Alias approval checks active alias conflicts.
- Recipe reconciliation uses safe apply paths.
- Smart Import does not directly mutate catalog truth.
- Edge import assistance does not create canonical ingredients.
- LLM output is assistance, not authority.

## 9. Known Limits

- Smart Import may use heuristic local matches for draft quality.
- Heuristic matches are not the same as governed approved aliases.
- LLM proposals still require validation before becoming catalog truth.
- Alias writing has multiple controlled entrypoints, though approval should prefer `approve_reconciliation_alias(...)`.
- Some unresolved observations may require human review before safe automation.
