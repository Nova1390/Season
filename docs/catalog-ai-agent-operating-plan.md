# Catalog AI Agent Operating Plan

Status: planning document, no implementation yet.

This document describes how Season should introduce an AI agent for catalog governance without weakening the current deterministic, auditable autopilot architecture.

It complements:

- `docs/catalog-architecture.md`
- `docs/smart-import-catalog-intelligence-pipeline.md`
- `docs/catalog-system-review-and-consolidation-plan.md`

## 1. Executive Summary

Season already has a catalog autopilot. It is a controlled automation pipeline that observes unresolved recipe ingredients, enriches drafts, creates safe canonical catalog items, approves safe aliases/localizations, and reconciles recipe ingredients through governed backend functions.

The proposed AI agent should not replace that pipeline.

Instead, the agent should become a structured reasoning layer that prepares decisions, explains rationale, detects ambiguity, and routes work into the existing governed write paths. The autopilot remains the executor. Supabase remains the source of truth. SQL/RPC guardrails remain the only authority allowed to mutate catalog identity and recipe reconciliation state.

Target architecture:

```text
custom ingredient observations
  -> candidate queues and diagnostics
  -> AI agent analysis and structured proposals
  -> policy/guardrail validation
  -> autopilot applies safe operations
  -> human review handles ambiguous exceptions
  -> audit tables preserve every decision
```

Core principle:

The agent can recommend. The database decides what can be applied.

## 2. Why Add an Agent

The current autopilot is strong at deterministic, repeatable operations:

- exact alias approval when policy says it is safe
- ready draft validation
- canonical ingredient creation from validated drafts
- safe recipe reconciliation
- cron-based recurring maintenance
- audit-friendly batch summaries

It is weaker at interpretive work:

- deciding whether a text is an alias, localization, variant, or new root ingredient
- explaining why a specific canonical node is safer than another
- comparing several related unresolved observations together
- detecting semantic duplication across languages and source styles
- prioritizing catalog fixes by user impact
- identifying when existing automation would create catalog noise

An AI agent is useful because those tasks require context, language understanding, and policy reasoning. But those same properties make the agent unsafe as a direct database writer.

Therefore, the agent should act as:

- analyst
- reviewer
- triage assistant
- proposal generator
- exception router
- audit note author

It should not act as:

- direct SQL writer
- unrestricted service-role operator
- autonomous canonical identity creator
- autonomous recipe mutator
- replacement for RLS, constraints, and governed RPCs

## 3. Architectural Positioning

### 3.1 Existing System Layers

Current backend authority layers:

- `public.ingredients`: canonical ingredient identity.
- `public.ingredient_localizations`: localized display names.
- `public.ingredient_aliases_v2`: governed text-to-ingredient mapping.
- `public.custom_ingredient_observations`: unresolved ingredient signal.
- `public.catalog_candidate_decisions`: governance/audit decision history.
- `public.catalog_ingredient_enrichment_drafts`: structured draft proposals.
- `public.legacy_ingredient_mapping`: compatibility bridge only.
- Reconciliation safety views/RPCs: only safe recipe rewrites should be applied.

Current automation surfaces:

- `catalog-enrichment-proposal`: LLM-backed enrichment proposal endpoint.
- `run-catalog-enrichment-draft-batch`: enriches pending drafts.
- `run-catalog-ingredient-creation-batch`: creates ready catalog ingredients through governed functions.
- `run-catalog-automation-cycle`: orchestration wrapper for recovery, enrichment, creation, alias/localization application, and reconciliation.
- `staging_catalog_autopilot_v2_*`: staging-only scheduler and verification scripts.

The agent should sit above these automation surfaces, not beside them as a parallel writer.

### 3.2 New Agent Layer

The agent should be introduced as a bounded backend worker:

```text
Catalog signals
  -> Agent reads snapshots
  -> Agent produces structured recommendations
  -> Recommendations are stored as proposals
  -> Existing RPCs validate/apply safe proposals
  -> Ambiguous proposals stay pending for human review
```

The first implementation should be read-heavy and proposal-only.

Direct mutation should be limited to inserting agent proposal/audit rows. Any catalog or recipe mutation must go through existing governed functions.

## 4. Agent Responsibilities

### 4.1 What The Agent Should Do

The agent should inspect unresolved catalog work and return typed decisions:

- `approve_alias`
- `create_canonical`
- `add_localization`
- `merge_duplicate`
- `redirect_duplicate`
- `reconcile_recipe_ingredients`
- `ignore_noise`
- `needs_human_review`

For each decision it should provide:

- normalized input text
- proposed canonical ingredient id or slug, when applicable
- proposed localized display name, when applicable
- proposed parent ingredient, when applicable
- confidence score
- risk level
- decision rationale
- evidence references
- blocking questions, if any
- whether the proposal is auto-apply eligible

### 4.2 What The Agent Must Not Do

The agent must not:

- insert directly into `public.ingredients`
- update `public.ingredients` directly
- approve aliases by direct table writes
- mutate recipe JSON directly
- bypass `is_catalog_admin`, `assert_catalog_admin`, RLS, or RPC authorization
- use service-role credentials in app-side code
- collapse specific variants into generic nodes for convenience
- treat LLM confidence as sufficient authority
- create new taxonomy/hierarchy rules outside `docs/catalog-architecture.md`

## 5. Decision Policy

### 5.1 Alias vs Canonical Ingredient

Use `approve_alias` when:

- the text is a surface form of an existing ingredient
- the text contains quantity, cut, preparation, or formatting noise
- the text is a language/local spelling variant
- the culinary identity does not materially change

Use `create_canonical` when:

- the ingredient represents a distinct culinary identity
- it has materially different use, taste, texture, nutrition, substitution, or cooking behavior
- it should be independently filterable, seasonal, nutritional, or purchasable
- no existing canonical node safely captures it

Use `needs_human_review` when:

- multiple canonical targets are plausible
- the distinction depends on culinary context
- the text might represent brand/product/package rather than ingredient identity
- the agent cannot justify a parent-child relation
- applying the decision could affect many recipes

### 5.2 Parent Assignment

The agent may propose a parent only when the child is a strict semantic refinement of the parent.

Valid examples:

- `farina_00` -> `farina`
- `cipolla_rossa` -> `cipolla`
- `riso_carnaroli` -> `riso`

Invalid examples:

- co-usage relation
- marketing category
- preparation-only difference
- quantity/state contamination

Parent suggestions should include:

- proposed parent slug/id
- refinement rationale
- specificity rank suggestion
- variant kind suggestion
- confidence
- explicit reason why alias/localization is insufficient

### 5.3 Auto-Apply Eligibility

A proposal can be auto-apply eligible only if all are true:

- single target
- high confidence
- low risk
- no new hierarchy ambiguity
- source text is observed enough to matter
- existing guardrail functions accept it
- no conflicting active alias exists
- no duplicate canonical slug/localization conflict exists

Examples likely eligible:

- accent/case/punctuation variants
- plural/singular variants where language policy is clear
- quantity-contaminated terms mapped to an existing canonical ingredient
- known Giallo Zafferano ingredient text already resolved in similar recipes

Examples not auto-apply eligible:

- new root ingredients
- specific cultivar/variety decisions
- allergy-sensitive or nutritionally distinct terms
- animal/plant identity ambiguity
- terms that could be product names
- large fan-out recipe rewrites

## 6. Proposed Data Model Additions

No existing table should be replaced. Add proposal/audit tables around the current model.

### 6.1 `catalog_agent_runs`

Purpose:

Track each agent execution.

Suggested fields:

- `id`
- `environment`
- `agent_version`
- `model`
- `prompt_version`
- `input_snapshot_hash`
- `status`
- `started_at`
- `finished_at`
- `summary`
- `error_message`
- `created_by`

### 6.2 `catalog_agent_proposals`

Purpose:

Store structured agent recommendations.

Suggested fields:

- `id`
- `run_id`
- `proposal_type`
- `normalized_text`
- `source_observation_ids`
- `target_ingredient_id`
- `target_slug`
- `proposed_slug`
- `proposed_localized_name`
- `proposed_language_code`
- `proposed_parent_ingredient_id`
- `proposed_specificity_rank`
- `proposed_variant_kind`
- `confidence_score`
- `risk_level`
- `auto_apply_eligible`
- `rationale`
- `evidence`
- `status`
- `applied_at`
- `applied_by`
- `rejection_reason`

Recommended statuses:

- `draft`
- `queued_for_validation`
- `validated`
- `auto_applied`
- `needs_human_review`
- `rejected`
- `failed_validation`
- `superseded`

### 6.3 `catalog_agent_proposal_events`

Purpose:

Append-only audit timeline.

Suggested fields:

- `id`
- `proposal_id`
- `event_type`
- `event_payload`
- `created_at`
- `created_by`

### 6.4 Relationship To Existing Tables

Agent proposal tables do not replace:

- `catalog_candidate_decisions`
- `catalog_ingredient_enrichment_drafts`
- `ingredient_aliases_v2`
- reconciliation audit tables

Instead:

- agent proposals feed candidate decisions
- agent proposals can prepare enrichment drafts
- approved proposals call existing alias/localization RPCs
- safe reconciliation proposals call existing preview/apply RPCs

## 7. Agent Input Contract

The agent should receive a bounded snapshot, not unrestricted database access.

Input should include:

- top unresolved observations
- related recipe titles/source metadata
- existing candidate queue hints
- existing canonical ingredient matches
- active aliases for the same normalized text family
- localization matches
- hierarchy context for likely target families
- duplicate redirect context
- previous rejected decisions
- current policy excerpts

The snapshot should be generated by SQL views/RPCs, not by giving the agent ad hoc database browsing power.

Recommended first input RPC:

```text
public.get_catalog_agent_triage_snapshot(limit integer, source_domain text)
```

It should return:

- observations grouped by normalized text
- occurrence counts
- source recipe examples
- current candidate recommendation
- possible canonical matches
- existing alias conflicts
- existing localization conflicts
- hierarchy candidates
- safety flags

## 8. Agent Output Contract

The agent should return strict JSON, not prose-only output.

High-level shape:

```json
{
  "run_summary": {
    "items_reviewed": 0,
    "auto_apply_candidates": 0,
    "human_review_required": 0,
    "blocked": 0
  },
  "proposals": [
    {
      "proposal_type": "approve_alias",
      "normalized_text": "example",
      "target_slug": "example_slug",
      "confidence_score": 0.95,
      "risk_level": "low",
      "auto_apply_eligible": true,
      "rationale": "Short explanation.",
      "evidence": []
    }
  ]
}
```

Output validation should reject:

- unknown proposal types
- missing rationale
- missing target for alias proposals
- new canonical proposals without slug/localization
- parent proposals without rationale
- confidence outside allowed range
- auto-apply proposals with high risk
- proposals that contradict catalog policy

## 9. Runtime Flow

### 9.1 Proposal-Only Run

First milestone:

```text
cron/manual trigger
  -> fetch bounded triage snapshot
  -> call agent
  -> validate JSON
  -> insert catalog_agent_runs
  -> insert catalog_agent_proposals
  -> no catalog mutations
```

Success criteria:

- proposals are visible and reviewable
- no production data changes except proposal/audit rows
- no service-role secret in client
- no duplicate catalog writer introduced

### 9.2 Guardrail Validation Run

Second milestone:

```text
proposal rows
  -> backend validator checks against current catalog state
  -> proposal status moves to validated or failed_validation
  -> no catalog mutations yet
```

Validation should check:

- target ingredient exists and is active
- no active alias conflict exists
- proposed slug is unique
- proposed localization is not duplicate/conflicting
- parent assignment is structurally valid
- risk/auto-apply policy is consistent
- recipe reconciliation preview marks rows safe

### 9.3 Safe Auto-Apply Run

Third milestone:

```text
validated low-risk proposals
  -> existing governed RPCs
  -> audit event
  -> proposal status auto_applied
```

Allowed safe operations at first:

- approve alias to existing canonical ingredient
- add missing localization to existing ingredient
- mark obvious noise as ignored
- trigger safe reconciliation for rows already covered by approved alias/localization

Not allowed at first:

- autonomous new canonical creation
- autonomous parent assignment
- autonomous duplicate redirect
- high-volume recipe rewrites

### 9.4 Human Review Run

Fourth milestone:

Ambiguous proposals should appear in the existing catalog admin surface, or a new focused "Agent Review Inbox".

Reviewer actions:

- approve and apply
- edit proposal
- reject
- mark as duplicate of another proposal
- request more evidence
- defer

Human-approved proposals should still be applied through existing governed RPCs.

## 10. Integration With Existing Autopilot

The current autopilot should remain the recurring executor.

The agent should add one or two new stages around it:

```text
Stage 0: recover observations
Stage 1: agent proposal generation
Stage 2: proposal validation
Stage 3: safe auto-apply proposals
Stage 4: current enrichment batch
Stage 5: current creation batch
Stage 6: current alias/localization application
Stage 7: current safe reconciliation
Stage 8: summary and exception reporting
```

For the first release, the agent can run separately from autopilot. Once proven, it can become an optional stage in `run-catalog-automation-cycle`.

Recommended feature flags:

- `agent_enabled`
- `agent_proposal_only`
- `agent_auto_apply_aliases`
- `agent_auto_apply_localizations`
- `agent_create_canonical_enabled`
- `agent_reconciliation_enabled`

Default staging configuration:

- proposals enabled
- validation enabled
- auto-apply aliases disabled for the first observation window
- canonical creation disabled
- duplicate redirects disabled

## 11. Security And Authorization

The agent should run server-side only.

Required controls:

- service-role key stored only as Supabase secret
- no service-role credentials in iOS app or repo
- RLS remains enabled on public tables
- proposal write functions are restricted to service-role/admin
- apply functions remain governed by existing admin checks
- all runs and proposals are auditable
- prompt/model versions are recorded
- raw model output is stored only if it does not contain secrets or user-sensitive content

The agent should not receive unrestricted user data. Snapshots should include only what is needed for catalog governance:

- ingredient text
- recipe title examples
- source name/domain
- counts
- relevant catalog candidates

Avoid sending:

- user emails
- auth metadata
- private profile data
- unrelated recipe notes
- non-catalog personal data

## 12. Observability

Each run should produce:

- run status
- item counts
- proposal counts by type
- auto-apply eligibility counts
- validation failure reasons
- human review queue size
- applied operations by type
- reconciliation impact summary
- errors and retryability

Recommended dashboards:

- custom ingredient backlog over time
- percent of recipe ingredients canonical
- unresolved Giallo Zafferano terms
- agent proposal acceptance rate
- false positive/rejection rate
- auto-apply rollback count
- duplicate canonical creation count
- average time from observation to resolution

## 13. Evaluation Strategy

Before allowing auto-apply, build an evaluation set from known decisions.

Evaluation examples:

- safe aliases already approved
- terms previously rejected
- known duplicate localization cases
- known new canonical ingredients
- known variant policy cases
- "patate" vs "patate dolci" style distinctions
- Giallo Zafferano residual ingredients

Metrics:

- exact decision type accuracy
- target ingredient accuracy
- unsafe auto-apply rate
- correct human-review routing rate
- rationale usefulness
- duplicate prevention rate

Gate to enable auto-apply:

- zero critical unsafe actions in evaluation
- high target accuracy on low-risk aliases
- stable JSON validity
- clear validation failure handling
- audit logs complete

## 14. Rollout Plan

### Phase 0: Design And Contracts

Deliverables:

- final policy doc
- proposal JSON schema
- prompt versioning convention
- staging-only feature flags
- evaluation dataset definition

No runtime behavior changes.

### Phase 1: Proposal-Only Agent

Deliverables:

- agent run Edge Function or backend worker
- snapshot RPC
- proposal/audit tables
- JSON validation
- staging-only manual trigger

No catalog mutations.

### Phase 2: Review Inbox

Deliverables:

- admin review surface
- proposal status transitions
- approve/reject/edit workflow
- proposal-to-existing-RPC adapter

Mutations require human approval.

### Phase 3: Low-Risk Auto-Apply

Deliverables:

- auto-apply aliases only
- auto-apply localizations only
- strict guardrail validator
- daily summary
- kill switch

No autonomous canonical creation.

### Phase 4: Guided Canonical Creation

Deliverables:

- agent prepares enrichment drafts
- existing draft validation remains mandatory
- human approval required for new root/variant creation
- optional auto-ready only for extremely constrained known patterns

Canonical writer remains unchanged.

### Phase 5: Agent-Assisted Reconciliation

Deliverables:

- agent prioritizes reconciliation candidates
- existing safety preview determines applicability
- apply only safe rows
- large-impact rewrites require human confirmation

### Phase 6: Production Hardening

Deliverables:

- monitoring dashboard
- rollback playbooks
- scheduled staging run
- controlled production rollout
- documented operator process

## 15. Failure Modes And Mitigations

### Wrong Alias Target

Risk:

An alias maps a text to the wrong ingredient.

Mitigation:

- auto-apply only low-risk exact/surface variants
- require no conflicting aliases
- require evidence and target uniqueness
- keep alias activation reversible
- reconcile recipes only after safety preview

### Duplicate Canonical Ingredient

Risk:

The agent proposes a new ingredient that already exists.

Mitigation:

- validator checks slug/localization/alias similarity
- human approval for canonical creation
- duplicate redirect workflow stays separate
- no auto-create in early phases

### Over-Collapsing Variants

Risk:

Specific ingredients are collapsed into generic nodes.

Mitigation:

- enforce `docs/catalog-architecture.md`
- agent must justify alias vs canonical
- variants and allergy/nutrition-sensitive terms require human review
- track rejected over-collapse cases in eval set

### Prompt Drift

Risk:

Agent behavior changes unexpectedly after prompt/model changes.

Mitigation:

- store prompt/model version per run
- run eval set before enabling auto-apply
- compare proposal distribution between versions
- keep feature flags off by default for new versions

### Hidden Data Leakage

Risk:

Agent receives unnecessary personal data.

Mitigation:

- use bounded snapshot RPCs
- exclude private user data
- log input schema and sample payloads
- review data sent to LLM provider

## 16. Open Product Decisions

Before implementation, decide:

- Should agent proposals be visible only in admin UI or also summarized in docs/devops reports?
- What is the first auto-apply category: aliases only, localizations only, or both?
- Should staging agent runs happen on the same six-hour cadence as autopilot or only manually at first?
- What confidence threshold is acceptable for low-risk alias auto-apply?
- Who is the human reviewer of ambiguous catalog identity decisions during TestFlight?
- Should agent-created rationale be exposed in admin UI or only stored in audit tables?

## 17. Recommended First Scope

Recommended first implementation scope:

- staging only
- proposal-only
- no auto-apply
- top 50 unresolved observations
- Giallo Zafferano source focus
- output stored in proposal tables
- admin-readable summary
- evaluation against previously resolved decisions

Recommended first proposal types:

- `approve_alias`
- `create_canonical`
- `ignore_noise`
- `needs_human_review`

Recommended exclusions:

- duplicate redirects
- parent assignment auto-apply
- recipe reconciliation auto-apply
- autonomous canonical creation

This gives Season the useful intelligence of an agent without sacrificing the safety of the existing autopilot.

## 18. Final Target State

The mature system should feel like this operationally:

1. Recipes and Smart Import generate unresolved ingredient observations.
2. The agent reviews the backlog and proposes catalog actions.
3. Guardrails validate proposals against current catalog state.
4. Low-risk proposals are applied by existing governed functions.
5. Ambiguous proposals enter a focused review inbox.
6. Autopilot continues recurring enrichment, creation, alias/localization application, and safe reconciliation.
7. Dashboards show catalog health, backlog, and agent quality.

The result is not "AI writes the database".

The result is:

```text
AI reasons.
Supabase validates.
Autopilot applies.
Humans decide ambiguity.
Audit preserves truth.
```
