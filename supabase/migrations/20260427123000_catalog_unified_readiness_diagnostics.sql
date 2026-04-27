-- Read-only diagnostics for the ingredient_id-first catalog migration.
--
-- These views make the target model measurable:
-- - recipes should move toward ingredient_id on every ingredient row;
-- - legacy produce/basic IDs should be treated as bridge data;
-- - catalog entries should expose the attributes needed by app features.

create or replace view public.catalog_unified_readiness_summary as
select
  count(*)::bigint as ingredient_count,
  count(*) filter (where ingredient_type = 'produce')::bigint as produce_count,
  count(*) filter (where ingredient_type = 'basic')::bigint as basic_count,
  count(*) filter (where is_seasonal)::bigint as seasonal_count,
  count(*) filter (where is_seasonal and cardinality(coalesce(season_months, '{}'::int[])) > 0)::bigint as seasonal_with_months_count,
  count(*) filter (
    where is_seasonal
      and cardinality(coalesce(season_months, '{}'::int[])) = 0
  )::bigint as seasonal_missing_months_count,
  count(*) filter (where calories_per_100g is not null)::bigint as nutrition_calorie_count,
  count(*) filter (
    where calories_per_100g is not null
      and protein_per_100g is not null
      and carbs_per_100g is not null
      and fat_per_100g is not null
  )::bigint as nutrition_macro_complete_count,
  count(*) filter (where default_unit is not null and cardinality(coalesce(supported_units, '{}'::text[])) > 0)::bigint as unit_profile_count,
  count(*) filter (where quality_status = 'active')::bigint as active_count,
  count(*) filter (where lm.ingredient_id is not null)::bigint as legacy_bridge_count,
  count(*) filter (where it_l10n.ingredient_id is not null)::bigint as italian_localized_count,
  count(*) filter (where en_l10n.ingredient_id is not null)::bigint as english_localized_count,
  count(*) filter (where alias_rollup.ingredient_id is not null)::bigint as approved_alias_count
from public.ingredients i
left join public.legacy_ingredient_mapping lm
  on lm.ingredient_id = i.id
left join public.ingredient_localizations it_l10n
  on it_l10n.ingredient_id = i.id
 and it_l10n.language_code = 'it'
left join public.ingredient_localizations en_l10n
  on en_l10n.ingredient_id = i.id
 and en_l10n.language_code = 'en'
left join (
  select distinct a.ingredient_id
  from public.ingredient_aliases_v2 a
  where a.status = 'approved'
    and coalesce(a.is_active, true)
) alias_rollup
  on alias_rollup.ingredient_id = i.id;

create or replace view public.recipe_ingredient_identity_readiness as
with recipe_ingredient_rows as (
  select
    coalesce(nullif(trim(r.source_name), ''), 'unknown') as source_name,
    coalesce(nullif(trim(r.source_type), ''), 'unknown') as source_type,
    r.id::text as recipe_id,
    ingredient.ingredient as ingredient_json
  from public.recipes r
  cross join lateral jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) as ingredient(ingredient)
),
classified as (
  select
    rir.source_name,
    rir.source_type,
    rir.recipe_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'ingredient_id', '')), '')::uuid as ingredient_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'produce_id', '')), '') as produce_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'basic_ingredient_id', '')), '') as basic_ingredient_id
  from recipe_ingredient_rows rir
),
bridged as (
  select
    c.*,
    coalesce(c.ingredient_id, lm_by_produce.ingredient_id, lm_by_basic.ingredient_id) as canonical_ingredient_id,
    case
      when c.ingredient_id is not null then 'modern_ingredient_id'
      when lm_by_produce.ingredient_id is not null or lm_by_basic.ingredient_id is not null then 'legacy_bridge_convertible'
      when c.produce_id is not null or c.basic_ingredient_id is not null then 'legacy_bridge_missing'
      else 'custom_unresolved'
    end as identity_state
  from classified c
  left join public.legacy_ingredient_mapping lm_by_produce
    on lm_by_produce.legacy_produce_id = c.produce_id
  left join public.legacy_ingredient_mapping lm_by_basic
    on lm_by_basic.legacy_basic_id = c.basic_ingredient_id
)
select
  source_name,
  source_type,
  count(distinct recipe_id)::bigint as recipe_count,
  count(*)::bigint as ingredient_row_count,
  count(*) filter (where identity_state = 'modern_ingredient_id')::bigint as modern_ingredient_id_count,
  count(*) filter (where identity_state = 'legacy_bridge_convertible')::bigint as legacy_bridge_convertible_count,
  count(*) filter (where identity_state = 'legacy_bridge_missing')::bigint as legacy_bridge_missing_count,
  count(*) filter (where identity_state = 'custom_unresolved')::bigint as custom_unresolved_count,
  count(*) filter (where canonical_ingredient_id is not null)::bigint as canonical_identity_count,
  round(
    (
      count(*) filter (where canonical_ingredient_id is not null)::numeric
      / nullif(count(*)::numeric, 0)
    ) * 100.0,
    2
  ) as canonical_identity_pct,
  round(
    (
      count(*) filter (where identity_state = 'modern_ingredient_id')::numeric
      / nullif(count(*)::numeric, 0)
    ) * 100.0,
    2
  ) as modern_ingredient_id_pct
from bridged
group by source_name, source_type;

create or replace view public.catalog_duplicate_localization_candidates as
select
  l.language_code,
  lower(trim(l.display_name)) as normalized_display_name,
  count(distinct l.ingredient_id)::bigint as ingredient_count,
  array_agg(distinct i.slug order by i.slug) as slugs,
  array_agg(distinct l.ingredient_id::text order by l.ingredient_id::text) as ingredient_ids
from public.ingredient_localizations l
join public.ingredients i
  on i.id = l.ingredient_id
where nullif(trim(l.display_name), '') is not null
group by l.language_code, lower(trim(l.display_name))
having count(distinct l.ingredient_id) > 1;

grant select on public.catalog_unified_readiness_summary to authenticated;
grant select on public.catalog_unified_readiness_summary to service_role;
grant select on public.recipe_ingredient_identity_readiness to authenticated;
grant select on public.recipe_ingredient_identity_readiness to service_role;
grant select on public.catalog_duplicate_localization_candidates to authenticated;
grant select on public.catalog_duplicate_localization_candidates to service_role;
