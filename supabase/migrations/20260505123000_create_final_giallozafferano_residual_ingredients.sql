-- Close the final Giallo Zafferano residual custom ingredients.
--
-- Notes:
-- - "Sottilette(R)" is mapped to a generic processed cheese slices ingredient;
-- - recipe wording is preserved in recipes, while ingredient_id points to the
--   canonical catalog identity for filters, shopping, fridge and nutrition.

do $$
declare
  v_now timestamptz := now();
  v_creation_batch_id uuid := gen_random_uuid();
  v_reconciliation_batch_id uuid := gen_random_uuid();
  v_recipe_ingredients jsonb;
  v_old_ingredient jsonb;
  v_new_ingredient jsonb;
  v_new_ingredients jsonb;
  rec record;
begin
  create temp table _final_residual_terms (
    normalized_text text primary key,
    alias_text text not null,
    slug text not null,
    ingredient_type text not null,
    canonical_name_it text not null,
    canonical_name_en text not null,
    default_unit text not null,
    supported_units text[] not null,
    confidence_score double precision not null
  ) on commit drop;

  insert into _final_residual_terms (
    normalized_text,
    alias_text,
    slug,
    ingredient_type,
    canonical_name_it,
    canonical_name_en,
    default_unit,
    supported_units,
    confidence_score
  )
  values
    (
      'cioccolato fondente al 50%',
      'Cioccolato fondente al 50%',
      'dark_chocolate',
      'basic',
      'Cioccolato fondente',
      'Dark chocolate',
      'g',
      array['g', 'kg'],
      0.92
    ),
    (
      'groviera',
      'Groviera',
      'gruyere',
      'basic',
      'Groviera',
      'Gruyere',
      'g',
      array['g', 'kg'],
      0.9
    ),
    (
      'maggiorana',
      'Maggiorana',
      'marjoram',
      'basic',
      'Maggiorana',
      'Marjoram',
      'g',
      array['g', 'kg'],
      0.86
    ),
    (
      'seppie',
      'Seppie',
      'cuttlefish',
      'basic',
      'Seppie',
      'Cuttlefish',
      'piece',
      array['piece', 'g', 'kg'],
      0.9
    ),
    (
      'sottilette®',
      'Sottilette(R)',
      'processed_cheese_slices',
      'basic',
      'Formaggio fuso a fette',
      'Processed cheese slices',
      'slice',
      array['slice', 'g', 'kg'],
      0.82
    );

  insert into public.ingredients (
    slug,
    ingredient_type,
    is_seasonal,
    season_months,
    default_unit,
    supported_units,
    parent_ingredient_id,
    specificity_rank,
    variant_kind,
    created_at,
    updated_at
  )
  select
    t.slug,
    t.ingredient_type,
    false,
    '{}'::int[],
    t.default_unit,
    t.supported_units,
    null,
    0,
    'base',
    v_now,
    v_now
  from _final_residual_terms t
  where not exists (
    select 1
    from public.ingredients i
    where i.slug = t.slug
  );

  create temp table _final_residual_ingredients on commit drop as
  select
    t.normalized_text,
    t.alias_text,
    t.slug,
    t.canonical_name_it,
    t.canonical_name_en,
    t.confidence_score,
    i.id as ingredient_id
  from _final_residual_terms t
  join public.ingredients i
    on i.slug = t.slug;

  insert into public.ingredient_localizations (
    ingredient_id,
    language_code,
    display_name,
    created_at,
    updated_at
  )
  select
    f.ingredient_id,
    l.language_code,
    l.display_name,
    v_now,
    v_now
  from _final_residual_ingredients f
  cross join lateral (
    values
      ('it'::text, f.canonical_name_it),
      ('en'::text, f.canonical_name_en)
  ) as l(language_code, display_name)
  on conflict on constraint ingredient_localizations_pkey do update
  set
    display_name = excluded.display_name,
    updated_at = excluded.updated_at;

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
    f.ingredient_id,
    f.alias_text,
    f.normalized_text,
    'it',
    'manual_review',
    f.confidence_score,
    f.confidence_score,
    true,
    'approved',
    'manual',
    v_now,
    'final_giallozafferano_residual_catalog_cleanup',
    v_now,
    v_now
  from _final_residual_ingredients f
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
    f.normalized_text,
    jsonb_build_array(f.alias_text),
    'it',
    'final_giallozafferano_residual_catalog_cleanup',
    1,
    'ingredient_created',
    v_now,
    v_now,
    v_now
  from _final_residual_ingredients f
  on conflict (normalized_text) do update
  set
    status = 'ingredient_created',
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
    f.normalized_text,
    case
      when exists (
        select 1
        from public.catalog_candidate_decisions existing
        where existing.normalized_text = f.normalized_text
          and existing.ingredient_id = f.ingredient_id
          and existing.action in ('create_ingredient_from_candidate', 'create_ingredient_from_candidate_existing')
      ) then 'create_ingredient_from_candidate_existing'
      else 'create_ingredient_from_candidate'
    end,
    f.ingredient_id,
    f.alias_text,
    'it',
    f.confidence_score,
    'final_giallozafferano_residual_catalog_cleanup',
    'ingredient_created',
    'approved',
    v_now,
    v_now
  from _final_residual_ingredients f
  where not exists (
    select 1
    from public.catalog_candidate_decisions existing
    where existing.normalized_text = f.normalized_text
      and existing.ingredient_id = f.ingredient_id
      and existing.action in ('create_ingredient_from_candidate', 'create_ingredient_from_candidate_existing')
  );

  insert into public.catalog_ready_draft_creation_audit (
    batch_id,
    normalized_text,
    ingredient_id,
    ingredient_slug,
    result_status,
    detail,
    created_new
  )
  select
    v_creation_batch_id,
    f.normalized_text,
    f.ingredient_id,
    f.slug,
    'created',
    'final_giallozafferano_residual_catalog_cleanup',
    true
  from _final_residual_ingredients f
  where not exists (
    select 1
    from public.catalog_ready_draft_creation_audit a
    where a.normalized_text = f.normalized_text
      and a.ingredient_id = f.ingredient_id
      and a.detail = 'final_giallozafferano_residual_catalog_cleanup'
  );

  update public.catalog_ingredient_enrichment_drafts d
  set
    status = 'applied',
    needs_manual_review = false,
    reviewer_note = coalesce(nullif(trim(d.reviewer_note), '') || E'\n', '')
      || 'final_giallozafferano_residual_catalog_cleanup',
    validated_ready = true,
    validated_errors = '[]'::jsonb,
    last_validated_at = v_now,
    updated_at = v_now
  from _final_residual_ingredients f
  where f.normalized_text = d.normalized_text
    and d.status in ('pending', 'ready');

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
    join _final_residual_ingredients f
      on f.normalized_text = p.reconciliation_match_text
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
      v_reconciliation_batch_id,
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
      'final_giallozafferano_residual_safe_apply',
      v_now,
      v_now
    );
  end loop;
end;
$$;
