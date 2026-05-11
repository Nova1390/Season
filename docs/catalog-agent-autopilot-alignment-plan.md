# Catalog Agent and Autopilot Alignment Plan

Status: implementation plan.

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

## 4. Implementation Phases

### Phase 1: Documented Authority Boundary

Status: in progress.

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

Candidate RPC:

- `request_catalog_agent_worker_job(...)`

Allowed worker names initially:

- `enrichment_draft_batch`
- `reconciliation_preview`

Rules:

- only service role or catalog admin;
- item limit capped;
- source domain optional but explicit;
- default dry-run for new worker types;
- no recursive worker chains;
- worker result must write summary back to the ledger.

Exit criteria:

- the agent can request enrichment without calling the worker ad hoc;
- Autopilot does not self-schedule outside policy;
- failed worker jobs create learning/audit events.

### Phase 4: Cost Governor

Centralize LLM budget controls across agent and Autopilot.

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

### Phase 5: Low-Risk Autonomous Apply

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

### Phase 6: Policy-Based Canonical Creation

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

## 6. Recommended Next Technical Step

Implement Phase 2 first.

Reason:

- it does not change catalog behavior;
- it creates the audit backbone for agent-controlled Autopilot;
- it prevents hidden overlap between LLM surfaces;
- it lets us wire worker jobs incrementally without touching staging.

After Phase 2, implement Phase 3 for `enrichment_draft_batch` only, in dev only.

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
