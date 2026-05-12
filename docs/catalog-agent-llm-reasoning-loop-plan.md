# Catalog Agent LLM Reasoning Loop Plan

Status: implementation contract. Step 1 prompt-contract expansion and Step 3 batch-level multi-pass orchestration are implemented in `run-catalog-agent-triage` v4. Per-term adaptive loops, catalog matcher split-out, learning writer, and full budget governor remain planned.

This document defines how the Season Catalog Governance Agent should use LLMs as controlled reasoning tools, not as a single-shot autopilot wrapper.

It complements:

- `docs/catalog-ai-agent-operating-plan.md`
- `docs/catalog-ai-agent-contracts.md`
- `docs/catalog-agent-autopilot-alignment-plan.md`
- `docs/catalog-agent-responsibility-charter.md`
- `docs/catalog-agent-learning-memory.md`

## 1. Goal

The agent should behave like a responsible catalog manager.

For each unresolved ingredient term, it should gather enough evidence to make a safe decision, then either:

- authorize a low-risk worker action;
- create a structured proposal;
- request more evidence;
- escalate to human review with a precise reason;
- write learning memory when the case teaches a reusable rule.

The LLM should be used for semantic depth, not only for a final classification.

## 2. Current Limitation

The current `run-catalog-agent-triage` runtime is intentionally conservative:

- it sends compact work packets to one LLM prompt;
- it receives one structured proposal set;
- it stores proposals only;
- deterministic validators decide whether anything is actionable.

That is safe, but it underuses the model's ability to reason deeply about:

- product families;
- culinary variants;
- substitutability;
- language and market context;
- nutrition, allergy, seasonality, fridge, shopping, and filter implications;
- when a term should become a child variant instead of an alias to a base ingredient.

The v4 runtime keeps the same safety posture while allowing bounded batch-level multi-pass reasoning.

Implemented now:

- semantic profiling pass;
- optional risk review pass;
- final decision writer pass using the existing proposal validator;
- per-role token attribution in `catalog_ai_usage_events`;
- aggregate reasoning trace in the run summary.

Still planned:

- per-term adaptive continuation when one term needs deeper investigation;
- separate catalog matcher role or deterministic matcher wrapper;
- learning writer for failed/rejected/overridden outcomes;
- stronger pre-call budget stop checks.

## 3. Target Loop

The agent should run a finite loop for each work item or small related cluster.

```text
observe unresolved term
  -> load catalog context and learning memory
  -> semantic profiling pass
  -> catalog matching pass
  -> risk review pass when needed
  -> decision synthesis
  -> validator / worker routing
  -> audit and learning memory
```

The loop stops when the agent has either:

- a low-risk validated path;
- a catalog-gap proposal to create a missing canonical ingredient;
- a clear human-review question;
- insufficient evidence after budget is exhausted;
- repeated reasoning passes produce no new evidence.

The loop must never continue indefinitely.

## 4. LLM Task Roles

The agent should call specialized LLM task prompts instead of one overloaded prompt.

### 4.1 Semantic Profiler

Purpose:

- understand what the term likely is.

Inputs:

- normalized text;
- raw examples;
- recipe title and nearby ingredients;
- quantities and units;
- language and source;
- known candidate ingredients;
- relevant learning memory.

Expected output:

- `product_family`;
- `semantic_category`;
- `variant_dimension`;
- `is_identity_bearing_variant`;
- `parent_candidate_slug`;
- `substitutability_with_parent`;
- `attribute_implications`;
- `market_or_language_notes`;
- confidence and rationale.

Example:

```json
{
  "normalized_text": "pomodorini",
  "product_family": "tomato",
  "variant_dimension": "size_or_market_variant",
  "is_identity_bearing_variant": true,
  "parent_candidate_slug": "tomato",
  "substitutability_with_parent": "partial",
  "attribute_implications": ["shopping_matching", "fridge_matching", "culinary_usage"],
  "confidence_score": 0.9
}
```

### 4.2 Catalog Matcher

Purpose:

- compare the semantic profile with current Supabase catalog candidates.

Expected output:

- exact canonical match, if safe;
- parent-child recommendation, if strict;
- alias recommendation, if identity is unchanged;
- catalog gap, if no safe node exists;
- conflicting candidates;
- missing evidence.

### 4.3 Risk Reviewer

Purpose:

- challenge the proposed decision before any validation or apply path.

The reviewer should actively look for:

- meaningful variants collapsed into base ingredients;
- product/package/brand ambiguity;
- nutrition/allergy/seasonality differences;
- multilingual false friends;
- context too weak for automation;
- previous failed or rejected decisions.

### 4.4 Decision Writer

Purpose:

- convert the reasoning trace into a strict agent proposal.

It should output only supported proposal types:

- `approve_alias`;
- `create_canonical`;
- `add_localization`;
- `ignore_noise`;
- `needs_human_review`.

It must include:

- final confidence;
- risk level;
- auto-apply eligibility;
- rationale;
- evidence references;
- blocking questions.

Catalog-gap behavior:

- If the term is clearly an ingredient and the catalog has no safe target, write `create_canonical`.
- If the term is a meaningful variant and the child/specialized target is missing, write `create_canonical` when the identity is clear, or `needs_human_review` when the parent-child policy is unclear.
- Do not use `needs_human_review` merely because `possible_canonical_matches` is empty.
- Do not invent `target_ingredient_id`; use proposed fields for new canonical creation.
- If implemented learning says a term family must not be compressed into a base ingredient, use that learning to prefer a child/specialized `create_canonical` draft when the identity is clear.

Current execution bridge:

- `prepare_catalog_agent_canonical_enrichment_draft(...)` turns a `create_canonical` proposal into a pending enrichment draft.
- The enrichment draft worker then enriches the missing ingredient candidate.
- Ingredient creation remains behind draft readiness and governed creation RPCs.

### 4.5 Learning Writer

Purpose:

- convert failures, human corrections, validator blocks, and repeated ambiguity into reusable memory.

It should not create catalog policy by itself. It should create an advisory learning artifact that future agent runs can use.

## 5. Semantic Profile Contract

Future runtime should persist or embed a semantic profile alongside proposals.

Recommended fields:

- `normalized_text`;
- `language_code`;
- `product_family`;
- `semantic_category`;
- `variant_dimension`;
- `variant_kind`;
- `parent_candidate_slug`;
- `is_identity_bearing_variant`;
- `substitutability_with_parent`;
- `attribute_implications`;
- `nutrition_implication`;
- `seasonality_implication`;
- `allergy_implication`;
- `fridge_matching_implication`;
- `shopping_matching_implication`;
- `filter_implication`;
- `market_or_language_notes`;
- `confidence_score`;
- `evidence`;
- `open_questions`.

Allowed `substitutability_with_parent` values:

- `full`;
- `partial`;
- `unsafe`;
- `unknown`.

Allowed implication values:

- `none`;
- `possible`;
- `likely`;
- `material`;
- `unknown`.

The semantic profile is not catalog truth. It is evidence for validators, workers, and reviewers.

## 6. Budget and Stop Conditions

Default budget per normalized term:

- 1 semantic profiling call;
- 1 decision synthesis call;
- 1 optional risk review call.

Maximum budget per normal term:

- 3 LLM calls.

Maximum budget per high-impact recurring term:

- 5 LLM calls.

High-impact means at least one of:

- many observations;
- affects many recipes;
- appears across multiple sources/languages;
- blocks a known catalog coverage goal;
- has repeated prior failures or human corrections.

Hard stop conditions:

- estimated daily budget exceeded;
- per-run item limit exceeded;
- per-term call limit exceeded;
- two consecutive passes add no new evidence;
- risk reviewer flags `critical`;
- required catalog candidates are missing from context;
- validator rejects the same recommendation twice;
- learning memory says the pattern is unresolved and no new evidence exists.

Cost policy:

- use cheaper models for semantic profiling and decision synthesis when risk is low or medium;
- reserve stronger models for high-impact ambiguous terms;
- cache semantic profiles by normalized text, language, source domain, and relevant context hash;
- never call an LLM when deterministic rules or implemented learning memory already settle the case.

## 7. Agent and Autopilot Boundary

The agent owns the loop.

Autopilot remains a bounded worker.

Autopilot may still call LLMs for enrichment proposal generation, but those calls are execution-level subtasks. They do not own governance policy.

The agent may delegate work to Autopilot when:

- semantic profile says more metadata is needed;
- catalog draft enrichment is the correct next step;
- a low-risk apply batch can be previewed or executed within policy;
- reconciliation preview is needed before any recipe mutation.

The agent must pause or narrow Autopilot when:

- worker quality drops;
- validation failure ratio is high;
- LLM spend approaches the run/day budget;
- worker output conflicts with learning memory or guardrails.

## 8. Human Review Philosophy

Human review should be rare and high-signal.

The agent should not ask the founder to resolve repetitive questions that it can answer safely from:

- current catalog context;
- recipe context;
- learning memory;
- previous validator outcomes;
- specialized LLM reasoning passes.

When review is needed, the agent should ask one precise question, for example:

```text
"Should Italian 'pomodorini' be represented as a child tomato variant for shopping/fridge matching,
or should it temporarily remain a non-auto-applicable alias until the tomato family is modeled?"
```

Bad review request:

```text
"What should I do with pomodorini?"
```

## 9. Implementation Plan

### Step 1: Prompt Contract Expansion

Add a semantic profile contract to `run-catalog-agent-triage`.

Status: implemented in `supabase/functions/run-catalog-agent-triage`.

Deliverables:

- new TypeScript interfaces for semantic profile output;
- updated JSON schema/validator;
- prompt sections for semantic profiling and meaningful variant analysis;
- no DB mutation changes yet.

Exit criteria:

- LLM output includes structured semantic evidence;
- existing proposal persistence still works;
- invalid semantic fields fail validation.

Implementation note:

- The current implementation stores the semantic profile inside proposal `evidence` to avoid a DB schema change in Step 1.
- Step 2 should promote that reasoning trace into a first-class persisted/read model if the shape proves useful in dev smoke tests.

### Step 2: Reasoning Trace Persistence

Persist agent reasoning in an auditable way.

Deliverables:

- table or JSON column for per-proposal semantic profile and reasoning trace;
- migration with RLS/grants aligned to current admin-console policy;
- review inbox exposes profile summary.

Exit criteria:

- admin console can show "why the agent thinks this is a variant/family/alias";
- raw JSON remains available for debugging;
- proposals remain immutable except governed status transitions.

### Step 3: Multi-Pass Orchestrator

Introduce bounded task calls.

Status: partially implemented in `supabase/functions/run-catalog-agent-triage` v4.

Deliverables:

- `semantic_profiler` prompt: implemented.
- `catalog_matcher` prompt or deterministic matcher wrapper: planned.
- optional `risk_reviewer` prompt: implemented.
- `decision_writer` synthesis prompt: implemented.
- per-term call budget and stop conditions: planned; current implementation has per-run call ceiling.

Exit criteria:

- normal batch uses at most 3 calls today;
- high-impact item uses at most 5 calls: planned;
- no loop can recursively schedule itself: implemented, because the function performs a fixed finite sequence;
- every call writes `catalog_ai_usage_events`: implemented with `metadata.task_role`.

### Step 4: Cost Governor Upgrade

Centralize cost controls across agent and Autopilot LLM calls.

Deliverables:

- per-run budget enforcement before each provider call;
- daily budget view includes task role;
- stop reasons visible in run summary;
- admin console budget status.

Exit criteria:

- agent refuses more LLM work once budget is exhausted;
- console explains whether it stopped because it solved, escalated, or hit budget.

### Step 5: Learning Feedback Loop

Use outcomes to improve future reasoning.

Deliverables:

- learning writer prompt for failed/rejected/overridden decisions;
- structured learning fields for semantic rules and anti-patterns;
- runtime retrieval of term-specific and family-level lessons.

Exit criteria:

- future LLM packets include relevant lessons;
- repeated mistakes become less likely;
- learning remains advisory and validator-bound.

### Step 6: Worker Delegation Policy

Let the agent decide when Autopilot should run.

Deliverables:

- agent loop can request bounded worker jobs;
- worker jobs inherit risk ceiling and budget;
- worker failures feed learning memory;
- no staging scheduling until dev proof is complete.

Exit criteria:

- Autopilot is visibly governed by agent runs;
- workers do not independently expand LLM workload;
- low-risk batches can run without creating founder review noise.

### Step 7: Evaluation Fixtures

Create regression fixtures for common semantic traps.

Initial fixtures:

- `pomodori` vs `pomodorini`;
- `patate` vs `patate dolci`;
- `lievito` vs `lievito per dolci` vs `lievito di birra`;
- `cipolla` vs `cipolla rossa`;
- localization-only examples across Italian, English, and French.

Exit criteria:

- prompt changes can be tested before deployment;
- regressions are caught without relying on manual dashboard inspection.

## 10. Non-Goals

This plan does not authorize:

- autonomous creation of canonical ingredients without validator and policy approval;
- direct LLM writes to catalog tables;
- unbounded research loops;
- web browsing from the Edge Function;
- staging enablement before dev smoke tests and release approval;
- replacing deterministic validators with LLM judgment.

## 11. Success Metrics

The loop is working when:

- fewer proposals land in vague `needs_human_review`;
- high-risk review requests contain precise questions;
- low-risk alias/localization work is handled without founder review;
- meaningful variants are no longer collapsed into base ingredients;
- daily LLM cost remains predictable;
- repeated mistakes create learning memory and do not recur;
- Autopilot work is visible as agent-authorized execution, not independent policy.

## 12. 4.0 Supervised Autonomy Checkpoint

Status: reached in `Season-dev` on 2026-05-12.

Evidence:

- `run-catalog-agent-triage` executed with prompt version `catalog-agent-triage-v4-multi-pass`.
- The first two dry-runs stopped before LLM usage because recent-proposal guardrails removed every item.
- The successful smoke run sent exactly `1` eligible work item to the LLM.
- The run executed the three planned reasoning roles: `semantic_profiler`, `risk_reviewer`, and `decision_writer`.
- Dry-run mode returned a `create_canonical` draft for `pasta corta` but persisted `0` proposals.
- The temporary operator token was removed after the smoke test and `CATALOG_AGENT_ENABLED=false` was restored.

Current autonomy rating:

```text
4.0 supervised autonomy
```

Meaning:

- the agent can reason in multiple bounded LLM passes;
- it can stop before spending tokens when recent work already exists;
- it can use learning memory and enriched context;
- it can produce non-mutating dry-run decisions;
- it still cannot autonomously apply catalog changes or run on staging.

Next improvement target:

```text
4.5 governed proposal autonomy
```

To reach `4.5`, the agent should produce persisted proposals only when all of these are true:

- pre-LLM context gate passes;
- budget governor allows the run;
- recent-proposal guardrail leaves eligible work;
- semantic profile contains enough target/candidate evidence;
- deterministic validator can classify the proposal without founder interpretation;
- admin console clearly explains why each proposal is safe, blocked, or escalated.

The full maturity path from `4.0` to `8.0+` is defined in `docs/catalog-agent-autonomy-roadmap.md`.

## 13. 4.5 Proposal Persistence Gate

Status: implementation started.

`run-catalog-agent-triage` now separates three concepts:

- provider output is valid JSON;
- provider output is operationally reviewable;
- provider output is allowed to be persisted.

The first concept is handled by the strict LLM contract validator. The second is handled by the runtime proposal quality gate. The third is controlled by `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED`, which defaults to `false`.

Quality gate checks include:

- evidence is present;
- actionable alias/localization targets are grounded in the current work packet;
- actionable confidence and semantic-profile confidence pass minimum thresholds;
- `create_canonical` proposals have a safe slug, localized name, language, semantic family/category, and enough confidence;
- `needs_human_review` proposals ask a concrete blocking/open question;
- unknown or critical risk cannot be persisted as an actionable proposal.

The gate can block individual proposals while allowing the run to complete. This is important because the agent should learn to produce better work without turning every weak item into either a database write or a hard runtime failure.

Dev smoke:

- `run_id=47` executed the quality gate in `dry_run=true`.
- The run returned `1` `create_canonical` draft for `pasta corta`.
- The proposal quality gate classified it as persistable with `0` blocking issues.
- No proposal was inserted because persistence remained disabled.
