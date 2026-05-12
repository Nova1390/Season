# Catalog Agent and Autopilot Alignment Plan

Status: Phase 1 complete; Phase 2, Phase 3 worker routing, Phase 4 first ledger, Phase 4.5 batch-level multi-pass reasoning, and Phase 5 safety foundation implemented on dev. Low-risk apply real mode remains intentionally gated for scheduling, but one reviewed low-risk proposal has passed validator + governed apply as a dev smoke. Canonical creation now has an agent-routed worker path, still behind ready-draft validation and a dedicated backend enable flag.

This plan aligns Season catalog automation around one operating principle:

`Catalog Governance Agent = manager`

`Autopilot = bounded worker`

The goal is to reduce founder review workload while preventing duplicated LLM decision-making, uncontrolled cost, and unsafe catalog mutations.

## 1. Current Split

Today there are two LLM-capable catalog surfaces:

- `catalog-enrichment-proposal`
- `run-catalog-agent-triage`

They solve different jobs, but the boundary is not yet enforced by runtime orchestration.

Current behavior:

- enrichment LLM proposes draft ingredient metadata;
- agent LLM proposes governance decisions;
- Autopilot can run batch enrichment independently;
- agent does not yet formally authorize Autopilot worker jobs;
- cost and audit are recorded per function, not under one manager-level decision.

## 2. Target Operating Model

The Catalog Agent owns:

- backlog priority;
- policy interpretation;
- risk classification;
- semantic investigation depth;
- autonomy level;
- worker delegation;
- budget envelope;
- learning memory;
- escalation to human review.

Autopilot owns:

- observation recovery;
- enrichment draft generation;
- deterministic draft validation;
- safe reconciliation preview;
- safe low-risk apply execution when authorized;
- job-level telemetry.

Backend validators own:

- structural safety checks;
- RLS/auth boundaries;
- mutation eligibility;
- audit records.

The founder owns:

- new policy approvals;
- high-risk identity decisions;
- exception review;
- release gates for staging/TestFlight.

## 3. Non-Overlap Rules

Autopilot must not:

- decide whether a new catalog policy is acceptable;
- decide high-risk canonical identity creation alone;
- schedule unbounded LLM enrichment without a manager-level budget;
- treat LLM enrichment output as approval;
- create review noise when implemented learning memory can resolve the case.

The agent must not:

- re-implement enrichment proposal generation already handled by Autopilot;
- mutate catalog tables directly;
- bypass deterministic validators;
- run unlimited exploratory LLM calls;
- ask the founder to review repetitive low-risk work.

The agent may run multiple LLM task prompts only inside a bounded loop:

- semantic profiler;
- catalog matcher;
- risk reviewer;
- decision writer;
- learning writer.

Each pass must have a clear purpose, inherited budget, audit trail, and stop condition. If another pass cannot add new evidence, the agent must stop and either decide, delegate a worker, or escalate.

## 4. Implementation Phases

### Phase 1: Documented Authority Boundary

Status: complete.

Deliverables:

- update responsibility charter with manager/worker rules;
- update Smart Import pipeline diagram;
- update agent contracts with worker delegation and cost attribution;
- keep staging untouched.

Exit criteria:

- docs identify one governance manager;
- Autopilot LLM role is explicitly bounded;
- no code path claims Autopilot LLM output is catalog truth.

### Phase 2: Agent Orchestration Ledger

Add a manager-level table for delegated work.

Status: implemented in `supabase/migrations/20260511170000_catalog_agent_worker_jobs_and_ai_usage.sql`.

Proposed object:

- `catalog_agent_worker_jobs`

Core fields:

- `agent_run_id`
- `worker_name`
- `worker_function`
- `requested_action`
- `source_domain`
- `status`
- `risk_ceiling`
- `item_limit`
- `budget_limit_usd`
- `started_at`
- `finished_at`
- `summary`
- `failure_reason`

Purpose:

- every Autopilot job launched by the agent has a parent agent run;
- cost and quality can be reviewed at manager level;
- the agent can stop delegating after failures.

Exit criteria:

- worker jobs are auditable;
- manual Autopilot runs are distinguishable from agent-delegated runs;
- future console can show "agent asked worker to do X".

### Phase 3: Worker Invocation Adapter

Add a backend-safe way for the agent to request bounded worker jobs.

Status: first worker adapter implemented for `enrichment_draft_batch` through `supabase/functions/run-catalog-agent-orchestrator`.

Implemented RPC:

- `create_catalog_agent_worker_job(...)`
- `start_catalog_agent_worker_job(...)`
- `complete_catalog_agent_worker_job(...)`
- `fail_catalog_agent_worker_job(...)`

Worker names in the ledger:

- `enrichment_draft_batch`
- `ingredient_creation_batch`
- `reconciliation_preview`
- `low_risk_apply_batch`

Runtime support today:

- `enrichment_draft_batch` is implemented through `run-catalog-agent-orchestrator`;
- `ingredient_creation_batch` is implemented through `run-catalog-agent-orchestrator`, consumes only ready enrichment drafts, and requires `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=true`;
- `low_risk_apply_batch` is implemented through `run-catalog-agent-orchestrator` in dry-run mode by default;
- `reconciliation_preview` is a reserved ledger type, not yet enabled by the orchestrator.
- reviewed single-proposal low-risk apply has been smoke-tested through `apply_catalog_agent_proposal(...)`; scheduled/batch real apply remains disabled.

Rules:

- only service role or catalog admin;
- item limit capped;
- source domain optional but explicit;
- default dry-run for new worker types;
- no recursive worker chains;
- worker result must write summary back to the ledger.
- creation workers must never consume raw LLM proposals; they consume only validated enrichment drafts.

Exit criteria:

- the agent can request enrichment without calling the worker ad hoc;
- Autopilot does not self-schedule outside policy;
- failed worker jobs create learning/audit events.

### Phase 4: Cost Governor

Centralize LLM budget controls across agent and Autopilot.

Status: first ledger implemented through `catalog_ai_usage_events` and `catalog_agent_daily_automation_summary`.

Required tracking:

- function name;
- model;
- input tokens;
- output tokens;
- total tokens;
- estimated cost;
- parent agent run id when delegated;
- source domain;
- environment.

Required policies:

- max daily agent runs;
- max daily worker jobs;
- max items per worker job;
- max estimated spend per day;
- pause on repeated validation failures;
- pause on high human-review ratio.

Exit criteria:

- one daily budget view covers both agent and Autopilot;
- manager-level run summary includes delegated worker costs;
- console can show "today's automation spend and yield".

### Phase 4.5: Multi-Pass LLM Reasoning

Let the agent use LLMs as specialized reasoning tools before final proposal synthesis.

Status: batch-level runtime implemented in `supabase/functions/run-catalog-agent-triage` v4; adaptive per-term loops remain planned in `docs/catalog-agent-llm-reasoning-loop-plan.md`.

Required behavior:

- semantic profiling happens before final decision when multi-pass mode is enabled;
- risk review is called only when enabled and the semantic profile indicates ambiguity, open questions, non-full substitutability, or identity-bearing variant risk;
- decision synthesis produces the same governed proposal vocabulary used today;
- all calls are attributed in `catalog_ai_usage_events` with `metadata.task_role`;
- per-run call ceiling is implemented; per-term adaptive budget enforcement remains planned.

Exit criteria:

- fewer vague `needs_human_review` proposals: requires dev smoke history;
- review questions become precise policy questions: requires dev smoke history;
- meaningful variants are identified before alias validation: implemented in prompt contract and semantic profile pass;
- Autopilot remains execution-only and does not own policy: unchanged.

### Phase 5: Low-Risk Autonomous Apply

Status: safety foundation implemented in `supabase/migrations/20260511174500_catalog_agent_auto_apply_audit_rollback.sql`; worker routing is implemented, real apply remains disabled unless `CATALOG_AGENT_LOW_RISK_APPLY_ENABLED=true`.

Let the agent authorize safe apply only for low-risk work.

First eligible actions:

- approved alias for existing active canonical;
- add localization for existing active canonical;
- ignore clear noise;
- reconcile recipe rows only when safe preview says safe.

Not eligible yet:

- autonomous canonical creation;
- duplicate redirects;
- culturally ambiguous multilingual identity;
- allergy/nutrition/seasonality-sensitive variants;
- broad recipe rewrites.

Exit criteria:

- founder review volume drops;
- every auto-apply has validator proof and rollback/audit trail;
- console becomes audit-first, not approval-first.

Implemented safety primitives:

- `apply_catalog_agent_low_risk_proposal(...)`;
- `apply_catalog_agent_low_risk_proposal_batch(...)`;
- `rollback_catalog_agent_apply(...)`;
- `catalog_agent_apply_audit`;
- `catalog_agent_auto_apply_audit_summary`;
- `catalog-low-risk-apply-batch`;
- detailed operating policy in `docs/catalog-agent-auto-apply-safety.md`.

### Phase 6: Policy-Based Canonical Creation

Status: planned, not enabled.

Allow the agent to create canonical ingredients only after patterns are proven.

Initial mode:

- agent proposes catalog-gap policy;
- founder approves policy once;
- backend stores implemented learning;
- future matching cases can be auto-applied inside that policy.

Possible later mode:

- repeated high-confidence, low-risk catalog gaps auto-create only when evidence, slug, localization, units, and duplicate checks pass.

Exit criteria:

- "lievito"-style manual interventions become agent-managed workflows;
- new ingredients are created rarely, safely, and with durable policy memory.

## 5. Console Changes

The console should evolve from "review every item" to "manage the manager".

Needed views:

- daily agent summary;
- worker jobs launched by agent;
- LLM cost and token usage;
- auto-applied changes;
- blocked items grouped by policy gap;
- learning memory changes;
- high-risk review inbox.

The console should default to:

- what the agent did;
- what it refused to do;
- what needs a policy decision;
- what it learned.

## 6. Implemented Dev Step

Implemented on dev:

- `catalog_agent_worker_jobs` records manager-authorized worker jobs;
- `catalog_ai_usage_events` records shared LLM usage across agent and Autopilot;
- `catalog_agent_daily_automation_summary` powers the console overview;
- `run-catalog-agent-orchestrator` delegates bounded enrichment work to Autopilot;
- `run-catalog-enrichment-draft-batch` reports job lifecycle back to the ledger;
- admin console shows orchestration summary and recent worker jobs.

Next technical step:

- run dry operational history for `low_risk_apply_batch` from the orchestrator, then decide daily limits before enabling real apply.

## 7. Dev/Staging Policy

Development:

- agent/autopilot orchestration experiments allowed;
- manual worker invocation allowed;
- aggressive telemetry allowed;
- agent disabled by default unless testing.

Staging:

- no experimental orchestration until dev is stable;
- only release-safe schedules;
- no uncontrolled enrichment batches;
- must pass security lint and preflight checks before TestFlight-facing use.
