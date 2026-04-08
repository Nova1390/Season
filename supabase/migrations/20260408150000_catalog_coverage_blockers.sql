-- Surface top blocked unresolved terms with actionable fix hints for catalog coverage.
-- Read-only artifact for admin/ops triage (alias vs localization vs new ingredient).

create or replace view public.catalog_coverage_blocker_terms as
with unresolved as (
  select
    a.normalized_text,
    a.row_count,
    a.recipe_count,
    a.top_safety_reason,
    a.recommended_next_action
  from public.recipe_reconciliation_unresolved_text_analysis a
),
observation_rollup as (
  select
    o.normalized_text,
    o.occurrence_count
  from public.custom_ingredient_observations o
),
candidate_rollup as (
  select
    c.normalized_text,
    c.priority_score,
    c.suggested_resolution_type
  from public.catalog_resolution_candidate_queue c
),
canonical_keys as (
  select
    i.id as ingredient_id,
    i.slug,
    replace(i.slug, '_', ' ') as display_name,
    regexp_replace(
      lower(trim(replace(i.slug, '_', ' '))),
      '[^a-z0-9]+',
      '',
      'g'
    ) as compact_key
  from public.ingredients i

  union all

  select
    l.ingredient_id,
    i.slug,
    l.display_name,
    regexp_replace(
      lower(trim(l.display_name)),
      '[^a-z0-9]+',
      '',
      'g'
    ) as compact_key
  from public.ingredient_localizations l
  join public.ingredients i
    on i.id = l.ingredient_id
  where l.display_name is not null
    and trim(l.display_name) <> ''
),
canonical_match as (
  select
    u.normalized_text,
    count(distinct ck.ingredient_id) as canonical_match_count,
    (array_agg(distinct ck.ingredient_id order by ck.ingredient_id))[1] as canonical_candidate_ingredient_id,
    (array_agg(distinct ck.slug order by ck.slug))[1] as canonical_candidate_slug,
    (array_agg(distinct ck.display_name order by ck.display_name))[1] as canonical_candidate_name
  from unresolved u
  left join canonical_keys ck
    on ck.compact_key = regexp_replace(lower(trim(u.normalized_text)), '[^a-z0-9]+', '', 'g')
  group by u.normalized_text
)
select
  u.normalized_text,
  u.row_count,
  u.recipe_count,
  coalesce(o.occurrence_count, 0) as occurrence_count,
  c.priority_score,
  case
    when cm.canonical_match_count = 1 then 'localization'
    when u.recommended_next_action = 'add_alias' then 'alias'
    when u.recommended_next_action = 'create_new_ingredient' then 'new_ingredient'
    else 'unknown'
  end::text as likely_fix_type,
  case
    when cm.canonical_match_count = 1 then cm.canonical_candidate_ingredient_id
    else null
  end as canonical_candidate_ingredient_id,
  case
    when cm.canonical_match_count = 1 then cm.canonical_candidate_slug
    else null
  end as canonical_candidate_slug,
  case
    when cm.canonical_match_count = 1 then cm.canonical_candidate_name
    else null
  end as canonical_candidate_name,
  coalesce(c.suggested_resolution_type, 'unknown') as suggested_resolution_type,
  u.top_safety_reason as blocker_reason,
  u.recommended_next_action
from unresolved u
left join observation_rollup o
  on o.normalized_text = u.normalized_text
left join candidate_rollup c
  on c.normalized_text = u.normalized_text
left join canonical_match cm
  on cm.normalized_text = u.normalized_text;

create or replace function public.top_catalog_coverage_blockers(
  p_limit integer default 50,
  p_focus_alias_localization boolean default true
)
returns table (
  normalized_text text,
  row_count bigint,
  recipe_count bigint,
  occurrence_count integer,
  priority_score numeric,
  likely_fix_type text,
  canonical_candidate_ingredient_id uuid,
  canonical_candidate_slug text,
  canonical_candidate_name text,
  suggested_resolution_type text,
  blocker_reason text,
  recommended_next_action text
)
language sql
stable
set search_path = public
as $$
  select
    b.normalized_text,
    b.row_count,
    b.recipe_count,
    b.occurrence_count,
    b.priority_score,
    b.likely_fix_type,
    b.canonical_candidate_ingredient_id,
    b.canonical_candidate_slug,
    b.canonical_candidate_name,
    b.suggested_resolution_type,
    b.blocker_reason,
    b.recommended_next_action
  from public.catalog_coverage_blocker_terms b
  where (not p_focus_alias_localization)
     or b.likely_fix_type in ('alias', 'localization')
  order by
    b.row_count desc,
    b.recipe_count desc,
    b.occurrence_count desc,
    b.priority_score desc nulls last,
    b.normalized_text asc
  limit greatest(1, coalesce(p_limit, 50));
$$;

grant select on public.catalog_coverage_blocker_terms to authenticated;
grant execute on function public.top_catalog_coverage_blockers(integer, boolean) to authenticated;
grant execute on function public.top_catalog_coverage_blockers(integer, boolean) to service_role;
