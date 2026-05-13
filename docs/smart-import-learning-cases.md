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
- The runner also reports draft usability signals: title presence, step count, parsed steps, confidence, servings, and prep/cook times. These fields tell us whether Smart Import is producing a creator-ready recipe draft, not just a correct ingredient list.

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

## Boundaries

- The suite reads from dev through `get_catalog_agent_learning_context(...)`.
- `run_learning_context.py` does not call `parse-recipe-caption` directly.
- `run_edge_contract.py` calls `parse-recipe-caption` with exact candidates and expects `meta.usedServerLLM=false`.
- `run_llm_probe.py` can call OpenAI through dev `parse-recipe-caption`; run it intentionally and with small limits.
- It does not create canonical ingredients, aliases, proposals, or recipe data.
- It catches missing or stale memory context, not final recipe-draft quality.

If a case fails, the likely issue is either missing learning memory, an RPC permission/regression problem, or a change in the lesson wording that should be reflected in the fixture.
