# run-catalog-ingredient-creation-batch

Creates canonical catalog ingredients from enrichment drafts that are already `ready`.

This worker is an executor, not a reasoning agent:

- it does not call the LLM;
- it does not choose canonical identity;
- it does not create from `create_canonical` proposals directly;
- it only calls `create_catalog_ingredient_from_enrichment_draft(...)`.
- the governed RPC preserves every localization present in the draft, for example both `canonical_name_it` and `canonical_name_en` when available.

## Agent-Orchestrated Mode

When invoked by `run-catalog-agent-orchestrator`, the payload includes:

```json
{
  "limit": 1,
  "source_domain": null,
  "agent_run_id": 123,
  "agent_worker_job_id": 456,
  "debug": false
}
```

The worker then:

- marks the parent `catalog_agent_worker_jobs` row as `running`;
- fetches ready enrichment drafts;
- applies only drafts that pass local preflight checks;
- marks the worker job `completed` or `failed` with a structured summary.

## Safety Gates

- Requires catalog admin or service role.
- Requires `CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=true`.
- Caps each run through `CATALOG_AGENT_INGREDIENT_CREATION_MAX_ITEMS`; default max is `3`.
- Requires draft status `ready`.
- Requires non-unknown ingredient type, canonical Italian name, slug, default unit, supported units, and minimum confidence.
- For produce, `is_seasonal` must be explicitly considered.

## Source Filtering

If `source_domain` is provided, ready drafts are limited to observations whose `custom_ingredient_observations.source` matches that value.

## Response Shape

```json
{
  "summary": {
    "mode": "create_ingredient",
    "total": 1,
    "created": 1,
    "skipped_existing": 0,
    "skipped_invalid": 0,
    "failed": 0,
    "duration_ms": 1200
  },
  "items": [],
  "agent_run_id": 123,
  "agent_worker_job_id": 456
}
```

## Operating Rule

Enable the worker only during controlled dev/staging test windows, then disable it again unless the environment has an explicit release policy for autonomous catalog creation.
