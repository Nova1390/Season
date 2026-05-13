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
- Golden-case evaluation now exists to measure catalog-agent intelligence without extra LLM calls.
- Golden cases now include `effective_target`, an operational gate that separates fixed catalog state from historical latest-proposal quality.
- Dev-only controlled apply proved the low-risk path with `pomodori -> tomato`.
- Dev-only canonical draft preparation proved the create-canonical path for `fiocchi d avena -> oat_flakes` without creating an ingredient directly.
- Golden cases now include a `context_target` pre-LLM quality gate.
- Dev context quality is `10/10` after retargeting the legacy small tomato alias `pomodorini ciliegino -> pomodorini`.
- Dev reached `4.0 supervised autonomy`: the agent can run a bounded multi-pass LLM dry-run, use learning/context guardrails, record usage, and remain non-mutating by default.
- The autonomy path from `4.0` through `8.0+` is documented in `docs/catalog-agent-autonomy-roadmap.md`.
- The first `4.5` persistence guard is deployed to `Season-dev`: `dry_run=false` fails closed unless `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=true`.
- `catalog.seasonapp.it` was restored after the remote subdomain folder was missing; the deployed console now returns HTTP `200`.

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

### 2026-05-12 Dev-Gated Autonomy Step

Controlled actions:

- Run `42` created `#23 pomodori` as `approve_alias -> tomato`, low risk, confidence `0.99`, auto-apply eligible.
- Run `42` created `#24 fiocchi d avena` as `create_canonical`, proposed slug `oat_flakes`, medium risk.
- `#23 pomodori` was queued for validation.
- `validate_catalog_agent_proposal(23)` returned no validation errors and marked it `validated`.
- `apply_catalog_agent_proposal(23, ...)` applied it through the governed alias RPC.
- Result: active approved alias `pomodori -> tomato`; proposal status `applied`.
- `#24 fiocchi d avena` was not directly applied because `create_canonical` must use the enrichment path.
- `prepare_catalog_agent_canonical_enrichment_draft(24, ...)` created/refreshed a pending draft with suggested slug `oat_flakes`.

Golden-case output:

```text
current: 10/10 passed
target: 6/10 passed
effective_target: 10/10 passed
```

Autonomy assessment:

- Current maturity is `3.5 dev-gated`.
- The agent can produce actionable low-risk work, pass deterministic validation, and apply through governed RPCs on dev.
- The agent can route missing-canonical work into Autopilot's enrichment-draft lane instead of creating catalog identity directly.
- Scheduled real apply, broad batch apply, and staging promotion remain disabled until `target` improves beyond the historical latest-proposal failures.

### 2026-05-12 Context Quality Gate

Implementation:

- Added `scripts/catalog_agent_golden_cases/run_context_quality.py`.
- Added `context_target` expectations to `scripts/catalog_agent_golden_cases/golden_cases.json`.
- The runner reconstructs pre-LLM context for golden cases even when the terms are already resolved and no longer appear in the normal unresolved queue.
- The runner is read-only and does not call an LLM.

Finding and fix:

- First run: `9/10`.
- Failing case: `pomodorini` context included forbidden parent target `tomato`.
- Cause: legacy active alias `pomodorini ciliegino -> tomato`.
- Migration `20260512190000_retarget_small_tomato_variant_aliases.sql` retargeted the alias to child canonical `pomodorini`, added a candidate decision, and recorded implemented learning.
- Final run: `context_target: 10/10`.

Interpretation:

- This is a concrete intelligence improvement before model invocation.
- The agent now gets cleaner target context for small tomato variants.
- Future LLM failures can be separated into context failures vs reasoning/prompt failures.

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

Run `41`:

- Used the repaired provider-output function with a temporary `limit=12`.
- Items in snapshot: `12`.
- Items sent to LLM: `2`.
- Recent proposals skipped: `10`.
- Proposals created: `2`.
- Token usage: `8,103` input, `1,654` output, `9,757` total.
- No adaptive retry was needed.
- Triage was disabled again after the run.

Created proposals:

| ID | Term | Proposal | Target | Risk | Status | Assessment |
| --- | --- | --- | --- | --- | --- | --- |
| `21` | `mais` | `add_localization` | `corn` | low | draft | Target was correct, but action was wrong: `mais` is a surface/common alias because `corn` already has Italian display text. |
| `22` | `mele` | `add_localization` | `apple` | low | draft | Target was correct, but action was wrong: plural/common forms should become aliases, not replace canonical display localization. |

Governance decision:

- `mais` maps to existing canonical `corn` as an approved Italian alias.
- `mele` maps to existing canonical `apple` as an approved Italian alias.
- `add_localization` should be reserved for missing or incorrect display names, not for plural/imported surface forms when a curated localization already exists.
- The prompt now contains this general rule before the model proposes anything.

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

### 2026-05-12 Golden-Case Harness

Added:

- `scripts/catalog_agent_golden_cases/golden_cases.json`
- `scripts/catalog_agent_golden_cases/run_golden_cases.py`
- `docs/catalog-agent-golden-cases.md`

Purpose:

- `current` profile checks whether dev catalog/proposal state remains correct after reviewed governance.
- `target` profile checks what the agent should eventually propose autonomously.
- The runner is read-only and does not call OpenAI or any LLM provider.

Local verification completed:

- `python3 scripts/catalog_agent_golden_cases/run_golden_cases.py --schema-only`: passed.
- `python3 scripts/catalog_agent_golden_cases/run_golden_cases.py --profile target --schema-only`: passed.
- `python3 -m py_compile scripts/catalog_agent_golden_cases/run_golden_cases.py`: passed.
- `git diff --check`: passed.
- Supabase dev `current` profile: `10/10` passed.
- Supabase dev `target` profile: `3/10` passed, which is the autonomy baseline before further prompt/context improvement.

Next intelligence increment:

- Seeded fresh learning for `pomodori`, `pomodorini`, and `fiocchi d avena` target gaps.
- Updated the LLM contract so base plural/localized forms prefer aliasing when non-variant, while product-form identities can become canonical drafts when missing.
- This is no-apply learning only; the next controlled triage run should show whether target score improves without manual governance.

Mini target run result:

- `catalog_agent_runs.id = 42`.
- Items sent to LLM: `2`.
- Token usage: `14,873` total.
- New proposal `#23`: `pomodori` as `approve_alias -> tomato`, low risk, confidence `0.99`.
- New proposal `#24`: `fiocchi d avena` as `create_canonical` with proposed slug `oat_flakes`, medium risk, confidence `0.93`.
- Agent disabled immediately after the run.
- Golden target score improved from `3/10` to `6/10` after fixture correction for valid `create_canonical` proposals.

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

## 2026-05-12 Supervised Autonomy 4.0 Smoke Test

Environment: `Season-dev` only. Staging was not touched.

Temporary runtime changes:

- `CATALOG_AGENT_ENABLED=true` was enabled only for the smoke test.
- `CATALOG_AGENT_OPERATOR_TOKEN` was set only long enough to invoke the dev function and was unset afterwards.
- `CATALOG_AGENT_ENABLED=false` was restored immediately after the smoke test.

Observed runs:

- `run_id=43`: dry-run completed, `0` items sent to LLM, `1` item skipped because a recent proposal already existed.
- `run_id=44`: dry-run completed, `0` items sent to LLM, `2` items skipped because recent proposals already existed.
- `run_id=45`: dry-run completed, `1` item sent to LLM, `0` proposals persisted.

Run `45` details:

- Source domain: `smart_import_training_captions`.
- Model: `gpt-5.4-mini`.
- Prompt version: `catalog-agent-triage-v4-multi-pass`.
- Reasoning mode: `multi_pass`.
- Internal roles executed: `semantic_profiler`, `risk_reviewer`, `decision_writer`.
- Token usage: `6,333` input, `1,221` output, `7,554` total.
- Returned dry-run proposal: `pasta corta`, `create_canonical`, medium risk, draft.
- Persisted proposals for run `45`: `0`.

Interpretation:

- The recent-proposal guardrail worked before any LLM spend.
- The bounded multi-pass LLM path works when an eligible item is available.
- Dry-run mode correctly avoids writing proposals or catalog mutations.
- This is the current `4.0 supervised autonomy` level: useful reasoning is proven, but real apply and scheduled autonomous mutation remain disabled.

## 2026-05-12 Proposal Persistence Gate 4.5 Start

Environment: `Season-dev` only. Staging was not touched.

Implemented and deployed:

- `run-catalog-agent-triage` agent version `proposal-only-v4.5-quality-gate`.
- New secret flag: `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED`, default `false`.
- If `dry_run=false` and persistence is not enabled, the function returns `PROPOSAL_PERSISTENCE_DISABLED` before calling the LLM or inserting proposals.
- Runtime proposal quality gate added before proposal insert.
- The gate checks evidence, confidence, grounded targets, create-canonical completeness, concrete human-review questions, and unsafe actionable risk.

Smoke result:

- Temporary dev operator token was set for the test and removed afterwards.
- `dry_run=false` with persistence disabled returned `PROPOSAL_PERSISTENCE_DISABLED` as expected.
- A follow-up LLM dry-run was attempted, but the daily run budget correctly stopped it with `DAILY_RUN_BUDGET_EXHAUSTED`.
- Dev was restored to `CATALOG_AGENT_ENABLED=false`, `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=false`, and conservative daily run budget.

Interpretation:

- The 4.5 fail-closed guard is proven.
- The LLM-side quality-gate summary still needs a fresh run window before 4.5 can be marked complete.

### Quality-Gate Dry-Run Smoke

Run `47` completed after opening a temporary dev-only run window.

Result:

- Source domain: `smart_import_training_captions`.
- Items in snapshot: `10`.
- Items sent to LLM: `1`.
- Recent proposals skipped: `9`.
- Returned proposals: `1`.
- Persistable proposals: `1`.
- Blocked by quality gate: `0`.
- Persisted proposals: `0`, because `dry_run=true` and persistence remained disabled.
- Proposal: `pasta corta`, `create_canonical`, medium risk, draft.
- Token usage: `6,309` input, `1,253` output, `7,562` total.

Interpretation:

- The runtime quality gate can classify a real LLM proposal as persistable without writing it.
- This confirms the next safe microstep is a tiny `dry_run=false` dev test with `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=true`, still with real apply disabled.
- Dev was restored again to `CATALOG_AGENT_ENABLED=false`, `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=false`, and the temporary operator token was removed.

### Governed Proposal Persistence Smoke

Run `48` completed after opening a temporary dev-only persistence window.

Result:

- Source domain: `smart_import_training_captions`.
- Items in snapshot: `10`.
- Items sent to LLM: `1`.
- Recent proposals skipped: `9`.
- Returned proposals: `1`.
- Persistable proposals: `1`.
- Blocked by quality gate: `0`.
- Persisted proposals: `1`.
- Proposal id: `25`.
- Proposal: `pasta corta`, `create_canonical`, medium risk, draft.
- Proposed slug: `short_pasta`.
- Proposed localized name: `pasta corta`.
- Proposed language: `it`.
- Confidence: `0.91`.
- Auto-apply eligible: `false`.
- Applied at: `null`.
- Token usage: `6,257` input, `1,266` output, `7,523` total.

Verification:

- `catalog_agent_proposals.id=25` exists with `status='draft'`, `auto_apply_eligible=false`, `applied_at is null`, and no target ingredient id/slug.
- Run `48` events are limited to run lifecycle, reasoning trace, quality gate, and `proposal_created`.
- No apply event or catalog mutation was performed.

Interpretation:

- This proves the first real `4.5` behavior: the agent can persist a governed proposal that passed the quality gate.
- This does not yet complete `4.5`; the roadmap still requires a larger mixed-term sample and no unsafe classifications.
- Dev was restored again to `CATALOG_AGENT_ENABLED=false`, `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=false`, conservative daily run budget, and the temporary operator token was removed.

### Persisted Create-Canonical Draft Routing Smoke

Proposal `#25` was routed into the governed enrichment-draft lane.

Action:

- Called `prepare_catalog_agent_canonical_enrichment_draft(25, ...)`.
- Result: `ok=true`, `draft_status='pending'`, `draft_created_or_refreshed=true`, `next_worker='enrichment_draft_batch'`.
- Mutation scope: `enrichment_draft_only`.

Draft verification:

- `catalog_ingredient_enrichment_drafts.normalized_text='pasta corta'`.
- Status: `pending`.
- Suggested slug: `short_pasta`.
- Italian canonical name: `pasta corta`.
- Confidence: `0.91`.
- Ingredient type: `unknown`.
- Needs manual review: `true`.
- Validated ready: `false`.

Safety verification:

- No `ingredients` row exists for `short_pasta` or `pasta_corta`.
- Proposal events include `canonical_enrichment_draft_prepared`.
- No apply event or ingredient creation occurred.

Interpretation:

- This proves the correct `create_canonical` path after proposal persistence: agent proposal -> enrichment draft -> future Autopilot enrichment/validation.
- The next microstep is to run a bounded enrichment worker for this pending draft, still without enabling ingredient creation.
