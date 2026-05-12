# Catalog Agent Context Enrichment

Status: backend-first implementation contract.

This document describes how Season gives the Catalog Governance Agent better context before it reasons about unresolved ingredients.

## Problem

Some terms are clearly ingredients but not always clearly one canonical ingredient.

Example:

- `lievito` is an ingredient.
- Bare `lievito` now has a governed generic catalog target.
- More specific terms may still mean baker's yeast, dry yeast, baking powder, sourdough starter, or another leavening agent depending on recipe context.

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

If the term is clearly an ingredient and the problem is not ambiguity but catalog absence, the agent should return:

- `create_canonical`;
- `status = draft`;
- proposed slug/localized name/language;
- evidence explaining why no existing target is safe.

Missing target and ambiguous target are different states. Missing target should create a catalog-gap proposal; ambiguous target should ask a precise review question.

Accepted or implemented learning memory can resolve part of the policy question. If learning says a product-family variant must not be collapsed into the base ingredient, and the variant identity is clear, the agent should propose a child/specialized catalog gap instead of reopening the same human review.

For bare `lievito`, the preferred target is the generic `lievito` catalog item when that candidate is present and recipe context does not specify a more precise leavening variant. Specific variants remain separate catalog identities.

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

On 2026-05-11, the context-enriched snapshot for `lievito` originally showed:

- the term is treated as likely ingredient, not noise;
- the only current catalog candidate is `lievito_in_polvere_per_dolci` / baking powder;
- `recipe_context` is empty because the observation has no `latest_recipe_id`;
- the correct next action remains human-review or richer context, not blind alias approval.

Later on 2026-05-11, Season added a governed generic `lievito` base ingredient so bare unspecified `lievito` can resolve safely without being forced into `lievito_in_polvere_per_dolci`.

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
