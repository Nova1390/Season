# Catalog Policy Backlog

## 1. Closed Patterns
- Clean Canonical Core
  - Example: `burro a temperatura ambiente` -> `burro` (ready)
  - Example: `parmigiano reggiano dop da grattugiare` -> `parmigiano reggiano dop` (ready)
- Derived Culinary Entities
  - Example: `tuorli (circa 7)` -> `tuorli` (ready)
- Produce Clean Identity
  - Example: `limoni 1` -> `limoni` (ready)
  - Example: `prezzemolo 1 ciuffo` -> `prezzemolo` (ready)
  - Example: `sedano 1 costa` -> `sedano` (ready)
  - Example: `zucchine 2` -> `zucchine` (ready)
- Intrinsic Variants (basic)
  - Example: `latte intero` (ready)
  - Example: `zucchero di canna` (ready)
- Transformed / Preserved Products
  - Example: `tonno sott'olio` (ready)
  - Example: `salmone affumicato` (ready)
  - Example: `capperi sotto sale` (ready)
- Narrow typing override for preserved plant-derived products
  - Example: `capperi sotto sale` typed as `basic` (scoped override)

## 2. Open Patterns
- Post-preparation qualifiers that still sometimes keep drafts pending.
- Typing edge cases beyond narrow scoped overrides.
- Confidence instability for some transformed/preserved products.
- Remaining high-confidence pending `basic` cases worth targeted analysis.

## 3. Known Residual Cases
- `tonno sott'olio sgocciolato` (pending in latest observed run; normalized identity aligns to `tonno sott'olio`).
- Additional residual cases should be appended only after confirmed live observations.

## 4. Policy Decisions Already Made
- Catalog models ingredient identity, not recipe instructions.
- Weak recipe/use qualifiers are removable during identity normalization.
- Intrinsic variants preserve identity-bearing type/composition.
- Maturity/aging descriptors are not canonical identity.
- Transformed markers like `sott'olio`, `affumicato`, `sotto sale` are identity-bearing.
- `sgocciolato` is not identity-bearing.
- Narrow plant-derived preserved products may be typed as `basic` (scoped policy).

## 5. Next Candidate Areas
- Typing policy expansion (only if recurring evidence supports it).
- Deterministic/provider fallback quality improvements.
- Residual pending `basic` review and confidence-stability checks.
- `catalog_ingredient_enrichment_drafts` lifecycle policy: keep current dual use (operational state + historical trace) for now, but track long-term retention/separation needs to prevent table growth, query noise, and maintenance drift.
