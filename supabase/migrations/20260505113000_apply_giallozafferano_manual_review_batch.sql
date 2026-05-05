-- Apply the next small, reviewed Giallo Zafferano cleanup batch.
--
-- Decisions:
-- - create canonical ingredients for pancetta fresca, scampi, taleggio;
-- - resolve semolino as an alias of existing semola instead of creating a
--   duplicate semolina-like ingredient;
-- - reconcile only rows that the safety preview marks safe after the changes.

do $$
declare
  v_now timestamptz := now();
  v_creation_batch_id uuid := gen_random_uuid();
  v_reconciliation_batch_id uuid := gen_random_uuid();
  v_semola_id uuid;
  v_recipe_ingredients jsonb;
  v_old_ingredient jsonb;
  v_new_ingredient jsonb;
  v_new_ingredients jsonb;
  rec record;
begin
  select c.ingredient_id
  into v_semola_id
  from public.ingredient_catalog_app_summary c
  where c.slug = 'semola'
  limit 1;

  if v_semola_id is null then
    raise exception 'semola canonical ingredient not found';
  end if;

  create temp table _review_create_terms (
    normalized_text text primary key
  ) on commit drop;

  insert into _review_create_terms (normalized_text)
  values
    ('pancetta fresca'),
    ('scampi'),
    ('taleggio morbido');

  create temp table _review_ready_drafts on commit drop as
  select
    d.normalized_text,
    d.ingredient_type,
    d.canonical_name_it,
    d.canonical_name_en,
    d.suggested_slug,
    d.default_unit,
    d.supported_units,
    coalesce(d.is_seasonal, false) as is_seasonal,
    coalesce(d.season_months, '{}'::int[]) as season_months,
    d.confidence_score
  from public.catalog_ingredient_enrichment_drafts d
  join _review_create_terms t
    on t.normalized_text = d.normalized_text
  where d.status = 'pending'
    and coalesce(d.validated_ready, false)
    and d.ingredient_type = 'basic'
    and nullif(trim(coalesce(d.suggested_slug, '')), '') is not null
    and nullif(trim(coalesce(d.default_unit, '')), '') is not null
    and cardinality(coalesce(d.supported_units, '{}'::text[])) > 0;

  create temp table _review_created_ingredients (
    normalized_text text primary key,
    ingredient_id uuid not null,
    ingredient_slug text not null,
    created_new boolean not null default false
  ) on commit drop;

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
    d.suggested_slug,
    d.ingredient_type,
    d.is_seasonal,
    d.season_months,
    d.default_unit,
    d.supported_units,
    null,
    0,
    'base',
    v_now,
    v_now
  from _review_ready_drafts d
  where not exists (
    select 1
    from public.ingredients i
    where i.slug = d.suggested_slug
  );

  insert into _review_created_ingredients (
    normalized_text,
    ingredient_id,
    ingredient_slug,
    created_new
  )
  select
    d.normalized_text,
    i.id,
    i.slug,
    not exists (
      select 1
      from public.catalog_candidate_decisions ccd
      where ccd.normalized_text = d.normalized_text
        and ccd.ingredient_id = i.id
        and ccd.action in ('create_ingredient_from_candidate', 'create_ingredient_from_candidate_existing')
    ) as created_new
  from _review_ready_drafts d
  join public.ingredients i
    on i.slug = d.suggested_slug
  on conflict (normalized_text) do nothing;

  insert into public.ingredient_localizations (
    ingredient_id,
    language_code,
    display_name,
    created_at,
    updated_at
  )
  select
    c.ingredient_id,
    l.language_code,
    l.display_name,
    v_now,
    v_now
  from _review_created_ingredients c
  join _review_ready_drafts d
    on d.normalized_text = c.normalized_text
  cross join lateral (
    values
      ('it'::text, nullif(trim(coalesce(d.canonical_name_it, '')), '')),
      ('en'::text, nullif(trim(coalesce(d.canonical_name_en, '')), ''))
  ) as l(language_code, display_name)
  where l.display_name is not null
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
    c.ingredient_id,
    coalesce(nullif(trim(d.canonical_name_it), ''), d.normalized_text),
    d.normalized_text,
    'it',
    'manual_review',
    d.confidence_score,
    d.confidence_score,
    true,
    'approved',
    'manual',
    v_now,
    'manual_review_giallozafferano_residual_custom_batch',
    v_now,
    v_now
  from _review_created_ingredients c
  join _review_ready_drafts d
    on d.normalized_text = c.normalized_text
  where not exists (
    select 1
    from public.ingredient_aliases_v2 a
    where a.normalized_alias_text = d.normalized_text
      and coalesce(a.is_active, true)
  );

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
    v_semola_id,
    'Semolino',
    'semolino',
    'it',
    'manual_review',
    0.88,
    0.88,
    true,
    'approved',
    'manual',
    v_now,
    'resolved_as_alias_to_existing_semola_from_giallozafferano_review',
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
    normalized_text,
    jsonb_build_array(normalized_text),
    'it',
    'giallozafferano_manual_review_batch',
    1,
    'ingredient_created',
    v_now,
    v_now,
    v_now
  from _review_created_ingredients
  on conflict (normalized_text) do update
  set
    status = 'ingredient_created',
    updated_at = excluded.updated_at;

  update public.custom_ingredient_observations as o
  set
    status = 'resolved_alias',
    updated_at = v_now
  where o.normalized_text = 'semolino';

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
    d.normalized_text,
    case when c.created_new then 'create_ingredient_from_candidate' else 'create_ingredient_from_candidate_existing' end,
    c.ingredient_id,
    coalesce(nullif(trim(d.canonical_name_it), ''), d.normalized_text),
    'it',
    d.confidence_score,
    'manual_review_giallozafferano_residual_custom_batch',
    'ingredient_created',
    'approved',
    v_now,
    v_now
  from _review_created_ingredients c
  join _review_ready_drafts d
    on d.normalized_text = c.normalized_text
  where not exists (
    select 1
    from public.catalog_candidate_decisions existing
    where existing.normalized_text = d.normalized_text
      and existing.ingredient_id = c.ingredient_id
      and existing.action in ('create_ingredient_from_candidate', 'create_ingredient_from_candidate_existing')
  );

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
    'semolino',
    'approve_alias',
    v_semola_id,
    'Semolino',
    'it',
    0.88,
    'resolved_as_alias_to_existing_semola_from_giallozafferano_review',
    'resolved_alias',
    'approved',
    v_now,
    v_now
  where not exists (
    select 1
    from public.catalog_candidate_decisions d
    where d.normalized_text = 'semolino'
      and d.ingredient_id = v_semola_id
      and d.action = 'approve_alias'
  );

  update public.catalog_ingredient_enrichment_drafts d
  set
    status = 'applied',
    needs_manual_review = false,
    reviewer_note = coalesce(nullif(trim(d.reviewer_note), '') || E'\n', '')
      || 'auto_applied_from_manual_review_giallozafferano_batch',
    validated_ready = true,
    validated_errors = '[]'::jsonb,
    last_validated_at = v_now,
    updated_at = v_now
  from _review_created_ingredients c
  where c.normalized_text = d.normalized_text
    and d.status = 'pending';

  update public.catalog_ingredient_enrichment_drafts d
  set
    status = 'rejected',
    needs_manual_review = false,
    reviewer_note = coalesce(nullif(trim(d.reviewer_note), '') || E'\n', '')
      || 'resolved_as_alias_to_existing_semola_from_giallozafferano_review',
    validated_ready = false,
    validated_errors = '[]'::jsonb,
    last_validated_at = v_now,
    updated_at = v_now
  where d.normalized_text = 'semolino'
    and d.status = 'pending';

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
    c.normalized_text,
    c.ingredient_id,
    c.ingredient_slug,
    case when c.created_new then 'created' else 'reused_existing' end,
    'giallozafferano_manual_review_creation_batch',
    c.created_new
  from _review_created_ingredients c;

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
      and p.reconciliation_match_text in ('pancetta fresca', 'scampi', 'semolino', 'taleggio morbido')
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
      'giallozafferano_manual_review_safe_apply',
      v_now,
      v_now
    );
  end loop;
end;
$$;
