-- Upgrade candidate queue prioritization with a richer, explainable score.
-- Signals:
-- 1) occurrence count (log-scaled)
-- 2) recency (inverse days since last seen)
-- 3) persistence (days unresolved since first seen, capped)
-- 4) suggested action weight (alias_existing/create_new_ingredient/ignore)

drop view if exists public.catalog_resolution_candidate_queue cascade;

create view public.catalog_resolution_candidate_queue as
with alias_rollup as (
  select
    a.normalized_alias_text as normalized_text,
    count(*) > 0 as has_any_alias_match,
    bool_or(a.status = 'approved' and coalesce(a.is_active, true)) as has_approved_alias,
    case
      when bool_or(a.status = 'approved' and coalesce(a.is_active, true)) then 'approved'
      when bool_or(a.status = 'suggested') then 'suggested'
      when bool_or(a.status = 'rejected') then 'rejected'
      when bool_or(a.status = 'deprecated') then 'deprecated'
      else 'unknown'
    end as existing_alias_status
  from public.ingredient_aliases_v2 a
  group by a.normalized_alias_text
),
canonical_rollup as (
  select
    normalized_text,
    true as has_canonical_match
  from (
    select
      regexp_replace(lower(trim(l.display_name)), '\s+', ' ', 'g') as normalized_text
    from public.ingredient_localizations l
    where l.display_name is not null
      and trim(l.display_name) <> ''

    union

    select
      regexp_replace(lower(trim(replace(i.slug, '_', ' '))), '\s+', ' ', 'g') as normalized_text
    from public.ingredients i
    where i.slug is not null
      and trim(i.slug) <> ''
  ) canonical_names
  where normalized_text <> ''
  group by normalized_text
),
base as (
  select
    s.normalized_text,
    s.occurrence_count,
    s.latest_example,
    s.language_code,
    s.source,
    s.first_seen_at,
    s.last_seen_at,
    s.days_since_last_seen,
    coalesce(ar.existing_alias_status, 'none') as existing_alias_status,
    coalesce(ar.has_approved_alias, false) as has_approved_alias,
    coalesce(ar.has_any_alias_match, false) as has_any_alias_match,
    case
      when s.occurrence_count >= 12 then 'alias_existing'
      when s.occurrence_count between 4 and 11 then 'create_new_ingredient'
      when s.occurrence_count = 1 and s.days_since_last_seen > 45 then 'ignore'
      else 'unknown'
    end::text as suggested_resolution_type,
    s.status
  from public.custom_ingredient_observation_summary s
  left join alias_rollup ar
    on ar.normalized_text = s.normalized_text
  left join canonical_rollup cr
    on cr.normalized_text = s.normalized_text
  where coalesce(s.status, 'new') = 'new'
    and coalesce(ar.has_any_alias_match, false) = false
    and coalesce(cr.has_canonical_match, false) = false
),
scored as (
  select
    b.*,
    ln(1 + greatest(b.occurrence_count, 0)::numeric) as occurrence_weight,
    (1.0 / (1 + greatest(b.days_since_last_seen, 0)))::numeric as recency_weight,
    (
      least(
        greatest(
          floor(extract(epoch from (now() - b.first_seen_at)) / 86400.0),
          0
        )::numeric,
        60
      ) / 60.0
    ) as persistence_weight,
    case b.suggested_resolution_type
      when 'alias_existing' then 2.0::numeric
      when 'create_new_ingredient' then 1.0::numeric
      when 'ignore' then -1.0::numeric
      else 0.0::numeric
    end as action_weight
  from base b
)
select
  s.normalized_text,
  s.occurrence_count,
  s.latest_example,
  s.language_code,
  s.source,
  s.first_seen_at,
  s.last_seen_at,
  round(
    (s.occurrence_weight * 3.0)
    + (s.recency_weight * 2.0)
    + s.persistence_weight
    + s.action_weight,
    4
  ) as priority_score,
  s.existing_alias_status,
  s.has_approved_alias,
  s.has_any_alias_match,
  s.suggested_resolution_type,
  s.status
from scored s;

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
  existing_alias_status text,
  has_approved_alias boolean,
  has_any_alias_match boolean,
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
    c.existing_alias_status,
    c.has_approved_alias,
    c.has_any_alias_match,
    c.suggested_resolution_type
  from public.catalog_resolution_candidate_queue c
  where (not only_status_new) or c.status = 'new'
  order by c.priority_score desc, c.occurrence_count desc, c.normalized_text asc
  limit greatest(1, coalesce(limit_count, 100));
$$;

grant execute on function public.catalog_resolution_candidates(integer, boolean) to authenticated;
grant execute on function public.catalog_resolution_candidates(integer, boolean) to service_role;
