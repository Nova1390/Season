-- Lightweight analytics surface for recurring unresolved/custom ingredients.
-- Read-only summary for triage and alias/canonical mapping decisions.

create or replace view public.custom_ingredient_observation_summary as
select
  normalized_text,
  occurrence_count,
  jsonb_array_length(coalesce(raw_examples, '[]'::jsonb))::integer as example_count,
  case
    when jsonb_array_length(coalesce(raw_examples, '[]'::jsonb)) > 0
      then raw_examples ->> (jsonb_array_length(raw_examples) - 1)
    else null
  end as latest_example,
  language_code,
  source,
  last_seen_at,
  status
from public.custom_ingredient_observations;

create or replace function public.top_custom_ingredient_observations(
  limit_count integer default 50
)
returns table (
  normalized_text text,
  occurrence_count integer,
  example_count integer,
  latest_example text,
  language_code text,
  source text,
  last_seen_at timestamptz,
  status text
)
language sql
stable
set search_path = public
as $$
  select
    s.normalized_text,
    s.occurrence_count,
    s.example_count,
    s.latest_example,
    s.language_code,
    s.source,
    s.last_seen_at,
    s.status
  from public.custom_ingredient_observation_summary s
  where s.status = 'new'
  order by s.occurrence_count desc, s.last_seen_at desc
  limit greatest(1, coalesce(limit_count, 50));
$$;

grant select on public.custom_ingredient_observation_summary to authenticated;
grant execute on function public.top_custom_ingredient_observations(integer) to authenticated;
grant execute on function public.top_custom_ingredient_observations(integer) to service_role;
