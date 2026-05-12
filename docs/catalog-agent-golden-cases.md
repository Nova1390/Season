# Catalog Agent Golden Cases

Status: dev evaluation harness for `agent/catalog-governance`.

This document defines how we measure the Catalog Governance Agent without making extra LLM calls.

The goal is simple: separate three things that can otherwise get confused.

- The database may be correct because we manually governed a case.
- The agent may have proposed something useful but incomplete.
- The agent may be ready to act autonomously only after it repeatedly passes known cases.

## Files

- Fixture: `scripts/catalog_agent_golden_cases/golden_cases.json`
- Runner: `scripts/catalog_agent_golden_cases/run_golden_cases.py`

## Profiles

`current`

- Verifies the dev database and proposal state as it exists now.
- Useful after migrations/manual governance.
- Should pass before we trust the branch state.

`target`

- Describes what the autonomous agent should eventually propose by itself.
- Useful after controlled triage runs.
- Expected to fail in places while the agent is still learning.

## Current Golden Cases

The first set covers the behaviors that define the jump from "proposal bot" to "catalog manager junior":

- `uovo -> eggs`: base singular alias.
- `pane raffermo -> bread`: preparation state should not create a new canonical identity.
- `mais -> corn`: surface/common term should be an alias, not a localization overwrite.
- `mele -> apple`: plural/common form should be an alias, not a localization overwrite.
- `pomodori -> tomato`: base plural should resolve to existing tomato.
- `pomodorini`: meaningful small-tomato variant must not collapse into base tomato.
- `lenticchie rosse`: meaningful missing lentil variant should become a create-canonical draft when missing.
- `olive`: ambiguous generic family should remain review-only.
- `lievito per dolci`: likely specific leavening product, but policy needs explicit target before automation.
- `fiocchi d avena`: likely oat-flake catalog gap or specific alias, not vague review once context is sufficient.

## Run Locally

Schema-only check, no network:

```bash
python3 scripts/catalog_agent_golden_cases/run_golden_cases.py --schema-only
```

Read-only check against Supabase dev:

```bash
export SUPABASE_URL="https://gyuedxycbnqljryenapx.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="..."
python3 scripts/catalog_agent_golden_cases/run_golden_cases.py --profile current
```

Target-intelligence check after a controlled agent run:

```bash
python3 scripts/catalog_agent_golden_cases/run_golden_cases.py --profile target
```

JSON output for CI or future dashboard ingestion:

```bash
python3 scripts/catalog_agent_golden_cases/run_golden_cases.py --profile current --json
```

## Rules

- The runner is read-only.
- The runner does not call OpenAI or any LLM provider.
- Failing `current` means the dev catalog/proposal state regressed.
- Failing `target` means the agent is not yet autonomous for that behavior.
- Add new golden cases whenever a human correction teaches a reusable catalog rule.

## Autonomy Gate

Before increasing autonomy, the agent should pass:

- 100% of `current`;
- at least 80% of `target` across low/medium risk cases;
- 0 dangerous failures where a meaningful variant is collapsed into a generic base;
- 0 localization/alias category mistakes for already-governed examples.

Only after that should low-risk apply be considered for scheduled dev runs.

## 2026-05-12 Baseline

Read-only Supabase dev run:

```text
current: 10/10 passed
target: 3/10 passed
```

Interpretation:

- `current` passing means the dev catalog/proposal state is coherent after reviewed governance.
- `target` at `3/10` means the agent is not ready for broad autonomy yet.
- The failures are useful and expected because they expose decisions that were fixed by manual governance or post-run learning, not by the agent itself.

Current target passes:

- `lenticchie rosse`: correct `create_canonical` draft behavior.
- `olive`: correct conservative human-review behavior.
- `lievito per dolci`: acceptable conservative behavior until target policy is explicit.

Main target gaps:

- `uovo`, `pane raffermo`, `mais`, and `mele` were fixed by governance, but the historical agent proposals were wrong.
- `pomodori` still needs to become an actionable alias proposal for `tomato`.
- `pomodorini` needs a fresh post-canonical rerun so the agent can target the new child canonical instead of the old missing-catalog proposal.
- `fiocchi d avena` needs better catalog-gap or alias confidence instead of vague review.
