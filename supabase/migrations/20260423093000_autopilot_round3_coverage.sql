-- Autopilot catalog coverage round 3.
-- Scope:
-- - approve only low-risk exact Italian aliases through the governed alias writer
-- - prepare `lievito` as a review-driven enrichment draft only
-- - do not auto-create canonical ingredients or overwrite conflicting aliases.

do $$
declare
  v_alias_spec jsonb;
  v_draft_spec jsonb;
  v_target_id uuid;
  v_existing_alias_ingredient_id uuid;
  v_existing_alias_slug text;
  v_existing_canonical_id uuid;
  v_existing_draft_status text;
  v_existing_draft_slug text;
begin
  -- Migration-time governed RPC calls should follow the same admin-gated path
  -- used by service-role automation.
  perform set_config('request.jwt.claim.role', 'service_role', true);

  for v_alias_spec in
    select *
    from jsonb_array_elements(
      '[
        {
          "normalized_text": "olio",
          "alias_text": "olio",
          "slug": "olive_oil",
          "note": "Autopilot coverage round 3: common Italian cooking shorthand maps to olive oil canonical."
        },
        {
          "normalized_text": "carota",
          "alias_text": "carota",
          "slug": "carrot",
          "note": "Autopilot coverage round 3: exact Italian singular maps to carrot canonical."
        },
        {
          "normalized_text": "patate",
          "alias_text": "patate",
          "slug": "potato",
          "note": "Autopilot coverage round 3: exact Italian plural maps to potato canonical."
        },
        {
          "normalized_text": "funghi",
          "alias_text": "funghi",
          "slug": "mushroom",
          "note": "Autopilot coverage round 3: exact Italian plural maps to mushroom canonical."
        },
        {
          "normalized_text": "pasta",
          "alias_text": "pasta",
          "slug": "pasta",
          "note": "Autopilot coverage round 3: exact Italian surface maps to dry pasta canonical."
        },
        {
          "normalized_text": "tonno",
          "alias_text": "tonno",
          "slug": "tuna",
          "note": "Autopilot coverage round 3: exact Italian surface maps to tuna canonical."
        },
        {
          "normalized_text": "acciughe",
          "alias_text": "acciughe",
          "slug": "anchovies",
          "note": "Autopilot coverage round 3: exact Italian plural maps to anchovies canonical."
        },
        {
          "normalized_text": "peperoni",
          "alias_text": "peperoni",
          "slug": "bell_pepper",
          "note": "Autopilot coverage round 3: exact Italian plural maps to bell pepper canonical, not black pepper."
        },
        {
          "normalized_text": "acqua",
          "alias_text": "acqua",
          "slug": "water",
          "note": "Autopilot coverage round 3: exact Italian surface maps to water canonical."
        },
        {
          "normalized_text": "aglio",
          "alias_text": "aglio",
          "slug": "garlic",
          "note": "Autopilot coverage round 3: exact Italian surface maps to garlic canonical."
        },
        {
          "normalized_text": "aceto",
          "alias_text": "aceto",
          "slug": "vinegar",
          "note": "Autopilot coverage round 3: exact Italian surface maps to vinegar canonical."
        },
        {
          "normalized_text": "salmone",
          "alias_text": "salmone",
          "slug": "salmon",
          "note": "Autopilot coverage round 3: exact Italian fish surface maps to salmon canonical."
        }
      ]'::jsonb
    )
  loop
    v_target_id := null;
    v_existing_alias_ingredient_id := null;
    v_existing_alias_slug := null;

    select i.id into v_target_id
    from public.ingredients i
    where i.slug = v_alias_spec->>'slug'
    limit 1;

    if v_target_id is null then
      raise exception 'autopilot round 3 coverage failed: missing canonical slug %', v_alias_spec->>'slug';
    end if;

    select a.ingredient_id, i.slug
    into v_existing_alias_ingredient_id, v_existing_alias_slug
    from public.ingredient_aliases_v2 a
    join public.ingredients i on i.id = a.ingredient_id
    where a.normalized_alias_text = v_alias_spec->>'normalized_text'
      and coalesce(a.is_active, true)
    order by a.id desc
    limit 1;

    if v_existing_alias_ingredient_id is null then
      perform *
      from public.approve_reconciliation_alias(
        p_normalized_text => v_alias_spec->>'normalized_text',
        p_ingredient_id => v_target_id,
        p_alias_text => v_alias_spec->>'alias_text',
        p_language_code => 'it',
        p_reviewer_note => v_alias_spec->>'note',
        p_confidence_score => 0.99
      );
    elsif v_existing_alias_ingredient_id = v_target_id then
      raise notice 'skipping alias %: active alias already points to %',
        v_alias_spec->>'normalized_text',
        v_alias_spec->>'slug';
    else
      raise notice 'skipping alias %: active alias points to %, requested %',
        v_alias_spec->>'normalized_text',
        v_existing_alias_slug,
        v_alias_spec->>'slug';
    end if;
  end loop;

  -- Existing round 1/2 coverage intentionally remains untouched:
  -- - capperi sotto sale already points to the more specific capperi_sotto_sale canonical
  -- - curry, acciughe sott'olio, acciughe sott olio, olive nere already have governed aliases
  -- - latte di cocco, orata, pesce spada already have review-driven drafts

  for v_draft_spec in
    select *
    from jsonb_array_elements(
      '[
        {
          "normalized_text": "lievito",
          "raw_example": "lievito 7g",
          "suggested_slug": "yeast",
          "canonical_name_it": "Lievito",
          "canonical_name_en": "Yeast",
          "suggested_aliases": ["lievito", "yeast"],
          "default_unit": "g",
          "supported_units": ["g"],
          "confidence_score": 0.82,
          "reasoning_summary": "Recurring Smart Import unresolved leavening term from focaccia-style captions; real ingredient, but review is required because Italian lievito can refer to different leavening products.",
          "reviewer_note": "Review-driven canonical candidate only. Do not auto-promote; confirm yeast vs baking powder/governed hierarchy before creation."
        }
      ]'::jsonb
    )
  loop
    v_existing_canonical_id := null;
    v_existing_draft_status := null;
    v_existing_draft_slug := null;

    select i.id into v_existing_canonical_id
    from public.ingredients i
    where i.slug = v_draft_spec->>'suggested_slug'
    limit 1;

    if v_existing_canonical_id is not null then
      raise notice 'skipping draft %: canonical slug % already exists',
        v_draft_spec->>'normalized_text',
        v_draft_spec->>'suggested_slug';
      continue;
    end if;

    select d.status, d.suggested_slug
    into v_existing_draft_status, v_existing_draft_slug
    from public.catalog_ingredient_enrichment_drafts d
    where d.normalized_text = v_draft_spec->>'normalized_text'
    limit 1;

    if v_existing_draft_status is not null then
      raise notice 'skipping draft %: existing draft status=%, suggested_slug=%',
        v_draft_spec->>'normalized_text',
        v_existing_draft_status,
        v_existing_draft_slug;
      continue;
    end if;

    perform public.observe_custom_ingredient(
      p_normalized_text => v_draft_spec->>'normalized_text',
      p_raw_example => v_draft_spec->>'raw_example',
      p_language_code => 'it',
      p_source => 'autopilot_round3_coverage',
      p_latest_recipe_id => null
    );

    perform *
    from public.upsert_catalog_ingredient_enrichment_draft(
      p_normalized_text => v_draft_spec->>'normalized_text',
      p_status => 'pending',
      p_ingredient_type => 'basic',
      p_canonical_name_it => v_draft_spec->>'canonical_name_it',
      p_canonical_name_en => v_draft_spec->>'canonical_name_en',
      p_suggested_slug => v_draft_spec->>'suggested_slug',
      p_suggested_aliases => v_draft_spec->'suggested_aliases',
      p_default_unit => v_draft_spec->>'default_unit',
      p_supported_units => array(
        select jsonb_array_elements_text(v_draft_spec->'supported_units')
      ),
      p_is_seasonal => false,
      p_season_months => '{}'::int[],
      p_nutrition_fields => '{}'::jsonb,
      p_confidence_score => (v_draft_spec->>'confidence_score')::double precision,
      p_needs_manual_review => true,
      p_reasoning_summary => v_draft_spec->>'reasoning_summary',
      p_reviewer_note => v_draft_spec->>'reviewer_note'
    );
  end loop;
end
$$;

-- Verification helpers:
-- select a.alias_text, a.normalized_alias_text, i.slug, a.status, a.is_active, a.approval_source, a.approved_at
-- from public.ingredient_aliases_v2 a
-- join public.ingredients i on i.id = a.ingredient_id
-- where a.normalized_alias_text in (
--   'olio', 'carota', 'patate', 'funghi', 'pasta', 'tonno', 'acciughe',
--   'peperoni', 'acqua', 'aglio', 'aceto', 'salmone'
-- )
-- order by a.normalized_alias_text;
--
-- select normalized_text, status, ingredient_type, suggested_slug, needs_manual_review, validated_ready, confidence_score
-- from public.catalog_ingredient_enrichment_drafts
-- where normalized_text = 'lievito';
