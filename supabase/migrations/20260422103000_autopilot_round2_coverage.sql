-- Autopilot catalog coverage round 2.
-- Scope:
-- - approve low-risk aliases through the governed alias writer
-- - prepare swordfish and sea bream as review-driven enrichment drafts only
-- - do not auto-create canonical ingredients or alias ambiguous terms.

do $$
declare
  v_curry_id uuid;
  v_anchovies_id uuid;
  v_black_olives_id uuid;
  v_existing_alias_ingredient_id uuid;
begin
  -- Migration-time governed RPC calls should follow the same admin-gated path
  -- used by service-role automation.
  perform set_config('request.jwt.claim.role', 'service_role', true);

  select i.id into v_curry_id
  from public.ingredients i
  where i.slug = 'curry_powder'
  limit 1;

  select i.id into v_anchovies_id
  from public.ingredients i
  where i.slug = 'anchovies'
  limit 1;

  select i.id into v_black_olives_id
  from public.ingredients i
  where i.slug = 'black_olives'
  limit 1;

  if v_curry_id is null then
    raise exception 'autopilot round 2 coverage failed: missing canonical slug curry_powder';
  end if;

  if v_anchovies_id is null then
    raise exception 'autopilot round 2 coverage failed: missing canonical slug anchovies';
  end if;

  if v_black_olives_id is null then
    raise exception 'autopilot round 2 coverage failed: missing canonical slug black_olives';
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
      p_reviewer_note => 'Autopilot coverage round 2: exact Italian alias for curry powder.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id = v_curry_id then
    raise notice 'skipping alias curry: active alias already points to requested target %', v_curry_id;
  else
    raise notice 'skipping alias curry: active alias points to %, requested %',
      v_existing_alias_ingredient_id, v_curry_id;
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
      p_reviewer_note => 'Autopilot coverage round 2: oil-packed anchovies surface maps to anchovies canonical.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id = v_anchovies_id then
    raise notice 'skipping alias acciughe sott''olio: active alias already points to requested target %', v_anchovies_id;
  else
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
      p_reviewer_note => 'Autopilot coverage round 2: normalized spelling for oil-packed anchovies maps to anchovies canonical.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id = v_anchovies_id then
    raise notice 'skipping alias acciughe sott olio: active alias already points to requested target %', v_anchovies_id;
  else
    raise notice 'skipping alias acciughe sott olio: active alias points to %, requested %',
      v_existing_alias_ingredient_id, v_anchovies_id;
  end if;

  v_existing_alias_ingredient_id := null;
  select a.ingredient_id into v_existing_alias_ingredient_id
  from public.ingredient_aliases_v2 a
  where a.normalized_alias_text = 'olive nere'
    and coalesce(a.is_active, true)
  order by a.id desc
  limit 1;

  if v_existing_alias_ingredient_id is null then
    perform *
    from public.approve_reconciliation_alias(
      p_normalized_text => 'olive nere',
      p_ingredient_id => v_black_olives_id,
      p_alias_text => 'olive nere',
      p_language_code => 'it',
      p_reviewer_note => 'Autopilot coverage round 2: Italian surface maps to black olives canonical.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id = v_black_olives_id then
    raise notice 'skipping alias olive nere: active alias already points to requested target %', v_black_olives_id;
  else
    raise notice 'skipping alias olive nere: active alias points to %, requested %',
      v_existing_alias_ingredient_id, v_black_olives_id;
  end if;

  perform public.observe_custom_ingredient(
    p_normalized_text => 'pesce spada',
    p_raw_example => 'pesce spada',
    p_language_code => 'it',
    p_source => 'autopilot_round2_coverage',
    p_latest_recipe_id => null
  );

  perform *
  from public.upsert_catalog_ingredient_enrichment_draft(
    p_normalized_text => 'pesce spada',
    p_status => 'pending',
    p_ingredient_type => 'basic',
    p_canonical_name_it => 'Pesce spada',
    p_canonical_name_en => 'Swordfish',
    p_suggested_slug => 'swordfish',
    p_suggested_aliases => '["pesce spada", "swordfish"]'::jsonb,
    p_default_unit => 'g',
    p_supported_units => array['g']::text[],
    p_is_seasonal => false,
    p_season_months => '{}'::int[],
    p_nutrition_fields => '{}'::jsonb,
    p_confidence_score => 0.9,
    p_needs_manual_review => true,
    p_reasoning_summary => 'Recurring Smart Import fish term; distinct ingredient candidate, not safe to alias to generic fish.',
    p_reviewer_note => 'Review-driven canonical candidate only. Do not auto-promote without admin review.'
  );

  perform public.observe_custom_ingredient(
    p_normalized_text => 'orata',
    p_raw_example => 'orata',
    p_language_code => 'it',
    p_source => 'autopilot_round2_coverage',
    p_latest_recipe_id => null
  );

  perform *
  from public.upsert_catalog_ingredient_enrichment_draft(
    p_normalized_text => 'orata',
    p_status => 'pending',
    p_ingredient_type => 'basic',
    p_canonical_name_it => 'Orata',
    p_canonical_name_en => 'Sea bream',
    p_suggested_slug => 'sea_bream',
    p_suggested_aliases => '["orata", "sea bream"]'::jsonb,
    p_default_unit => 'g',
    p_supported_units => array['g']::text[],
    p_is_seasonal => false,
    p_season_months => '{}'::int[],
    p_nutrition_fields => '{}'::jsonb,
    p_confidence_score => 0.9,
    p_needs_manual_review => true,
    p_reasoning_summary => 'Recurring Smart Import fish term; distinct ingredient candidate, not safe to alias to generic fish.',
    p_reviewer_note => 'Review-driven canonical candidate only. Do not auto-promote without admin review.'
  );
end
$$;

-- Verification helpers:
-- select a.alias_text, a.normalized_alias_text, i.slug, a.status, a.is_active, a.approval_source, a.approved_at
-- from public.ingredient_aliases_v2 a
-- join public.ingredients i on i.id = a.ingredient_id
-- where a.normalized_alias_text in ('curry', 'acciughe sott''olio', 'acciughe sott olio', 'olive nere')
-- order by a.normalized_alias_text;
--
-- select normalized_text, status, ingredient_type, suggested_slug, needs_manual_review, validated_ready, confidence_score
-- from public.catalog_ingredient_enrichment_drafts
-- where normalized_text in ('pesce spada', 'orata')
-- order by normalized_text;
