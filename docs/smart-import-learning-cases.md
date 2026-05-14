# Smart Import Learning Cases

This document describes the no-LLM validation suite that protects the bridge between Smart Import and Catalog Agent learning memory.

## Purpose

Smart Import should learn from catalog-governance mistakes without becoming a catalog writer.

The learning cases verify that `parse-recipe-caption` can retrieve the same relevant lessons that the Catalog Agent has already stored for ingredient terms such as `pomodorini`, `pane raffermo`, `uovo`, and `fiocchi d avena`.

These checks do not call an LLM and do not mutate Supabase. They only confirm that the advisory memory needed by the Smart Import prompt is available before reasoning begins.

## Current Cases

| Case | Term | Expected learning |
|---|---|---|
| `SIL-001` | `pomodorini` | Small tomato wording must not collapse into generic tomato when a child variant is required or available. |
| `SIL-002` | `pane raffermo` | Staleness is recipe context; the ingredient identity remains bread. |
| `SIL-003` | `uovo` | Bare singular Italian `uovo` should prefer canonical eggs when that target is available. |
| `SIL-004` | `fiocchi d avena` | Product-form terms can be real catalog identities when the parent would be too generic. |

## How To Run

Schema-only check:

```bash
python3 scripts/smart_import_learning_cases/run_learning_context.py --schema-only
```

Dev learning-context check:

```bash
python3 scripts/smart_import_learning_cases/run_learning_context.py
```

If the Supabase CLI session is not visible to Python subprocesses, run the same command with `SUPABASE_ACCESS_TOKEN` set in your shell.

JSON output for automation:

```bash
python3 scripts/smart_import_learning_cases/run_learning_context.py --json
```

Edge Function contract check:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_ANON_KEY="..." \
USER_JWT="..." \
python3 scripts/smart_import_learning_cases/run_edge_contract.py
```

Or sign in with a disposable dev test account:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_ANON_KEY="..." \
SUPABASE_TEST_EMAIL="..." \
SUPABASE_TEST_PASSWORD="..." \
python3 scripts/smart_import_learning_cases/run_edge_contract.py
```

Or let the runner create and delete a temporary dev user:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_ANON_KEY="..." \
SUPABASE_SERVICE_ROLE_KEY="..." \
python3 scripts/smart_import_learning_cases/run_edge_contract.py --use-temp-user
```

The Edge Function contract check sends exact local-catalog candidates, so it should not call OpenAI. It verifies that `smartImportAgent.passes` includes `learning_memory_context` when the selected terms have learning memory.

Operational note: the first live run of this smoke exposed a quota edge case where a newly created user could hit cooldown before consuming any request. Migration `20260513205500_fix_recipe_import_quota_first_request.sql` updates `consume_recipe_import_quota(...)` so cooldown applies only when `count > 0`.

## Budgeted LLM Probe

Use `run_llm_probe.py` only when we intentionally want to spend a small amount of provider budget against dev.

Preview selected cases without network or LLM:

```bash
python3 scripts/smart_import_learning_cases/run_llm_probe.py --dry-run --limit 3 --json
```

Preview specific cases:

```bash
python3 scripts/smart_import_learning_cases/run_llm_probe.py \
  --dry-run \
  --case-id SI-TRAIN-017 \
  --case-id SI-TRAIN-020 \
  --case-id SI-TRAIN-050 \
  --json
```

Run a small full-caption probe:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_ANON_KEY="..." \
SUPABASE_SERVICE_ROLE_KEY="..." \
python3 scripts/smart_import_learning_cases/run_llm_probe.py --use-temp-user --limit 3
```

Run a scorecard expectation probe for an assembly-style caption that must ask for method steps instead of inventing them:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_ANON_KEY="..." \
SUPABASE_SERVICE_ROLE_KEY="..." \
python3 scripts/smart_import_learning_cases/run_llm_probe.py \
  --use-temp-user \
  --case-id SI-TRAIN-040 \
  --expect-blocking steps_missing \
  --expect-nice-to-fix quantities_missing
```

Run a targeted ingredient-resolution probe with Swift-like unresolved candidates:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_ANON_KEY="..." \
SUPABASE_SERVICE_ROLE_KEY="..." \
python3 scripts/smart_import_learning_cases/run_llm_probe.py --use-temp-user --with-candidates --limit 3
```

Budget guardrails:

- Default limit is 3 cases.
- Hard limit is 10 cases per run.
- The runner sleeps between requests to avoid quota cooldown.
- Use `--dry-run` before any live run.
- Prefer existing CSV fixtures before calling Apify.
- Provider or Edge errors are captured per case in the JSON output so a transient `502` does not hide the rest of the probe results.
- The runner reports both ingredient-name matches and measurable quantity/unit matches, so we can distinguish "recognized the ingredient" from "creator can publish without fixing doses".
- The runner also reports draft usability signals: title presence, step count, parsed steps, confidence, servings, prep/cook times, the agent `nextAction`, and the structured `scorecard`. These fields tell us whether Smart Import is producing a creator-ready recipe draft, not just a correct ingredient list.
- The runner can assert required scorecard entries with `--expect-blocking`, `--expect-nice-to-fix`, and `--expect-auto-fixable`; use those assertions for small targeted probes, not large exploratory runs.

## Real Caption Training Corpus

Use Apify caption exports as an operational training corpus, not as direct catalog truth.

Massive offline screening:

```bash
python3 scripts/smart_import_learning_cases/build_real_caption_training_set.py
```

This generates:

- `docs/smart-import-caption-training-corpus.md`
- `docs/smart-import-caption-training-corpus.json`

The corpus is non-mutating. It does not call OpenAI, does not write to Supabase, and does not store full social captions. It classifies recipe-like captions and extracts ingredient-like terms into advisory buckets:

- `catalog_alias_candidate`
- `meaningful_variant_candidate`
- `condition_or_state_check`
- `product_form_candidate`
- `compound_identity_candidate`
- `egg_family_candidate`

Import reviewed corpus terms as Catalog Agent training signals:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_SERVICE_ROLE_KEY="..." \
python3 scripts/smart_import_learning_cases/import_training_signals.py \
  --limit 40 \
  --min-count 8
```

Preview before writing:

```bash
python3 scripts/smart_import_learning_cases/import_training_signals.py \
  --dry-run \
  --limit 40 \
  --min-count 8 \
  --json
```

This writes only to `public.catalog_agent_training_signals`. It does not insert custom ingredient observations, create aliases, create canonical ingredients, or write implemented learning.

Parallel Catalog Agent dry-run eval:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_ANON_KEY="..." \
CATALOG_AGENT_OPERATOR_TOKEN="..." \
python3 scripts/smart_import_learning_cases/run_catalog_agent_parallel_eval.py \
  --source smart_import_training_captions \
  --source import \
  --source import_recovery \
  --limit 2 \
  --concurrency 3 \
  --report docs/catalog-agent-parallel-eval-latest.json
```

The script always calls `run-catalog-agent-triage` with `dry_run=true`. It is for measuring and training the agent, not for applying proposals or mutating catalog data.

Bounded real-caption E2E:

```bash
SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co" \
SUPABASE_ANON_KEY="..." \
SUPABASE_SERVICE_ROLE_KEY="..." \
python3 scripts/smart_import_learning_cases/run_real_caption_e2e.py \
  --use-temp-user \
  --limit 20 \
  --strategy stratified \
  --json-report docs/smart-import-real-caption-e2e-stratified.json
```

The stratified strategy samples across complete recipes, ingredient-rich captions, method-rich captions, messy recipe-like captions, and weak recipe signals. This is better than repeatedly testing only perfect recipes.

Training boundary:

- Smart Import E2E results may create regression fixtures, prompt changes, scorecard rules, or reviewed learning candidates.
- They must not directly create canonical ingredients, aliases, or implemented learning.
- Catalog Agent must govern any catalog mutation or durable learning promotion.
- `catalog_agent_training_signals` are advisory corpus signals. They become durable behavior only after review and promotion into explicit policy, prompt, validator, evaluation, or `catalog_agent_learnings` changes.

Latest dev probe notes:

- `2026-05-13`: targeted `--with-candidates` probe on `SI-TRAIN-017`, `SI-TRAIN-020`, and `SI-TRAIN-050` matched `19/19` expected ingredient names. The first pass used name-only candidates, so it correctly showed `quantities_missing` as probe noise.
- `2026-05-13`: runner was updated to include fixture quantity fragments in Swift-like candidates.
- `2026-05-13`: repeat probe on `SI-TRAIN-017` matched `7/7`, preserved `pane raffermo` as base `pane`, included `learning_memory_context`, used LLM, and no longer emitted `quantities_missing`.
- `2026-05-13`: one live run returned transient `502 PROVIDER_REQUEST_FAILED`; the runner now records per-case errors instead of aborting the whole probe.
- `2026-05-13`: quantity-aware repeat probe on `SI-TRAIN-017` matched `7/7` ingredient names and `3/3` measurable quantity/unit expectations (`pane 200g`, `pomodori 3`, `cetriolo 1`).
- `2026-05-13`: hard/messy full-caption probe on `SI-TRAIN-027`, `SI-TRAIN-029`, `SI-TRAIN-034`, `SI-TRAIN-038`, and `SI-TRAIN-040` matched `28/29` ingredient names. The only miss was `piadina`, because the edible base appeared in the opening phrase rather than the filling list.
- `2026-05-13`: the probe parser now recognizes fractional quantities such as `1/2 bustina` as `0.5 piece`, and the full-caption prompt now tells the model to keep edible base/container ingredients from titles or opening phrases.
- `2026-05-13`: repeat probe on `SI-TRAIN-040` after the prompt update matched `6/6` ingredient names and included `piadina` as the edible base.
- `2026-05-13`: the LLM probe now records title and step quality fields, so future runs can catch drafts that recognize ingredients but still need human work before publishing.
- `2026-05-13`: title/step probe on `SI-TRAIN-027`, `SI-TRAIN-029`, and `SI-TRAIN-040` matched `18/18` ingredient names. The model extracted usable titles, preserved explicit method sentences as one-step drafts for frittata/puttanesca, and correctly left the piadina draft with `steps_missing` instead of inventing a method from a caption that only listed fillings.
- `2026-05-13`: Smart Import Agent now returns `nextAction` and `actionReason` so the creator UI can show the highest-priority next step, for example "add method steps" before secondary quantity cleanup.
- `2026-05-13`: dev probe on `SI-TRAIN-040` after deploy returned `draftQuality=needs_more_input` and `nextAction=add_method_steps`, confirming the agent asks for a real method step instead of inventing one for an assembly-style caption.
- `2026-05-13`: Smart Import Agent now returns a `scorecard` that separates blocking issues, nice-to-fix improvements, and deterministic autofix opportunities for future autonomous loops.
- `2026-05-13`: dev probe on `SI-TRAIN-040` after scorecard deploy returned `blockingIssues=["steps_missing"]`, `niceToFix=["quantities_missing","servings_missing","timings_missing"]`, and `autoFixable=[]`, confirming the agent can prioritize creator action without losing secondary cleanup tasks.
- `2026-05-14`: Smart Import Agent now returns an `autoFixPlan` with deterministic `safeFixes` and guarded `deferredFixes`; the probe runner can assert scorecard expectations for targeted live checks.
- `2026-05-14`: dev probe on `SI-TRAIN-040` passed `--expect-blocking steps_missing` and `--expect-nice-to-fix quantities_missing`; `autoFixPlan.safeFixes=[]` and deferred fixes ask for method steps, amounts, servings, and timings instead of guessing them.
- `2026-05-14`: Smart Import now has a safe autofix worker. It records `appliedAutoFixes` and can fill a missing title from deterministic fallback context only: explicit caption title, `inferredDish`, or URL host. It still refuses to invent steps, quantities, servings, timings, or catalog identity.
- `2026-05-14`: dev probe on `SI-TRAIN-040` after safe autofix deploy preserved `appliedAutoFixes=[]`, `blockingIssues=["steps_missing"]`, and `nextAction=add_method_steps`, confirming the worker does not mask real creator-input blockers.
- `2026-05-14`: imported the first 40 high-frequency real-caption corpus terms into dev `catalog_agent_training_signals` as advisory signals only. The smoke query confirmed runtime context for `uovo` and `fiocchi d'avena`; `pomodorini` was absent because it was not part of this bounded first import batch.
- `2026-05-14`: deployed `run-catalog-agent-triage` on dev with training-signal context attached to work items and passed into the LLM packet as `training_signal_policy`.
- `2026-05-14`: dry-run `catalog_agent_runs.id=76` confirmed the agent reads training signals (`terms_with_training_signals=1`) without persisting proposals. It also exposed a policy gap: a `catalog_alias_candidate` without target evidence must not become `create_canonical`. The contract now routes that shape toward matching/review evidence instead.
- `2026-05-14`: training-signal lookup now includes lexical candidate terms and punctuation-tolerant matching so corpus terms like `fiocchi d'avena` can inform work items normalized as `fiocchi d avena`.
- `2026-05-14`: repeat dry-run `catalog_agent_runs.id=77` confirmed the fix. Training-signal coverage increased to `terms_with_training_signals=2`, the runtime source changed to `catalog_agent_training_signal_context_v2_broadened_lookup`, and `pepe` changed from unsafe `create_canonical` to `needs_human_review` because no safe canonical target was present.
- `2026-05-14`: the runtime quality gate now enforces the same lesson deterministically and is deployed on dev. Future LLM regressions that propose `create_canonical` for `catalog_alias_candidate` terms without a safe target will be blocked before persistence.
- `2026-05-14`: parallel dry-run eval batch completed with dev still non-mutating. `run_id=78` (`import_recovery`) had no eligible items; `run_id=79` (`import`) reviewed 2 items and produced 2 persistable human-review proposals; `run_id=80` (`smart_import_training_captions`) reviewed 2 items, blocked the attempted `pepe -> create_canonical` regression through `alias_candidate_requires_target_before_canonical_creation`, and left `olive` as human review.
- `2026-05-14`: added `run_catalog_agent_parallel_eval.py` and executed a scripted parallel eval (`run_id=81,82,83`, report `docs/catalog-agent-parallel-eval-latest.json`). It sent 2 items to LLM, returned 2 proposals, persisted 0, and again blocked the `pepe -> create_canonical` regression through the training-signal quality gate.
- `2026-05-14`: the parallel eval runner now supports `--timeout-seconds`, because multi-pass agent runs can exceed the old 30s HTTP client timeout while still completing successfully in Supabase.
- `2026-05-14`: depth eval (`run_id=92,93`, report `docs/catalog-agent-parallel-eval-depth-latest.json`) reviewed 10 items, returned 10 proposals, persisted 0, and kept good behavior: `pepe`, `olive`, `acqua di cottura`, and `carne macinata` went to review while `fiocchi d avena` remained an allowed `create_canonical` draft.
- `2026-05-14`: targeted aggregate-term eval (`run_id=94`, report `docs/catalog-agent-parallel-eval-spezie-latest.json`) confirmed the next guardrail. The LLM still proposed `spezie -> create_canonical`, but the runtime blocked it with `generic_aggregate_requires_specific_identity` because generic group/category words need evidence of a concrete product, blend, mix, or identity-bearing aggregate before catalog creation.
- `2026-05-14`: larger dev dry-run (`run_id=95,96`, report `docs/catalog-agent-parallel-eval-large-latest.json`) reviewed 20 items with persistence disabled. It returned 20 proposals, persisted 0, and spent 98,026 total tokens. Stable behaviors: `pepe` and `olive` stayed in review, `fiocchi d avena`, `frutti di bosco`, and `lenticchie rosse` stayed as canonical drafts. Newly visible teaching targets: source-dependent disagreement on `acqua di cottura`, `lievito per dolci`, `pasta senza glutine`, and `pecorino romano`; the gate blocked `pasta senza glutine` when the model marked an actionable canonical draft as `critical` risk.
- `2026-05-14`: promoted the larger-batch teaching targets into agent policy. New rules clarify cooking/process liquids vs reusable ingredient identities, explicit baking-powder targets, gluten-free pasta as a real dietary/product variant, and protected-designation cheese routing. The runtime quality gate now blocks `create_canonical` for recipe-process byproducts through `recipe_process_byproduct_not_canonical`.
- `2026-05-14`: policy verification run `97` showed improvement on `acqua di cottura`, `pasta senza glutine`, and `pecorino romano`, but exposed a duplicate-output failure where the LLM returned two proposals for `olive`. The quality gate now blocks duplicate proposals for the same normalized work item with `duplicate_proposal_for_work_item`.

## Boundaries

- The suite reads from dev through `get_catalog_agent_learning_context(...)`.
- `run_learning_context.py` does not call `parse-recipe-caption` directly.
- `run_edge_contract.py` calls `parse-recipe-caption` with exact candidates and expects `meta.usedServerLLM=false`.
- `run_llm_probe.py` can call OpenAI through dev `parse-recipe-caption`; run it intentionally and with small limits.
- It does not create canonical ingredients, aliases, proposals, or recipe data.
- It catches missing or stale memory context, not final recipe-draft quality.

If a case fails, the likely issue is either missing learning memory, an RPC permission/regression problem, or a change in the lesson wording that should be reflected in the fixture.
