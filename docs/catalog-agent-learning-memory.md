# Catalog Agent Learning Memory

Status: backend-first implementation contract.

This document describes the structured continuous-improvement memory for the Catalog Governance Agent.

## Purpose

The agent should not merely fail, get rejected, or ask for help. It should learn operationally.

Learning memory turns important outcomes into reusable artifacts:

- human rejections;
- validation failures;
- manual apply failures;
- recurring ambiguity;
- catalog gaps;
- policy gaps;
- prompt improvements;
- validator improvements.

## Backend Objects

Implemented by:

- `supabase/migrations/20260511120000_catalog_agent_structured_learning.sql`
- `supabase/migrations/20260511123000_catalog_agent_learning_context.sql`

Table:

- `public.catalog_agent_learnings`

RPCs:

- `public.record_catalog_agent_learning(...)`
- `public.get_catalog_agent_learning_memory(...)`
- `public.get_catalog_agent_learning_context(...)`
- `public.review_catalog_agent_learning(...)`

## Learning Types

Supported types:

- `human_rejection`
- `validator_failure`
- `manual_apply_failure`
- `policy_gap`
- `ambiguity`
- `duplicate_identity_risk`
- `prompt_improvement`
- `catalog_gap`
- `other`

## Lifecycle

Supported statuses:

- `draft`
- `needs_review`
- `accepted`
- `rejected`
- `implemented`
- `superseded`

Default status is `needs_review`.

## Automatic Learning Sources

The migration also updates existing RPCs so learning artifacts are created automatically when:

- a reviewer rejects a proposal;
- a reviewer requests more evidence;
- deterministic validation fails;
- manual apply fails.

## Safety Boundary

Learning memory is advisory.

It does not:

- mutate ingredients;
- approve aliases;
- add localizations;
- reconcile recipes;
- change prompt behavior automatically.

Accepted learnings must still be translated into explicit prompt, validator, policy, or evaluation-set changes.

## Runtime Context

The proposal-only Edge Function now reads learning memory before calling the LLM.

Runtime flow:

- fetch bounded triage snapshot;
- fetch compact learning context for the candidate normalized texts;
- attach term-specific lessons to each work item as `context.relevant_learning_memory`;
- skip recent unchanged proposals only after learning memory is attached;
- attach global lessons as `global_learning_memory`;
- include `learning_memory_policy` so the model understands status semantics.

If a term already has a recent live proposal, the agent normally skips it to control cost and noise. A newer learning-memory entry reopens the term for another proposal-only pass, because the agent now has information it did not have during the previous decision.

Example implemented policy:

- Bare `lievito` maps to the generic catalog item `lievito` when no recipe evidence specifies a more precise leavening variant.
- Specific terms such as baking powder, brewer's yeast, sourdough starter, fresh yeast, or dry yeast remain separate identities and should only be chosen when the source text supports them.

Included learning statuses:

- `implemented`: behavior/policy already changed; follow it;
- `accepted`: human-reviewed lesson; strongly prefer it unless current evidence contradicts it;
- `needs_review`: useful caution from an observed failure or operator note.

Excluded learning statuses:

- `draft`
- `rejected`
- `superseded`

## Smart Import Read Path

Smart Import also reads this memory, but with a narrower contract than Catalog Governance.

`parse-recipe-caption` may call `get_catalog_agent_learning_context(...)` for the ingredient candidates sent by Swift before targeted ingredient-resolution LLM calls. The memory is included as compact advisory context so the drafting agent can avoid repeated semantic mistakes, for example:

- not collapsing identity-bearing variants into a generic parent when implemented learning says the variant matters;
- keeping non-identity conditions as recipe text when learning says they should not become catalog identity;
- separating ingredient-existence confidence from canonical-target confidence.

Smart Import must not:

- write learning artifacts;
- approve aliases;
- create canonical ingredients;
- reconcile saved recipe ingredients;
- block import if learning lookup fails.

This keeps the learning loop useful for creators while preserving the Catalog Governance Agent as the manager for durable catalog policy.

Runtime learning memory still does not mutate catalog data. It only changes the evidence available to the proposal-only model.
