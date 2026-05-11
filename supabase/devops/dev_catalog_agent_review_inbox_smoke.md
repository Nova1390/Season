# DEV-ONLY Catalog Agent Review Inbox Smoke Test

Use this only against `Season-dev` (`gyuedxycbnqljryenapx`).

Do not run against staging while TestFlight is in review.

## Link Dev

```bash
supabase link --project-ref gyuedxycbnqljryenapx
```

## Read Inbox

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.get_catalog_agent_review_inbox(p_limit := 10);"
```

Expected:

- JSON payload with `metadata.source = catalog_agent_review_inbox_v1`;
- `metadata.counts`;
- `items` array;
- no catalog mutation.

## Review Transition

Use only a proposal created during dev smoke testing.

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.review_catalog_agent_proposal(1, 'request_more_evidence', 'Dev smoke: verifying proposal lifecycle only.');"
```

Expected:

- proposal status becomes `needs_human_review`;
- one `review_more_evidence_requested` event is inserted;
- no changes to `ingredients`, aliases, localizations, recipes, observations, or reconciliation state.
