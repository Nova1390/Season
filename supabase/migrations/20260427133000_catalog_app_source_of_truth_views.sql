-- App-facing source-of-truth views for the unified ingredient catalog.
--
-- These views expose canonical ingredient records with all attributes needed by
-- app features: display names, nutrition, unit profile, seasonality, hierarchy,
-- and temporary legacy bridge IDs.

create or replace view public.ingredient_catalog_app_summary as
select
  i.id as ingredient_id,
  i.slug,
  i.ingredient_type,
  i.quality_status,
  i.parent_ingredient_id,
  parent.slug as parent_slug,
  i.specificity_rank,
  i.variant_kind,
  i.is_seasonal,
  i.season_months,
  i.default_unit,
  i.supported_units,
  i.grams_per_unit,
  i.ml_per_unit,
  i.grams_per_ml,
  i.calories_per_100g,
  i.protein_per_100g,
  i.carbs_per_100g,
  i.fat_per_100g,
  i.fiber_per_100g,
  i.vitamin_c_per_100g,
  i.potassium_per_100g,
  it_l10n.display_name as it_name,
  it_l10n.short_name as it_short_name,
  en_l10n.display_name as en_name,
  en_l10n.short_name as en_short_name,
  lm.legacy_produce_id,
  lm.legacy_basic_id,
  (i.calories_per_100g is not null
    and i.protein_per_100g is not null
    and i.carbs_per_100g is not null
    and i.fat_per_100g is not null
  ) as has_macro_nutrition,
  (i.default_unit is not null
    and cardinality(coalesce(i.supported_units, '{}'::text[])) > 0
  ) as has_unit_profile,
  (not i.is_seasonal
    or cardinality(coalesce(i.season_months, '{}'::int[])) > 0
  ) as has_required_seasonality
from public.ingredients i
left join public.ingredients parent
  on parent.id = i.parent_ingredient_id
left join public.ingredient_localizations it_l10n
  on it_l10n.ingredient_id = i.id
 and it_l10n.language_code = 'it'
left join public.ingredient_localizations en_l10n
  on en_l10n.ingredient_id = i.id
 and en_l10n.language_code = 'en'
left join public.legacy_ingredient_mapping lm
  on lm.ingredient_id = i.id
where not exists (
  select 1
  from public.ingredient_canonical_redirects r
  where r.ingredient_id = i.id
);

create or replace view public.ingredient_alias_app_summary as
select
  a.id as alias_id,
  a.alias_text,
  a.normalized_alias_text,
  a.language_code,
  coalesce(r.canonical_ingredient_id, a.ingredient_id) as ingredient_id,
  canonical.slug as ingredient_slug,
  a.confidence_score,
  a.confidence,
  a.status,
  coalesce(a.is_active, true) as is_active,
  a.approval_source,
  a.approved_at
from public.ingredient_aliases_v2 a
left join public.ingredient_canonical_redirects r
  on r.ingredient_id = a.ingredient_id
join public.ingredients canonical
  on canonical.id = coalesce(r.canonical_ingredient_id, a.ingredient_id)
where a.status = 'approved'
  and coalesce(a.is_active, true)
  and canonical.quality_status <> 'deprecated_duplicate';

create or replace view public.ingredient_catalog_app_readiness_summary as
select
  count(*)::bigint as app_ingredient_count,
  count(*) filter (where ingredient_type = 'produce')::bigint as produce_count,
  count(*) filter (where ingredient_type = 'basic')::bigint as basic_count,
  count(*) filter (where has_macro_nutrition)::bigint as macro_nutrition_count,
  count(*) filter (where has_unit_profile)::bigint as unit_profile_count,
  count(*) filter (where has_required_seasonality)::bigint as required_seasonality_count,
  count(*) filter (where it_name is not null)::bigint as italian_name_count,
  count(*) filter (where en_name is not null)::bigint as english_name_count,
  count(*) filter (where legacy_produce_id is not null or legacy_basic_id is not null)::bigint as legacy_bridge_count,
  count(*) filter (
    where has_macro_nutrition
      and has_unit_profile
      and has_required_seasonality
      and it_name is not null
      and en_name is not null
  )::bigint as feature_ready_count
from public.ingredient_catalog_app_summary;

grant select on public.ingredient_catalog_app_summary to authenticated;
grant select on public.ingredient_catalog_app_summary to service_role;
grant select on public.ingredient_alias_app_summary to authenticated;
grant select on public.ingredient_alias_app_summary to service_role;
grant select on public.ingredient_catalog_app_readiness_summary to authenticated;
grant select on public.ingredient_catalog_app_readiness_summary to service_role;
