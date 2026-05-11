# Catalog Governance Dev Closeout Checklist

Status: active checklist for closing the current `agent/catalog-governance` dev cycle.

This checklist is for the current branch and dev environment only. It does not authorize staging changes.

## Current State

- Branch: `agent/catalog-governance`
- Console URL: `https://catalog.seasonapp.it/`
- Console backend: `Season-dev`
- Staging backend: intentionally untouched for this agent-console cycle
- Real low-risk apply: disabled by default
- Console low-risk apply: dry-run only

## Completed

- Catalog Agent responsibility model documented.
- Agent and Autopilot roles separated: manager vs bounded worker.
- Worker ledger added through `catalog_agent_worker_jobs`.
- AI usage ledger added through `catalog_ai_usage_events`.
- Agent orchestrator can delegate bounded worker jobs.
- Low-risk apply worker exists and defaults to dry-run behavior.
- Auto-apply audit and rollback foundation exists.
- Rollback failure persistence is implemented.
- Dev controlled apply test was performed and documented.
- Console operations dashboard shows worker jobs, AI usage, readiness, and audit.
- Console exposes only safe dry-run for low-risk apply.
- Console uses backend diagnostics for zero-eligible explanations.
- Console help bubbles explain operator-facing fields.
- Tooltip rendering was moved to a page-level popover to avoid clipping.
- Static console is deployed to `catalog.seasonapp.it`.
- SSH deploy path and command are documented.
- Smart Import training captions were imported into dev custom observations as a controlled catalog-agent exercise.
- The agent triage run timestamp bug was fixed after the training import exposed it.

## Dev Training Import

2026-05-11 Smart Import caption batch:

- Input file: `smart_import_training_captions.csv`.
- Rows processed: 50.
- Expected ingredient mentions analyzed: 288.
- New dev observations inserted: 26.
- New dev observation occurrences inserted: 43.
- Observation source: `smart_import_training_captions`.
- Staging was not touched.

Top new signals:

- `pepe`: 7 occurrences.
- `pomodori`: 4 occurrences.
- `pomodorini`: 4 occurrences.
- `olive`: 3 occurrences.
- `fiocchi d avena`: 2 occurrences.
- `pane raffermo`: 2 occurrences.
- `uovo`: 2 occurrences.

Agent run:

- `catalog_agent_runs.id = 18`.
- Snapshot items: 5.
- Items sent to LLM: 5.
- Proposals created: 5.
- Result: all 5 proposals were `needs_human_review`.
- Terms: `pepe`, `pomodori`, `pomodorini`, `olive`, `fiocchi d avena`.

Interpretation:

- The agent did not create or apply catalog changes blindly.
- `pomodori` and `pomodorini` show that the agent can infer likely tomato intent but needs a stronger actionable target context before approving aliases.
- `olive` correctly remains high-risk because green/black/generic olive identity is ambiguous.
- This is useful training data for improving context enrichment and deterministic alias validation, not a failure.

Runtime fix discovered by this test:

- Immediate cancelled/completed agent runs could violate `catalog_agent_runs_finished_after_started` because `finished_at` came from Edge runtime time while `started_at` used database default `now()`.
- `run-catalog-agent-triage` now inserts both `started_at` and immediate `finished_at` from the same Edge timestamp.

## Final Dev Smoke Test

Run these checks before treating the branch as ready for review.

### 1. Static Console

Open:

```text
https://catalog.seasonapp.it/
```

Verify:

- login works with a catalog-admin dev user;
- the sidebar says `Season-dev`;
- non-admin users cannot access the workspace;
- help bubbles are readable and not clipped;
- raw JSON panels stay collapsed unless opened.

### 2. Review Inbox

Verify:

- inbox loads without console errors;
- selecting a proposal updates the detail panel;
- `needs_human_review` proposals do not show unsafe apply actions;
- learning memory can be loaded for a selected term.

### 3. Operations

Run:

```text
low_risk_apply_batch
dry_run = true
limit = 1
```

Expected acceptable outcomes:

- eligible count is zero with a clear explanation; or
- eligible preview lists only validated, low-risk, existing-canonical work.

Do not enable real apply from the console.

### 4. AI Usage

Verify:

- today's AI usage panel loads;
- costs/tokens are visible when available;
- no unexpected spike appears after a small worker run.

### 5. Audit And Rollback

Verify:

- recent auto-apply audit rows are visible;
- rollback buttons appear only for active applied records;
- rollback requires an operator note.

Do not rollback real records unless there is a concrete reason.

## Required Before Staging

Staging work should be a separate decision and preferably a separate checklist.

Before touching staging:

- revoke or rotate the Supabase PAT shared during setup;
- confirm App Store/TestFlight review status;
- run Supabase lint against the intended project;
- re-check Supabase Security Advisor;
- decide whether the staging console should exist or remain dev-only;
- create staging-specific console config if needed;
- keep real low-risk apply disabled initially;
- run a dry-run-only worker smoke test on staging;
- document the exact staging source-of-truth policy for recipes and catalog updates.

## Suggested Closeout Commit Criteria

The branch can be considered ready to merge/review when:

- `git diff --check` passes;
- `node --check admin-console/app.js` passes;
- docs describe the operator workflow;
- live console reflects the latest static assets;
- GitHub branch is pushed;
- no uncommitted files remain.

## Open Decision

The only deliberate open operational decision is when to promote any of this beyond dev.

Recommended default:

```text
Keep the console dev-backed until the current TestFlight release is accepted and tester feedback begins.
```

This keeps the agent work moving without destabilizing the release candidate.
