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
| `olive` | `needs_human_review`, high risk | Good: Italian PAT evidence reinforces that bare olive terms are ambiguous and should not auto-collapse. |
| `fiocchi d avena` | `create_canonical`, medium risk | Good: CREA evidence reinforces product-form identity rather than generic oat collapse. |
| `acqua di cottura` | `ignore_noise`, low risk | Good: recipe-process byproduct remains non-catalog truth. |

## Interpretation

The external evidence layer is working as intended: it changes the evidence
packet seen by the agent without creating catalog changes. In this run, the
agent used the new context directionally:

- evidence-backed product-form terms can become `create_canonical`;
- ambiguous Italian product families stay in review;
- process/context terms stay out of the catalog.

The next useful step is to run another bounded dry-run after adding a few more
reviewed Italian evidence rows for terms currently crowding the review inbox,
then compare `needs_human_review` volume and blocking-question quality.
