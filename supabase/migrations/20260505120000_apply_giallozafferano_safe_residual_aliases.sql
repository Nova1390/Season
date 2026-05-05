-- Resolve the safest remaining Giallo Zafferano residuals as aliases to
-- canonical ingredients already present in the catalog.
--
-- These are intentionally coarse but feature-safe mappings:
-- - recipe wording remains in the recipe ingredient name;
-- - fridge/nutrition/filter identity uses the canonical catalog item.

do $$
declare
  v_now timestamptz := now();
  v_batch_id uuid := gen_random_uuid();
  v_recipe_ingredients jsonb;
  v_old_ingredient jsonb;
  v_new_ingredient jsonb;
  v_new_ingredients jsonb;
  rec record;
begin
  create temp table _safe_residual_aliases (
    normalized_text text primary key,
    alias_text text not null,
    target_slug text not null,
    confidence_score double precision not null
  ) on commit drop;

  insert into _safe_residual_aliases (
    normalized_text,
    alias_text,
    target_slug,
    confidence_score
  )
  values
    ('frutti di cappero', 'Frutti di cappero', 'capers', 0.86),
    ('pecorino romano dop stagionatura media', 'Pecorino Romano DOP stagionatura media', 'pecorino', 0.88),
    ('sale grosso per le vongole', 'Sale grosso per le vongole', 'salt', 0.9),
    ('sedani rigati', 'Sedani rigati', 'pasta', 0.82),
    ('uova possibilmente biologiche', 'Uova possibilmente biologiche', 'eggs', 0.92);

  if exists (
    select 1
    from _safe_residual_aliases a
    left join public.ingredient_catalog_app_summary c
      on c.slug = a.target_slug
    where c.ingredient_id is null
  ) then
    raise exception 'missing canonical target for one or more safe residual aliases';
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
  select
    c.ingredient_id,
    a.alias_text,
    a.normalized_text,
    'it',
    'manual_review',
    a.confidence_score,
    a.confidence_score,
    true,
    'approved',
    'manual',
    v_now,
    'safe_alias_from_giallozafferano_residual_cleanup',
    v_now,
    v_now
  from _safe_residual_aliases a
  join public.ingredient_catalog_app_summary c
    on c.slug = a.target_slug
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

  insert into public.custom_ingredient_observations (
    normalized_text,
    raw_examples,
    language_code,
    source,
    occurrence_count,
    status,
    first_seen_at,
    last_seen_at,
    updated_at
  )
  select
    a.normalized_text,
    jsonb_build_array(a.alias_text),
    'it',
    'giallozafferano_safe_residual_aliases',
    1,
    'resolved_alias',
    v_now,
    v_now,
    v_now
  from _safe_residual_aliases a
  on conflict (normalized_text) do update
  set
    status = 'resolved_alias',
    updated_at = excluded.updated_at;

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
    a.normalized_text,
    'approve_alias',
    c.ingredient_id,
    a.alias_text,
    'it',
    a.confidence_score,
    'safe_alias_from_giallozafferano_residual_cleanup',
    'resolved_alias',
    'approved',
    v_now,
    v_now
  from _safe_residual_aliases a
  join public.ingredient_catalog_app_summary c
    on c.slug = a.target_slug
  where not exists (
    select 1
    from public.catalog_candidate_decisions d
    where d.normalized_text = a.normalized_text
      and d.ingredient_id = c.ingredient_id
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
    join _safe_residual_aliases a
      on a.normalized_text = p.reconciliation_match_text
    where r.source_name = 'ricette.giallozafferano.it'
      and p.safe_to_apply
      and p.match_source in ('approved_alias', 'canonical_localization')
    order by p.recipe_id asc, p.ingredient_index asc
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
      || jsonb_build_object('ingredient_id', to_jsonb(rec.matched_ingredient_id::text));

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
      rec.matched_ingredient_id,
      rec.match_source,
      null,
      null,
      v_old_ingredient,
      v_new_ingredient,
      v_now,
      'giallozafferano_safe_residual_alias_apply',
      v_now,
      v_now
    );
  end loop;
end;
$$;
