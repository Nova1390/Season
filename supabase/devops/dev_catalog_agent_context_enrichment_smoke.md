# DEV-ONLY Catalog Agent Context Enrichment Smoke Test

Use this only against `Season-dev` (`gyuedxycbnqljryenapx`).

Do not run against staging while TestFlight is in review.

## Link Dev

```bash
supabase link --project-ref gyuedxycbnqljryenapx
```

## Read Context-Enriched Snapshot

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.get_catalog_agent_triage_snapshot(3, null, true);"
```

Expected:

- `metadata.source = catalog_agent_triage_snapshot_v2_context_enriched`;
- each work item includes `context.semantic_disambiguation`;
- work items with `latest_recipe_id` can include `context.recipe_context`;
- no catalog mutation.

## Inspect A Specific Term

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.get_catalog_agent_triage_snapshot(10, null, true)->'work_items' as work_items;"
```

For terms like `lievito`, check whether the packet distinguishes:

- ingredient existence;
- canonical target ambiguity;
- candidate targets;
- recipe clues.

Observed on 2026-05-11:

- snapshot source is `catalog_agent_triage_snapshot_v2_context_enriched`;
- `lievito` includes semantic disambiguation guidance;
- current catalog has `lievito_in_polvere_per_dolci` as candidate;
- `recipe_context` is empty because the observation does not carry `latest_recipe_id`;
- this is sufficient to avoid treating the term as noise, but not sufficient for blind alias approval.
