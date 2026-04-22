-- Smart Import catalog coverage quick wins.
-- Scope:
-- - approve three low-risk Italian aliases through the governed alias writer
-- - prepare `latte di cocco` as a review-driven enrichment draft, without
--   aliasing it to milk or auto-creating a canonical ingredient.

do $$
declare
  v_curry_id uuid;
  v_capers_id uuid;
  v_anchovies_id uuid;
  v_coconut_milk_id uuid;
  v_existing_alias_ingredient_id uuid;
begin
  -- Migration-time governed RPC calls should follow the same admin-gated path
  -- used by service-role automation.
  perform set_config('request.jwt.claim.role', 'service_role', true);

  select i.id into v_curry_id
  from public.ingredients i
  where i.slug = 'curry_powder'
  limit 1;

  select i.id into v_capers_id
  from public.ingredients i
  where i.slug = 'capers'
  limit 1;

  select i.id into v_anchovies_id
  from public.ingredients i
  where i.slug = 'anchovies'
  limit 1;

  if v_curry_id is null then
    raise exception 'smart import alias seed failed: missing canonical slug curry_powder';
  end if;

  if v_capers_id is null then
    raise exception 'smart import alias seed failed: missing canonical slug capers';
  end if;

  if v_anchovies_id is null then
    raise exception 'smart import alias seed failed: missing canonical slug anchovies';
  end if;

  select a.ingredient_id into v_existing_alias_ingredient_id
  from public.ingredient_aliases_v2 a
  where a.normalized_alias_text = 'curry'
    and coalesce(a.is_active, true)
  order by a.id desc
  limit 1;

  if v_existing_alias_ingredient_id is null then
    perform *
    from public.approve_reconciliation_alias(
      p_normalized_text => 'curry',
      p_ingredient_id => v_curry_id,
      p_alias_text => 'curry',
      p_language_code => 'it',
      p_reviewer_note => 'Smart Import batch quick win: exact Italian alias for curry powder.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id is distinct from v_curry_id then
    raise notice 'skipping alias curry: active alias points to %, requested %',
      v_existing_alias_ingredient_id, v_curry_id;
  end if;

  v_existing_alias_ingredient_id := null;
  select a.ingredient_id into v_existing_alias_ingredient_id
  from public.ingredient_aliases_v2 a
  where a.normalized_alias_text = 'capperi sotto sale'
    and coalesce(a.is_active, true)
  order by a.id desc
  limit 1;

  if v_existing_alias_ingredient_id is null then
    perform *
    from public.approve_reconciliation_alias(
      p_normalized_text => 'capperi sotto sale',
      p_ingredient_id => v_capers_id,
      p_alias_text => 'capperi sotto sale',
      p_language_code => 'it',
      p_reviewer_note => 'Smart Import batch quick win: salted capers surface maps to capers canonical.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id is distinct from v_capers_id then
    raise notice 'skipping alias capperi sotto sale: active alias points to %, requested %',
      v_existing_alias_ingredient_id, v_capers_id;
  end if;

  v_existing_alias_ingredient_id := null;
  select a.ingredient_id into v_existing_alias_ingredient_id
  from public.ingredient_aliases_v2 a
  where a.normalized_alias_text = 'acciughe sott''olio'
    and coalesce(a.is_active, true)
  order by a.id desc
  limit 1;

  if v_existing_alias_ingredient_id is null then
    perform *
    from public.approve_reconciliation_alias(
      p_normalized_text => 'acciughe sott''olio',
      p_ingredient_id => v_anchovies_id,
      p_alias_text => 'acciughe sott''olio',
      p_language_code => 'it',
      p_reviewer_note => 'Smart Import batch quick win: oil-packed anchovies surface maps to anchovies canonical.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id is distinct from v_anchovies_id then
    raise notice 'skipping alias acciughe sott''olio: active alias points to %, requested %',
      v_existing_alias_ingredient_id, v_anchovies_id;
  end if;

  v_existing_alias_ingredient_id := null;
  select a.ingredient_id into v_existing_alias_ingredient_id
  from public.ingredient_aliases_v2 a
  where a.normalized_alias_text = 'acciughe sott olio'
    and coalesce(a.is_active, true)
  order by a.id desc
  limit 1;

  if v_existing_alias_ingredient_id is null then
    perform *
    from public.approve_reconciliation_alias(
      p_normalized_text => 'acciughe sott olio',
      p_ingredient_id => v_anchovies_id,
      p_alias_text => 'acciughe sott olio',
      p_language_code => 'it',
      p_reviewer_note => 'Smart Import batch quick win: normalized spelling for oil-packed anchovies maps to anchovies canonical.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id is distinct from v_anchovies_id then
    raise notice 'skipping alias acciughe sott olio: active alias points to %, requested %',
      v_existing_alias_ingredient_id, v_anchovies_id;
  end if;

  select i.id into v_coconut_milk_id
  from public.ingredients i
  where i.slug = 'coconut_milk'
  limit 1;

  perform public.observe_custom_ingredient(
    p_normalized_text => 'latte di cocco',
    p_raw_example => 'latte di cocco',
    p_language_code => 'it',
    p_source => 'smart_import_batch_seed',
    p_latest_recipe_id => null
  );

  if v_coconut_milk_id is null then
    perform *
    from public.upsert_catalog_ingredient_enrichment_draft(
      p_normalized_text => 'latte di cocco',
      p_status => 'pending',
      p_ingredient_type => 'basic',
      p_canonical_name_it => 'Latte di cocco',
      p_canonical_name_en => 'Coconut milk',
      p_suggested_slug => 'coconut_milk',
      p_suggested_aliases => '["latte di cocco", "coconut milk"]'::jsonb,
      p_default_unit => 'ml',
      p_supported_units => array['ml', 'g']::text[],
      p_is_seasonal => false,
      p_season_months => '{}'::int[],
      p_nutrition_fields => '{}'::jsonb,
      p_confidence_score => 0.88,
      p_needs_manual_review => true,
      p_reasoning_summary => 'Frequent Smart Import unresolved term; distinct pantry ingredient and not an alias of milk.',
      p_reviewer_note => 'Review-driven canonical candidate only. Do not alias to milk and do not auto-promote without admin review.'
    );
  end if;
end
$$;

-- Verification helpers:
-- select a.alias_text, a.normalized_alias_text, i.slug, a.status, a.approval_source
-- from public.ingredient_aliases_v2 a
-- join public.ingredients i on i.id = a.ingredient_id
-- where a.normalized_alias_text in ('curry', 'capperi sotto sale', 'acciughe sott''olio', 'acciughe sott olio')
-- order by a.normalized_alias_text;
--
-- select normalized_text, status, ingredient_type, suggested_slug, needs_manual_review, validated_ready
-- from public.catalog_ingredient_enrichment_drafts
-- where normalized_text = 'latte di cocco';
