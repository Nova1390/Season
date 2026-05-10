# run-catalog-agent-triage

Proposal-only Catalog Governance Agent runner.

This Edge Function is the first runtime surface for the autonomous catalog agent. It is intentionally conservative:

- reads the bounded `get_catalog_agent_triage_snapshot(...)` work packet;
- skips items with recent agent proposals;
- calls OpenAI Responses API with `gpt-5.4-mini` by default;
- validates strict JSON output;
- stores proposals in `catalog_agent_proposals`;
- records run/proposal events;
- never mutates catalog identity, aliases, localizations, recipes, or reconciliation state.

## Required Secrets

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OPENAI_API_KEY`
- `CATALOG_AGENT_OPERATOR_TOKEN` for server/operator invocations when service-role header matching is unavailable.

## Safety / Budget Env Vars

- `CATALOG_AGENT_ENABLED`: must be `true`; defaults to disabled.
- `CATALOG_AGENT_OPENAI_MODEL`: defaults to `gpt-5.4-mini`.
- `CATALOG_AGENT_MAX_ITEMS_PER_RUN`: defaults to `10`, capped at `25`.
- `CATALOG_AGENT_MAX_RUNS_PER_DAY`: defaults to `3`, capped at `24`.
- `CATALOG_AGENT_RECENT_PROPOSAL_DAYS`: defaults to `7`.
- `CATALOG_AGENT_PROVIDER_TIMEOUT_MS`: defaults to `20000`.
- `CATALOG_AGENT_INPUT_COST_PER_1M_USD`: optional cost estimate.
- `CATALOG_AGENT_OUTPUT_COST_PER_1M_USD`: optional cost estimate.

## Request

```json
{
  "limit": 10,
  "source_domain": null,
  "include_non_new": false,
  "dry_run": false
}
```

`dry_run=true` still calls the LLM and records a run, but does not insert proposals. Use it sparingly because it still costs tokens.

## Response

```json
{
  "ok": true,
  "run_id": 123,
  "summary": {
    "items_in_snapshot": 10,
    "items_sent_to_llm": 8,
    "proposals_returned": 8,
    "proposals_created": 8,
    "skipped_recent_proposal": 2,
    "usage": {
      "inputTokens": 1000,
      "outputTokens": 500,
      "totalTokens": 1500
    },
    "estimated_cost_usd": null
  }
}
```

## Dev Invocation

For development, invoke only against `Season-dev`.

Fetch the anon key for the Edge gateway, then pass the separate operator token for function-level authorization:

```bash
ANON_KEY="$(supabase projects api-keys --project-ref gyuedxycbnqljryenapx -o json | jq -r '.[] | select(.name=="anon") | .api_key' | head -n 1)"
```

```bash
curl -X POST 'https://gyuedxycbnqljryenapx.supabase.co/functions/v1/run-catalog-agent-triage' \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "x-season-catalog-agent-token: ${CATALOG_AGENT_OPERATOR_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"limit":1,"dry_run":true}'
```

The anon key is used only to satisfy the Edge gateway. The function-level authorization is the catalog admin check or `CATALOG_AGENT_OPERATOR_TOKEN`.

After manual smoke tests, set `CATALOG_AGENT_ENABLED=false` again unless you intentionally want the dev function callable:

```bash
supabase secrets set CATALOG_AGENT_ENABLED=false --project-ref gyuedxycbnqljryenapx
```

## Current Autonomy Level

Level 1: propose only.

The function does not apply proposals and does not schedule itself.
