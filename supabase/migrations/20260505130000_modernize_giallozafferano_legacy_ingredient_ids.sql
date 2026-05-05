-- Modernize Giallo Zafferano recipe ingredient identity.
--
-- Moves legacy produce_id/basic_ingredient_id rows to ingredient_id while
-- preserving the previous identifiers as legacy_* metadata for traceability.

do $$
declare
  v_now timestamptz := now();
  v_batch_id uuid := gen_random_uuid();
  v_recipe_ingredients jsonb;
  v_new_ingredients jsonb;
  v_old_ingredient jsonb;
  v_new_ingredient jsonb;
  rec record;
begin
  for rec in
    with legacy_rows as (
      select
        r.id::text as recipe_id,
        i.ordinality::int as ingredient_index,
        i.ingredient as ingredient_json,
        nullif(trim(i.ingredient ->> 'produce_id'), '') as produce_id,
        nullif(trim(i.ingredient ->> 'basic_ingredient_id'), '') as basic_ingredient_id
      from public.recipes r
      cross join lateral jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as i(ingredient, ordinality)
      where r.source_name = 'ricette.giallozafferano.it'
        and nullif(trim(i.ingredient ->> 'ingredient_id'), '') is null
        and (
          nullif(trim(i.ingredient ->> 'produce_id'), '') is not null
          or nullif(trim(i.ingredient ->> 'basic_ingredient_id'), '') is not null
        )
    )
    select
      l.recipe_id,
      (l.recipe_id || '#' || l.ingredient_index::text) as recipe_ingredient_row_id,
      l.ingredient_index,
      l.ingredient_json,
      l.produce_id,
      l.basic_ingredient_id,
      coalesce(mp.ingredient_id, mb.ingredient_id) as mapped_ingredient_id,
      case
        when mp.ingredient_id is not null then 'legacy_produce_bridge'
        when mb.ingredient_id is not null then 'legacy_basic_bridge'
        else 'missing_legacy_bridge'
      end as match_source
    from legacy_rows l
    left join public.legacy_ingredient_mapping mp
      on mp.legacy_produce_id = l.produce_id
    left join public.legacy_ingredient_mapping mb
      on mb.legacy_basic_id = l.basic_ingredient_id
    where coalesce(mp.ingredient_id, mb.ingredient_id) is not null
    order by l.recipe_id asc, l.ingredient_index asc
  loop
    select r.ingredients::jsonb
    into v_recipe_ingredients
    from public.recipes r
    where r.id::text = rec.recipe_id
    for update;

    select e.elem
    into v_old_ingredient
    from jsonb_array_elements(v_recipe_ingredients) with ordinality as e(elem, ord)
    where e.ord = rec.ingredient_index;

    if v_old_ingredient is null then
      continue;
    end if;

    if nullif(trim(coalesce(v_old_ingredient ->> 'ingredient_id', '')), '') is not null then
      continue;
    end if;

    v_new_ingredient :=
      (v_old_ingredient - 'produce_id' - 'basic_ingredient_id' - 'ingredient_id')
      || jsonb_build_object('ingredient_id', rec.mapped_ingredient_id::text);

    if rec.produce_id is not null then
      v_new_ingredient := v_new_ingredient || jsonb_build_object('legacy_produce_id', rec.produce_id);
    end if;

    if rec.basic_ingredient_id is not null then
      v_new_ingredient := v_new_ingredient || jsonb_build_object('legacy_basic_ingredient_id', rec.basic_ingredient_id);
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
      mechanism,
      created_at,
      updated_at
    )
    values (
      v_batch_id,
      rec.recipe_id,
      rec.recipe_ingredient_row_id,
      rec.ingredient_index,
      rec.mapped_ingredient_id,
      rec.match_source,
      rec.produce_id,
      rec.basic_ingredient_id,
      v_old_ingredient,
      v_new_ingredient,
      v_now,
      'giallozafferano_legacy_bridge_modernization',
      v_now,
      v_now
    );
  end loop;
end;
$$;
