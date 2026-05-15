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
- Context-quality runner: `scripts/catalog_agent_golden_cases/run_context_quality.py`

## Profiles

`current`

- Verifies the dev database and proposal state as it exists now.
- Useful after migrations/manual governance.
- Should pass before we trust the branch state.

`target`

- Describes what the autonomous agent should eventually propose by itself.
- Useful after controlled triage runs.
- Expected to fail in places while the agent is still learning.

`effective_target`

- Verifies the operationally correct end state after governed review/apply paths.
- Useful when historical latest proposals are known-bad but the catalog has since been fixed.
- This is the practical autonomy gate for "is Season usable and safe now?" while `target` remains the stricter "would the next proposal be right by itself?" measure.

## Current Golden Cases

The first set covers the behaviors that define the jump from "proposal bot" to "catalog manager junior":

- `uovo -> eggs`: base singular alias.
- `pane raffermo -> bread`: preparation state should not create a new canonical identity.
- `mais -> corn`: surface/common term should be an alias, not a localization overwrite.
- `mele -> apple`: plural/common form should be an alias, not a localization overwrite.
- `pollo -> chicken`: bare creator-facing poultry term should resolve to Season's base chicken convention when no cut/state modifier is present.
- `tacchino -> turkey`: bare creator-facing turkey term should resolve to Season's base turkey convention when no sliced/ham/cured modifier is present.
- `pomodori -> tomato`: base plural should resolve to existing tomato.
- `pomodorini`: meaningful small-tomato variant must not collapse into base tomato.
- `lenticchie rosse`: meaningful missing lentil variant should become a create-canonical draft when missing.
- `olive`: creator-facing generic base should become a base `olives` catalog gap when no exact base exists; specific olive forms stay variants.
- `carne macinata`: species-unspecified ground meat should become a generic `ground_meat` base draft instead of guessing beef or staying in review forever.
- `stracchino`: clear named Italian fresh-cheese identity should become a canonical draft when missing, not collapse to generic cheese.
- `pepe`: ambiguous spice family should remain conservative unless source evidence selects black pepper or another specific target.
- `lievito per dolci`: likely specific leavening product, but policy needs explicit target before automation.
- `fiocchi d avena`: likely oat-flake catalog gap or specific alias, not vague review once context is sufficient.
- `riso basmati`: meaningful rice variant should target an existing child or create a child canonical, not collapse into generic rice.
- `patate dolci`: meaningful potato variant should target the sweet-potato child when present, not collapse into generic potatoes.

## 2026-05-15 Generic Olive Correction

The real-world creator pattern is that many captions say bare `olive` without
specifying green/black/taggiasche/brined form. That should not create a loop of
permanent human-review proposals.

Current governed policy:

- the generic-base rule is general, not olive-specific;
- simple concrete base ingredients used in fast creator captions, for example
  potatoes, tomatoes, mushrooms, apples, onions, or olives, should resolve to a
  base canonical when present or become a base `create_canonical` draft when
  missing;
- bare `olive` / `oliva` can surface a missing generic base `olives` identity;
- explicit forms such as `olive verdi`, `olive nere`, `taggiasche`, brined,
  pitted, or oil-preserved olives remain child/specific variants;
- broad umbrella categories such as vegetables, fruit, herbs, spices, cheeses,
  seafood, fish, or seasonings still require specificity;
- the proposal is only a `create_canonical` draft and is never auto-applied.

Verification:

- `context_target: 13/13 passed` after applying
  `20260515120000_catalog_agent_generic_olive_base_policy.sql`;
- dry-run `#112` confirmed matcher output
  `catalog_gap_candidate` + `create_canonical_if_identity_clear`;
- dry-run `#113` confirmed final proposal output
  `olive -> create_canonical`, `draft`, medium risk, quality-gate clean, with
  no persisted catalog mutation because the run was dry-run.

## 2026-05-15 Common Creator Generics Correction

The next `8.0` step expands the same principle to recurring real-caption terms
that were creating noisy `needs_human_review` rows.

Current governed policy:

- bare `pollo` and `tacchino` should use the catalog's base poultry convention
  when the caption does not specify cut, frozen state, sliced deli form, ham, or
  curing;
- explicit product-form terms such as sliced turkey breast or frozen chicken
  remain separate targets;
- bare `carne macinata` should create/use a generic `ground_meat` base when no
  species is provided, while `macinato di manzo`, pork mince, mixed mince, and
  sausage mince remain specific variants;
- `stracchino` is a clear Italian fresh-cheese identity and should become a
  canonical draft if absent, not a generic cheese alias;
- proposals already solved by active aliases/canonicals, or completed
  `ignore_noise` validations, should be superseded from the operational inbox
  while audit history remains intact.

This is still governance data, not hidden hardcoding: the behavior is encoded in
lexical overrides, structured learning rows, golden cases, and inbox cleanup.

Controlled runs after this correction:

- run `#114`, limit `5`, proposal persistence enabled temporarily:
  `olive -> create_canonical`, `carne macinata -> create_canonical`,
  `fiocchi d avena -> create_canonical`, `frutti di bosco -> create_canonical`,
  `acqua di cottura -> ignore_noise`; quality gate blocked `0`; superseded `4`
  older open proposals.
- run `#115`, targeted `normalized_texts=["pollo","tacchino","stracchino"]`:
  `pollo -> approve_alias(chicken)`, `tacchino -> approve_alias(turkey)`,
  `stracchino -> create_canonical`; quality gate blocked `0`; superseded `3`
  older review proposals.
- after the runs, open `needs_human_review` items dropped to `3`:
  `piadina`, `pecorino romano`, and `lievito per dolci`.

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

Operational target check after governed applies:

```bash
python3 scripts/catalog_agent_golden_cases/run_golden_cases.py --profile effective_target
```

JSON output for CI or future dashboard ingestion:

```bash
python3 scripts/catalog_agent_golden_cases/run_golden_cases.py --profile current --json
```

Pre-LLM context-quality check:

```bash
python3 scripts/catalog_agent_golden_cases/run_context_quality.py
```

## Rules

- The runner is read-only.
- The runner does not call OpenAI or any LLM provider.
- Failing `current` means the dev catalog/proposal state regressed.
- Failing `target` means the agent is not yet autonomous for that behavior.
- Failing `effective_target` means the currently governed catalog/proposal outcome is not safe enough for the next autonomy step.
- Failing `context_target` means the agent may be spending LLM tokens with missing or noisy candidates.
- Add new golden cases whenever a human correction teaches a reusable catalog rule.

## Autonomy Gate

Before increasing autonomy, the agent should pass:

- 100% of `current`;
- at least 80% of `target` across low/medium risk cases;
- 0 dangerous failures where a meaningful variant is collapsed into a generic base;
- 0 localization/alias category mistakes for already-governed examples.

Only after that should low-risk apply be considered for scheduled dev runs.

`effective_target` can pass before `target` passes. That is intentional: `effective_target` measures the current governed outcome, while `target` keeps pressure on the agent to stop producing the same historical mistakes.

## 2026-05-12 Baseline

Read-only Supabase dev run before the mini target run:

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
- `olive`: previous conservative behavior was too strict for real creator captions; bare `olive` should now surface a generic base identity/gap while specific forms remain variants.
- `lievito per dolci`: acceptable conservative behavior until target policy is explicit.

Main target gaps:

- `uovo`, `pane raffermo`, `mais`, and `mele` were fixed by governance, but the historical agent proposals were wrong.
- `pomodori` still needs to become an actionable alias proposal for `tomato`.
- `pomodorini` already showed good variant intelligence by proposing a dedicated canonical child; future runs should target the existing child canonical instead of recreating it.
- `fiocchi d avena` needs better catalog-gap or alias confidence instead of vague review.

Follow-up learning seeded:

- `pomodori`: base plural/localized tomato forms should become `approve_alias -> tomato` unless semantic evidence shows a meaningful variant.
- `pomodorini`: once the child canonical exists, future proposals should target `pomodorini`, not recreate it or collapse to `tomato`.
- `fiocchi d avena`: clear product-form identities such as oat flakes should become a catalog-gap `create_canonical` draft when no dedicated child target exists.
- These lessons are deliberately term-specific plus policy-shaped: they reopen the cases for the next controlled agent run without applying catalog mutations.
- The `target` score remained `3/10` until a new controlled triage run created fresh proposals; learning changes future eligibility and reasoning, not historical proposal rows.

## 2026-05-12 Mini Target Run

Run `42`:

- Source domain: `smart_import_training_captions`.
- Limit: `4`.
- Items in snapshot: `4`.
- Items sent to LLM: `2`.
- Recent proposals skipped: `2`.
- Proposals created: `2`.
- Token usage: `13,028` input, `1,845` output, `14,873` total.
- Provider duration: `18,273ms`.
- Triage was disabled immediately after the run.

Created proposals:

- `#23 pomodori`: `approve_alias -> tomato`, low risk, confidence `0.99`, auto-apply eligible.
- `#24 fiocchi d avena`: `create_canonical`, proposed slug `oat_flakes`, medium risk, confidence `0.93`.

Golden-case result after updating the fixture to recognize valid `create_canonical` proposals:

```text
current: 10/10 passed
target: 6/10 passed
```

Interpretation:

- The agent moved from `3/10` to `6/10` on target behavior after learning memory and a small rerun.
- Remaining target failures are historical proposals for already-governed terms: `uovo`, `pane raffermo`, `mais`, `mele`.
- Those cases are fixed in the catalog, but the target profile still records that the latest historical agent proposal was wrong because no fresh agent rerun exists for resolved observations.

## 2026-05-12 Governed Apply Gate

Dev-only controlled actions:

- Proposal `#23 pomodori` was queued for deterministic validation.
- The validator returned no errors and marked it `validated`.
- The governed apply RPC applied it as an approved active alias to `tomato`.
- Proposal `#24 fiocchi d avena` was not applied directly because it is `create_canonical` and medium risk.
- Proposal `#24` was routed into the canonical enrichment path by preparing a pending enrichment draft with suggested slug `oat_flakes`.

Golden-case result:

```text
current: 10/10 passed
target: 6/10 passed
effective_target: 10/10 passed
```

Interpretation:

- Season-dev now has the correct operational state for the initial golden set.
- The agent has demonstrated a low-risk proposal -> deterministic validator -> governed apply path.
- The agent has also demonstrated a catalog-gap proposal -> enrichment draft path without directly creating an ingredient.
- This raises the dev autonomy maturity to `3.5 dev-gated`: useful operational autonomy exists, but scheduled real apply and staging promotion remain disabled until more target-profile reruns are clean.

## 2026-05-12 Context Quality Gate

The next step added a no-LLM preflight for the agent work packet:

```text
context_target: 10/10 passed
```

What it checks:

- common surface forms expose the expected existing target before GPT runs;
- meaningful variants expose the most specific child target, not only the generic parent;
- ambiguous families expose multiple plausible candidates instead of pretending there is one safe target;
- true catalog gaps remain gaps instead of being forced into a bad alias.

Useful finding:

- Initial context quality was `9/10` because `pomodorini` received base `tomato` as an applyable candidate through the legacy alias `pomodorini ciliegino -> tomato`.
- Migration `20260512190000_retarget_small_tomato_variant_aliases.sql` retargeted that alias to the child canonical `pomodorini` and recorded implemented learning.
- After the migration, `pomodorini` context exposes `pomodorini` without leaking `tomato` as a forbidden applyable target.

Interpretation:

- This moves the agent closer to `4.0 supervised autonomy` because it can now prove whether the input context is good before paying for LLM reasoning.
- If future target runs fail while `context_target` passes, the problem is likely prompt/reasoning.
- If `context_target` fails, fix snapshot/catalog context first and do not spend more model budget.
