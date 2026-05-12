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

## Next Controlled Agent Batch

Status: planned for `Season-dev` only. Staging remains untouched.

Goal:

- verify that the agent behaves like a catalog manager, not a blind proposal generator;
- confirm it can choose between existing-canonical aliasing, meaningful variant creation, new canonical creation, and human escalation;
- keep all mutation workers disabled until proposal quality is reviewed.

Runtime gates:

- run triage/proposal generation first;
- allow enrichment only for `create_canonical` drafts after reviewing the proposal shape;
- keep `CATALOG_AGENT_ORCHESTRATOR_ENABLED=false` unless a single bounded worker run is intentionally requested;
- keep `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=false` unless one reviewed `ready` draft should be created with `limit=1`;
- restore `CATALOG_AGENT_ENABLED=false` immediately after any manual dev smoke run.

Candidate expectations:

| Term | Expected agent behavior | Why it matters |
| --- | --- | --- |
| `pomodori` | Resolve toward existing base canonical `tomato`; do not create a new ingredient. | Plural/localized base terms should improve aliases/localizations without catalog duplication. |
| `pepe` | Prefer an existing pepper canonical only if the observed context supports it; avoid deprecated duplicate `pepe_nero`. | The agent must use active catalog identity and avoid resurrecting deprecated duplicates. |
| `uovo` | Resolve toward existing canonical `eggs` as a singular/localized alias candidate. | Common singular/plural forms should become deterministic catalog coverage. |
| `fiocchi d avena` | Treat as a likely distinct oat-flake product under `oats`, not as a blind alias of base oats. | This tests parent/child variant reasoning and nutrition/filter implications. |
| `olive` | Keep as human review unless context identifies green, black, pitted, oil-preserved, etc. | Generic terms with meaningful product variants should not auto-collapse. |
| `pane raffermo` | Escalate or propose a contextual child only if policy supports stale bread as an ingredient identity. | Some recipe terms are preparation state/context, not always new catalog products. |

Pass criteria:

- high-confidence base terms produce actionable existing-canonical proposals;
- clear missing catalog identities produce `create_canonical` drafts rather than generic review;
- genuinely ambiguous terms remain `needs_human_review` with a precise blocking question;
- no catalog ingredient, alias, localization, recipe, or reconciliation state changes happen during triage;
- AI usage remains bounded and visible in `catalog_ai_usage_events`.

### 2026-05-12 Batch Output

Run:

- `catalog_agent_runs.id = 34`.
- Source domain: `smart_import_training_captions`.
- Limit: `10`.
- Items sent to LLM: `6`.
- Proposals created: `6`.
- Recent proposals skipped: `4`.
- Reasoning mode: `multi_pass`.
- Token usage: `18,634` input, `5,316` output, `23,950` total.
- Triage was disabled again after the run.

Created proposals:

| ID | Term | Proposal | Risk | Status | Assessment |
| --- | --- | --- | --- | --- | --- |
| `13` | `pane raffermo` | `create_canonical` | medium | draft | Good behavior: recognizes a state-based bread identity instead of collapsing to base bread. Needs policy decision before creation. |
| `14` | `uovo` | `needs_human_review` | low | needs review | Not good enough: the ingredient is clear and should have received an existing `eggs`/`uova` candidate in context. |
| `15` | `acqua di cottura` | `needs_human_review` | medium | needs review | Good behavior: preparation byproduct, not safe to alias to plain water. |
| `16` | `carne macinata` | `needs_human_review` | medium | needs review | Acceptable behavior: species is unspecified, so nutrition/filter meaning may differ. |
| `17` | `cipolle` | `needs_human_review` | high | needs review | Acceptable until a generic onion parent policy exists; current candidates can imply color/type ambiguity. |
| `18` | `frutti di bosco` | `create_canonical` | medium | draft | Good behavior: mixed berry identity should not collapse to one berry type. |

Important diagnosis:

- The agent is now capable of creating catalog-gap drafts when identity is clear.
- The main weakness is upstream context, not only prompt wording.
- `uovo` shows the gap: the model correctly understood "standard hen egg" with high confidence, but the work packet did not provide `eggs`/`uova` as a usable target candidate.
- The next implementation step should enrich `get_catalog_agent_triage_snapshot(...)` with deterministic lexical candidate expansion before the LLM runs.

Recommended implementation:

- add a deterministic candidate-expansion layer for common singular/plural and localized forms;
- include active aliases and localizations found through that expansion in `possible_canonical_matches` / `existing_alias_matches`;
- keep the expansion data-driven where possible and use explicit exceptions only as catalog governance data, not hidden prompt hacks;
- re-run the same batch and expect `uovo` to become an actionable existing-canonical proposal instead of human review;
- only after that, prepare drafts for reviewed `create_canonical` proposals such as `frutti di bosco` with creation still disabled.

### Reviewed Decisions After Batch 34

Decisions:

- `uovo` maps to existing canonical `eggs`; this is a singular Italian alias problem, not a catalog gap.
- `pane raffermo` maps to existing canonical `bread`; `raffermo` is recipe preparation/context and should not create a separate catalog identity.
- `frutti di bosco` remains open because mixed-berry identity needs a careful product-family decision before catalog creation.

Implementation:

- migration `20260512161000_govern_uovo_and_stale_bread_aliases.sql` adds governed aliases for `uovo -> eggs` and `pane raffermo -> bread`;
- the migration records candidate decisions and implemented learning memory;
- open agent proposals for those terms are marked `superseded`;
- staging is still untouched.

Dev verification:

- `uovo` alias is approved, active, confidence `0.99`, target `eggs`;
- `pane raffermo` alias is approved, active, confidence `0.94`, target `bread`;
- matching custom observations are `resolved_alias`;
- agent proposals `#13` and `#14` are `superseded`;
- `supabase db lint --linked` returned no schema errors.

### Learning-To-Context Automation

Implementation:

- migration `20260512163500_catalog_agent_lexical_candidate_expansion.sql` adds `catalog_agent_lexical_candidate_terms(...)`;
- the triage snapshot now includes `context.lexical_candidate_terms`;
- `possible_canonical_matches` and `existing_alias_matches` use lexical terms before the LLM runs;
- migration `20260512165000_refine_catalog_agent_lexical_expansion_noise.sql` keeps morphology conservative by applying singular/plural expansion only to single-token terms.

Behavior added:

- localized singular/plural forms can expose existing catalog targets, e.g. `pomodori` now gets `pomodoro` as a lookup hint and sees canonical `tomato`;
- phrase modifiers that are preparation/freshness state can expose the base ingredient, e.g. `pane raffermo` can produce `pane` as a lookup hint;
- multi-word product phrases such as `fiocchi d avena` no longer receive noisy fake morphology;
- ambiguous families still show ambiguity rather than being auto-collapsed, e.g. `olive` exposes black/green/oil-related candidates and should remain review-only without stronger context.

Dev verification:

- `pomodori` snapshot includes lexical term `pomodoro` and canonical candidate `tomato` with match reason `it_name_lexical_variant`;
- `fiocchi d avena` snapshot keeps only the original lexical term;
- `pepe` snapshot keeps only the original lexical term;
- `olive` snapshot exposes multiple plausible candidates, preserving ambiguity;
- `supabase db lint --linked` returned no schema errors.

### 2026-05-12 Post-Learning Agent Launch

Runs:

- `catalog_agent_runs.id = 35`: failed before proposals with `semantic_profiler:AbortError`; no proposals were created and AI usage recorded an error without token counts.
- `catalog_agent_runs.id = 36`: `limit=3` no-op; all 3 items were skipped by recent-proposal dedupe.
- `catalog_agent_runs.id = 37`: successful proposal-only run after temporarily setting `CATALOG_AGENT_PROVIDER_TIMEOUT_MS=60000`.

Run `37` summary:

- Source domain: `smart_import_training_captions`.
- Items in snapshot: `10`.
- Items sent to LLM: `2`.
- Recent proposals skipped: `8`.
- Proposals created: `2`.
- Token usage: `8,498` input, `2,236` output, `10,734` total.
- Provider duration: `18,917ms`.
- Triage was disabled again after the run.

Created proposals:

| ID | Term | Proposal | Risk | Status | Assessment |
| --- | --- | --- | --- | --- | --- |
| `19` | `lenticchie rosse` | `create_canonical` | medium | draft | Good behavior: red lentils are a meaningful lentil variant and should not collapse into generic lentils without a dedicated child. |
| `20` | `lievito per dolci` | `needs_human_review` | high | needs review | Good conservative behavior: usually dessert baking powder/cake leavening in Italian, but formulation/target policy is not yet explicit. |

Operational note:

- Multi-pass runs over larger packets can exceed the default `20s` provider timeout.
- For controlled dev smoke tests, `60s` provider timeout is more realistic.
- The triage Edge Function now has a single-shot adaptive retry: on provider timeout it records the failed attempt, halves eligible items, and retries once.
- Before production scheduling, keep batches small and monitor `adaptive_retry` frequency; repeated retries mean the prompt packet or batch size should be reduced.

Adaptive retry deployment:

- `run-catalog-agent-triage` was deployed to `Season-dev` after adding the retry path.
- The retry records `provider_adaptive_retry_scheduled` and `provider_adaptive_retry_succeeded` run events when used.
- Timeout retry attempts also create `catalog_ai_usage_events` rows with `reason=provider_timeout_retry`.
- Post-deploy smoke run `catalog_agent_runs.id = 38` completed as a no-op with `10` recent-proposal skips and `0` LLM calls.
- `CATALOG_AGENT_ENABLED` was disabled again after the smoke run.
- `CATALOG_AGENT_PROVIDER_TIMEOUT_MS` was restored to `20000`.

Budget-conscious follow-up:

- Run `39` was a no-op because `CATALOG_AGENT_MAX_ITEMS_PER_RUN=10` only reached recent proposals.
- Run `40` used a temporary cap of `12` and spent `10,367` total tokens.
- Run `40` found a useful runtime issue: the provider returned an `add_localization` proposal without a target, so validation failed and no proposals were inserted.
- The triage function now repairs incomplete actionable proposals by downgrading them to `needs_human_review`, recording `provider_output_repaired`, and preserving a blocking question.

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
