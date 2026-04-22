-- Final reconciliation observability cleanup for the modern ingredient_id path.
-- Scope:
-- - keep modern safe rows visibly actionable
-- - relabel legacy bridge gaps so they are not mistaken for modern blockers
-- - do not change reconciliation matching or apply behavior.

create or replace view public.recipe_reconciliation_blockers as
with preview as (
  select
    p.recipe_ingredient_row_id,
    p.safe_to_apply,
    p.safety_reason,
    p.matched_ingredient_id
  from public.recipe_ingredient_reconciliation_safety_preview p
  where p.safety_reason <> 'already_resolved'
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
  'legacy_bridge_gap'::text as blocker_category,
  count(*)::bigint as blocked_row_count
from safe_missing_legacy_mapping;

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
actionable_preview as (
  select *
  from preview
  where safety_reason <> 'already_resolved'
),
applied_unique as (
  select distinct a.recipe_ingredient_row_id
  from public.recipe_ingredient_reconciliation_audit a
),
safe_rows as (
  select p.recipe_ingredient_row_id, p.matched_ingredient_id
  from actionable_preview p
  where p.safe_to_apply
),
safe_legacy_bridge_gap as (
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
  (select count(*)::bigint from safe_legacy_bridge_gap) as safe_rows_missing_legacy_mapping
from actionable_preview p
left join applied_unique au
  on au.recipe_ingredient_row_id = p.recipe_ingredient_row_id;
