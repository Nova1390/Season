-- Phase 1 reconciliation impact measurement (read-only).
-- Built directly on preview/apply/audit artifacts for ops decision support.

create or replace view public.recipe_reconciliation_impact_summary as
with preview as (
  select
    p.recipe_ingredient_row_id,
    p.safe_to_apply,
    p.safety_reason,
    p.normalized_text,
    p.match_source,
    p.matched_ingredient_id
  from public.recipe_ingredient_reconciliation_safety_preview p
),
applied_unique as (
  select distinct a.recipe_ingredient_row_id
  from public.recipe_ingredient_reconciliation_audit a
),
safe_rows as (
  select p.recipe_ingredient_row_id, p.matched_ingredient_id
  from preview p
  where p.safe_to_apply
),
safe_missing_legacy_mapping as (
  select s.recipe_ingredient_row_id
  from safe_rows s
  left join public.legacy_ingredient_mapping lm
    on lm.ingredient_id = s.matched_ingredient_id
  where lm.ingredient_id is null
)
select
  count(*)::bigint as inspected_rows,
  count(*) filter (where p.safe_to_apply)::bigint as safe_to_apply_rows,
  count(*) filter (where au.recipe_ingredient_row_id is not null)::bigint as applied_rows,
  count(*) filter (where p.safe_to_apply and au.recipe_ingredient_row_id is not null)::bigint as safe_and_applied_rows,
  count(*) filter (where p.safe_to_apply and au.recipe_ingredient_row_id is null)::bigint as safe_not_applied_rows,
  count(*) filter (where not p.safe_to_apply)::bigint as blocked_rows,
  coalesce(
    round(
      (count(*) filter (where p.safe_to_apply)::numeric / nullif(count(*)::numeric, 0)) * 100.0,
      2
    ),
    0
  ) as safe_coverage_rate_pct,
  coalesce(
    round(
      (count(*) filter (where au.recipe_ingredient_row_id is not null)::numeric / nullif(count(*)::numeric, 0)) * 100.0,
      2
    ),
    0
  ) as applied_coverage_rate_pct,
  coalesce(
    round(
      (
        count(*) filter (where p.safe_to_apply and au.recipe_ingredient_row_id is not null)::numeric
        / nullif(count(*) filter (where p.safe_to_apply)::numeric, 0)
      ) * 100.0,
      2
    ),
    0
  ) as applied_of_safe_rate_pct,
  (select count(*)::bigint from safe_missing_legacy_mapping) as safe_rows_missing_legacy_mapping
from preview p
left join applied_unique au
  on au.recipe_ingredient_row_id = p.recipe_ingredient_row_id;

create or replace view public.recipe_reconciliation_blockers as
with preview as (
  select
    p.recipe_ingredient_row_id,
    p.safe_to_apply,
    p.safety_reason,
    p.matched_ingredient_id
  from public.recipe_ingredient_reconciliation_safety_preview p
),
safe_missing_legacy_mapping as (
  select p.recipe_ingredient_row_id
  from preview p
  left join public.legacy_ingredient_mapping lm
    on lm.ingredient_id = p.matched_ingredient_id
  where p.safe_to_apply
    and lm.ingredient_id is null
)
select
  p.safety_reason as blocker_category,
  count(*)::bigint as blocked_row_count
from preview p
where not p.safe_to_apply
group by p.safety_reason

union all

select
  'missing_legacy_mapping'::text as blocker_category,
  count(*)::bigint as blocked_row_count
from safe_missing_legacy_mapping;

create or replace view public.recipe_reconciliation_match_source_breakdown as
select
  p.match_source,
  count(*)::bigint as row_count,
  count(*) filter (where p.safe_to_apply)::bigint as safe_row_count,
  count(*) filter (where a.recipe_ingredient_row_id is not null)::bigint as applied_row_count
from public.recipe_ingredient_reconciliation_safety_preview p
left join (
  select distinct recipe_ingredient_row_id
  from public.recipe_ingredient_reconciliation_audit
) a
  on a.recipe_ingredient_row_id = p.recipe_ingredient_row_id
group by p.match_source
order by row_count desc, p.match_source asc;

create or replace function public.top_unreconciled_recipe_ingredients(
  p_limit integer default 50,
  p_safe_not_applied_only boolean default false
)
returns table (
  normalized_text text,
  row_count bigint,
  safe_row_count bigint,
  blocked_row_count bigint,
  safe_not_applied_count bigint,
  missing_legacy_mapping_count bigint,
  top_safety_reason text
)
language sql
stable
set search_path = public
as $$
  with base as (
    select
      p.recipe_ingredient_row_id,
      p.normalized_text,
      p.safe_to_apply,
      p.safety_reason,
      p.matched_ingredient_id,
      (a.recipe_ingredient_row_id is not null) as is_applied
    from public.recipe_ingredient_reconciliation_safety_preview p
    left join (
      select distinct recipe_ingredient_row_id
      from public.recipe_ingredient_reconciliation_audit
    ) a
      on a.recipe_ingredient_row_id = p.recipe_ingredient_row_id
    where p.normalized_text is not null
      and p.normalized_text <> ''
  ),
  unresolved as (
    select b.*
    from base b
    where not b.is_applied
      and (
        (not p_safe_not_applied_only)
        or b.safe_to_apply
      )
  ),
  unresolved_with_mapping as (
    select
      u.*,
      (lm.ingredient_id is null) as missing_legacy_mapping
    from unresolved u
    left join public.legacy_ingredient_mapping lm
      on lm.ingredient_id = u.matched_ingredient_id
  ),
  reason_rank as (
    select
      u.normalized_text,
      u.safety_reason,
      count(*) as reason_count,
      row_number() over (
        partition by u.normalized_text
        order by count(*) desc, u.safety_reason asc
      ) as rn
    from unresolved_with_mapping u
    group by u.normalized_text, u.safety_reason
  )
  select
    u.normalized_text,
    count(*)::bigint as row_count,
    count(*) filter (where u.safe_to_apply)::bigint as safe_row_count,
    count(*) filter (where not u.safe_to_apply)::bigint as blocked_row_count,
    count(*) filter (where u.safe_to_apply and not u.is_applied)::bigint as safe_not_applied_count,
    count(*) filter (where u.safe_to_apply and u.missing_legacy_mapping)::bigint as missing_legacy_mapping_count,
    rr.safety_reason as top_safety_reason
  from unresolved_with_mapping u
  left join reason_rank rr
    on rr.normalized_text = u.normalized_text
   and rr.rn = 1
  group by u.normalized_text, rr.safety_reason
  order by row_count desc, safe_not_applied_count desc, u.normalized_text asc
  limit greatest(1, coalesce(p_limit, 50));
$$;

grant select on public.recipe_reconciliation_impact_summary to authenticated;
grant select on public.recipe_reconciliation_blockers to authenticated;
grant select on public.recipe_reconciliation_match_source_breakdown to authenticated;
grant execute on function public.top_unreconciled_recipe_ingredients(integer, boolean) to authenticated;
grant execute on function public.top_unreconciled_recipe_ingredients(integer, boolean) to service_role;

