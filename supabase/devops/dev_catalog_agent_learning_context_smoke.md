# Dev Catalog Agent Learning Context Smoke

Status: dev-only runbook.

Environment:

- Supabase project: `Season-dev`
- Project ref: `gyuedxycbnqljryenapx`
- Do not run this against staging while TestFlight release validation is in progress.

## 1. Link Dev

```bash
SUPABASE_ACCESS_TOKEN='<token>' supabase link --project-ref gyuedxycbnqljryenapx
```

## 2. Apply Migration

```bash
SUPABASE_ACCESS_TOKEN='<token>' supabase db push --linked --yes
```

Expected:

- migration `20260511123000_catalog_agent_learning_context.sql` applies;
- no staging project is touched.

## 3. Read Learning Context

```bash
SUPABASE_ACCESS_TOKEN='<token>' supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.get_catalog_agent_learning_context(array['lievito'], 3);"
```

Expected:

- `metadata.source = catalog_agent_learning_context_v1`;
- `metadata.terms_requested = 1`;
- `term_learnings.lievito` contains any active learning memory for the term.

## 4. Verify Function Packet Path

Deploy the Edge Function to dev only:

```bash
SUPABASE_ACCESS_TOKEN='<token>' supabase functions deploy run-catalog-agent-triage --project-ref gyuedxycbnqljryenapx
```

Invoke a bounded dry run only if `CATALOG_AGENT_ENABLED=true` is intentional:

```bash
curl -X POST 'https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-agent-triage' \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "x-season-catalog-agent-token: ${CATALOG_AGENT_OPERATOR_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"limit":1,"include_non_new":true,"dry_run":true}'
```

Expected response summary includes:

- `prompt_version = catalog-agent-triage-v2-learning-memory`;
- `learning_memory.source = catalog_agent_learning_context_v1`;
- `learning_memory.terms_requested > 0`.

Reset dev callable state after smoke unless intentionally testing:

```bash
SUPABASE_ACCESS_TOKEN='<token>' supabase secrets set CATALOG_AGENT_ENABLED=false --project-ref gyuedxycbnqljryenapx
```
