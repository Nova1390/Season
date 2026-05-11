# DEV-ONLY Catalog Agent Manual Apply Smoke Test

Use this only against `Season-dev` (`gyuedxycbnqljryenapx`).

Do not run against staging while TestFlight is in review.

## Link Dev

```bash
supabase link --project-ref gyuedxycbnqljryenapx
```

## Batch No-Op Smoke

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.apply_catalog_agent_proposal_batch(10);"
```

Expected when no validated low-risk proposals exist:

- `ok=true`;
- `applied=0`;
- `failed=0`;
- no catalog mutation.

Observed on 2026-05-11:

- `ok=true`;
- `applied=0`;
- `failed=0`;
- `results=[]`.

## Single Proposal Apply

Only use this for a real validated low-risk proposal.

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.apply_catalog_agent_proposal(<proposal_id>, 'Manual dev apply after validation.');"
```

Expected:

- proposal status becomes `applied`;
- `applied_at` and `applied_by` are set;
- `manual_apply_succeeded` event is inserted;
- mutation happens only through the governed RPC for the proposal type.
