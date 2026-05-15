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
- `supabase/migrations/20260514153000_catalog_agent_worker_learning_writer.sql`
- `supabase/migrations/20260515100000_catalog_agent_75_matcher_learning_contract.sql`

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
- `alias_policy`
- `variant_policy`
- `state_vs_identity`
- `ambiguous_term`
- `worker_failure`
- `other`

Current semantic taxonomy:

- `alias_policy`: a surface form, plural, import text, or localization-like phrase should map to an existing safe target through alias governance.
- `variant_policy`: the term is an identity-bearing variant and must not collapse into a generic parent unless explicit policy says so.
- `catalog_gap`: the ingredient identity appears clear, but the catalog lacks the canonical child/product.
- `state_vs_identity`: the observed text is a preparation, freshness, leftovers, or cooking state that should usually stay in recipe text rather than become catalog identity.
- `ambiguous_term`: the text can point to multiple culinary identities and needs more evidence before action.
- `worker_failure`: a delegated worker failed, returned failed items, or produced a surprising terminal result.
- `prompt_improvement`: the model or prompt missed a reusable rule that should become eval/prompt guidance.

Legacy types remain supported for backwards compatibility with existing learning rows and review events.

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
- a quality gate downgrades or blocks a proposal and the learning writer is enabled;
- manual apply fails;
- a delegated worker job fails;
- a delegated worker job completes with failed items.

Human rejection, more-evidence, failed validation, quality-gate downgrade, and worker failure are all treated as learning opportunities. `needs_review` rows are advisory only; they should help the next run ask better questions, but they must not override validators. `accepted` and `implemented` rows can influence matcher/prompt behavior more strongly, but still do not become catalog truth by themselves.

Worker learning is intentionally manager-level. A worker failure does not prove a catalog policy by itself, but it is evidence that future delegation should become smaller, safer, or better preflighted. The worker lifecycle RPCs now record proposal events such as `worker_job_failed` and `worker_job_completed_with_failures`, then create `catalog_agent_learnings` rows with status `needs_review`.

Worker learning must not block the worker ledger from closing. If the learning insert fails, the job still records its terminal status and emits a database notice so operations are not left half-open.

## Safety Boundary

Learning memory is advisory.

It does not:

- mutate ingredients;
- approve aliases;
- add localizations;
- reconcile recipes;
- change prompt behavior automatically.

Accepted learnings must still be translated into explicit prompt, validator, policy, or evaluation-set changes.

No learning row becomes source-of-truth catalog data without passing through a governed validator/RPC path. In practice this means the agent may remember that `pane raffermo` is usually bread with a recipe-state modifier, but it still cannot silently mutate `ingredients`, aliases, localizations, or recipe ingredient rows from memory alone.

## Runtime Context

The proposal-only Edge Function now reads learning memory before calling the LLM.

Runtime flow:

- fetch bounded triage snapshot;
- expand lexical candidates with singular/plural, compact text, aliases, localizations, preparation-state, and governed override terms;
- fetch compact learning context for the candidate normalized texts;
- attach term-specific lessons to each work item as `context.relevant_learning_memory`;
- attach weak `training_signals` from real Smart Import captions when available;
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

## Evaluation Reports

The Smart Import learning-context runner can now write a compact JSON coverage report:

```bash
python3 scripts/smart_import_learning_cases/run_learning_context.py \
  --write-report docs/smart-import-learning-context-latest.json
```

The report records:

- pass/fail per learning fixture;
- how many fixture terms currently have memory;
- which terms are missing memory;
- Supabase learning-context metadata.

This gives the two-agent system a shared, no-LLM health check: Smart Import can prove it is receiving relevant catalog lessons before it asks for targeted ingredient reasoning, while Catalog Governance remains the only writer of durable catalog knowledge.
