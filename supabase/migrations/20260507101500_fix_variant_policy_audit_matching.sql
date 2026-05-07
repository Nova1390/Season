-- Fix qualifier matching in the policy audit views.
-- PostgreSQL regex "\b" is not a portable word-boundary marker for these
-- strings, so use explicit ILIKE patterns for deterministic classification.

create or replace view public.giallozafferano_variant_policy_audit as
select
  recipe_id,
  recipe_title,
  ingredient_index,
  ingredient_name,
  normalized_text,
  golden_canonical_ingredient_id,
  golden_ingredient_slug,
  replay_target_id as base_catalog_ingredient_id,
  replay_target_slug as base_catalog_slug,
  case
    when ingredient_name ilike '%a temperatura ambiente%'
      or ingredient_name ilike '%ammorbidit%'
      then 'preparation_state'
    when ingredient_name ilike '%da grattugiare%'
      then 'usage_instruction'
    when ingredient_name ilike '%a pasta gialla%'
      then 'catalog_variant_candidate'
    when ingredient_name ilike '%di uova medie%'
      then 'source_or_size_note'
    else 'manual_review'
  end as qualifier_type,
  case
    when ingredient_name ilike '%a temperatura ambiente%'
      then 'a temperatura ambiente'
    when ingredient_name ilike '%ammorbidit%'
      then 'ammorbidito'
    when ingredient_name ilike '%da grattugiare%'
      then 'da grattugiare'
    when ingredient_name ilike '%a pasta gialla%'
      then 'a pasta gialla'
    when ingredient_name ilike '%di uova medie%'
      then 'di uova medie'
    else null
  end as extracted_qualifier,
  case
    when ingredient_name ilike '%a temperatura ambiente%'
      or ingredient_name ilike '%ammorbidit%'
      or ingredient_name ilike '%da grattugiare%'
      or ingredient_name ilike '%di uova medie%'
      then 'map_recipe_to_base_catalog_item_and_preserve_qualifier_on_recipe_row'
    when ingredient_name ilike '%a pasta gialla%'
      then 'review_as_true_catalog_variant_or_recipe_attribute'
    else 'manual_review_required'
  end as recommended_policy,
  case
    when ingredient_name ilike '%a temperatura ambiente%'
      or ingredient_name ilike '%ammorbidit%'
      then 'preparation_note'
    when ingredient_name ilike '%da grattugiare%'
      then 'usage_note'
    when ingredient_name ilike '%di uova medie%'
      then 'source_or_size_note'
    when ingredient_name ilike '%a pasta gialla%'
      then 'variant_note_or_catalog_child'
    else null
  end as proposed_recipe_attribute,
  case
    when ingredient_name ilike '%a temperatura ambiente%'
      or ingredient_name ilike '%ammorbidit%'
      or ingredient_name ilike '%da grattugiare%'
      or ingredient_name ilike '%di uova medie%'
      then 'Do not create/keep a separate catalog ingredient only for this qualifier; keep nutrition, filters, fridge matching, and shopping matching on the base catalog item.'
    when ingredient_name ilike '%a pasta gialla%'
      then 'Potentially valid catalog child variant because it describes a product type, but it needs explicit parent/base matching rules so generic potatoes in the fridge can still satisfy it.'
    else 'Needs manual review before deciding catalog identity.'
  end as policy_rationale,
  ingredient_json
from public.giallozafferano_autopilot_replay_audit
where gap_category = 'qualifier_variant_collapses_to_base';

create or replace view public.giallozafferano_variant_policy_summary as
select
  qualifier_type,
  recommended_policy,
  proposed_recipe_attribute,
  count(*)::bigint as ingredient_row_count,
  count(distinct normalized_text)::bigint as distinct_base_text_count,
  array_agg(distinct normalized_text order by normalized_text) as normalized_texts,
  array_agg(distinct golden_ingredient_slug order by golden_ingredient_slug) as current_variant_slugs
from public.giallozafferano_variant_policy_audit
group by qualifier_type, recommended_policy, proposed_recipe_attribute;

grant select on public.giallozafferano_variant_policy_audit to authenticated;
grant select on public.giallozafferano_variant_policy_audit to service_role;
grant select on public.giallozafferano_variant_policy_summary to authenticated;
grant select on public.giallozafferano_variant_policy_summary to service_role;
