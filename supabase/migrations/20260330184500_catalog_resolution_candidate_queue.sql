-- Read-only candidate queue for off-app catalog operations review.
-- This keeps review workflow in Supabase/ops paths, not inside consumer app UI.

create or replace view public.catalog_resolution_candidate_queue as
select
  s.normalized_text,
  s.occurrence_count,
  s.latest_example,
  s.language_code,
  s.source,
  s.first_seen_at,
  s.last_seen_at,
  s.priority_score,
  case
    when s.status is not null and s.status <> 'new' then 'ignore'
    when s.occurrence_count >= 12 then 'alias_existing'
    when s.occurrence_count between 4 and 11 then 'create_new_ingredient'
    when s.occurrence_count = 1 and s.days_since_last_seen > 45 then 'ignore'
    else 'unknown'
  end::text as suggested_resolution_type,
  s.status
from public.custom_ingredient_observation_summary s;

create or replace function public.catalog_resolution_candidates(
  limit_count integer default 100,
  only_status_new boolean default true
)
returns table (
  normalized_text text,
  occurrence_count integer,
  latest_example text,
  language_code text,
  source text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  priority_score numeric,
  suggested_resolution_type text
)
language sql
stable
set search_path = public
as $$
  select
    c.normalized_text,
    c.occurrence_count,
    c.latest_example,
    c.language_code,
    c.source,
    c.first_seen_at,
    c.last_seen_at,
    c.priority_score,
    c.suggested_resolution_type
  from public.catalog_resolution_candidate_queue c
  where (not only_status_new) or c.status = 'new'
  order by c.priority_score desc, c.occurrence_count desc, c.last_seen_at desc, c.normalized_text asc
  limit greatest(1, coalesce(limit_count, 100));
$$;

grant select on public.catalog_resolution_candidate_queue to authenticated;
grant execute on function public.catalog_resolution_candidates(integer, boolean) to authenticated;
grant execute on function public.catalog_resolution_candidates(integer, boolean) to service_role;

