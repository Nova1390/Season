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

## Boundaries

- The suite reads from dev through `get_catalog_agent_learning_context(...)`.
- `run_learning_context.py` does not call `parse-recipe-caption` directly.
- `run_edge_contract.py` calls `parse-recipe-caption` with exact candidates and expects `meta.usedServerLLM=false`.
- It does not call OpenAI or any other LLM.
- It does not create canonical ingredients, aliases, proposals, or recipe data.
- It catches missing or stale memory context, not final recipe-draft quality.

If a case fails, the likely issue is either missing learning memory, an RPC permission/regression problem, or a change in the lesson wording that should be reflected in the fixture.
