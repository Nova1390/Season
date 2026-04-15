# Catalog Policy Specification

## 1. Core Principles
- The catalog models ingredient identity, not recipe instructions, serving context, or preparation steps.
- Identity decisions should remain stable, conservative, and understandable.
- Simplicity is preferred over deep taxonomy when equivalent safety can be achieved.
- Input must be normalized before semantic and promotion evaluation.
- Automation is applied only when confidence is high and ambiguity is low.
- Unsafe or unclear cases remain reviewable by design.

## 2. Identity Normalization
Before enrichment and promotion checks, input is reduced to a cleaned identity form.

Normalization removes weak recipe-level qualifiers that do not define canonical ingredient identity, including:
- quantity noise (numbers, fractions, approximate counts)
- weak quantity/unit phrases (for example: pizzico, mazzetto, ciuffo, costa, pezzi)
- usage/preparation phrases (for example: "da ...", "per ...")
- storage/state phrases (for example: room temperature, refrigerated state)
- parentheses content

Representative outcomes:
- `pepe nero 1 pizzico` -> `pepe nero`
- `burro a temperatura ambiente` -> `burro`
- `prezzemolo 1 ciuffo` -> `prezzemolo`

## 3. Auto-Ready Rules
Auto-ready behavior is rule-based, additive, and guarded.

### 3.1 Clean Canonical Core (basic)
Applies to `basic` identities when:
- validation passed
- high confidence
- cleaned identity differs from original
- removed qualifiers are present and all belong to approved low-risk qualifier types
- `alias_conflict` absent
- `semantic_category_unknown` absent
- risky semantic category flags absent
- no mixed or unclear identity signal

Scoped policy note:
- `canonical_conflict` may be ignored for this rule only when all of the following are true:
  - confidence is very high (strict threshold)
  - cleaned identity is stable and clearly stronger than original noisy input
  - removed qualifiers are only weak recipe/state/use qualifiers
  - no alias conflict is present

Effect:
- draft moves to ready
- manual review is disabled

Validated Examples:
- `burro a temperatura ambiente` -> `burro` (ready)
- `parmigiano reggiano dop da grattugiare` -> `parmigiano reggiano dop` (ready)
- `grana padano dop freddo di frigo (da grattugiare)` -> `grana padano dop` (ready)

### 3.2 Derived Culinary Entities
Applies to a strict allowlist of stable derived entities.
Current allowlist:
- `tuorli`
- `albumi`

Conditions include:
- validation passed
- `ingredient_type = basic`
- high confidence
- cleaned identity exact-match in allowlist
- `alias_conflict` absent

Scoped policy note:
- `canonical_conflict` is intentionally ignored in this helper only

Effect:
- draft moves to ready
- manual review is disabled

Validated Examples:
- `tuorli (circa 7)` -> `tuorli` (ready)

### 3.3 Produce Clean Identity
Applies to produce entries where normalization removes simple quantity noise.
Conditions include:
- validation passed
- `ingredient_type = produce`
- confidence at a strict high threshold (currently 0.97)
- cleaned identity differs from original
- removed qualifiers are present and restricted to simple quantity/unit qualifier classes
- `alias_conflict` absent
- `semantic_category_unknown` absent
- risky semantic category flags absent

Scoped policy note:
- `canonical_conflict` is intentionally ignored in this helper only

Effect:
- draft moves to ready
- manual review is disabled

Validated Examples:
- `limoni 1` -> `limoni` (ready)
- `prezzemolo 1 ciuffo` -> `prezzemolo` (ready)
- `sedano 1 costa` -> `sedano` (ready)
- `zucchine 2` -> `zucchine` (ready)

### 3.4 Category-Specific Safe Behavior (example: pasta)
For safe lexical families (for example pasta shapes/styles):
- root parent fallback is allowed when specific intermediate parent is missing
- minimal hierarchy is considered sufficient when confidence and signals are strong
- obvious shape/style variants can progress without requiring taxonomy expansion

### 3.5 Intrinsic Variants (basic)
Applies to stable `basic` ingredient identities where the variant descriptor is identity-bearing (not weak recipe noise).

Intrinsic variants are terms where the qualifier changes the product identity itself, for example composition, style, or designation, and therefore should not be treated as removable cleanup qualifiers.

Clarification:
- Identity-bearing intrinsic variants are composition/type variants (for example fat-content/type variants).
- Aging duration and similar maturity descriptors (for example `24 mesi`) are descriptive quality attributes, not separate canonical ingredient identities.

How this differs from Clean Canonical Core:
- Clean Canonical Core removes weak recipe/state/use qualifiers and promotes the cleaned core identity.
- Intrinsic Variants preserve the qualifier as part of the identity (no qualifier stripping required for correctness).

Conservative auto-ready eligibility for Intrinsic Variants:
- validation passed
- `ingredient_type = basic`
- high confidence (strict threshold)
- semantic identity is stable and clear
- `alias_conflict` absent
- no mixed/composite identity signal
- risky semantic category flags absent

Still blocked:
- alias conflict
- mixed/composite identity
- risky semantic category
- low confidence or unclear semantic identity

Validated Examples:
- `latte intero`
- `zucchero di canna`

### 3.6 Transformed / Preserved Products (basic)
Applies to stable `basic` identities where transformation/preservation is part of the product identity.

Transformed/preserved products are terms where the qualifier defines a durable product form (not recipe noise), for example preserved medium or processing style.

Clarification on identity scope:
- Preservation/processing markers such as `sott'olio`, `affumicato`, and `sotto sale` are identity-bearing for this rule.
- Post-use/preparation qualifiers such as `sgocciolato` are not identity-bearing and must not create a separate canonical ingredient.
- Example normalization target: `tonno sott'olio sgocciolato` -> `tonno sott'olio`.
- Narrow typing clarification:
  - Some plant-derived preserved condiments/products may be classified as `basic` (pantry) rather than `produce` when the preservation marker is explicit and stable.
  - Example: `capperi sotto sale`.
  - This clarification is scoped and conservative: it does not imply broad reclassification of preserved vegetables, and it does not change fresh produce logic.

How this differs from other rules:
- Unlike Clean Canonical Core, these are not weak cleanup qualifiers to strip away.
- Unlike Intrinsic Variants, these are processing/preservation-form identities rather than composition/type variants.

Conservative auto-ready eligibility for Transformed / Preserved Products:
- validation passed
- `ingredient_type = basic`
- high confidence (strict threshold)
- transformed/preserved identity signal is explicit and stable
- `alias_conflict` absent
- no mixed/composite identity signal
- risky semantic category flags absent
- no broad generalization beyond clear transformed/preserved forms

Still blocked:
- alias conflict
- mixed/composite identity
- risky semantic category
- low confidence or unclear transformed/preserved signal

Validated Examples:
- `tonno sott'olio`
- `salmone affumicato`
- `capperi sotto sale`

## 4. Category Allowlist
Current safe categories used by scoped automation behavior:
- pasta
- rice
- flour
- produce (through produce clean-identity rule)
- derived entities (strict lexical allowlist)

These are treated as safer due to:
- relatively low ambiguity
- strong lexical signals
- predictable identity structure

## 5. Hard Blockers
Auto-ready remains blocked when rule-specific safety conditions fail.
Common blockers include:
- `alias_conflict`
- `semantic_category_unknown` (for rules where semantic certainty is required)
- confidence below the rule threshold
- risky semantic category flags
- unclear or mixed identity input

Blockers are intentionally rule-scoped; not every blocker applies to every helper.

## 6. Conflict Handling
Conflict treatment is explicit and scoped.

Default posture:
- conflicts are generally conservative and can block promotion.

Scoped exceptions:
- `canonical_conflict` is intentionally allowed in:
  - clean canonical core (basic), under strict high-confidence cleaned-identity conditions
  - derived culinary entity auto-ready
  - produce clean-identity auto-ready

Outside those scoped rules, conflict behavior remains unchanged.

## 7. What Remains Manual
The following classes remain pending/manual by policy:
- ambiguous identities with weak semantic evidence
- composite or mixed expressions
- low-confidence outputs
- unresolved conflicts outside scoped safe-rule exceptions
- context-dependent or unclear brand/product expressions

Manual review is retained where automation confidence is not reliably safe.

## 8. Design Philosophy
- Keep identity modeling simple, stable, and auditable.
- Automate only high-confidence, low-ambiguity paths.
- Prefer narrow, explicit exceptions over broad heuristics.
- Avoid taxonomy explosion; use minimal hierarchy when safe.
- Let real production evidence drive iterative policy refinement.

## Outside Current Scope (for now)
- similar intrinsic variants (fat content, processing level)
- cases not reprocessed yet
