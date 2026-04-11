# Catalog Architecture Contract

This document is the canonical technical contract for Season ingredient catalog architecture.
All catalog-related features, migrations, RPCs, enrichment flows, and admin workflows MUST follow this document.

## 1) Core Principles (Non-Negotiable)
- Rule: `ingredient` is the single canonical domain entity for food identity.
- Rule: Domain identity MUST NOT be split into parallel models (`product` vs `produce` vs `basic`) for canonical truth.
- Rule: Specific ingredients MUST NOT be collapsed into generic ingredients when culinary identity changes.
- Rule: `legacy_ingredient_mapping` is compatibility-only and MUST NOT define canonical identity.
- Rule: Ingredient identity MUST be language-independent.
- Rule: Canonical identity decisions MUST be backend-governed and auditable.

## 2) Target Data Model (Phase 1)
- `public.ingredients`
  - Represents canonical ingredient identity nodes.
  - Required baseline fields: `id`, `slug`, `parent_ingredient_id` (nullable).
  - Optional Phase-1 metadata: `specificity_rank`, `variant_kind`.
  - MUST NOT store language-specific display text as canonical truth.
  - MUST NOT be replaced by legacy IDs.
- `public.ingredient_localizations`
  - Represents language-specific display values for an ingredient node.
  - MUST contain translations only.
  - MUST NOT encode parent-child structure or identity decisions.
- `public.ingredient_aliases_v2`
  - Represents normalized text mapping to a canonical ingredient node.
  - MUST be governance-controlled (approval state, activation state).
  - MUST NOT be used as a substitute for creating a canonical ingredient when identity is genuinely new.

## 3) Hierarchy Model
- Model: Adjacency list (`parent_ingredient_id`) on `ingredients`.
- Rationale: Simple, scalable, migration-safe, and sufficient for current scope.
- We are NOT introducing complex taxonomy frameworks in this phase (no mandatory closure graph, ontology engine, or multi-axis taxonomy model).

Examples:
- `farina` -> `farina_00`
- `cipolla` -> `cipolla_rossa`
- `riso` -> `riso_carnaroli`

Classification rules:
- Child ingredient:
  - Added specificity changes meaningful culinary identity, behavior, or substitution semantics.
  - Examples: cultivar/type, protected designation (DOP/IGP), shape/form where semantically relevant.
- Separate root:
  - Ingredient does not semantically belong as a specialization of an existing root.
  - Ingredient family is independent and not just a refinement of another node.

## 4) Localization Strategy
- Canonical identity is language-neutral and lives in `ingredients` (`id`, `slug`, hierarchy).
- All translated names live in `ingredient_localizations`.
- Fallback order for display:
  - Requested language
  - Default language (`it` for current launch, configurable)
  - `slug` as technical fallback
- Localization MUST NOT drive canonical identity creation by itself.

Why this is required:
- Prevents language-specific duplication of canonical ingredients.
- Enables multi-language expansion without changing ingredient IDs.
- Keeps matching and enrichment pipelines stable across locales.

## 5) Alias & Matching Strategy
- Aliases map normalized free text to canonical ingredient nodes.
- Alias targeting rule:
  - MUST point to the most specific canonical node when confidence is high and semantics are clear.
  - MAY fallback to parent node only when specificity is unclear.
- Import flow:
  - First resolve via approved alias/localization exact matching.
  - If unresolved, log observation and route through candidate/enrichment workflow.
- LLM enrichment flow:
  - Produces proposals only.
  - MUST NOT bypass admin review/governance.
- User input flow:
  - User text is normalized and matched against governed aliases/localizations.

## 6) Legacy Mapping Policy (Critical)
- `legacy_ingredient_mapping` is temporary compatibility infrastructure.
- It exists to support old recipe storage/app contracts during transition.
- It MUST NOT define canonical identity.
- It MUST NOT force flattening specific nodes into generic identity.

Policy examples:
- Wrong:
  - `farina_00` collapsed into `flour` as canonical identity everywhere.
- Correct:
  - `farina_00` remains canonical.
  - Legacy mapping is used only where backward compatibility requires legacy IDs.

## 7) Migration Strategy (Phased)
- Phase 1: Schema introduction (non-breaking)
  - Goal: Introduce hierarchy-capable canonical model.
  - Scope: Additive schema changes (`parent_ingredient_id`, optional metadata), no destructive rewrites.
  - Not included: full recipe model rewrite, bulk taxonomy automation.
- Phase 2: Selective parent-child assignment
  - Goal: Curate high-value families (flour, onion, rice, cheeses, pasta shapes).
  - Scope: Controlled assignments via admin-reviewed workflow.
  - Not included: large auto-generated taxonomy.
- Phase 3: Enrichment pipeline alignment
  - Goal: Ensure candidate/enrichment outputs include parent/specificity decisions.
  - Scope: Draft validation + admin review alignment.
  - Not included: autonomous ingredient creation without review.
- Phase 4: Recipe alignment (future)
  - Goal: Move recipe ingredient references toward canonical `ingredient_id` usage.
  - Scope: Safe migration path with compatibility bridge retained during transition.
  - Not included: abrupt legacy contract removal.

## 8) Governance Rules
- Create a new ingredient when:
  - Text represents a semantically distinct culinary ingredient not captured by existing canonical nodes.
- Use alias when:
  - Text is a linguistic/surface variant of an existing canonical node.
- Assign a parent when:
  - New node is a strict semantic refinement of an existing canonical ingredient.
- Avoid taxonomy corruption by:
  - Requiring explicit review for parent assignment.
  - Blocking bulk/unreviewed parent rewrites.
  - Recording decisions and rationale in auditable workflow artifacts.

## 9) Anti-Patterns (Must Never Happen)
- Never collapse specific ingredients into generic ones for convenience.
- Never create parallel canonical systems for the same ingredient domain.
- Never use `legacy_ingredient_mapping` as primary identity.
- Never mix localization strings with canonical identity keys.
- Never allow uncontrolled or automatic parent assignment at scale.
- Never bypass governance/audit for catalog mutations.

## 10) Future Extensions (Not Implemented Yet)
- Optional closure table for fast ancestor/descendant queries.
- Optional non-tree ingredient relationships (substitution, pairing, processing relationships).
- Future recipe storage alignment to canonical `ingredient_id` as primary reference.

Direction only:
- These extensions are valid only if they preserve the principles in Section 1.
- They are not authorized for immediate implementation without explicit scope approval.
