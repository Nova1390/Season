# DEV-ONLY Catalog Agent Validator Smoke Test

Use this only against `Season-dev` (`gyuedxycbnqljryenapx`).

Do not run against staging while TestFlight is in review.

## Link Dev

```bash
supabase link --project-ref gyuedxycbnqljryenapx
```

## Queue A Dev Proposal

Use only a proposal created during dev smoke testing.

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.review_catalog_agent_proposal(1, 'queue_for_validation', 'Dev smoke: queue before deterministic validation.');"
```

## Validate One Proposal

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.validate_catalog_agent_proposal(1);"
```

For the current `lievito` smoke proposal, expected result is `failed_validation` because `needs_human_review` is intentionally non-actionable.

Observed on 2026-05-11:

- `proposal_id=1`;
- status moved to `failed_validation`;
- validation error code: `human_review_proposal_not_actionable`.

## Validate Batch

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.validate_catalog_agent_proposal_batch(10);"
```

Expected:

- queued proposals become `validated` or `failed_validation`;
- validation errors are structured JSON;
- events are written with `validator_passed` or `validator_failed`;
- no changes to `ingredients`, aliases, localizations, recipes, observations, or reconciliation state.
