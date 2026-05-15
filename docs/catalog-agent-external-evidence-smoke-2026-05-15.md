# Catalog Agent External Evidence Smoke - 2026-05-15

Status: completed on `Season-dev`.

## Goal

Verify that the first reviewed Italian external-evidence batch is visible to the
Catalog Governance Agent during a non-mutating dry run.

## Runtime

- Environment: `Season-dev`
- Branch: `agent/catalog-governance`
- Function: `run-catalog-agent-triage`
- Mode: `dry_run=true`
- Source domain: `import`
- Limit: `10`
- Persistence: disabled
- Catalog mutations: none
- Agent disabled again after the smoke
- Operator token rotated after the smoke

## Result

- Run ID: `109`
- Items in snapshot: `12`
- Items sent to LLM: `3`
- Proposals returned: `3`
- Proposals persisted: `0`
- Quality-gate blocked proposals: `0`
- External evidence terms requested: `33`
- Terms with external evidence: `3`
- External evidence rows attached: `3`
- Training-signal terms attached: `3`
- Token usage: `28,777` total tokens

## Proposal Shape

| Term | Outcome | Assessment |
| --- | --- | --- |
| `olive` | `needs_human_review`, high risk | Follow-up needed: this was conservative but too strict for creator reality. Bare `olive` should surface a generic `olives` base identity/gap, while specific forms stay variants. |
| `fiocchi d avena` | `create_canonical`, medium risk | Good: CREA evidence reinforces product-form identity rather than generic oat collapse. |
| `acqua di cottura` | `ignore_noise`, low risk | Good: recipe-process byproduct remains non-catalog truth. |

## Interpretation

The external evidence layer is working as intended: it changes the evidence
packet seen by the agent without creating catalog changes. In this run, the
agent used the new context directionally:

- evidence-backed product-form terms can become `create_canonical`;
- ambiguous Italian product families stay in review when the term is truly a family/category, but bare creator-facing base terms such as `olive` should be allowed to become a generic base identity/gap;
- process/context terms stay out of the catalog.

Follow-up:

- `20260515120000_catalog_agent_generic_olive_base_policy.sql` changes bare
  `olive` from always-review to a governed base lookup/gap policy.
- Follow-up run `#110` showed the decision writer was still too conservative
  while the matcher did not yet see the governed lookup.
- Runtime fix: `run-catalog-agent-triage` now reads both `source` and
  `expansion_source` from `context.lexical_candidate_terms`.
- Follow-up run `#112` confirmed matcher behavior:
  `catalog_gap_candidate` + `create_canonical_if_identity_clear`.
- Follow-up run `#113` confirmed final proposal behavior:
  `olive -> create_canonical`, `draft`, medium risk, quality-gate clean,
  `0` persisted mutations because the run was dry-run.
- Agent was disabled again after verification and temporary local key files were
  removed.
