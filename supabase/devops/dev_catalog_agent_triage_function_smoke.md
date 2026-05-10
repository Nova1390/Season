# DEV-ONLY Catalog Agent Function Smoke Test

Use this only against `Season-dev` (`gyuedxycbnqljryenapx`).

Do not run against staging while TestFlight is in review.

## Deploy

```bash
supabase functions deploy run-catalog-agent-triage --project-ref gyuedxycbnqljryenapx
```

## Required Dev Secrets

```bash
supabase secrets set CATALOG_AGENT_ENABLED=true --project-ref gyuedxycbnqljryenapx
supabase secrets set CATALOG_AGENT_MAX_ITEMS_PER_RUN=10 --project-ref gyuedxycbnqljryenapx
supabase secrets set CATALOG_AGENT_MAX_RUNS_PER_DAY=3 --project-ref gyuedxycbnqljryenapx
supabase secrets set CATALOG_AGENT_RECENT_PROPOSAL_DAYS=7 --project-ref gyuedxycbnqljryenapx
supabase secrets set CATALOG_AGENT_OPERATOR_TOKEN=<random-devops-token> --project-ref gyuedxycbnqljryenapx
```

`OPENAI_API_KEY` should already be configured for existing GPT-backed functions.

## Smoke Test

Fetch the anon key used by the Edge gateway:

```bash
ANON_KEY="$(supabase projects api-keys --project-ref gyuedxycbnqljryenapx -o json | jq -r '.[] | select(.name=="anon") | .api_key' | head -n 1)"
```

Dry run still calls GPT, so use a tiny limit:

```bash
curl -X POST 'https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-agent-triage' \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "x-season-catalog-agent-token: ${CATALOG_AGENT_OPERATOR_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"limit":1,"dry_run":true}'
```

Real proposal insert, still proposal-only:

```bash
curl -X POST 'https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-agent-triage' \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "x-season-catalog-agent-token: ${CATALOG_AGENT_OPERATOR_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"limit":1,"dry_run":false}'
```

Expected result:

- one `catalog_agent_runs` row;
- zero or more `catalog_agent_proposals` rows;
- run summary includes token usage and budget settings;
- no changes to `ingredients`, aliases, localizations, or recipes.

The first dev smoke on 2026-05-10 produced:

- dry run: `run_id=1`, one item sent to GPT, zero proposals inserted, `1304` total tokens;
- proposal-only insert: `run_id=2`, one `needs_human_review` proposal for `lievito`, `1307` total tokens;
- repeat guardrail: `run_id=3`, zero items sent to GPT, one recent proposal skipped.

After smoke testing:

```bash
supabase secrets set CATALOG_AGENT_ENABLED=false --project-ref gyuedxycbnqljryenapx
```
