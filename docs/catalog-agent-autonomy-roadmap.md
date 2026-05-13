# Catalog Agent Autonomy Roadmap

Status: strategic implementation roadmap. Current level is `5.0 low-risk apply autonomy in progress` on `Season-dev`, with Level `6.0` guardrail infrastructure started but not yet scheduled.

This document defines how Season should grow the Catalog Governance Agent from a supervised reasoning assistant into a reliable autonomous catalog operator without bypassing Supabase guardrails, Autopilot workers, audit, or human policy ownership.

The roadmap is deliberately staged. Each level must pass its gates before the next one starts.

Core principle:

```text
Increase autonomy by shrinking ambiguity, not by trusting the LLM more.
```

## Current Baseline: 4.0 Supervised Autonomy

Reached on `Season-dev` on 2026-05-12.

Capabilities:

- bounded multi-pass LLM dry-run;
- semantic profiler, risk reviewer, and decision writer roles;
- learning memory included in the work packet;
- recent-proposal guardrail avoids duplicate LLM spend;
- token usage is logged;
- dry-run returns decisions without persisting proposals;
- no catalog mutation is possible from the dry-run.

Evidence:

- `run_id=45`;
- model `gpt-5.4-mini`;
- prompt version `catalog-agent-triage-v4-multi-pass`;
- `1` item sent to LLM;
- `0` proposals persisted;
- `0` catalog mutations.

Primary limitation:

- The agent can reason, but it cannot yet reliably convert reasoning into persistent governed work without founder supervision.

## Level 4.5: Governed Proposal Autonomy

Goal:

The agent may persist proposals automatically, but only when preflight context, budget, recent-work, semantic evidence, and deterministic policy checks all pass.

Allowed actions:

- create `catalog_agent_proposals` rows;
- classify proposal risk;
- attach semantic profile and evidence;
- mark proposals as draft or needs review;
- refuse to persist weak proposals.

Still forbidden:

- direct catalog mutation;
- real low-risk apply;
- canonical ingredient creation;
- staging scheduling;
- unbounded retry loops.

Required implementation:

- proposal persistence feature flag that fails closed before any LLM call when `dry_run=false` is requested accidentally;
- proposal persistence gate that checks context-quality status before calling/persisting LLM output;
- budget governor with explicit per-run, per-day, and per-item limits;
- proposal quality validator that rejects empty targets, missing evidence, and vague `needs_human_review`;
- admin console summary showing why a proposal was persisted, rejected, or skipped;
- replay test comparing dry-run proposal shape against persisted proposal shape.

Implementation status:

Reached on `Season-dev` on 2026-05-13.

- `run-catalog-agent-triage` now includes `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED`, defaulting to disabled.
- `run-catalog-agent-triage` now evaluates a proposal quality gate before insert.
- The quality gate records `proposal_quality_gate_evaluated` and run-summary counts for persistable vs blocked proposals.
- The updated Edge Function is deployed to `Season-dev`.
- Fail-closed smoke passed: invoking `dry_run=false` while persistence was disabled returned `PROPOSAL_PERSISTENCE_DISABLED` before LLM usage or proposal writes.
- Full LLM quality-gate smoke passed in dry-run with `run_id=47`: `1` returned proposal, `1` persistable proposal, `0` blocked proposals, and `0` persisted proposals because persistence remained disabled.
- First governed persistence smoke passed with `run_id=48`: `1` persistable proposal was inserted as proposal `#25`, with `0` quality-gate blocks and no catalog apply.
- First persisted `create_canonical` proposal was routed into the enrichment-draft lane: proposal `#25` prepared a pending draft for `pasta corta` / `short_pasta`, with no ingredient creation.
- First agent-orchestrated enrichment worker smoke passed with `run_id=49`, `worker_job_id=16`: one pending draft was enriched, validated, and promoted to `ready` without ingredient creation.
- First agent-orchestrated ingredient creation smoke passed with `run_id=50`, `worker_job_id=17`: one reviewed ready draft created `pasta_corta` as an active child ingredient of `pasta`; the worker was redeployed first-class on dev after a ledger drift gap was detected and reconciled.
- Repeatable worker-ledger regression smoke was added and passed with `run_id=52`, `worker_job_id=19` using non-mutating `low_risk_apply_batch` dry-run mode.
- Mixed-term persistence batch passed with `run_id=53`: `12` snapshot items, `9` recent-proposal skips, `3` LLM-reviewed items, `3` persistable proposals, `0` quality-gate blocks, and `3` persisted proposals.
- Cumulative dev proposal volume is now above the Level 4.5 quantity threshold: `25` total agent proposals, `0` critical-risk proposals, and `4` auto-apply-eligible proposals awaiting sample audit.
- Low-risk and auto-apply-eligible sample audit passed: proposals `#5`, `#14`, `#21`, `#22`, and `#23` showed `0` unsafe low-risk classifications and `0` unsafe low-risk mutations.
- Historical proposals `#21` and `#22` exposed quality debt because they used `target_slug` without `target_ingredient_id`, but they were superseded and did not mutate catalog state; future auto-apply remains constrained by stronger target grounding.
- The dev run window was closed afterwards: `CATALOG_AGENT_ENABLED=false`, `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=false`, and the temporary operator token was removed.

Exit gates:

- golden `current`: `10/10`;
- golden `effective_target`: `10/10`;
- golden `context_target`: `10/10`;
- at least `10` dev persisted proposals from mixed terms with no unsafe low-risk classification: passed with `25` total agent proposals and `0` unsafe sampled low-risk classifications;
- low-risk and auto-apply-eligible proposal sample audit documented: passed;
- no direct catalog mutation from the proposal-persistence path: passed;
- daily estimated LLM cost stays below the configured budget: passed within the configured run budget.

Operational rating after completion:

```text
The agent creates useful governed work, but humans or validators still decide application.
```

## Level 5.0: Low-Risk Apply Autonomy

Goal:

The agent can authorize Autopilot to apply only validated, low-risk, existing-canonical proposals.

Implementation status:

- started on `2026-05-13` on `Season-dev` only;
- rollback regression smoke passed with run `#55`, proposal `#30`, and apply audit `#4`;
- the smoke created an intentionally reversible `approve_alias` proposal for `season rollback smoke sale fino 20260513` -> `sale_fino`;
- the apply path inserted alias id `178`, wrote audit metadata, and emitted `auto_apply_succeeded`;
- the rollback path deleted the inserted alias, marked audit `#4` as `reverted`, returned proposal `#30` to `validated`, and emitted `auto_apply_rollback_succeeded`;
- final verification showed `remaining_alias_rows=0`, `proposal_status=validated`, and `audit_status=reverted`;
- the smoke was converted into repeatable script `scripts/catalog_agent_rollback_smoke.sh`;
- scripted smoke passed with run `#58`, proposal `#33`, apply audit `#7`, and `rollback_smoke_ok=true`;
- the repeatable smoke now retires its own test proposal to `superseded` after verification, so future real low-risk batches cannot re-apply smoke aliases;
- post-cleanup verification showed no remaining `validated + low + auto_apply_eligible` proposals;
- first Level 5.0 proposal-generation run after cleanup created proposals `#34` and `#35`, but both were correctly routed to human review (`pepe` medium risk, `olive` high risk) because the work packet did not provide a grounded unique target;
- runtime improvement added: `run-catalog-agent-triage` now oversamples the candidate snapshot before recent-proposal dedupe, then sends only the bounded eligible subset to the LLM. This keeps token spend capped while avoiding runs where most of the requested batch is skipped before the provider call.
- oversampling regression run `#61` exposed an over-eager provider `auto_apply_eligible=true` flag on an unsupported proposal type; the runtime now repairs unsupported auto-apply flags to `false` before contract validation instead of discarding the whole batch.
- run `#62` confirmed the improvement: useful LLM items increased from `2` to `7`, with `6` proposals persisted and `1` low-confidence noise proposal blocked by the quality gate.
- `CATALOG_AGENT_RECENT_PROPOSAL_DAYS=0` is now allowed only for controlled dev/eval reruns after context/runtime changes, avoiding term-specific fake learning while preserving the default dedupe behavior.
- parent-candidate cleanup applied on dev: duplicate `cipolla` now redirects to active canonical `onion`, and implemented learning teaches generic unqualified plural produce terms to prefer the active parent when no identity-bearing modifier is present.
- run `#64` produced the first new Level 5.0 candidate: proposal `#50` `cipolle -> onion`, `approve_alias`, low risk, confidence `0.96`, auto-apply eligible.
- proposal `#50` passed deterministic validation and was auto-applied by the orchestrated `low_risk_apply_batch` worker in run `#66`, worker job `#21`.
- apply audit `#8` is active with rollback plan `delete_inserted_alias` for alias id `182`; verification found one active alias row for `cipolle` with `approval_source='agent_auto_apply'`.
- no staging data or schedules were touched.

Allowed actions:

- queue deterministic validation;
- authorize low-risk apply worker in real mode;
- apply approved alias/localization proposals through governed RPCs;
- write audit rows and rollback metadata;
- stop automatically when zero eligible or risk changes.

Still forbidden:

- applying medium/high-risk work;
- creating new canonical ingredients;
- applying recipe reconciliation that depends on unresolved catalog identity;
- staging scheduling without release approval.

Required implementation:

- backend feature flag for real low-risk apply remains off by default;
- agent worker authorization record required for each real apply batch;
- low-risk apply batch must be idempotent and capped;
- rollback must exist for every applied row;
- console must show before/after and rollback availability;
- failed apply or rollback must create learning memory.

Exit gates:

- at least `20` low-risk proposals validated on dev;
- at least `5` real low-risk apply batches on dev with `0` unsafe mutations;
- rollback tested successfully on at least one intentionally reversible dev record;
- no founder review required for straightforward alias/localization cases;
- Supabase lint and security checks remain clean.

Operational rating after completion:

```text
The agent can safely close boring catalog work.
```

## Level 5.5: Managed Autopilot Delegation

Goal:

The agent becomes the manager of Autopilot workers instead of merely coexisting with them.

Allowed actions:

- decide which worker should run next;
- set small batch sizes and source filters;
- run enrichment draft batch;
- run ingredient creation batch only for ready drafts and only when the backend creation flag is enabled;
- run low-risk apply dry-run or real low-risk apply depending on current autonomy level;
- record worker outcomes under the parent agent run.

Still forbidden:

- letting Autopilot independently expand LLM workload;
- worker chains without explicit parent run;
- applying medium/high-risk decisions;
- staging cron.

Required implementation:

- worker planning step in agent run summary;
- worker risk ceiling inherited from agent run;
- worker budget inherited from agent run;
- worker result must feed learning memory when failed, empty, or surprising;
- console should show a single pipeline story: agent decision -> worker job -> result -> audit.

Exit gates:

- agent-run worker ledger fully covers every delegated job;
- no orphan worker jobs during dev tests;
- empty worker runs explain why they were empty;
- Autopilot LLM calls are visible in manager-level AI usage;
- repeated worker failures produce actionable learning.

Operational rating after completion:

```text
The agent manages the factory floor; Autopilot runs the machines.
```

## Level 6.0: Scheduled Dev Autonomy

Goal:

The agent runs on a controlled dev schedule and manages routine backlog without manual invocation.

Allowed actions:

- scheduled dev triage;
- scheduled low-risk dry-run;
- scheduled low-risk real apply only if Level 5.0 gates remain green;
- automatic stop when budget, error, or ambiguity thresholds are hit;
- daily digest for operator review.

Still forbidden:

- staging schedule;
- unrestricted source-domain scope;
- autonomous canonical creation;
- silent policy changes.

Required implementation:

- pg_cron or external scheduler for dev only;
- explicit kill switch;
- daily budget and run-count ceiling;
- anomaly detector for proposal volume, risk mix, token spend, and failed validations;
- daily digest in admin console or stored report table.

Implementation status:

- started on `2026-05-13` on `Season-dev` only;
- migration `20260513113000_catalog_agent_dev_schedule_digest.sql` introduces `catalog_agent_dev_schedule_config`, the disabled-by-default kill switch and daily ceilings table;
- migration `20260513113000_catalog_agent_dev_schedule_digest.sql` introduces `catalog_agent_daily_digests`, a durable daily shift report table for runs, workers, proposals, apply audit, AI usage, and anomaly classification;
- `catalog_agent_dev_schedule_guard(...)` returns whether scheduled dev work is allowed under the kill switch and daily ceilings;
- `catalog_agent_build_daily_digest(...)` builds and stores a daily digest with `green`, `yellow`, or `red` status;
- `catalog_agent_dev_schedule_status` exposes the current schedule config plus latest digest for the admin console;
- the default dev config is intentionally disabled, with dry-run enabled and real low-risk apply disabled until Level 5.0 gates have more history;
- dev smoke passed through `scripts/catalog_agent_daily_digest_smoke.sh`: the guard returned `schedule_disabled` with `kill_switch=true`, and the digest stored a `red` status for the current manual-heavy development day;
- the `red` digest is expected today because manual testing exceeded scheduled-day run, worker, and token ceilings; it proves the schedule guard/digest layer can detect when the agent should not continue unattended;
- `run-catalog-agent-dev-shift` was added as the future scheduler entrypoint: it calls the guard first, skips safely while the kill switch is off, always refreshes the daily digest, and does not wire real apply or triage scheduling yet;
- first controlled dry-shift smoke passed: `run-catalog-agent-dev-shift` was temporarily allowed on dev, launched `low_risk_apply_batch` in dry-run mode through orchestrator run `#67` and worker job `#22`, found `0` eligible proposals, applied `0` mutations, consumed `0` new LLM triage calls, refreshed the digest, and was then fully disabled again;
- Supabase lint passed with `No schema errors found`;
- no staging schedule or staging table writes are part of this step.

Exit gates:

- `7` consecutive scheduled dev days without unsafe mutation;
- cost stays within daily cap every day;
- digest correctly explains all non-trivial decisions;
- no stale proposals pile up without classification;
- founder review workload decreases rather than shifts into a noisier queue.

Operational rating after completion:

```text
The dev agent can work shifts without being babysat.
```

## Level 6.5: Staging Readiness Pilot

Goal:

Move from dev-only autonomy to staging pilot readiness without exposing testers to unsafe catalog drift.

Allowed actions:

- staging dry-run only;
- staging proposal persistence only after dev replay passes;
- staging low-risk apply remains disabled initially;
- compare dev/staging catalog coverage and proposal behavior.

Still forbidden:

- staging real apply until explicitly approved;
- staging cron until dry-run pilot is clean;
- migration of dev training noise into staging without source-of-truth decision.

Required implementation:

- staging-specific secrets and operator token;
- staging console config or clearly labeled environment switch;
- staging security advisor check;
- staging recipe/catalog alignment check;
- staging runbook for rollback, disable, and incident response.

Exit gates:

- PAT rotated before staging promotion;
- Supabase Security Advisor critical findings are resolved or accepted with written rationale;
- staging dry-run produces no unsafe proposal classification;
- TestFlight backend remains stable during the pilot;
- staging source-of-truth policy remains clear.

Operational rating after completion:

```text
The agent is safe to observe staging, not yet to change it.
```

## Level 7.0: Governed Canonical Creation Autonomy

Goal:

The agent can shepherd missing ingredients from observation to canonical catalog entry through Autopilot and validators, without direct LLM writes.

Allowed actions:

- identify true catalog gaps;
- prepare enrichment drafts;
- request Autopilot enrichment;
- validate ready drafts;
- authorize ingredient creation worker for ready low/medium-risk drafts when policy allows;
- create aliases/localizations linked to the new canonical only through governed RPCs.

Still forbidden:

- direct creation from an LLM answer;
- creating high-risk identity nodes without human approval;
- creating broad ambiguous families such as `spezie` without a clear policy;
- bypassing nutrition/seasonality/category requirements where relevant.

Required implementation:

- catalog-gap quality score;
- required semantic profile for product family, subtype, preparation state, and localization;
- draft completeness validator by ingredient class;
- parent/variant policy validator;
- duplicate search against aliases, localizations, canonical slugs, and redirects;
- nutrition/seasonality enrichment quality gates;
- rollback/deprecation plan for mistaken creations.

Exit gates:

- at least `20` create-canonical proposals reviewed on dev;
- at least `5` governed ingredient creations on dev with complete metadata;
- no duplicate canonical created for an existing ingredient;
- meaningful variants are preserved where product identity differs;
- broad generic terms are escalated rather than created blindly.

Operational rating after completion:

```text
The agent can open new catalog shelves, but only after inventory control signs off.
```

## Level 7.5: Cross-Language Catalog Stewardship

Goal:

The agent can manage multilingual aliases/localizations and cross-language ambiguity while respecting canonical identity.

Allowed actions:

- propose localized names;
- propose aliases in supported languages;
- detect translation false friends;
- keep language-specific terms attached to the same canonical when safe;
- escalate culturally or regionally ambiguous food identities.

Still forbidden:

- treating translation as identity proof;
- collapsing regionally distinct ingredients into one canonical without policy;
- using one language's food taxonomy as universal truth.

Required implementation:

- language-aware semantic profile;
- localized evidence examples;
- cross-language duplicate detector;
- locale-specific alias confidence thresholds;
- admin console filters by language and source.

Exit gates:

- golden cases include Italian, English, French, and at least one additional target market language;
- localization-only cases reach `10/10`;
- false-friend fixture set passes;
- no multilingual alias can bypass canonical identity validation.

Operational rating after completion:

```text
The agent can work across languages without pretending every translation is simple.
```

## Level 8.0: Staging Governed Autonomy

Goal:

The agent can run safely on staging with limited real low-risk apply and strong observability.

Allowed actions:

- scheduled staging triage;
- staging proposal persistence;
- real low-risk alias/localization apply within strict caps;
- dry-run canonical creation pipeline;
- daily operator digest;
- automatic disable on anomaly.

Still forbidden:

- high-risk apply;
- direct canonical creation without ready draft and validator path;
- unreviewed recipe reconciliation that could affect tester experience;
- production launch assumptions.

Required implementation:

- staging kill switch tested;
- staging rollback tested;
- staging daily report;
- budget alerting;
- release-aware freeze switch for TestFlight review windows;
- security advisor and lint checks integrated into promotion checklist.

Exit gates:

- `14` consecutive staging days without unsafe mutation;
- no tester-visible catalog regression attributable to the agent;
- low-risk apply precision is effectively perfect in sampled audit;
- rollback and disable procedures are rehearsed;
- operator dashboard is understandable without reading raw JSON.

Operational rating after completion:

```text
The agent can work in the tester environment with guardrails tight enough for early public feedback.
```

## Level 8.0+: Multi-Market Autonomous Catalog Steward

Goal:

The agent becomes Season's long-running catalog steward across sources, languages, and markets, with human review reserved for genuinely new policy decisions.

Allowed actions:

- continuous backlog prioritization;
- market/language-specific catalog improvement;
- recurring low-risk apply;
- governed canonical creation for low-risk catalog gaps;
- stale learning cleanup;
- source quality scoring;
- drift detection between recipes, catalog, and user behavior.

Still forbidden:

- changing policy without approval;
- hiding uncertainty;
- silently mutating high-risk food identity;
- creating nutrition/allergen claims without validated source data;
- operating without budget and audit controls.

Required implementation:

- market-aware policy packs;
- long-term learning memory pruning and promotion;
- source reliability scoring;
- anomaly detection across catalog, recipe reconciliation, and app behavior;
- periodic human-readable catalog health report;
- integration with release governance and incident response.

Exit gates:

- monthly catalog health improves without founder micromanagement;
- ambiguous review volume trends down;
- no uncontrolled cost growth;
- no repeated semantic class of mistake after learning is recorded;
- every autonomous mutation remains explainable, reversible, and attributable.

Operational rating after completion:

```text
The agent behaves like a careful catalog operations lead, not a script.
```

## Promotion Rules

No level may be promoted unless all of these are true:

- the previous level's exit gates passed;
- docs and runbooks are updated;
- Supabase lint is clean for changed database objects;
- security posture is reviewed if new privileges or schedules are added;
- staging remains untouched unless the level explicitly permits staging work;
- all new mutation paths have audit and rollback strategy;
- budget limits are configured before LLM calls expand;
- operator UI explains outcomes in human language.

## Immediate Next Step

The next target is `5.0 low-risk apply autonomy`.

Recommended implementation order:

1. Add a repeatable rollback regression smoke for one reversible dev alias. Completed on `2026-05-13`.
2. Keep real low-risk apply disabled by default and enable only controlled `limit=1` windows.
3. Validate at least `20` low-risk proposals on dev.
4. Run at least `5` real low-risk apply batches on dev with `0` unsafe mutations.
5. Ensure every applied row has audit and rollback metadata.
6. Keep staging untouched until Level `6.5`.
