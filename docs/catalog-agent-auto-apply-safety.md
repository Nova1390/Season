# Catalog Agent Auto-Apply Safety

Status: dev foundation implemented, worker wired through the orchestrator, real apply disabled by default.

This document defines how Season can safely let the Catalog Governance Agent apply a narrow class of catalog changes without human review.

## Operating Principle

The agent may act only when the backend has already proven that the action is low-risk, reversible, and limited to an existing canonical catalog item.

The agent must not treat an LLM recommendation as catalog truth. The LLM can propose; deterministic validators and guarded SQL functions decide whether anything is mutable.

## Service-Role Semantics

The existing manual apply path stays admin-first:

- a human catalog admin signs in;
- the admin applies a validated proposal;
- governed admin RPCs perform the mutation.

The auto-apply path is separate:

- service role may call `apply_catalog_agent_low_risk_proposal(...)`;
- authenticated catalog admins may call it for controlled testing;
- anonymous users cannot call it;
- normal app users cannot call it;
- service role bypass is allowed only inside the function after strict proposal checks.

Required proposal state:

- `status = 'validated'`;
- `risk_level = 'low'`;
- `auto_apply_eligible = true`;
- `validation_errors = []`;
- `proposal_type in ('approve_alias', 'add_localization')`;
- target ingredient exists and is active.

Blocked proposal types:

- `create_canonical`;
- `merge_duplicate`;
- `redirect_duplicate`;
- `reconcile_recipe_ingredients`;
- `needs_human_review`;
- anything medium/high/critical/unknown risk.

## Supported Mutations

### Approve Alias

Allowed only when:

- the target ingredient already exists;
- no active alias points to another ingredient;
- the proposal was already validated;
- the action can be reversed by deleting a new alias or restoring a previous alias row.

Side effects:

- inserts or updates one `ingredient_aliases_v2` row;
- marks matching `custom_ingredient_observations` as `resolved_alias`;
- records one `catalog_candidate_decisions` row;
- marks proposal as `auto_applied`;
- writes one `catalog_agent_apply_audit` row;
- writes one proposal event.

### Add Localization

Allowed only when:

- the target ingredient already exists;
- the target does not already have a different localization for the same language;
- the proposal was already validated;
- the action can be reversed by deleting the inserted localization.

If the same localization already exists, the proposal can be marked `auto_applied`, but rollback is a no-op.

## Audit

Every successful auto-apply writes to `catalog_agent_apply_audit`.

The audit row stores:

- proposal id and run id;
- optional worker job id;
- mutation type and mutation scope;
- actor role and user id, when available;
- target ingredient;
- before state;
- after state;
- rollback plan;
- apply note;
- current audit status.

The audit table is admin-readable and service-role writable.

## Rollback

Rollback is handled by `rollback_catalog_agent_apply(...)`.

Rollback is allowed only when:

- the audit row is still `applied`;
- a revert reason is provided;
- the current catalog row still matches the audited after-state.

This guard prevents the rollback function from overwriting later legitimate changes.

Rollback behavior:

- inserted alias: delete the alias row;
- updated alias: restore the previous alias row;
- inserted localization: delete the localization row;
- existing same localization: no catalog mutation;
- proposal returns to `validated`;
- audit status becomes `reverted`;
- proposal event records the rollback.

Rollback failures:

- if the audited after-state no longer matches the current catalog row, rollback is blocked;
- the audit row is marked `revert_failed`;
- the failure event records the SQL error and rollback action;
- the RPC returns a structured failure payload so the admin console can surface the problem without losing audit history.

## Worker Policy

The `low_risk_apply_batch` worker is implemented by `catalog-low-risk-apply-batch`.

It can:

- preview eligible proposals with `dry_run=true`;
- apply eligible proposals with `dry_run=false` only when `CATALOG_AGENT_LOW_RISK_APPLY_ENABLED=true`;
- attach the result to `catalog_agent_worker_jobs`;
- call `apply_catalog_agent_low_risk_proposal_batch(...)`;
- report applied and failed counts.

The orchestrator can delegate to it with:

- `worker_name = 'low_risk_apply_batch'`;
- `risk_ceiling = 'low'`;
- `action = 'dry_run'` for preview;
- `action = 'apply_low_risk'` for real apply.

The admin console exposes only the dry-run path. Real apply remains a backend/operator-controlled path gated by `CATALOG_AGENT_LOW_RISK_APPLY_ENABLED`.

The console explains dry-run zero-result states through `get_catalog_agent_auto_apply_diagnostics()`. This RPC uses the same readiness criteria as the low-risk apply batch: validated status, low risk, auto-apply eligibility, supported proposal type, empty validation errors, and no active apply audit.

The worker should:

- create a `catalog_agent_worker_jobs` row;
- stop at a small item limit;
- report applied and failed counts;
- avoid retry storms after validation or rollback failures.

Real apply should stay disabled until dev has enough successful dry operational history.

## Release Policy

Development:

- functions can be tested with temporary transaction-based smoke tests;
- auto-apply primitives can exist;
- no schedule should run by default.

Staging:

- do not enable autonomous apply until dev audit history is clean;
- require Supabase lint success;
- verify console visibility for audit rows;
- verify rollback on a representative alias and localization.

Production:

- enable only after staging has real tester data and rollback confidence;
- keep daily limits very low at first;
- alert on any rollback or failed apply.

## Dev Dry-Run History

2026-05-11:

- created a real validated low-risk `approve_alias` proposal for `sale fino` -> `sale_fino`;
- ran `low_risk_apply_batch` through the orchestrator in dry-run mode;
- result: `1` eligible proposal previewed, `0` applied, `0` failed;
- worker job: `catalog_agent_worker_jobs.id = 4`;
- real apply remained disabled.

## Dev Controlled Apply History

2026-05-11:

- enabled `CATALOG_AGENT_ORCHESTRATOR_ENABLED` and `CATALOG_AGENT_LOW_RISK_APPLY_ENABLED` temporarily;
- ran `low_risk_apply_batch` through the orchestrator with `limit=1`;
- applied proposal `catalog_agent_proposals.id = 5`;
- created alias `sale fino` for `sale_fino`;
- marked observation `sale fino` as `resolved_alias`;
- wrote audit row `catalog_agent_apply_audit.id = 3`;
- rollback plan: `delete_inserted_alias` for alias id `168`;
- worker job: `catalog_agent_worker_jobs.id = 5`;
- result: `1` applied, `0` failed;
- disabled both feature flags and removed the temporary operator token after verification.

## Dev Rollback Console Follow-Up

2026-05-11:

- added console rollback controls for active auto-apply audit rows;
- rollback requires a human operator note;
- the console calls only `rollback_catalog_agent_apply(...)`;
- updated rollback failure semantics so failed rollback attempts remain visible in audit history.

## Dev Rollback Regression Smoke

2026-05-13:

- created run `#55` for a Level 5.0 rollback smoke on `Season-dev`;
- created validated low-risk proposal `#30`;
- proposal type: `approve_alias`;
- target: `sale_fino`;
- alias text: `season rollback smoke sale fino 20260513`;
- applied the proposal through `apply_catalog_agent_low_risk_proposal(...)`;
- apply audit row: `#4`;
- rollback plan: `delete_inserted_alias` for alias id `178`;
- rolled the mutation back through `rollback_catalog_agent_apply(...)`;
- final audit status: `reverted`;
- final proposal status: `validated`;
- final alias rows for the smoke alias: `0`;
- emitted both `auto_apply_succeeded` and `auto_apply_rollback_succeeded`;
- no staging data was touched.

This proves the reversible alias path can be applied and rolled back without leaving a catalog alias behind. It does not yet enable broad unattended auto-apply; it only closes the first Level 5.0 rollback safety gate.

Repeatable smoke:

- script: `scripts/catalog_agent_rollback_smoke.sh`;
- latest passing run: `catalog_agent_runs.id = 58`;
- latest passing proposal: `catalog_agent_proposals.id = 33`;
- latest passing apply audit: `catalog_agent_apply_audit.id = 7`;
- latest verification: `rollback_smoke_ok=true`.
- the script retires the smoke proposal to `superseded` after verification to keep real apply queues clean.
