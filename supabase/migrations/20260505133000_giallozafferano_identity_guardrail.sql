-- Read-only guardrail for Giallo Zafferano source-of-truth quality.
--
-- After the cleanup, every Giallo Zafferano recipe ingredient should carry a
-- modern ingredient_id. These views make future regressions visible without
-- blocking imports while the pipeline continues to evolve.

create or replace view public.giallozafferano_ingredient_identity_guardrail as
with ingredient_rows as (
  select
    r.id::text as recipe_id,
    r.title as recipe_title,
    coalesce(nullif(trim(r.source_name), ''), 'unknown') as source_name,
    coalesce(nullif(trim(r.source_type), ''), 'unknown') as source_type,
    i.ordinality::integer as ingredient_index,
    i.ingredient as ingredient_json,
    nullif(trim(i.ingredient ->> 'name'), '') as ingredient_name,
    nullif(trim(i.ingredient ->> 'ingredient_id'), '')::uuid as ingredient_id,
    nullif(trim(i.ingredient ->> 'produce_id'), '') as produce_id,
    nullif(trim(i.ingredient ->> 'basic_ingredient_id'), '') as basic_ingredient_id,
    nullif(trim(i.ingredient ->> 'legacy_produce_id'), '') as legacy_produce_id,
    nullif(trim(i.ingredient ->> 'legacy_basic_ingredient_id'), '') as legacy_basic_ingredient_id
  from public.recipes r
  cross join lateral jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as i(ingredient, ordinality)
  where r.source_name = 'ricette.giallozafferano.it'
),
classified as (
  select
    ir.*,
    c.slug as ingredient_slug,
    case
      when ir.ingredient_id is not null and c.ingredient_id is not null then 'ok_modern_ingredient_id'
      when ir.ingredient_id is not null and c.ingredient_id is null then 'broken_ingredient_id_reference'
      when ir.produce_id is not null or ir.basic_ingredient_id is not null then 'legacy_operational_id_regression'
      else 'custom_unresolved_regression'
    end as guardrail_status
  from ingredient_rows ir
  left join public.ingredient_catalog_app_summary c
    on c.ingredient_id = ir.ingredient_id
)
select
  recipe_id,
  recipe_title,
  source_name,
  source_type,
  ingredient_index,
  ingredient_name,
  ingredient_id,
  ingredient_slug,
  produce_id,
  basic_ingredient_id,
  legacy_produce_id,
  legacy_basic_ingredient_id,
  guardrail_status,
  ingredient_json
from classified;

create or replace view public.giallozafferano_ingredient_identity_guardrail_summary as
select
  count(distinct recipe_id)::bigint as recipe_count,
  count(*)::bigint as ingredient_row_count,
  count(*) filter (where guardrail_status = 'ok_modern_ingredient_id')::bigint as ok_modern_ingredient_id_count,
  count(*) filter (where guardrail_status = 'broken_ingredient_id_reference')::bigint as broken_ingredient_id_reference_count,
  count(*) filter (where guardrail_status = 'legacy_operational_id_regression')::bigint as legacy_operational_id_regression_count,
  count(*) filter (where guardrail_status = 'custom_unresolved_regression')::bigint as custom_unresolved_regression_count,
  count(*) filter (where guardrail_status <> 'ok_modern_ingredient_id')::bigint as violation_count,
  round(
    (
      count(*) filter (where guardrail_status = 'ok_modern_ingredient_id')::numeric
      / nullif(count(*)::numeric, 0)
    ) * 100.0,
    2
  ) as ok_modern_ingredient_id_pct
from public.giallozafferano_ingredient_identity_guardrail;

grant select on public.giallozafferano_ingredient_identity_guardrail to authenticated;
grant select on public.giallozafferano_ingredient_identity_guardrail to service_role;
grant select on public.giallozafferano_ingredient_identity_guardrail_summary to authenticated;
grant select on public.giallozafferano_ingredient_identity_guardrail_summary to service_role;
