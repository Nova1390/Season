# TestFlight Bugfix Handoff - 2026-05-12

Status: historical handoff after the TestFlight bugfix build was published.

This file is release-line context, not the current state of the `agent/catalog-governance` branch.

This document captures the current project state so bugfix work can proceed without losing the catalog-agent context.

## Release Context

- A new Season build has been published to TestFlight.
- At the time of this handoff, the TestFlight build was the active tester-facing version.
- That TestFlight build came from the previous `supabase-integration` branch, not from `agent/catalog-governance`.
- Bugfixes were prioritized against the TestFlight build behavior first.
- Keep staging/release-sensitive backend changes separate from dev catalog-agent experiments unless explicitly approved.

## Current Branch Context

- Catalog-agent working branch: `agent/catalog-governance`.
- TestFlight bugfix base branch: `supabase-integration`.
- Bugfix work for that TestFlight build should branch from `supabase-integration`, not from `agent/catalog-governance`.
- The catalog-agent GitHub branch is pushed and should remain separate unless explicitly merged later.
- Worktree was clean after the latest catalog-agent smoke test.
- Recent catalog-agent commits:
  - `b6850dc Document catalog agent LLM reasoning loop`
  - `47a8a05 Add catalog agent semantic profiles`

## Catalog Agent State

The agent architecture was upgraded in documentation and in the dev triage function.

Implemented:

- documented bounded multi-pass LLM reasoning loop;
- documented agent as governance manager and Autopilot as bounded worker;
- added `semantic_profile` to `run-catalog-agent-triage` LLM output contract;
- added semantic profile validator fields for:
  - product family;
  - semantic category;
  - variant dimension;
  - parent candidate;
  - identity-bearing variant flag;
  - substitutability with parent;
  - nutrition, seasonality, allergy, fridge, shopping, and filter implications;
  - evidence and open questions;
- persisted the semantic profile inside proposal `evidence` without a DB schema change;
- bumped prompt version to `catalog-agent-triage-v3-semantic-profile`;
- deployed `run-catalog-agent-triage` to `Season-dev` only.

Smoke test:

- Dev project: `gyuedxycbnqljryenapx`.
- Run id: `23`.
- Mode: `dry_run=true`.
- Items sent to LLM: `6`.
- Proposals returned: `6`.
- Proposals created: `0`.
- Prompt version: `catalog-agent-triage-v3-semantic-profile`.
- Model: `gpt-5.4-mini`.
- `pomodorini` returned as `needs_human_review` with high risk, which is expected because it should not be collapsed into base tomato.

Restored after smoke:

- `CATALOG_AGENT_ENABLED=false`.
- `CATALOG_AGENT_MAX_RUNS_PER_DAY=3`.
- `CATALOG_AGENT_RECENT_PROPOSAL_DAYS=7`.

Note:

- The dev `CATALOG_AGENT_OPERATOR_TOKEN` was rotated during the smoke test.
- If manual agent invocation is needed again, set a fresh dev operator token intentionally.

## Admin Console State

- Console URL: `https://catalog.seasonapp.it/`.
- Console backend: `Season-dev`.
- Console is separate from the iOS app and public website files.
- It currently supports:
  - catalog-agent proposal review;
  - learning memory inspection;
  - operations dashboard;
  - dry-run low-risk worker invocation;
  - visual summaries and help bubbles.

Next console improvement:

- Render `semantic_profile` in a readable card instead of leaving it only inside raw JSON/evidence.

## Backend Safety State

- Staging was not touched by the latest catalog-agent semantic-profile work.
- Real low-risk apply remains disabled by default.
- Console low-risk apply remains dry-run only.
- Supabase dev agent was temporarily enabled only for smoke testing and then disabled.

Important security reminder:

- The Supabase PAT shared during setup should be revoked/rotated before treating the cycle as closed.
- Avoid using staging for catalog-agent experiments while TestFlight feedback is active unless explicitly approved.

## Immediate Bugfix Mode

When new TestFlight bugs arrive:

1. Start from `supabase-integration` or a bugfix branch created from it.
2. Reproduce against the same environment/build if possible.
3. Identify whether the bug is iOS UI, app config, Supabase data, Auth/OAuth, recipe/catalog behavior, or admin-console only.
4. Avoid broad catalog migrations unless the bug is clearly backend-data related.
5. Prefer small commits per bugfix.
6. Re-run the relevant simulator/build or backend smoke test before pushing.
7. Document any backend env/secret changes in this handoff or a linked runbook.

Recommended branch command:

```bash
git checkout supabase-integration
git pull
git checkout -b codex/testflight-bugfixes
```

## Suggested Next Technical Steps

Only after urgent TestFlight bugs are under control:

- Step 2 of agent plan: persist semantic reasoning trace in a first-class read model.
- Update admin console to show semantic profile visually.
- Add regression fixtures for:
  - `pomodori` vs `pomodorini`;
  - `patate` vs `patate dolci`;
  - `lievito` vs specific leavening variants;
  - localization-only examples.
- Add a cost governor before introducing true multi-pass LLM loops.

## Do Not Forget

- Keep TestFlight bugfixes and catalog-agent autonomy work conceptually separate.
- Do not fix TestFlight bugs on `agent/catalog-governance` unless the user explicitly decides to merge that work into the release line.
- Do not touch staging unless the user explicitly asks.
- Do not enable real auto-apply while testers are starting to use the app.
- Rotate/revoke the Supabase PAT after this workstream is stable.
