# Catalog System Review and Consolidation Plan

## 1. Current System Map

### Backend data model (current)

Primary catalog entities:
- `public.ingredients` (canonical nodes; now includes hierarchy fields `parent_ingredient_id`, `specificity_rank`, `variant_kind` from `20260411100000_add_ingredient_hierarchy_fields.sql`)
- `public.ingredient_localizations` (display names by language)
- `public.ingredient_aliases_v2` (normalized alias -> canonical ingredient)
- `public.legacy_ingredient_mapping` (compatibility bridge, still required by reconciliation apply)

Observation/candidate pipeline:
- `public.custom_ingredient_observations`
- `public.custom_ingredient_observation_summary` (view)
- `public.catalog_resolution_candidate_queue` (view)
- `public.catalog_resolution_candidates(...)` (RPC)
- `public.catalog_resolution_candidate_policy` (view)
- `public.catalog_resolution_candidate_decisions(...)` (RPC)
- `public.catalog_candidate_decisions` (audit/governance table)

Coverage/blocker and ops read layer:
- `public.catalog_coverage_blocker_terms` (view)
- `public.top_catalog_coverage_blockers(...)` (RPC)
- `public.catalog_observation_coverage_state(...)` (RPC)
- `public.get_catalog_admin_ops_snapshot(...)` (consolidated admin read contract; now includes hierarchy advisory fields and multi-option decision hints)

Enrichment draft layer:
- `public.catalog_ingredient_enrichment_drafts`
- `public.upsert_catalog_ingredient_enrichment_draft(...)`
- `public.get_catalog_ingredient_enrichment_draft(...)`
- `public.validate_catalog_ingredient_enrichment_draft(...)`
- `public.catalog_ready_enrichment_draft_queue` (view)
- `public.list_ready_catalog_enrichment_drafts(...)`
- `public.review_pending_catalog_enrichment_drafts(...)`

Creation and catalog mutation layer:
- `public.create_catalog_ingredient_from_candidate(...)`
- `public.create_catalog_ingredient_from_enrichment_draft(...)`
- `public.approve_reconciliation_alias(...)`
- `public.add_ingredient_localization(...)`
- `public.execute_catalog_candidate_batch_triage(...)`

Reconciliation layer:
- `public.preview_safe_recipe_ingredient_reconciliation(...)`
- `public.apply_recipe_ingredient_reconciliation(...)`
- `public.recipe_ingredient_reconciliation_safety_preview` (view)
- `public.recipe_ingredient_reconciliation_audit` (table)
- `public.preview_reconciliation_legacy_bridge_gaps(...)`
- `public.backfill_reconciliation_legacy_mappings(...)`

Admin auth/security:
- `public.catalog_admin_allowlist`
- `public.is_catalog_admin(...)`
- `public.assert_catalog_admin(...)`
- `public.is_current_user_catalog_admin()`

### Edge Functions (catalog-adjacent)

Catalog-specific:
- `supabase/functions/catalog-enrichment-proposal` (LLM proposal endpoint)
- `supabase/functions/run-catalog-enrichment-draft-batch` (batch orchestration for pending drafts)
- `supabase/functions/run-catalog-ingredient-creation-batch` (ready draft -> ingredient)
- `supabase/functions/run-catalog-automation-cycle` (recovery -> enrichment -> creation)

Recipe ingestion (feeds catalog signals indirectly):
- `supabase/functions/import-recipe-from-url`
- `supabase/functions/parse-recipe-caption` (legacy/general parse path, still used in recipe flows)

### iOS app layers (catalog/admin)

Services:
- `Season/Services/SupabaseService.swift` (RPC + edge-function gateway; still broad)
- `Season/Services/CatalogAdminOpsService.swift` (thin app-side admin ops facade)
- `Season/Services/CatalogEnrichmentProvider.swift` (proposal pipeline: remote edge function + deterministic fallback)

Views:
- `Season/Views/AccountView.swift` exposes admin entry under "System Diagnostics"
- `Season/Views/CatalogCandidatesDebugView.swift` is the operational/admin surface and still hosts most tooling
- `CatalogEnrichmentDraftEditorView` is embedded in `CatalogCandidatesDebugView.swift`

Admin flow today (effective):
1. Load snapshot via `get_catalog_admin_ops_snapshot(...)`
2. Triaging from queue sections (alias/new ingredient/review-later)
3. Draft editing/validation/ready
4. Batch enrichment + batch create
5. Optional reconciliation preview/apply

### Where hierarchy is used now
- Data model: `ingredients.parent_ingredient_id`, `specificity_rank`, `variant_kind`
- Seeded families: `farina`, `riso`, `cipolla` roots + selected children
- Admin read path: `list_catalog_ingredient_hierarchy(...)` and hierarchy hints in `get_catalog_admin_ops_snapshot(...)`
- Advisory only; not yet driving runtime matching behavior

### Where legacy logic still dominates
- Recipe reconciliation apply still depends on `legacy_ingredient_mapping`
- Safe apply count can be much lower than preview due to missing legacy bridge
- Recipe ingredient storage remains legacy-compatible JSON shape

---

## 2. AI Trigger Map

## 2.1 `catalog-enrichment-proposal` (Edge Function)
- Entry point:
  - App: `SupabaseService.fetchCatalogEnrichmentProposal(...)`
  - Batch: `run-catalog-enrichment-draft-batch` calls this function per draft
- Purpose: generate structured enrichment proposal for unresolved term
- Input: `{ normalized_text }`
- Output: typed proposal (`ingredient_type`, names, slug, units, seasonality, confidence, reasoning)
- State impact: advisory by itself (no DB mutation)
- Risk level: Medium
  - constrained output + validation + fallback lowers risk
  - still model-dependent classification risk
- Usefulness: High (core enrichment engine)

## 2.2 `run-catalog-enrichment-draft-batch` (Edge Function)
- Entry point:
  - App button and automation cycle
- Purpose: orchestrate pending draft enrichment
- Input: `{ limit }`
- Output: per-item summary (`succeeded/failed/skipped`, validation state)
- State impact:
  - upserts draft fields
  - validates draft
  - may mark draft `ready`
- Risk level: Medium-High
  - state-changing in batch
  - safe because it does not create ingredients directly
- Usefulness: High

## 2.3 `run-catalog-ingredient-creation-batch` (Edge Function)
- Entry point:
  - App button and automation cycle
- Purpose: convert ready drafts into canonical ingredients + localizations + alias + mark `applied`
- Input: `{ limit }`
- Output: created/skipped/failed summary
- State impact: High (writes canonical catalog)
- Risk level: High
- Usefulness: High but needs stricter confidence/exception policy over time

## 2.4 `run-catalog-automation-cycle` (Edge Function)
- Entry point: app admin button
- Purpose: chained orchestration (recovery -> enrichment -> creation)
- Input: limits per stage
- Output: stage summaries
- State impact: High (multi-stage mutation)
- Risk level: High (compound effects)
- Usefulness: High for solo founder operations

## 2.5 `parse-recipe-caption` (Edge Function)
- Entry point: recipe import/parse flows (not catalog admin directly)
- Purpose: recipe parsing via LLM
- Catalog relation: indirect (affects unresolved observation generation downstream)
- State impact: indirect
- Risk level: Medium
- Usefulness: still useful, but not part of core catalog intelligence contract

## 2.6 App-side deterministic proposal provider
- Entry point: `CatalogEnrichmentProvider` fallback path
- Purpose: fallback proposal when remote fails
- State impact: advisory only unless user saves/marks ready
- Risk level: Low-Medium
- Usefulness: High reliability fallback

Observations:
- AI is already centralized correctly around `catalog-enrichment-proposal` for catalog proposal generation.
- Main risk is not proposal generation; risk is orchestration stages that auto-promote proposals into catalog writes.

---

## 3. Redundancy / Chaos Analysis

### 3.1 Overlapping queue surfaces
- Candidate queue, coverage blockers, observation coverage, pending-draft review, ready-draft queue, reconciliation preview all coexist in one view.
- Even after recent cleanup, `CatalogCandidatesDebugView` remains a monolithic mixed-role screen.

### 3.2 Duplicate action paths
- Alias decisions can be done via:
  - direct alias approval action
  - batch triage RPC
  - bulk alias operations
- Draft prep can happen via:
  - per-candidate editor
  - batch triage prepare
  - automation cycle + enrichment batch

### 3.3 Legacy/debug mixed with primary operations
- Technical diagnostics, reconciliation, URL import, and catalog ops are still bundled in one screen/component file.
- Operational model is conceptually "control panel", but implementation is still "god view".

### 3.4 Manual work that should be automated
- Localization still has manual tooling, while direction is automation-first.
- Trivial alias confirmations still require human clicks when confidence is very high.

### 3.5 Flat-catalog assumptions still present
- Several heuristics and review flows still reason as flat text matching + blocker categories.
- Hierarchy fields exist but are mostly advisory, not operationally first-class.

### 3.6 Reconciliation friction
- Safe preview/apply mismatch is expected but operationally confusing.
- Legacy mapping bridge remains the dominant bottleneck for apply throughput.

### 3.7 Historical/script residue
- `scripts/catalog_triage_batch.py` and related docs still describe an alternate operational path.
- This is now secondary to backend-native workflows but still visible in the project narrative.

---

## 4. Keep / Remove / Merge Plan

### KEEP
- Backend admin auth model:
  - `catalog_admin_allowlist`, `is_catalog_admin`, `assert_catalog_admin`, `is_current_user_catalog_admin`
- Unified canonical model tables:
  - `ingredients`, `ingredient_localizations`, `ingredient_aliases_v2`
- Enrichment draft pipeline primitives:
  - upsert/get/validate/list-ready/create-from-draft
- Consolidated admin snapshot RPC:
  - `get_catalog_admin_ops_snapshot(...)`
- Automation cycle edge function + stage runners
- Reconciliation safety preview/apply and audit tables

### KEEP BUT REFACTOR
- `CatalogCandidatesDebugView.swift`
  - keep capabilities, split into smaller focused components/files
- `SupabaseService.swift`
  - keep API coverage, further modularize catalog concerns behind dedicated repositories/services
- `CatalogAdminOpsService.swift`
  - keep as app boundary; add explicit operation domains (queues, draft lifecycle, reconciliation)
- `run-catalog-automation-cycle`
  - keep chain, improve policy gates and exception routing before expanding volume

### MERGE
- Merge overlapping "queue" concepts into a single exception-driven inbox model:
  - alias exceptions
  - new variant/new root review
  - reconciliation bridge gaps
  - batch failures
- Merge redundant manual batch concepts into one operator command set:
  - run cycle
  - review exceptions
  - approve/reject targeted items

### DEPRECATE
- Manual localization as primary operator task in day-to-day workflow
- Script-led triage (`scripts/catalog_triage_batch.py`) as normal operating path
- Legacy labels and historical “debug” framing for primary catalog operations

### REMOVE (from primary UX; keep hidden if needed short-term)
- Primary-surface localization queue/actions
- Primary-surface dense metadata (rows/recipe counts/raw blocker reasons)
- Opaque historical batch labels as operator-facing language

---

## 5. Target Operating Model

### A. Fully automatic (no human required)
- Observation recovery from saved/imported recipes
- High-confidence alias auto-approval (policy-gated)
- Localization generation/sync from AI + deterministic rules for high-confidence cases
- Pending-draft enrichment proposal generation
- Low-risk draft validation transitions

### B. Automatic with audit (no immediate human step, but logged/reviewable)
- Batch proposal updates to pending drafts
- Auto-promotion of drafts to ready when strict validation + confidence thresholds pass
- Ingredient creation from ready drafts when confidence + policy constraints pass
- Legacy bridge mapping backfill where deterministic and reversible

### C. Review queue (human-in-the-loop)
- Ambiguous alias vs new variant decisions
- New root ingredient creation with low/medium confidence
- Hierarchy parent assignment when semantic ambiguity exists
- Conflicts between existing child nodes and proposed canonicalization

### D. Error/anomaly queue
- Edge function failures/timeouts
- Validation failures that block ready status
- Creation failures (duplicates, constraints, policy conflict)
- Reconciliation apply blocked by missing legacy bridge mappings

Design intent:
- Operator should mostly handle exceptions, not routine triage.
- Human review load should shrink over time as confidence-policy coverage increases.

---

## 6. Human-in-the-Loop Policy

Human review MUST remain required for:
- Any low-confidence classification (`confidence=low`) that mutates canonical catalog
- Any `new_root` creation candidate without strong supporting signals
- Any parent-child assignment when parent is uncertain or multiple plausible parents exist
- Any semantic conflict with existing canonical node(s)
- Any destructive/overwriting action (future scope)

Human review SHOULD NOT be required for:
- Obvious alias variants with high confidence and governed target
- Routine localization additions where canonical identity is already clear
- Deterministic housekeeping/recovery jobs

Operational rule:
- Manual approval is for semantic risk, not for repetitive clerical tasks.

---

## 7. Cleanup Roadmap

### Phase A: Remove noise / simplify UI
- Objective: make the operator surface obvious in <10 seconds
- Areas:
  - `Season/Views/CatalogCandidatesDebugView.swift`
  - split into focused queue + technical components
- Why: reduce cognitive load and accidental misuse
- Risk: Low

### Phase B: Remove redundant manual work
- Objective: stop manual localization + trivial alias burden
- Areas:
  - admin UI queue policy (presentation)
  - automation orchestration policy (no new schema required initially)
- Why: solo-founder throughput
- Risk: Medium (needs careful policy gating)

### Phase C: Automate low-risk catalog operations
- Objective: auto-run safe alias/localization/draft transitions with strict guardrails
- Areas:
  - edge function stage policies
  - candidate policy thresholds
  - audit/result reporting
- Why: turn catalog ops from manual queue to exception handling
- Risk: Medium-High

### Phase D: Exception-based review inbox
- Objective: one queue for only uncertain/high-risk/conflicting items
- Areas:
  - snapshot contract shape (likely v-next)
  - app queue rendering and action routing
- Why: unify overlapping review surfaces
- Risk: Medium

### Phase E: Catalog maintenance agent (future)
- Objective: supervised autonomous maintenance with bounded actions
- Areas:
  - orchestration layer + policy engine + audit
- Why: long-term scalability
- Risk: High (defer until phases A-D stabilize)

---

## 8. Recommended Next Step

Single best next implementation step:

**Implement backend-driven automatic localization handling for high-confidence covered terms, and remove localization as an operator queue from day-to-day workflow (keep only anomaly visibility in technical tools).**

Why this is next:
- Aligns with architecture contract (identity is canonical, localization is display layer)
- Removes high-frequency manual toil immediately
- Preserves safety by keeping low-confidence/failed cases in anomaly queue
- Requires no broad schema redesign and complements existing automation cycle

Scope recommendation (implementation step, not done in this review):
- Backend job/path for localization auto-upsert where canonical target is unambiguous
- Keep strict audit trail
- UI: show localization anomalies only under technical tools

---

### Hard truths (explicit)
- The system is already powerful enough; current bottleneck is operational complexity and overlap, not missing primitives.
- `CatalogCandidatesDebugView` remains the main complexity hotspot and should be decomposed before further feature growth.
- Legacy bridge mapping is still the practical limiter for reconciliation impact.
- Continuing to add new queues without convergence will reintroduce chaos quickly.
