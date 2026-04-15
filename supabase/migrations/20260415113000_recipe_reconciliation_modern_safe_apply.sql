create or replace function public.apply_recipe_ingredient_reconciliation_modern(
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
  rec record;
begin
  perform public.assert_catalog_admin(v_user);

  for rec in
    select
      p.recipe_id,
      p.recipe_ingredient_row_id,
      p.ingredient_index,
      p.matched_ingredient_id,
      p.match_source
    from public.recipe_ingredient_reconciliation_safety_preview p
    where p.safe_to_apply = true
      and p.match_source in ('approved_alias', 'canonical_localization')
      and (
        p_recipe_ids is null
        or cardinality(p_recipe_ids) = 0
        or p.recipe_id = any(p_recipe_ids)
      )
    order by p.recipe_id asc, p.ingredient_index asc
    limit v_limit
  loop
    if rec.matched_ingredient_id is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'matched_ingredient_missing'::text;
      continue;
    end if;

    select r.ingredients::jsonb
    into v_recipe_ingredients
    from public.recipes r
    where r.id::text = rec.recipe_id
    for update;

    if v_recipe_ingredients is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'recipe_not_found_or_no_ingredients'::text;
      continue;
    end if;

    select e.elem
    into v_old_ingredient
    from jsonb_array_elements(v_recipe_ingredients) with ordinality as e(elem, ord)
    where e.ord = rec.ingredient_index;

    if v_old_ingredient is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'ingredient_index_not_found'::text;
      continue;
    end if;

    if nullif(trim(coalesce(v_old_ingredient ->> 'produce_id', '')), '') is not null
       or nullif(trim(coalesce(v_old_ingredient ->> 'basic_ingredient_id', '')), '') is not null
       or nullif(trim(coalesce(v_old_ingredient ->> 'ingredient_id', '')), '') is not null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'already_resolved'::text;
      continue;
    end if;

    v_new_ingredient :=
      (v_old_ingredient - 'produce_id' - 'basic_ingredient_id' - 'ingredient_id')
      || jsonb_build_object(
        'ingredient_id', to_jsonb(rec.matched_ingredient_id::text)
      );

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
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'failed_to_build_updated_ingredients'::text;
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
      rec.matched_ingredient_id,
      rec.match_source,
      null,
      null,
      v_old_ingredient,
      v_new_ingredient,
      v_now,
      v_user,
      'phase2_modern_safe_apply',
      v_now,
      v_now
    );

    return query
    select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, true, 'applied'::text;
  end loop;
end;
$$;

revoke all on function public.apply_recipe_ingredient_reconciliation_modern(integer, text[]) from public;
grant execute on function public.apply_recipe_ingredient_reconciliation_modern(integer, text[]) to authenticated;
grant execute on function public.apply_recipe_ingredient_reconciliation_modern(integer, text[]) to service_role;
