# DEV-ONLY Catalog Agent Learning Memory Smoke Test

Use this only against `Season-dev` (`gyuedxycbnqljryenapx`).

Do not run against staging while TestFlight is in review.

## Link Dev

```bash
supabase link --project-ref gyuedxycbnqljryenapx
```

## Read Memory

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.get_catalog_agent_learning_memory(p_limit := 10);"
```

Expected:

- `metadata.source = catalog_agent_learning_memory_v1`;
- `items` array;
- no catalog mutation.

## Manual Learning Record

Use a dev proposal id only.

```bash
supabase db query --linked "select set_config('request.jwt.claim.role', 'service_role', true); select public.record_catalog_agent_learning(p_proposal_id := 1, p_learning_type := 'ambiguity', p_observed_problem := 'Dev smoke: term is ingredient but canonical target remains ambiguous.', p_prompt_recommendation := 'Keep ingredient-existence confidence separate from canonical-target confidence.');"
```

Expected:

- one learning artifact is created;
- status defaults to `needs_review`;
- no catalog mutation.

Observed on 2026-05-11:

- `learning_id=1`;
- `learning_type=ambiguity`;
- `normalized_text=lievito`;
- status `needs_review`.
