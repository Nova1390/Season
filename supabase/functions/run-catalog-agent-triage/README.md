# run-catalog-agent-triage

Proposal-only Catalog Governance Agent runner.

This Edge Function is the first runtime surface for the autonomous catalog agent. It is intentionally conservative:

- reads the bounded `get_catalog_agent_triage_snapshot(...)` work packet;
- attaches compact learning memory for each candidate term;
- skips items with recent agent proposals unless newer learning memory asks the agent to reconsider;
- calls OpenAI Responses API with `gpt-5.4-mini` by default;
- uses a bounded multi-pass reasoning loop by default: semantic profiler, optional risk reviewer, final decision writer;
- validates strict JSON output, including a structured `semantic_profile` for each proposal;
- stores proposals in `catalog_agent_proposals`;
- records run/proposal events;
- records provider token usage in `catalog_ai_usage_events`;
- never mutates catalog identity, aliases, localizations, recipes, or reconciliation state.

## Learning Memory

Before the provider call, the function asks `public.get_catalog_agent_learning_context(...)` for term-specific and global lessons.

The model receives:

- `global_learning_memory`;
- `learning_memory_policy`;
- each work item `context.relevant_learning_memory`.

The memory is advisory. The model must still use only targets present in the current work item and every persisted proposal remains subject to deterministic validation before any apply step.

Recent proposal dedupe happens after learning memory is attached. This prevents repeated LLM calls for unchanged work, but still lets an operator note or review outcome reopen a term when the new lesson was created after the last live proposal.

## Multi-Pass Reasoning

The default runtime mode is `multi_pass`.

The agent now uses the LLM as a set of small task roles instead of asking for one overloaded answer:

- `semantic_profiler`: describes product family, variant dimensions, substitutability, and attribute implications before deciding.
- `risk_reviewer`: runs only when enabled and when the semantic profile suggests ambiguity or a meaningful variant risk.
- `decision_writer`: produces the final proposal using the same strict proposal JSON contract as the previous single-pass runtime.

Every provider call is recorded in `catalog_ai_usage_events` with `metadata.task_role`. The run summary also includes an aggregate `reasoning_trace`, while the aggregate run-level event keeps token fields empty to avoid double-counting provider calls.

Set `CATALOG_AGENT_REASONING_MODE=single_pass` to temporarily return to the old one-call behavior.

## Adaptive Timeout Retry

Provider timeouts should not make the whole run useless when the batch is too large.

If a provider role aborts because of timeout and the run has more than one eligible work item, the function now:

- records `provider_adaptive_retry_scheduled` on `catalog_agent_proposal_events`;
- records an error event in `catalog_ai_usage_events` with `reason=provider_timeout_retry`;
- retries once with the first half of eligible work items;
- stores `adaptive_retry` details in the run summary and reasoning trace when the retry succeeds.

The retry is deliberately single-shot. It prevents runaway loops and keeps costs bounded. If the smaller packet also fails, the run fails normally and remains visible in audit.

## Provider Output Repair

The deterministic validator remains the source of truth for proposal shape.

Before validation, the function performs one safe repair class:

- incomplete actionable proposals are downgraded to `needs_human_review`;
- examples: `approve_alias` / `add_localization` without a target, or `create_canonical` without required draft fields;
- the repair is recorded as `provider_output_repaired`;
- repaired proposals are not auto-applicable and include a blocking question.

This prevents one incomplete proposal from discarding an otherwise useful run, without weakening catalog safety.

## Semantic Profile

Every proposal now carries a `semantic_profile` in the LLM contract.

The profile captures:

- product family;
- semantic category;
- possible variant dimension;
- whether the term is an identity-bearing variant;
- parent candidate slug, if any;
- substitutability with the parent;
- possible implications for nutrition, seasonality, allergy, fridge matching, shopping matching, and filters;
- evidence and open questions.

The semantic profile is not catalog truth. It is persisted inside proposal `evidence` as a structured item so reviewers and future validators can understand why the agent thinks a term is an alias, child variant, new canonical ingredient, or review case.

## Catalog Gaps

The agent should not treat a missing target as automatic human review.

When a term is clearly a real ingredient identity and no safe catalog target exists, the expected proposal is:

- `proposal_type`: `create_canonical`;
- `target_ingredient_id` / `target_slug`: `null`;
- `proposed_slug`, `proposed_localized_name`, `proposed_language_code`: filled;
- `status`: `draft`;
- `auto_apply_eligible`: `false`.

`needs_human_review` is reserved for cases where the identity boundary, variant policy, language meaning, product/package interpretation, or safety implications are unresolved. In other words: missing catalog item means "propose creation"; unclear ingredient identity means "ask for review".

Implemented learning memory can make this stronger. If accepted/implemented learning says a family variant must not be compressed into a base ingredient, the agent should create a child/specialized `create_canonical` draft when the identity is clear and the child target is missing.

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
- `CATALOG_AGENT_REASONING_MODE`: defaults to `multi_pass`; set `single_pass` for the legacy one-call path.
- `CATALOG_AGENT_MAX_REASONING_CALLS_PER_RUN`: defaults to `3`, capped at `5`.
- `CATALOG_AGENT_RISK_REVIEW_ENABLED`: defaults to `true`.
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
    "estimated_cost_usd": null,
    "reasoning_mode": "multi_pass",
    "reasoning_trace": {
      "mode": "multi_pass",
      "semantic_profile_count": 8,
      "risk_review_enabled": true,
      "risk_review_performed": true
    },
    "learning_memory": {
      "source": "catalog_agent_learning_context_v1",
      "terms_requested": 8,
      "terms_with_learning": 1,
      "global_learning_count": 0,
      "term_learning_count": 1
    }
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
