-- Resolve the obvious Giallo Zafferano breadcrumb wording as an alias of bread.
-- Scope is intentionally tiny: one approved alias and one safe reconciliation pass.

do $$
declare
  v_now timestamptz := now();
  v_batch_id uuid := gen_random_uuid();
  v_bread_id uuid;
  v_recipe_ingredients jsonb;
  v_old_ingredient jsonb;
  v_new_ingredient jsonb;
  v_new_ingredients jsonb;
  rec record;
begin
  select c.ingredient_id
  into v_bread_id
  from public.ingredient_catalog_app_summary c
  where c.slug = 'bread'
  limit 1;

  if v_bread_id is null then
    raise notice 'bread canonical ingredient not found; skipping pane mollica alias migration';
    return;
  end if;

  insert into public.ingredient_aliases_v2 (
    ingredient_id,
    alias_text,
    normalized_alias_text,
    language_code,
    source,
    confidence,
    confidence_score,
    is_active,
    status,
    approval_source,
    approved_at,
    review_notes,
    created_at,
    updated_at
  )
  values (
    v_bread_id,
    'Pane mollica',
    'pane mollica',
    'it',
    'manual',
    0.95,
    0.95,
    true,
    'approved',
    'manual',
    v_now,
    'safe_alias_from_giallozafferano_residual_custom_review',
    v_now,
    v_now
  )
  on conflict (normalized_alias_text) where is_active = true do update
  set
    ingredient_id = excluded.ingredient_id,
    alias_text = excluded.alias_text,
    language_code = excluded.language_code,
    source = excluded.source,
    confidence = excluded.confidence,
    confidence_score = excluded.confidence_score,
    status = 'approved',
    approval_source = excluded.approval_source,
    approved_at = coalesce(public.ingredient_aliases_v2.approved_at, excluded.approved_at),
    review_notes = excluded.review_notes,
    updated_at = excluded.updated_at;

  update public.custom_ingredient_observations as o
  set
    status = 'resolved_alias',
    updated_at = v_now
  where o.normalized_text = 'pane mollica';

  insert into public.catalog_candidate_decisions (
    normalized_text,
    action,
    ingredient_id,
    alias_text,
    language_code,
    confidence_score,
    reviewer_note,
    resulting_observation_status,
    resulting_alias_status,
    created_at,
    updated_at
  )
  select
    'pane mollica',
    'approve_alias',
    v_bread_id,
    'Pane mollica',
    'it',
    0.95,
    'safe_alias_from_giallozafferano_residual_custom_review',
    'resolved_alias',
    'approved',
    v_now,
    v_now
  where not exists (
    select 1
    from public.catalog_candidate_decisions d
    where d.normalized_text = 'pane mollica'
      and d.ingredient_id = v_bread_id
      and d.action = 'approve_alias'
  );

  for rec in
    select
      p.recipe_id,
      p.recipe_ingredient_row_id,
      p.ingredient_index,
      p.matched_ingredient_id,
      p.match_source
    from public.recipe_ingredient_reconciliation_safety_preview p
    join public.recipes r
      on r.id::text = p.recipe_id
    where r.source_name = 'ricette.giallozafferano.it'
      and p.reconciliation_match_text = 'pane mollica'
      and p.safe_to_apply
      and p.matched_ingredient_id = v_bread_id
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

    if nullif(trim(coalesce(v_old_ingredient ->> 'produce_id', '')), '') is not null
       or nullif(trim(coalesce(v_old_ingredient ->> 'basic_ingredient_id', '')), '') is not null
       or nullif(trim(coalesce(v_old_ingredient ->> 'ingredient_id', '')), '') is not null then
      continue;
    end if;

    v_new_ingredient :=
      (v_old_ingredient - 'produce_id' - 'basic_ingredient_id' - 'ingredient_id')
      || jsonb_build_object('ingredient_id', to_jsonb(v_bread_id::text));

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
      v_bread_id,
      rec.match_source,
      null,
      null,
      v_old_ingredient,
      v_new_ingredient,
      v_now,
      'giallozafferano_breadcrumb_alias_safe_apply',
      v_now,
      v_now
    );
  end loop;
end;
$$;
