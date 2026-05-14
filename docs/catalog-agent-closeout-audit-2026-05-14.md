# Catalog Agent Closeout Audit - 2026-05-14

Status: dev closeout audit for `agent/catalog-governance`.

Scope:

- environment: `Season-dev`;
- staging: intentionally untouched;
- release branch: not part of this audit;
- database mutations: none introduced by this audit;
- cleanup: local generated caches only.

## Executive Summary

The Catalog Governance Agent is now at a Level `7.0 dev autonomy foundation`.

That means it can reason, persist governed proposals when explicitly enabled, delegate bounded workers, survive safe dev scheduler checks, and repair some blocked LLM output. It still cannot be treated as a staging or production autonomous catalog operator.

The strongest current achievement is not that the model is "smarter". It is that the system has more ways to stop, downgrade, explain, and audit the model before any catalog identity changes.

## What Is Working

- The agent and Autopilot roles are separated: the agent manages decisions, Autopilot executes bounded worker jobs.
- Proposal persistence is feature-flagged and fails closed.
- Low-risk apply has rollback/audit foundations and remains disabled by default.
- Dev scheduler foundations exist with kill switch, mandatory expiry windows, run ledger, and console visibility.
- The admin console is deployed at `https://catalog.seasonapp.it/` and points to `Season-dev`.
- Smart Import learning signals can feed catalog-agent evaluation without touching staging.
- Golden cases, context quality checks, and parallel eval runners exist for no-apply intelligence testing.
- The latest runtime blocks duplicate proposals for the same normalized work item.
- The latest runtime blocks broad generic aggregates and recipe-process byproducts using source/work-item evidence.
- The latest runtime can run one bounded self-repair pass over quality-gate-blocked proposals.

## Evidence Kept In Repo

These JSON files are intentionally kept as compact audit artifacts:

- `docs/catalog-agent-parallel-eval-latest.json`
- `docs/catalog-agent-parallel-eval-large-latest.json`
- `docs/catalog-agent-parallel-eval-depth-latest.json`
- `docs/catalog-agent-parallel-eval-policy-latest.json`
- `docs/catalog-agent-parallel-eval-spezie-latest.json`
- `docs/catalog-agent-self-repair-eval-latest.json`

Recent implementation commits:

- `4fb2c85` - larger catalog-agent eval batch;
- `8c90200` - policy learning from eval disagreements;
- `76a33e1` - quality-gate self-repair.

Recent important dev evidence:

- large/policy evals improved recurring disagreement handling;
- run `#98` exposed an unsafe `spezie` broad-canonical behavior;
- source-grounded guardrails were tightened so model-generated rationale cannot justify its own broad aggregate;
- run `#99` confirmed `spezie` became `needs_human_review` with no catalog mutation.

## Cleanup Performed

- Removed local generated Python cache directories:
  - `scripts/__pycache__`
  - `scripts/catalog_agent_golden_cases/__pycache__`
  - `scripts/smart_import_learning_cases/__pycache__`
- Confirmed no tracked `__pycache__` files remain.
- Kept latest eval JSON reports because they explain why the current guardrails exist.

## Pending Risks

- `deno check supabase/functions/run-catalog-agent-triage/index.ts` still reports pre-existing Supabase generic typing noise; `llm_contract.ts` checks cleanly, but the main runtime type-check signal is not yet useful enough.
- Level `7.0` is a foundation, not complete canonical creation autonomy.
- Catalog matcher logic is still partly embedded in packet construction and prompt behavior.
- Learning writer automation is still planned; some learning memory is written by migrations or controlled scripts rather than automatically from every override.
- Staging has not been validated for this agent workflow.
- PAT/token rotation is still recommended before any staging promotion or sensitive deploy window.
- Multi-pass reasoning and self-repair can increase token use, so run size and daily limits must stay conservative.

## Recommended Next Steps

1. Freeze the current dev default state after each smoke: agent disabled, proposal persistence disabled, scheduler window closed.
2. Add a dedicated catalog matcher layer before increasing LLM volume again.
3. Implement learning-writer automation for rejected, failed, and overridden proposals.
4. Improve the TypeScript/Supabase type boundary so `deno check index.ts` becomes a reliable release gate.
5. Keep staging out of scope until there is a separate staging promotion checklist.
6. Rotate the Supabase PAT before staging or external-tester operations resume.

## Closeout Decision

The branch is healthy enough for continued dev work on the agent system.

It is not yet ready for staging autonomy, but it is in a much better state than a raw LLM wrapper: it now behaves more like a cautious operations manager with brakes, audit, and learning hooks.
