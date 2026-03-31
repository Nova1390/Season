-- Alias governance metadata (backend-first) + review-ready candidate queue enrichment.
-- This migration intentionally avoids any consumer app admin UX coupling.

-- 1) Extend unified alias table with governance metadata.
alter table public.ingredient_aliases_v2
  add column if not exists status text not null default 'approved',
  add column if not exists confidence_score double precision,
  add column if not exists approval_source text not null default 'legacy_migration',
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid,
  add column if not exists review_notes text;

-- Backfill governance metadata for existing aliases so behavior stays backward-compatible.
update public.ingredient_aliases_v2
set
  status = coalesce(status, 'approved'),
  confidence_score = coalesce(confidence_score, confidence),
  approval_source = coalesce(
    approval_source,
    case
      when source in ('phase_a_seed', 'legacy_seed') then 'legacy_migration'
      when source = 'manual' then 'manual'
      else 'import_observation'
    end
  )
where
  status is null
  or confidence_score is null
  or approval_source is null;

update public.ingredient_aliases_v2
set approved_at = coalesce(approved_at, created_at)
where status = 'approved' and approved_at is null;

alter table public.ingredient_aliases_v2
  drop constraint if exists ingredient_aliases_v2_status_check;
alter table public.ingredient_aliases_v2
  add constraint ingredient_aliases_v2_status_check
  check (status in ('suggested', 'approved', 'rejected', 'deprecated'));

alter table public.ingredient_aliases_v2
  drop constraint if exists ingredient_aliases_v2_approval_source_check;
alter table public.ingredient_aliases_v2
  add constraint ingredient_aliases_v2_approval_source_check
  check (approval_source in ('manual', 'import_observation', 'llm_suggestion', 'legacy_migration'));

alter table public.ingredient_aliases_v2
  drop constraint if exists ingredient_aliases_v2_confidence_score_check;
alter table public.ingredient_aliases_v2
  add constraint ingredient_aliases_v2_confidence_score_check
  check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1));

alter table public.ingredient_aliases_v2
  drop constraint if exists ingredient_aliases_v2_approved_at_required_check;
alter table public.ingredient_aliases_v2
  add constraint ingredient_aliases_v2_approved_at_required_check
  check (
    (status = 'approved' and approved_at is not null)
    or (status <> 'approved')
  );

create index if not exists ingredient_aliases_v2_status_idx
  on public.ingredient_aliases_v2(status);

create index if not exists ingredient_aliases_v2_status_normalized_alias_idx
  on public.ingredient_aliases_v2(status, normalized_alias_text);

-- 2) Enrich candidate queue with alias governance coverage signals.
-- This makes SQL-first review safer before any future batch reconciliation.
drop view if exists public.catalog_resolution_candidate_queue cascade;

create or replace view public.catalog_resolution_candidate_queue as
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
)
select
  s.normalized_text,
  s.occurrence_count,
  s.latest_example,
  s.language_code,
  s.source,
  s.first_seen_at,
  s.last_seen_at,
  s.priority_score,
  coalesce(ar.existing_alias_status, 'none') as existing_alias_status,
  coalesce(ar.has_approved_alias, false) as has_approved_alias,
  coalesce(ar.has_any_alias_match, false) as has_any_alias_match,
  case
    when coalesce(ar.has_approved_alias, false) then 'ignore'
    when coalesce(ar.has_any_alias_match, false) then 'alias_existing'
    when s.status is not null and s.status <> 'new' then 'ignore'
    when s.occurrence_count >= 12 then 'alias_existing'
    when s.occurrence_count between 4 and 11 then 'create_new_ingredient'
    when s.occurrence_count = 1 and s.days_since_last_seen > 45 then 'ignore'
    else 'unknown'
  end::text as suggested_resolution_type,
  s.status
from public.custom_ingredient_observation_summary s
left join alias_rollup ar on ar.normalized_text = s.normalized_text;

drop function if exists public.catalog_resolution_candidates(integer, boolean);

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
  order by c.priority_score desc, c.occurrence_count desc, c.last_seen_at desc, c.normalized_text asc
  limit greatest(1, coalesce(limit_count, 100));
$$;

grant execute on function public.catalog_resolution_candidates(integer, boolean) to authenticated;
grant execute on function public.catalog_resolution_candidates(integer, boolean) to service_role;
