-- Autopilot qualifier reconciliation.
--
-- This turns the variant-policy audit into a reusable automation primitive:
-- recipe-specific qualifiers such as "ammorbidito", "a temperatura ambiente",
-- "da grattugiare", or "di uova medie" are preserved on the recipe row while
-- catalog identity is kept on the base ingredient. True product variants such
-- as "patate a pasta gialla" are intentionally excluded for review.

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
        then 'catalog_variant_candidate'
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
      else false
    end as qualifier_note_missing,
    (
      r.current_ingredient_id is not null
      and (
        r.current_ingredient_slug ilike '%_a_temperatura_ambiente'
        or r.current_ingredient_slug ilike '%_ammorbidit%'
        or r.current_ingredient_slug ilike '%_da_grattugiare'
        or r.current_ingredient_slug ilike '%_duovo'
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
    qualifier_type in ('preparation_state', 'usage_instruction', 'source_or_size_note')
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
    when qualifier_type = 'catalog_variant_candidate' then 'catalog_variant_requires_review'
    when base_catalog_ingredient_id is null then 'no_base_catalog_match'
    when match_source not in ('approved_alias', 'canonical_localization') then match_source
    when current_ingredient_id is null and (produce_id is not null or basic_ingredient_id is not null) then 'legacy_resolved_row'
    when current_ingredient_id is null then 'safe_unresolved_row'
    when current_canonical_ingredient_id = base_catalog_ingredient_id and qualifier_note_missing then 'safe_add_missing_qualifier_note'
    when current_canonical_ingredient_id = base_catalog_ingredient_id then 'already_base_with_qualifier_policy'
    when current_is_collapsible_qualifier_variant then 'safe_collapse_qualifier_variant_to_base'
    else 'current_ingredient_conflicts_with_base_match'
  end as safety_reason,
  ingredient_json
from actionable;

create or replace function public.preview_recipe_ingredient_qualifier_reconciliation(
  p_limit integer default 100,
  p_only_safe boolean default true
)
returns setof public.recipe_ingredient_qualifier_reconciliation_preview
language sql
security definer
set search_path = public
as $$
  select *
  from public.recipe_ingredient_qualifier_reconciliation_preview p
  where (not coalesce(p_only_safe, true) or p.safe_to_apply)
  order by p.recipe_id asc, p.ingredient_index asc
  limit greatest(1, coalesce(p_limit, 100));
$$;

create or replace function public.apply_recipe_ingredient_qualifier_reconciliation(
  p_limit integer default 100,
  p_recipe_ids text[] default null
)
returns table (
  batch_id uuid,
  recipe_id text,
  recipe_ingredient_row_id text,
  ingredient_index integer,
  matched_ingredient_id uuid,
  match_source text,
  applied boolean,
  apply_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch_id uuid := gen_random_uuid();
  v_user uuid := auth.uid();
  v_now timestamptz := now();
  v_limit integer := greatest(1, coalesce(p_limit, 100));
  v_recipe_ingredients jsonb;
  v_old_ingredient jsonb;
  v_new_ingredient jsonb;
  v_new_ingredients jsonb;
  v_current_ingredient_text text;
  v_current_ingredient_id uuid;
  rec record;
begin
  perform public.assert_catalog_admin(v_user);

  for rec in
    select *
    from public.recipe_ingredient_qualifier_reconciliation_preview p
    where p.safe_to_apply = true
      and (
        p_recipe_ids is null
        or cardinality(p_recipe_ids) = 0
        or p.recipe_id = any(p_recipe_ids)
      )
    order by p.recipe_id asc, p.ingredient_index asc
    limit v_limit
  loop
    if rec.base_catalog_ingredient_id is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.base_catalog_ingredient_id, rec.match_source, false, 'base_catalog_ingredient_missing'::text;
      continue;
    end if;

    select r.ingredients::jsonb
    into v_recipe_ingredients
    from public.recipes r
    where r.id::text = rec.recipe_id
    for update;

    if v_recipe_ingredients is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.base_catalog_ingredient_id, rec.match_source, false, 'recipe_not_found_or_no_ingredients'::text;
      continue;
    end if;

    select e.elem
    into v_old_ingredient
    from jsonb_array_elements(v_recipe_ingredients) with ordinality as e(elem, ord)
    where e.ord = rec.ingredient_index;

    if v_old_ingredient is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.base_catalog_ingredient_id, rec.match_source, false, 'ingredient_index_not_found'::text;
      continue;
    end if;

    v_current_ingredient_text := nullif(trim(v_old_ingredient ->> 'ingredient_id'), '');
    v_current_ingredient_id := case
      when v_current_ingredient_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then v_current_ingredient_text::uuid
      else null
    end;

    if rec.current_ingredient_id is null then
      if nullif(trim(coalesce(v_old_ingredient ->> 'produce_id', '')), '') is not null
         or nullif(trim(coalesce(v_old_ingredient ->> 'basic_ingredient_id', '')), '') is not null
         or v_current_ingredient_id is not null then
        return query
        select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.base_catalog_ingredient_id, rec.match_source, false, 'row_changed_or_already_resolved'::text;
        continue;
      end if;
    elsif v_current_ingredient_id is distinct from rec.current_ingredient_id then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.base_catalog_ingredient_id, rec.match_source, false, 'row_changed'::text;
      continue;
    end if;

    v_new_ingredient :=
      (v_old_ingredient - 'produce_id' - 'basic_ingredient_id' - 'ingredient_id')
      || jsonb_build_object(
        'ingredient_id', to_jsonb(rec.base_catalog_ingredient_id::text)
      );

    if rec.proposed_recipe_attribute is not null
       and rec.extracted_qualifier is not null
       and nullif(trim(coalesce(v_old_ingredient ->> rec.proposed_recipe_attribute, '')), '') is null then
      v_new_ingredient :=
        v_new_ingredient
        || jsonb_build_object(rec.proposed_recipe_attribute, rec.extracted_qualifier);
    end if;

    select jsonb_agg(
      case
        when e.ord = rec.ingredient_index then v_new_ingredient
        else e.elem
      end
      order by e.ord
    )
    into v_new_ingredients
    from jsonb_array_elements(v_recipe_ingredients) with ordinality as e(elem, ord);

    if v_new_ingredients is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.base_catalog_ingredient_id, rec.match_source, false, 'failed_to_build_updated_ingredients'::text;
      continue;
    end if;

    update public.recipes
    set ingredients = v_new_ingredients
    where id::text = rec.recipe_id;

    insert into public.recipe_ingredient_reconciliation_audit (
      batch_id,
      recipe_id,
      recipe_ingredient_row_id,
      ingredient_index,
      matched_ingredient_id,
      match_source,
      legacy_produce_id,
      legacy_basic_id,
      previous_ingredient_json,
      updated_ingredient_json,
      applied_at,
      applied_by,
      mechanism,
      created_at,
      updated_at
    )
    values (
      v_batch_id,
      rec.recipe_id,
      rec.recipe_ingredient_row_id,
      rec.ingredient_index,
      rec.base_catalog_ingredient_id,
      rec.match_source,
      nullif(trim(coalesce(v_old_ingredient ->> 'produce_id', '')), ''),
      nullif(trim(coalesce(v_old_ingredient ->> 'basic_ingredient_id', '')), ''),
      v_old_ingredient,
      v_new_ingredient,
      v_now,
      v_user,
      'qualifier_base_safe_apply',
      v_now,
      v_now
    );

    return query
    select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.base_catalog_ingredient_id, rec.match_source, true, 'applied'::text;
  end loop;
end;
$$;

grant select on public.recipe_ingredient_qualifier_reconciliation_preview to authenticated;
grant select on public.recipe_ingredient_qualifier_reconciliation_preview to service_role;
revoke all on function public.preview_recipe_ingredient_qualifier_reconciliation(integer, boolean) from public;
grant execute on function public.preview_recipe_ingredient_qualifier_reconciliation(integer, boolean) to authenticated;
grant execute on function public.preview_recipe_ingredient_qualifier_reconciliation(integer, boolean) to service_role;
revoke all on function public.apply_recipe_ingredient_qualifier_reconciliation(integer, text[]) from public;
grant execute on function public.apply_recipe_ingredient_qualifier_reconciliation(integer, text[]) to authenticated;
grant execute on function public.apply_recipe_ingredient_qualifier_reconciliation(integer, text[]) to service_role;
