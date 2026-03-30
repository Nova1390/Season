-- Enhanced read-only analytics for unresolved/custom ingredient observations.
-- Goal: prioritize high-impact strings for alias/catalog growth decisions.

drop view if exists public.custom_ingredient_observation_summary;

create view public.custom_ingredient_observation_summary as
with base as (
  select
    o.normalized_text,
    o.occurrence_count,
    jsonb_array_length(coalesce(o.raw_examples, '[]'::jsonb))::integer as example_count,
    case
      when jsonb_array_length(coalesce(o.raw_examples, '[]'::jsonb)) > 0
        then o.raw_examples ->> (jsonb_array_length(o.raw_examples) - 1)
      else null
    end as latest_example,
    o.language_code,
    o.source,
    o.first_seen_at,
    o.last_seen_at,
    greatest(
      0,
      floor(extract(epoch from (now() - o.last_seen_at)) / 86400.0)
    )::integer as days_since_last_seen,
    o.status
  from public.custom_ingredient_observations o
)
select
  b.normalized_text,
  b.occurrence_count,
  b.example_count,
  b.latest_example,
  b.language_code,
  b.source,
  b.first_seen_at,
  b.last_seen_at,
  b.days_since_last_seen,
  -- Lightweight, explainable priority:
  -- base signal = occurrence_count
  -- freshness boost = stronger for recently seen strings
  round(
    (
      b.occurrence_count::numeric *
      (
        case
          when b.days_since_last_seen <= 3 then 1.40
          when b.days_since_last_seen <= 7 then 1.25
          when b.days_since_last_seen <= 30 then 1.10
          else 0.90
        end
      )
    ),
    2
  ) as priority_score,
  b.status
from base b;

-- Backward-compatible helper (keeps original signature).
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
  order by s.priority_score desc, s.occurrence_count desc, s.last_seen_at desc
  limit greatest(1, coalesce(limit_count, 50));
$$;

-- Richer read-only inspection helper.
-- sort_mode: 'priority' | 'count' | 'recent'
create or replace function public.custom_ingredient_observation_insights(
  limit_count integer default 50,
  only_status_new boolean default true,
  sort_mode text default 'priority'
)
returns table (
  normalized_text text,
  occurrence_count integer,
  example_count integer,
  latest_example text,
  language_code text,
  source text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  days_since_last_seen integer,
  priority_score numeric,
  status text
)
language sql
stable
set search_path = public
as $$
  with params as (
    select lower(trim(coalesce(sort_mode, 'priority'))) as sort_key
  )
  select
    s.normalized_text,
    s.occurrence_count,
    s.example_count,
    s.latest_example,
    s.language_code,
    s.source,
    s.first_seen_at,
    s.last_seen_at,
    s.days_since_last_seen,
    s.priority_score,
    s.status
  from public.custom_ingredient_observation_summary s
  cross join params p
  where (not only_status_new) or s.status = 'new'
  order by
    case
      when p.sort_key = 'count' then s.occurrence_count::numeric
      when p.sort_key = 'recent' then extract(epoch from s.last_seen_at)::numeric
      else s.priority_score
    end desc,
    s.last_seen_at desc,
    s.occurrence_count desc,
    s.normalized_text asc
  limit greatest(1, coalesce(limit_count, 50));
$$;

grant select on public.custom_ingredient_observation_summary to authenticated;
grant execute on function public.top_custom_ingredient_observations(integer) to authenticated;
grant execute on function public.top_custom_ingredient_observations(integer) to service_role;
grant execute on function public.custom_ingredient_observation_insights(integer, boolean, text) to authenticated;
grant execute on function public.custom_ingredient_observation_insights(integer, boolean, text) to service_role;
