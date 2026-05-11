# Catalog Admin Console Plan

Status: first static console deployed to dev-backed catalog subdomain.

Season should not put catalog governance tools inside the consumer mobile app. The catalog agent needs an operator surface, but that surface belongs in a separate web console that can serve iOS, Android, and backend operations equally.

## Decision

Use a separate web console folder:

- `admin-console/`

Selected host:

- `catalog.seasonapp.it`

Current hosting path:

- `/home/u280052083/domains/seasonapp.it/public_html/catalog`

Current backend target:

- `Season-dev`

## Why Not In-App

Mobile admin tooling would be awkward for review-heavy work:

- proposal rationale and evidence are dense;
- JSON validation errors and learning memory need room;
- review/apply actions require deliberate notes;
- Android is likely coming soon, and admin UX should not be duplicated across clients;
- the consumer app should not expose internal operational controls.

## Security Model

The console must be browser-safe:

- use only Supabase anon key in frontend config;
- never store service-role keys in the repo or browser;
- require Supabase Auth login;
- require a successful `is_current_user_catalog_admin()` check before rendering the admin workspace;
- rely on `assert_catalog_admin(...)` and RLS/RPC authorization;
- keep console RPC `EXECUTE` grants off `anon`; only `authenticated`, `service_role`, and owner roles should retain access;
- call governed RPCs only;
- avoid direct table writes from the frontend.

## Initial Feature Set

The first static console supports:

- login/logout;
- review inbox loading through `get_catalog_agent_review_inbox(...)`;
- proposal detail view;
- queue for validation through `review_catalog_agent_proposal(...)`;
- request more evidence through `review_catalog_agent_proposal(...)`;
- reject with reviewer note through `review_catalog_agent_proposal(...)`;
- deterministic validation through `validate_catalog_agent_proposal(...)`;
- manual governed apply through `apply_catalog_agent_proposal(...)`;
- learning context through `get_catalog_agent_learning_context(...)`.
- operations visibility for agent worker jobs, AI usage, auto-apply audit records, and guarded rollback.
- safe worker invocation through `run-catalog-agent-orchestrator`.

## Rollout

Phase 1:

- deployed to `https://catalog.seasonapp.it/`;
- points at `Season-dev`;
- validate RPC permissions and UX with a catalog admin account.

Phase 2:

- keep environment config separate from source code;
- add HTTP basic protection or hosting-level access control if available.

Phase 3:

- add staging config only after TestFlight release is stable;
- add operational run history and agent invocation controls;
- add richer learning-memory review.

Implemented dev follow-up:

- the Operations section shows agent-delegated worker jobs and auto-apply audit records;
- active `applied` audit rows can be rolled back from the console only with an explicit operator reason;
- rollback still goes through `rollback_catalog_agent_apply(...)`, which checks catalog-admin access and verifies the current row still matches the audited after-state before mutating anything.
- the Operations section can start bounded worker runs for `low_risk_apply_batch` dry-run and small `enrichment_draft_batch` jobs;
- real apply is intentionally not exposed as a console action.
- low-risk dry-run zero-result states are explained through `get_catalog_agent_auto_apply_diagnostics()`, so operators can distinguish clean backlog from blocked proposals.
- Operations should prioritize visual summaries and hide raw JSON behind details panels unless an operator needs debugging data.

## Folder Ownership

The console is intentionally separate from:

- `Season/` iOS app code;
- `supabase/` backend schema/functions;
- `docs/` planning and operating documentation;
- public website assets.

This keeps admin workflows portable and prevents mobile product code from accumulating backoffice responsibilities.
