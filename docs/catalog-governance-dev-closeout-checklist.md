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
- TestFlight handoff: `docs/testflight-bugfix-handoff-2026-05-12.md`

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
- Console exposes `ingredient_creation_batch` for ready enrichment drafts only; the backend still requires `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=true`.
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

Meaningful variant learning:

- `catalog_agent_learnings.id = 4` records that `pomodorini`/small tomato terms must not be collapsed into base `tomato`.
- `catalog_agent_meaningful_variant_guardrails` stores data-driven base-vs-variant guardrails.
- `catalog_agent_meaningful_variant_guardrail_error(...)` blocks governed identity-bearing variants from validating as aliases of their generic base.
- The first data row covers small tomato variants vs base `tomato`, but the validator logic is general and reusable for future cases such as sweet potatoes vs potatoes, gluten-free pasta vs pasta, Greek yogurt vs yogurt, or basmati rice vs rice.
- The agent prompt now carries the general rule before the model proposes anything.
- Expected future behavior: `pomodori` can resolve to base `tomato`; `pomodorini` requires an explicit child variant such as `cherry_tomatoes` or human review/catalog-gap handling.

Semantic profile upgrade:

- `run-catalog-agent-triage` now uses prompt version `catalog-agent-triage-v3-semantic-profile`.
- Each LLM proposal must include a structured `semantic_profile`.
- The profile captures product family, variant dimension, parent candidate, identity-bearing variant risk, substitutability, and app-impact implications.
- Step 1 stores the profile inside proposal `evidence` without a DB schema change.
- Dev smoke test `catalog_agent_runs.id = 23` returned 6 valid dry-run proposals and created no rows.
- Dev was restored to `CATALOG_AGENT_ENABLED=false` after the smoke test.

Canonical creation worker bridge:

- `create_canonical` proposals can prepare a pending enrichment draft through `prepare_catalog_agent_canonical_enrichment_draft(...)`.
- `run-catalog-agent-orchestrator` now supports `ingredient_creation_batch`.
- `ingredient_creation_batch` calls `run-catalog-ingredient-creation-batch`, which creates only from already `ready` enrichment drafts.
- The worker records start/completion/failure on `catalog_agent_worker_jobs`.
- Real creation is disabled unless `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=true`.
- Dev smoke artifact: proposal `#12` for `pomodorini` prepared a pending draft; it was not created as a catalog ingredient because enrichment/validation still need to run.
- Follow-up dev smoke completed the path for `pomodorini`: enrichment resolved the Italian parent candidate `pomodoro` to canonical slug `tomato`, promoted the draft to `ready`, then `ingredient_creation_batch` created `pomodorini` as a child produce variant of `tomato`.
- The creation wrapper now preserves all available draft localizations, not only the display language chosen for the initial candidate creation call.

## Final Dev Smoke Test

Run these checks before treating the branch as ready for review.

### 2026-05-12 Closeout Verification Snapshot

Status: passed for the static console and branch hygiene after TestFlight `1.0.1 (4)` was merged into `agent/catalog-governance`.

Checks run:

- `git diff --check`: passed.
- `node --check admin-console/app.js`: passed.
- `node --check admin-console/config.example.js`: passed.
- Live `https://catalog.seasonapp.it/` static assets match local `admin-console/index.html`, `admin-console/app.js`, and `admin-console/styles.css` by SHA-256.
- Live `config.local.js` points to `Season-dev` (`gyuedxycbnqljryenapx`) and not staging.
- Live `config.local.js` does not expose service-role markers.
- `run-catalog-agent-orchestrator` responds to browser CORS preflight from the console origin with `204`.
- Direct worker/triage browser preflight is not enabled, which is acceptable because the console should route worker operations through the orchestrator.

Not run by automation in this snapshot:

- authenticated browser login with a catalog-admin dev user;
- real console button smoke test;
- Supabase CLI lint/query against dev, because no active Supabase CLI PAT is assumed during this closeout check.

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

For canonical creation testing, use the stricter sequence:

```text
Prepare draft -> Enrichment draft batch -> confirm draft ready -> Ingredient creation batch
```

Expected acceptable outcomes:

- if no draft is ready, the worker completes with zero created items;
- if one draft is ready and the enable flag is on, exactly one ingredient is created for a limit of `1`;
- if the enable flag is off, the worker job fails closed and records the failure reason.

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
