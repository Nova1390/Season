-- Policy decision: "patate a pasta gialla" is not a separate catalog item for
-- Season. Keep recipe/fridge/nutrition identity on base potatoes and preserve
-- the descriptor on the recipe row. Truly distinct ingredients such as sweet
-- potatoes should remain separate catalog items.

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
      then 'product_descriptor'
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
      or ingredient_name ilike '%a pasta gialla%'
      then 'map_recipe_to_base_catalog_item_and_preserve_qualifier_on_recipe_row'
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
      then 'variant_note'
    else null
  end as proposed_recipe_attribute,
  case
    when ingredient_name ilike '%a pasta gialla%'
      then 'Product descriptor for regular potatoes; keep catalog identity on potato. Sweet potatoes remain a separate ingredient because they are nutritionally and culinarily distinct.'
    when ingredient_name ilike '%a temperatura ambiente%'
      or ingredient_name ilike '%ammorbidit%'
      or ingredient_name ilike '%da grattugiare%'
      or ingredient_name ilike '%di uova medie%'
      then 'Do not create/keep a separate catalog ingredient only for this qualifier; keep nutrition, filters, fridge matching, and shopping matching on the base catalog item.'
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

create or replace view public.recipe_ingredient_qualifier_reconciliation_preview as
with recipe_ingredient_rows as (
  select
    r.id::text as recipe_id,
    r.title as recipe_title,
    r.source_name,
    i.ingredient as ingredient_json,
    i.ordinality::integer as ingredient_index,
    nullif(trim(i.ingredient ->> 'name'), '') as ingredient_name,
    public.normalize_recipe_ingredient_text_for_matching(i.ingredient ->> 'name') as normalized_text,
    nullif(trim(i.ingredient ->> 'produce_id'), '') as produce_id,
    nullif(trim(i.ingredient ->> 'basic_ingredient_id'), '') as basic_ingredient_id,
    case
      when nullif(trim(i.ingredient ->> 'ingredient_id'), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then nullif(trim(i.ingredient ->> 'ingredient_id'), '')::uuid
      else null
    end as current_ingredient_id
  from public.recipes r
  cross join lateral jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as i(ingredient, ordinality)
),
classified as (
  select
    rir.*,
    current_i.slug as current_ingredient_slug,
    coalesce(redirects.canonical_ingredient_id, rir.current_ingredient_id) as current_canonical_ingredient_id,
    case
      when rir.ingredient_name ilike '%a temperatura ambiente%'
        or rir.ingredient_name ilike '%ammorbidit%'
        then 'preparation_state'
      when rir.ingredient_name ilike '%da grattugiare%'
        then 'usage_instruction'
      when rir.ingredient_name ilike '%a pasta gialla%'
        then 'product_descriptor'
      when rir.ingredient_name ilike '%di uova medie%'
        then 'source_or_size_note'
      else 'none'
    end as qualifier_type,
    case
      when rir.ingredient_name ilike '%a temperatura ambiente%'
        then 'a temperatura ambiente'
      when rir.ingredient_name ilike '%ammorbidit%'
        then 'ammorbidito'
      when rir.ingredient_name ilike '%da grattugiare%'
        then 'da grattugiare'
      when rir.ingredient_name ilike '%a pasta gialla%'
        then 'a pasta gialla'
      when rir.ingredient_name ilike '%di uova medie%'
        then 'di uova medie'
      else null
    end as extracted_qualifier,
    case
      when rir.ingredient_name ilike '%a temperatura ambiente%'
        or rir.ingredient_name ilike '%ammorbidit%'
        then 'preparation_note'
      when rir.ingredient_name ilike '%da grattugiare%'
        then 'usage_note'
      when rir.ingredient_name ilike '%di uova medie%'
        then 'source_or_size_note'
      when rir.ingredient_name ilike '%a pasta gialla%'
        then 'variant_note'
      else null
    end as proposed_recipe_attribute
  from recipe_ingredient_rows rir
  left join public.ingredients current_i
    on current_i.id = rir.current_ingredient_id
  left join public.ingredient_canonical_redirects redirects
    on redirects.ingredient_id = rir.current_ingredient_id
),
alias_matches as (
  select
    c.recipe_id,
    c.ingredient_index,
    count(distinct a.ingredient_id)::integer as alias_target_count,
    (array_agg(distinct a.ingredient_id::text order by a.ingredient_id::text))[1]::uuid as alias_target_id,
    (array_agg(distinct a.ingredient_slug order by a.ingredient_slug))[1] as alias_target_slug
  from classified c
  left join public.ingredient_alias_app_summary a
    on a.normalized_alias_text = c.normalized_text
  group by c.recipe_id, c.ingredient_index
),
localization_matches as (
  select
    c.recipe_id,
    c.ingredient_index,
    count(distinct catalog.ingredient_id)::integer as localization_target_count,
    (array_agg(distinct catalog.ingredient_id::text order by catalog.ingredient_id::text))[1]::uuid as localization_target_id,
    (array_agg(distinct catalog.slug order by catalog.slug))[1] as localization_target_slug
  from classified c
  left join public.ingredient_catalog_app_summary catalog
    on lower(trim(catalog.it_name)) = c.normalized_text
    or lower(trim(catalog.en_name)) = c.normalized_text
  group by c.recipe_id, c.ingredient_index
),
resolved as (
  select
    c.*,
    case
      when am.alias_target_count = 1 then am.alias_target_id
      when am.alias_target_count = 0 and lm.localization_target_count = 1 then lm.localization_target_id
      else null
    end as base_catalog_ingredient_id,
    case
      when am.alias_target_count = 1 then am.alias_target_slug
      when am.alias_target_count = 0 and lm.localization_target_count = 1 then lm.localization_target_slug
      else null
    end as base_catalog_slug,
    case
      when am.alias_target_count = 1 then 'approved_alias'
      when am.alias_target_count > 1 then 'ambiguous_alias'
      when lm.localization_target_count = 1 then 'canonical_localization'
      when lm.localization_target_count > 1 then 'ambiguous_localization'
      else 'none'
    end as match_source,
    coalesce(am.alias_target_count, 0) as alias_target_count,
    coalesce(lm.localization_target_count, 0) as localization_target_count
  from classified c
  join alias_matches am
    on am.recipe_id = c.recipe_id
   and am.ingredient_index = c.ingredient_index
  join localization_matches lm
    on lm.recipe_id = c.recipe_id
   and lm.ingredient_index = c.ingredient_index
),
actionable as (
  select
    r.*,
    case r.proposed_recipe_attribute
      when 'preparation_note' then nullif(trim(coalesce(r.ingredient_json ->> 'preparation_note', '')), '') is null
      when 'usage_note' then nullif(trim(coalesce(r.ingredient_json ->> 'usage_note', '')), '') is null
      when 'source_or_size_note' then nullif(trim(coalesce(r.ingredient_json ->> 'source_or_size_note', '')), '') is null
      when 'variant_note' then nullif(trim(coalesce(r.ingredient_json ->> 'variant_note', '')), '') is null
      else false
    end as qualifier_note_missing,
    (
      r.current_ingredient_id is not null
      and (
        r.current_ingredient_slug ilike '%_a_temperatura_ambiente'
        or r.current_ingredient_slug ilike '%_ammorbidit%'
        or r.current_ingredient_slug ilike '%_da_grattugiare'
        or r.current_ingredient_slug ilike '%_duovo'
        or r.current_ingredient_slug ilike '%_a_pasta_gialla'
      )
    ) as current_is_collapsible_qualifier_variant
  from resolved r
)
select
  recipe_id,
  (recipe_id || '#' || ingredient_index::text) as recipe_ingredient_row_id,
  recipe_title,
  source_name,
  ingredient_index,
  ingredient_name,
  normalized_text,
  qualifier_type,
  extracted_qualifier,
  proposed_recipe_attribute,
  current_ingredient_id,
  current_ingredient_slug,
  current_canonical_ingredient_id,
  base_catalog_ingredient_id,
  base_catalog_slug,
  ('qualifier_' || match_source) as match_source,
  (
    qualifier_type in ('preparation_state', 'usage_instruction', 'source_or_size_note', 'product_descriptor')
    and extracted_qualifier is not null
    and proposed_recipe_attribute is not null
    and base_catalog_ingredient_id is not null
    and match_source in ('approved_alias', 'canonical_localization')
    and (
      (
        current_ingredient_id is null
        and produce_id is null
        and basic_ingredient_id is null
      )
      or (
        current_canonical_ingredient_id = base_catalog_ingredient_id
        and qualifier_note_missing
      )
      or (
        current_is_collapsible_qualifier_variant
        and (
          current_canonical_ingredient_id is distinct from base_catalog_ingredient_id
          or qualifier_note_missing
        )
      )
    )
  ) as safe_to_apply,
  case
    when qualifier_type = 'none' then 'no_qualifier'
    when base_catalog_ingredient_id is null then 'no_base_catalog_match'
    when match_source not in ('approved_alias', 'canonical_localization') then match_source
    when current_ingredient_id is null and (produce_id is not null or basic_ingredient_id is not null) then 'legacy_resolved_row'
    when current_ingredient_id is null then 'safe_unresolved_row'
    when current_canonical_ingredient_id = base_catalog_ingredient_id and qualifier_note_missing then 'safe_add_missing_qualifier_note'
    when current_canonical_ingredient_id = base_catalog_ingredient_id then 'already_base_with_qualifier_policy'
    when current_is_collapsible_qualifier_variant and qualifier_type = 'product_descriptor' then 'safe_collapse_product_descriptor_to_base'
    when current_is_collapsible_qualifier_variant then 'safe_collapse_qualifier_variant_to_base'
    else 'current_ingredient_conflicts_with_base_match'
  end as safety_reason,
  ingredient_json
from actionable;

grant select on public.giallozafferano_variant_policy_audit to authenticated;
grant select on public.giallozafferano_variant_policy_audit to service_role;
grant select on public.giallozafferano_variant_policy_summary to authenticated;
grant select on public.giallozafferano_variant_policy_summary to service_role;
grant select on public.recipe_ingredient_qualifier_reconciliation_preview to authenticated;
grant select on public.recipe_ingredient_qualifier_reconciliation_preview to service_role;
