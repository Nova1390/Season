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
- Current autonomy level: `7.5 dev matcher/learning foundation`, not staging-ready autonomy
- Agent persistence and scheduler windows: disabled by default after smoke runs
- TestFlight handoff: `docs/testflight-bugfix-handoff-2026-05-12.md`
- Current branch audit: `docs/catalog-agent-closeout-audit-2026-05-15.md`

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
- Level `6.0` dev scheduler foundation is implemented with a disabled-by-default kill switch, scheduled-shift ledger, readable console shift history, mandatory expiry windows, and two successful autonomous dry-run cron windows (`#10/#11`).
- Level `7.0` quality-gate foundation is implemented: duplicate proposal blocking, source-grounded generic aggregate guards, recipe-process byproduct guards, and bounded self-repair for blocked LLM output.
- Level `7.1` foundation started: `catalog_matcher_v1` now gives the LLM and quality gate deterministic target/gap/ambiguity hints, and quality-gate errors now produce learning-writer suggestions.
- Level `7.5` matcher contract is implemented locally: `catalog_matcher_v1` now returns ranked targets, recommended action, blocked actions, matcher confidence, and explanation; lexical expansion includes governed overrides for surface forms such as `uovo`, `pane raffermo`, and `fiocchi d avena`.
- Smart Import Agent `8.0` creator-facing contract is implemented locally: caption categories, quantity coverage, unresolved-count metrics, deterministic servings recovery, and stronger server dedupe are returned as internal metrics while keeping the app API backward compatible.
- Smart Import E2E reports now expose catalog-training evidence: unresolved terms, repeated terms, duplicate rate, and quantity coverage can be reviewed before becoming golden cases or training signals.
- Learning memory now supports the richer taxonomy `alias_policy`, `variant_policy`, `catalog_gap`, `state_vs_identity`, `ambiguous_term`, `worker_failure`, and `prompt_improvement` while preserving legacy rows.
- Worker lifecycle learning is implemented: failed worker jobs and worker completions with failed items now record manager-level learning candidates.
- Dev transactional smoke checks verified worker-learning behavior with rollback and no persistent test data.
- Dev self-repair smoke run `#99` confirmed `spezie` now escalates to `needs_human_review` instead of creating an unsafe broad canonical draft.
- Dev dry-run `#100` verified the deployed matcher/learning-writer foundation with `limit=1`: `catalog_matcher_v1` reported `needs_target_matching` for `pepe`, `learning_writer` was visible and disabled, `0` proposals were persisted, and the agent was disabled again immediately after the smoke.
- Latest evaluation JSON reports are kept intentionally as compact audit evidence, not as runtime configuration.
- Local generated Python cache folders were removed during closeout cleanup; no tracked `__pycache__` artifacts remain.
- 2026-05-15 branch audit verified Supabase dev schema cleanliness: no pending migrations and no `supabase db lint` schema errors.
- 2026-05-15 branch audit restored useful Deno type-check signal across the main Catalog Agent, Smart Import, enrichment, automation, import, and worker Edge Functions.
- 2026-05-15 branch audit deployed the updated Catalog Agent worker/orchestrator/enrichment Edge Functions to `Season-dev`.
- Documentation now marks `1.0.1 (4)` as release-line history and keeps `agent/catalog-governance` explicitly dev-only until promotion.
- 2026-05-15 Catalog Agent `7.5` / Smart Import Agent `8.0` checkpoint pushed two dev-only migrations, deployed `run-catalog-agent-triage` and `parse-recipe-caption`, and kept staging untouched.
- 2026-05-15 remote dev quality checks passed after the matcher update: `context_target 13/13`, `current golden 13/13`, and Supabase `db lint` reported no schema errors.
- 2026-05-15 Smart Import exact-caption probe passed for `Risotto ai funghi per 2`: duplicate candidate rows collapsed and measured quantities survived without using server LLM.
- 2026-05-15 admin console static files were redeployed to `https://catalog.seasonapp.it/`; `index`, `app.js`, and `styles.css` all returned HTTP `200`.
- 2026-05-15 review inbox hygiene superseded stale duplicate open proposals without mutating catalog truth. Open `needs_human_review` count dropped from `19` to `10`, open duplicate proposal groups dropped to `0`, and `acqua di cottura` was recorded as implemented `state_vs_identity` learning.
- 2026-05-15 admin console gained a default `Latest per term` view so historical duplicates stay available in the database but do not crowd the operator list.
- 2026-05-15 external evidence grounding was extended with Italian source slots (`crea_alimenti_nutrizione`, `ieo_bda`, `masaf_pat`, `regional_pat`) so the agent can reason from Italian-first food references without importing catalog truth.
- 2026-05-15 a guarded external-evidence importer was added for reviewed CSV/JSON files. It supports dry-run, validates source/license/type/status fields locally, and writes only advisory rows through `upsert_catalog_agent_external_evidence(...)`.
- 2026-05-15 the first reviewed Italian external-evidence batch was drafted for `stracchino`, `fiocchi d avena`, `pecorino romano`, `pomodorini`, and `olive`; all rows remain `needs_review` advisory evidence.
- 2026-05-15 the first reviewed Italian external-evidence batch was imported into `Season-dev`: 6 advisory rows, 0 failures, IDs `1`-`6`. Context RPC smoke confirmed external evidence coverage for `stracchino`, `fiocchi d avena`, and `olive`.
- 2026-05-15 dry-run Catalog Agent smoke `#109` confirmed the imported Italian evidence reaches the LLM packet: 3 terms with external evidence, 3 proposals returned, 0 persisted, 0 quality-gate blocks. `olive` stayed high-risk review, `fiocchi d avena` became create-canonical, and `acqua di cottura` stayed ignore-noise. Report: `docs/catalog-agent-external-evidence-smoke-2026-05-15.md`.

## Current Closeout Audit

Audit file:

- `docs/catalog-agent-closeout-audit-2026-05-15.md`

Closeout decision:

- the branch is safe to keep developing in dev;
- it is not yet ready for staging autonomy;
- the next intelligence work should validate the new 7.5 matcher/8.0 Smart Import contracts on dev, then evaluate worker-learning outcomes, not add more manual review volume.

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

Historical autonomy assessment at this checkpoint:

- Maturity at the time was `3.5 dev-gated`.
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

### 2026-05-15 Closeout Verification Snapshot

Status: passed for branch hygiene, Edge Function type-check gates, Python script compile checks, and Supabase dev schema cleanliness.

Checks run:

- Deno checks passed for the main Catalog Agent, Smart Import, enrichment, automation, import, and worker Edge Functions.
- Python compile checks passed for Smart Import learning/e2e scripts and Catalog Agent golden-case scripts.
- `supabase db push --linked --dry-run`: remote dev database is up to date.
- `supabase db lint --linked`: no schema errors found.
- Staging was not touched.

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

### Agent-Orchestrated Enrichment Worker Smoke

The agent orchestrator ran one bounded enrichment worker job for the pending `pasta corta` draft.

Temporary runtime settings:

- `CATALOG_AGENT_ORCHESTRATOR_ENABLED=true`.
- `CATALOG_AGENT_OPERATOR_TOKEN` was set for the smoke and removed afterwards.
- `CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN=1`.
- `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=false`.

Run result:

- Agent run: `49`.
- Worker job: `16`.
- Worker: `enrichment_draft_batch`.
- Worker function: `run-catalog-enrichment-draft-batch`.
- Limit: `1`.
- Total processed: `1`.
- Succeeded: `1`.
- Failed: `0`.
- Skipped: `0`.
- Ready: `1`.
- Pending: `0`.
- Processed item: `pasta corta`.
- Detail: `proposal_auto_promoted_ready`.

Draft after enrichment:

- Normalized text: `pasta corta`.
- Status: `ready`.
- Suggested slug: `pasta_corta`.
- Italian name: `pasta corta`.
- English name: `short pasta`.
- Ingredient type: `basic`.
- Parent candidate slug: `pasta`.
- Variant kind: `shape`.
- Specificity rank suggestion: `1`.
- Default unit: `g`.
- Supported units: `g`, `kg`, `pack`.
- Confidence: `0.93`.
- Needs manual review: `false`.
- Validated ready: `true`.
- Validation errors: `[]`.

Safety verification:

- No `ingredients` row exists for `short_pasta` or `pasta_corta`.
- Worker job `16` is completed and linked to agent run `49`.
- Orchestrator was disabled again after the smoke.
- Ingredient creation remains disabled.

Interpretation:

- This proves the manager-worker handoff: persisted agent proposal -> draft preparation -> orchestrated Autopilot enrichment -> ready draft.
- This still does not create catalog identity. The next microstep would be an explicit reviewed ingredient-creation test with `limit=1` and creation flag enabled only for the smoke.

### Agent-Orchestrated Ingredient Creation Smoke

The agent orchestrator ran the first bounded ingredient-creation worker job for the reviewed `pasta corta` ready draft.

Temporary runtime settings:

- `CATALOG_AGENT_ORCHESTRATOR_ENABLED=true`.
- `CATALOG_AGENT_OPERATOR_TOKEN` was set for the smoke and removed afterwards.
- `CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN=1`.
- `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=true`.
- `CATALOG_AGENT_INGREDIENT_CREATION_MAX_ITEMS=1`.

Preflight verification:

- Target environment: `Season-dev` (`gyuedxycbnqljryenapx`).
- Draft `pasta corta` was `ready`.
- Suggested slug was `pasta_corta`.
- Parent candidate `pasta` existed as an active base ingredient.
- No existing ingredient row existed for `pasta_corta` or `short_pasta`.

Run result:

- Agent run: `50`.
- Worker job: `17`.
- Worker: `ingredient_creation_batch`.
- Worker function: `run-catalog-ingredient-creation-batch`.
- Limit: `1`.
- Total processed: `1`.
- Created: `1`.
- Failed: `0`.
- Skipped existing: `0`.
- Skipped invalid: `0`.
- Created ingredient: `pasta_corta`.
- Created ingredient id: `4349c672-fff0-426e-abda-7e15e4db5293`.

Ingredient verification:

- Slug: `pasta_corta`.
- Type: `basic`.
- Quality status: `active`.
- Parent ingredient: `pasta` (`56952b5b-f411-4b5f-b6ef-8c4df9534651`).
- Variant kind: `shape`.
- Specificity rank: `1`.
- Default unit: `g`.
- Supported units: `g`, `kg`, `pack`.

Draft verification:

- Draft `pasta corta` is now `applied`.
- Confidence remains `0.93`.
- Validated ready remains `true`.
- Validation errors remain `[]`.

Ledger note:

- The first worker invocation succeeded and the agent run summary was completed, but the worker-job row initially remained `queued`.
- Root cause: `run-catalog-ingredient-creation-batch` deployed on dev was older than the local worker bridge and did not update `agent_worker_job_id`.
- Fix applied: deployed the current `run-catalog-ingredient-creation-batch` function to dev.
- Ledger reconciliation: job `17` was completed through the official `complete_catalog_agent_worker_job(...)` RPC with the actual creation summary and `reconciled_after_deploy_gap=true`.

Safety verification:

- Orchestrator was disabled again after the smoke.
- Ingredient creation was disabled again after the smoke.
- The temporary operator token was removed.
- A post-run orchestrator request returned `ORCHESTRATOR_DISABLED`.
- No staging changes were made.

Interpretation:

- This proves the complete governed creation chain on dev: agent proposal -> enrichment draft -> validation -> orchestrated creation -> applied draft -> active catalog child ingredient.
- This is a Level 5-adjacent capability, but it should not be scheduled autonomously yet. The next microstep is to add a repeatable ledger regression smoke so deployed worker drift cannot silently reduce audit quality again.

### Worker Ledger Regression Smoke

A repeatable worker-ledger regression smoke was added and executed on dev.

Artifact:

- Script: `scripts/catalog_agent_worker_ledger_smoke.sh`.
- Runbook: `supabase/devops/dev_catalog_agent_worker_ledger_smoke.md`.

Default behavior:

- Worker: `low_risk_apply_batch`.
- Action: `dry_run`.
- Limit: `1`.
- Mutation scope: none.
- Verification scope: `catalog_agent_runs`, `catalog_agent_worker_jobs`, run summary, worker summary, bidirectional run/job linkage.

Execution notes:

- First script attempt invoked the worker successfully as `run_id=51`, `worker_job_id=18`, but the verification SQL used `jsonb_object_length(...)`, which is not available in the deployed Postgres environment.
- The script was fixed to use `coalesce(summary, '{}'::jsonb) <> '{}'::jsonb`.
- Second attempt passed as `run_id=52`, `worker_job_id=19`.

Successful smoke verification:

- Agent run `52` status: `completed`.
- Worker job `19` status: `completed`.
- Worker job had `started_at` and `finished_at`.
- Worker summary was present.
- Run summary linked to worker job `19`.
- Worker job linked back to run `52`.
- `ledger_ok=true`.

Safety verification:

- The worker was dry-run only.
- No low-risk apply happened.
- Orchestrator was disabled again after the smoke.
- The temporary operator token was removed by script cleanup.
- A post-run orchestrator request returned `ORCHESTRATOR_DISABLED`.

Interpretation:

- This closes the specific audit gap found during the ingredient-creation smoke.
- Before expanding autonomy, this smoke should be run after any worker deploy or orchestration change.

### Mixed-Term Proposal Persistence Batch

A small mixed-term persistence batch was executed to advance the Level 4.5 quantitative gate.

Temporary runtime settings:

- `CATALOG_AGENT_ENABLED=true`.
- `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=true`.
- `CATALOG_AGENT_OPERATOR_TOKEN` was set for the smoke and removed afterwards.
- `CATALOG_AGENT_MAX_ITEMS_PER_RUN=12`.
- `CATALOG_AGENT_MAX_RUNS_PER_DAY=3`.
- `CATALOG_AGENT_RECENT_PROPOSAL_DAYS=7`.

Preflight:

- Proposal-only runs today before execution: `0`.
- Snapshot size: `12`.
- Many top-priority terms had recent proposals and were expected to be skipped by the recent-proposal guardrail.

Run result:

- Agent run: `53`.
- Dry run: `false`.
- Items in snapshot: `12`.
- Items eligible before retry: `3`.
- Items sent to LLM: `3`.
- Skipped because of recent proposals: `9`.
- Proposals returned: `3`.
- Proposals persistable: `3`.
- Proposals blocked by quality gate: `0`.
- Proposals created: `3`.
- Model: `gpt-5.4-mini`.
- Prompt version: `catalog-agent-triage-v4-multi-pass`.
- Total tokens: `15,779`.

Persisted proposals:

- `#26` `pasta senza glutine`: `create_canonical`, `medium`, `draft`, proposed slug `gluten_free_pasta`.
- `#27` `pecorino romano`: `needs_human_review`, `medium`, target slug `pecorino_romano_dop`.
- `#28` `piadina`: `needs_human_review`, `high`, target slug `stuffed_piadina`.

Quality interpretation:

- The agent preserved a meaningful dietary variant for `pasta senza glutine` instead of collapsing it into generic pasta.
- The agent escalated `pecorino romano` because protected-designation cheese identity and existing related aliases make the target decision policy-sensitive.
- The agent escalated `piadina` because filled vs plain piadina are not safely interchangeable.
- No low-risk or auto-apply-eligible proposal was created in this batch.
- No critical-risk proposal was created.

Cumulative proposal state after the batch:

- Total agent proposals: `25`.
- Low risk: `5`.
- Medium risk: `14`.
- High risk: `5`.
- Critical risk: `0`.
- Auto-apply eligible: `4`.

Safety verification:

- `CATALOG_AGENT_ENABLED=false` was restored after the batch.
- `CATALOG_AGENT_PROPOSAL_PERSISTENCE_ENABLED=false` was restored after the batch.
- The temporary operator token was removed.
- A post-run request returned `AGENT_DISABLED`.
- No catalog apply or recipe mutation occurred.
- No staging changes were made.

Interpretation:

- The persistence-volume side of the Level 4.5 gate is now satisfied in dev.
- Level 4.5 should still not be promoted until the low-risk/auto-apply-eligible proposal sample is audited for unsafe classifications and the result is documented.

### Low-Risk And Auto-Apply Safety Audit

The low-risk and auto-apply-eligible proposal sample was audited to close the remaining Level 4.5 safety gate.

Sample:

- Proposal `#5` `sale fino`: `approve_alias`, `low`, `auto_apply_eligible=true`, status `auto_applied`.
- Proposal `#14` `uovo`: `needs_human_review`, `low`, `auto_apply_eligible=false`, status `superseded`.
- Proposal `#21` `mais`: `add_localization`, `low`, `auto_apply_eligible=true`, status `superseded`.
- Proposal `#22` `mele`: `add_localization`, `low`, `auto_apply_eligible=true`, status `superseded`.
- Proposal `#23` `pomodori`: `approve_alias`, `low`, `auto_apply_eligible=true`, status `applied`.

Findings:

- `sale fino` is safe: it exactly maps to active canonical `sale_fino`; alias `sale fino` is active and approved with `approval_source='agent_auto_apply'`.
- `sale fino` has apply audit `#3` with rollback plan `delete_inserted_alias` for alias `168`.
- `uovo` is safe as a low-risk review outcome: the agent correctly recognized standard egg semantics but did not invent a target id when no candidate target was present.
- `mais` is semantically safe as Italian localization for `corn`, but it was superseded and did not mutate catalog state.
- `mele` is semantically safe as Italian plural/localization for `apple`, but it was superseded and did not mutate catalog state.
- `pomodori` is safe: it maps to active canonical `tomato`, passed deterministic validation, and was applied manually through a governed alias RPC.
- No sampled low-risk proposal points to a deprecated or missing canonical ingredient.
- No sampled low-risk proposal produced a critical-risk or high-risk mutation.

Quality debt:

- Historical proposals `#21` and `#22` were marked `auto_apply_eligible=true` while storing only `target_slug` and not `target_ingredient_id`.
- They were superseded and never applied, so this is not an unsafe mutation.
- Future auto-apply eligibility should continue to require a concrete target id, not only a target slug. The current proposal quality gate already enforces stronger actionable target grounding than those historical proposals.

Safety conclusion:

- Low-risk sample unsafe classifications found: `0`.
- Unsafe low-risk mutations found: `0`.
- Auto-apply with rollback audit found: `sale fino`.
- Governed manual apply after validation found: `pomodori`.

Level 4.5 conclusion:

- Level 4.5 governed proposal autonomy is complete on `Season-dev`.
- The agent can persist useful governed proposals, escalate ambiguity, avoid duplicate LLM spend through recent-proposal guardrails, and leave mutation to validators/workers/humans.
- The next roadmap target is Level 5.0 low-risk apply autonomy, starting with rollback regression tests and low-risk apply batch limits.

### Level 5.0 Rollback Regression Smoke

The first Level 5.0 microstep tested whether a low-risk catalog mutation can be applied and then reverted without leaving catalog residue.

Scope:

- Environment: `Season-dev`.
- Staging: untouched.
- Run: `catalog_agent_runs.id = 55`.
- Proposal: `catalog_agent_proposals.id = 30`.
- Apply audit: `catalog_agent_apply_audit.id = 4`.
- Proposal type: `approve_alias`.
- Alias text: `season rollback smoke sale fino 20260513`.
- Target canonical ingredient: `sale_fino`.

Result:

- `apply_catalog_agent_low_risk_proposal(...)` returned `ok=true`.
- The apply path inserted alias id `178`.
- The apply path wrote rollback plan `delete_inserted_alias`.
- The apply path emitted `auto_apply_succeeded`.
- `rollback_catalog_agent_apply(...)` returned `ok=true`.
- The rollback path deleted alias id `178`.
- The rollback path emitted `auto_apply_rollback_succeeded`.
- Final alias rows for `season rollback smoke sale fino 20260513`: `0`.
- Final proposal status: `validated`.
- Final audit status: `reverted`.
- The same check is now repeatable through `scripts/catalog_agent_rollback_smoke.sh`.
- Scripted smoke passed with run `#58`, proposal `#33`, apply audit `#7`, rollback plan `delete_inserted_alias` for alias id `181`, and `rollback_smoke_ok=true`.
- The script now retires its own smoke proposal to `superseded` after verification.
- Post-cleanup verification confirmed proposals `#30`, `#31`, `#32`, and `#33` are `superseded`.
- Post-cleanup verification found `0` remaining `validated + low + auto_apply_eligible` proposals.

Interpretation:

- The core apply/rollback contract works for an intentionally reversible low-risk alias.
- The proposal is still visible as historical evidence, but the catalog row was removed.
- Smoke proposals are not left in the real apply queue.
- This satisfies the first Level 5.0 rollback gate, not the full Level 5.0 autonomy gate.
- The next Level 5.0 microstep is controlled `limit=1` low-risk apply behavior with real eligible proposals and audit verification.

### Level 5.0 Proposal Generation Run 60

Run `#60` was executed on `Season-dev` with proposal persistence enabled and real apply disabled.

Result:

- Snapshot items: `12`.
- Items skipped because of recent proposals: `10`.
- Items sent to the LLM: `2`.
- Proposals created: `2`.
- Proposal `#34`: `pepe`, `needs_human_review`, medium risk.
- Proposal `#35`: `olive`, `needs_human_review`, high risk.
- Token usage: `13,771` total tokens.
- Dev flags were disabled and the temporary operator token was removed immediately after the run.
- No catalog mutation occurred.
- No staging changes were made.

Interpretation:

- The agent behaved safely: it did not force ambiguous terms into low-risk apply.
- The run exposed an orchestration inefficiency: recent-proposal dedupe happened after the snapshot limit, so most of the requested batch was skipped before the LLM call.
- `run-catalog-agent-triage` now oversamples the snapshot before dedupe and still caps the final LLM batch to the requested limit.
- This should increase the chance of finding real low-risk proposals without increasing the maximum items sent to the model.

### Level 5.0 Oversampling Regression Run 61

Run `#61` was executed after deploying candidate oversampling.

Result:

- The function reached the provider with a larger eligible set.
- Provider usage: `28,183` total tokens.
- The run failed before proposal persistence.
- Validation error: `proposals[4].auto_apply_eligible is only supported for approve_alias/add_localization`.
- No proposals were inserted.
- Dev flags were disabled and the temporary operator token was removed immediately after the failed run.
- No catalog mutation occurred.
- No staging changes were made.

Interpretation:

- The oversampling change exposed a second safety improvement: provider output can contain an over-eager `auto_apply_eligible=true` flag on a proposal type that is not apply-supported.
- This is not a semantic catalog decision and should not discard an otherwise useful batch.
- `run-catalog-agent-triage` now repairs that field to `false` before contract validation and records `provider_output_repaired`.

### Level 5.0 Proposal Generation Run 62

Run `#62` was executed after the repair-layer fix.

Result:

- Snapshot items: `19`.
- Eligible before final limit: `7`.
- Items sent to the LLM: `7`.
- Proposals returned: `7`.
- Proposals persisted: `6`.
- Quality-gate blocks: `1`.
- Token usage: `28,169` total tokens.
- Proposal `#36`: `pinoli`, `create_canonical`, medium risk.
- Proposal `#37`: `pollo`, `needs_human_review`, medium risk.
- Proposal `#38`: `riso basmati`, `create_canonical`, medium risk.
- Proposal `#39`: `robiola`, `create_canonical`, medium risk.
- Blocked proposal: `spezie`, `ignore_noise`, low risk, blocked because confidence was below `0.8`.
- Proposal `#40`: `stracchino`, `needs_human_review`, medium risk.
- Proposal `#41`: `tacchino`, `needs_human_review`, medium risk.
- Dev flags were disabled and the temporary operator token was removed immediately after the run.
- No catalog mutation occurred.
- No staging changes were made.

Interpretation:

- Oversampling works: the LLM batch grew from `2` useful items in run `#60` to `7` useful items in run `#62`.
- The current queue is dominated by missing canonical ingredients and genuinely ambiguous protein/cheese terms, not low-risk alias/localization work.
- The quality gate correctly blocked low-confidence noise.
- `CATALOG_AGENT_RECENT_PROPOSAL_DAYS=0` is now allowed for controlled dev/eval reruns after context/runtime changes, avoiding term-specific fake learning just to bypass dedupe.

### Level 5.0 Parent Candidate Cleanup And First New Auto-Apply

The `cipolle` review outcome showed a broader target-grounding issue: the work packet included active `onion`, active duplicate/localized `cipolla`, and color-specific onion variants. The agent correctly escalated because the candidate set looked noisier than the source text required.

Migration:

- `20260513103000_govern_generic_plural_parent_candidates.sql`.
- `cipolla` now redirects to active canonical `onion`.
- `cipolla` quality status changed to `deprecated_duplicate`.
- Implemented learning added for `cipolle`.
- Existing `cipolle` review proposals were superseded.

Policy learned:

- For unqualified plural or singular base produce terms, prefer `approve_alias` to the active parent canonical when the recipe has no color/cultivar/product-form modifier.
- Meaningful variants remain distinct; they should not block a parent mapping for unqualified source text.

Run `#64`:

- Snapshot items: `16`.
- Eligible before final limit: `1`.
- Items sent to the LLM: `1`.
- Proposal created: `#50`.
- Proposal: `cipolle` -> `onion`.
- Proposal type: `approve_alias`.
- Risk: `low`.
- Confidence: `0.96`.
- Auto-apply eligible: `true`.
- Token usage: `10,380` total tokens.

Validation:

- `review_catalog_agent_proposal(50, 'queue_for_validation', ...)`.
- `validate_catalog_agent_proposal(50)` returned `ok=true`.
- Final validation status before apply: `validated`.
- Validation errors: `[]`.

Worker dry-run:

- Orchestrator run: `#65`.
- Worker job: `#20`.
- Worker: `low_risk_apply_batch`.
- Result: `1` eligible previewed, `0` applied, `0` failed.

Worker real apply:

- Orchestrator run: `#66`.
- Worker job: `#21`.
- Worker: `low_risk_apply_batch`.
- Real apply was temporarily enabled with `CATALOG_AGENT_LOW_RISK_APPLY_ENABLED=true`.
- Result: `1` applied, `0` failed.
- Proposal `#50` status: `auto_applied`.
- Alias created: `ingredient_aliases_v2.id = 182`.
- Alias: `cipolle`.
- Target: `onion`.
- Approval source: `agent_auto_apply`.
- Apply audit: `catalog_agent_apply_audit.id = 8`.
- Audit status: `applied`.
- Rollback plan: `delete_inserted_alias` for alias id `182`.

Safety:

- The worker applied only one validated low-risk alias.
- The mutation is reversible.
- Feature flags were disabled and the temporary operator token was removed immediately after verification.
- No staging changes were made.

### Level 7.5 Review Inbox Refresh Guardrail

The first post-cleanup dry-run (`run_id=103`) confirmed that the improved matcher no
longer sends every remaining term to generic human review:

- `pepe`: `approve_alias`, low risk, persistable.
- `olive`: `needs_human_review`, high risk, persistable because the variant boundary remains ambiguous.
- `fiocchi d avena`: `create_canonical`, medium risk, persistable after self-repair.
- Quality gate blocked: `0`.
- Catalog mutations: `0`.
- Staging changes: `0`.

Runtime follow-up:

- `run-catalog-agent-triage` now supersedes older open proposals for the same
  `normalized_text` before inserting a newer persistable proposal.
- This prevents the admin inbox from accumulating stale duplicate cards while preserving all old rows and events for audit.
- The behavior is controlled by `CATALOG_AGENT_SUPERSEDE_OPEN_PROPOSALS`, default `true`.

Verification run `#104`:

- Mode: proposal persistence only, no apply worker.
- Items sent to LLM: `3`.
- Proposals created: `3`.
- Open proposals superseded: `3`.
- Created `#51`: `pepe`, `approve_alias`, low risk, draft.
- Created `#52`: `olive`, `needs_human_review`, high risk.
- Created `#53`: `fiocchi d avena`, `create_canonical`, medium risk, draft.
- Superseded stale proposals: `#42`, `#43`, `#44`.
- Open queue after refresh: `1` approve-alias draft, `8` create-canonical drafts, `9` needs-human-review proposals.
- Dev flags were disabled and the temporary operator token was removed immediately after verification.

Validation and worker dry-run:

- `review_catalog_agent_proposal(51, 'queue_for_validation', ...)` moved `pepe` to `queued_for_validation`.
- `validate_catalog_agent_proposal(51)` returned `ok=true`.
- Proposal `#51` final validation state: `validated`.
- Validation errors: `[]`.
- Orchestrator run: `#105`.
- Worker job: `#33`.
- Worker: `low_risk_apply_batch`.
- Mode: dry-run only.
- Eligible preview: `#51 pepe -> black_pepper`, `approve_alias`, confidence `0.97`.
- Applied: `0`.
- Failed: `0`.
- Orchestrator and temporary operator token were disabled/removed after verification.
- Temporary local key/output files were removed from `/tmp`.

Low-risk real apply:

- Orchestrator run: `#106`.
- Worker job: `#34`.
- Worker: `low_risk_apply_batch`.
- Mode: real apply with `limit=1`.
- Applied: `1`.
- Failed: `0`.
- Proposal `#51` status: `auto_applied`.
- Mutation type: `approve_alias`.
- Alias created: `ingredient_aliases_v2.id = 183`.
- Alias: `pepe`.
- Target: `black_pepper`.
- Alias status: `approved`, `is_active=true`.
- Apply audit: `catalog_agent_apply_audit.id = 9`.
- Rollback plan: `delete_inserted_alias` for alias id `183`.
- Real-apply and orchestrator flags were disabled immediately after verification.
- Temporary operator token and local `/tmp` key/output files were removed.
- No staging changes were made.

### Level 7.5 Noise Decision Micro-Batch

Run `#107`:

- Mode: dry-run.
- Recent proposal dedupe: `7` days.
- Items in snapshot: `12`.
- Items skipped as recent: `11`.
- Items sent to LLM: `1`.
- Proposal returned: `acqua di cottura`, `ignore_noise`, low risk.
- Quality gate blocked: `0`.
- Catalog mutations: `0`.

Run `#108`:

- Mode: proposal persistence only.
- Proposal created: `#54`.
- Proposal: `acqua di cottura`, `ignore_noise`, low risk.
- Output repair disabled auto-apply because `ignore_noise` is not an apply mutation.
- Quality gate blocked: `0`.

Validation:

- `review_catalog_agent_proposal(54, 'queue_for_validation', ...)` moved the proposal to validation.
- `validate_catalog_agent_proposal(54)` returned `ok=true`.
- Proposal `#54` status: `validated`.
- Validation errors: `[]`.
- Open queue after validation: `8` create-canonical drafts, `9` needs-human-review proposals, `1` validated ignore-noise proposal.
- Dev flags were disabled and the temporary operator token was removed after the run.
- Temporary local key/output files were removed from `/tmp`.
- No staging changes were made.

### External Catalog Evidence Foundation

Implementation status: deployed to `Season-dev`.

- Added `public.catalog_agent_external_evidence` as a non-mutating evidence store.
- Added `upsert_catalog_agent_external_evidence(...)` for catalog-admin/service-role evidence ingestion.
- Added `get_catalog_agent_external_evidence_context(...)` for compact agent packets.
- Added explicit grants, RLS, catalog-admin select policy, and service-role sequence access.
- Updated `run-catalog-agent-triage` to attach `context.external_catalog_evidence` and `external_evidence_policy`.
- Updated the LLM contract so external evidence can support reasoning but cannot bypass matcher, learning memory, validators, or apply gates.
- Added docs in `docs/catalog-agent-external-evidence.md`.
- Initial source policy: USDA FoodData Central, Wikidata, FoodOn, then Open Food Facts only with license-aware handling.
- No external data has been imported by this migration.
- No catalog mutations are introduced by this layer.
- `deno check supabase/functions/run-catalog-agent-triage/index.ts` passed.
- `supabase db push --linked --dry-run` showed only `20260515110000_catalog_agent_external_evidence.sql`.
- Migration `20260515110000_catalog_agent_external_evidence.sql` was applied to `Season-dev`.
- `run-catalog-agent-triage` was deployed to `Season-dev`.
- `supabase db lint --linked` returned `No schema errors found`.
- Read-only RPC smoke for `pepe` and `fiocchi d avena` returned `catalog_agent_external_evidence_context_v1` with `0` evidence rows, as expected before ingestion.
- No staging changes were made.
