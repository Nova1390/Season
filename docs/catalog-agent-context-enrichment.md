# Catalog Agent Context Enrichment

Status: backend-first implementation contract.

This document describes how Season gives the Catalog Governance Agent better context before it reasons about unresolved ingredients.

## Problem

Some terms are clearly ingredients but not always clearly one canonical ingredient.

Example:

- `lievito` is an ingredient.
- It may mean baker's yeast, dry yeast, baking powder, sourdough starter, or another leavening agent depending on recipe context.

The agent should not treat this as "low confidence that the term is an ingredient". It should treat it as "high confidence ingredient, uncertain canonical target".

## Implementation

Implemented by:

- `supabase/migrations/20260511110000_catalog_agent_context_enrichment.sql`

Updated runtime contract:

- `supabase/functions/run-catalog-agent-triage/index.ts`
- `supabase/functions/run-catalog-agent-triage/llm_contract.ts`
- `supabase/migrations/20260511123000_catalog_agent_learning_context.sql`

The snapshot source is now:

- `catalog_agent_triage_snapshot_v2_context_enriched`

## Added Context

Each work item can include:

- latest recipe id;
- recipe title;
- recipe source;
- servings;
- matched ingredient rows;
- nearby ingredients;
- all ingredient names, capped;
- step snippets mentioning the term;
- broader canonical candidates;
- broader alias candidates;
- semantic disambiguation instructions.
- relevant learning memory from prior review, validation, apply, or operator observations.

## Reasoning Rule

The agent must separate:

- ingredient-existence confidence;
- canonical-target confidence.

If the term is clearly an ingredient but target is ambiguous, the agent should return:

- `needs_human_review`;
- candidate targets in `evidence`;
- specific blocking questions;
- context-based rationale.

It should not return `ignore_noise` or vague low-confidence output.

## Learning Memory Rule

The Edge Function augments eligible work items with `context.relevant_learning_memory` before calling the LLM.

This memory is not a direct mutation policy. It is prior operational evidence.

The agent should:

- follow `implemented` and `accepted` lessons unless the current packet contains stronger contradictory evidence;
- treat `needs_review` lessons as caution signals;
- avoid repeating prior failed or ambiguous recommendations;
- cite the `learning_id` in `evidence` when a lesson materially changes the decision.

## Retry Rule

Previously failed proposals should not block re-analysis after context improves.

The Edge Function skips recent duplicate work only for live proposals. Terminal proposal states such as `failed_validation`, `rejected`, and `superseded` are retryable learning signals.

## Dev Observation

On 2026-05-11, the context-enriched snapshot for `lievito` showed:

- the term is treated as likely ingredient, not noise;
- the only current catalog candidate is `lievito_in_polvere_per_dolci` / baking powder;
- `recipe_context` is empty because the observation has no `latest_recipe_id`;
- the correct next action remains human-review or richer context, not blind alias approval.

## Safety Boundary

This enrichment is read-only.

It does not:

- call an LLM;
- approve aliases;
- create ingredients;
- add localizations;
- reconcile recipes;
- update observations;
- change proposal lifecycle.
