# Dev Catalog Agent Worker Ledger Smoke

Use this only against `Season-dev` (`gyuedxycbnqljryenapx`).

Purpose:

- prove the deployed orchestrator can create an agent run;
- prove the delegated worker can start and complete its `catalog_agent_worker_jobs` row;
- prove run and worker summaries are linked;
- keep the test non-mutating by default.

Default worker:

- `low_risk_apply_batch`;
- `action=dry_run`;
- `limit=1`;
- no catalog mutation.

Required environment:

```bash
export SUPABASE_ACCESS_TOKEN='<supabase personal access token>'
export SUPABASE_ANON_KEY='<dev anon key>'
```

Run:

```bash
scripts/catalog_agent_worker_ledger_smoke.sh
```

Expected result:

```text
Worker ledger regression passed for run <id>, worker job <id>.
```

The script temporarily enables:

- `CATALOG_AGENT_ORCHESTRATOR_ENABLED=true`;
- `CATALOG_AGENT_OPERATOR_TOKEN`;
- `CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN=1`.

The script cleanup restores:

- `CATALOG_AGENT_ORCHESTRATOR_ENABLED=false`;
- `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=false`;
- `CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN=5`;
- removes `CATALOG_AGENT_OPERATOR_TOKEN`.

Failure handling:

- If the orchestrator call succeeds but verification fails, inspect the returned `run_id` and `worker_job_id`.
- A worker job must not remain `queued` or `running` after a successful worker response.
- If the failure is caused by deployed worker drift, deploy the current worker function, then rerun this smoke.
- Do not promote an autonomy level while this smoke fails.
