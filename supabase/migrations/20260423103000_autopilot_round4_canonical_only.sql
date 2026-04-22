-- Autopilot coverage round 4: canonical preparation only.
-- Scope:
-- - observe recurring unresolved/custom ingredients
-- - prepare review-driven enrichment drafts when no canonical/draft exists
-- - do not approve aliases or create canonical ingredients.

do $$
declare
  v_spec jsonb;
  v_existing_canonical_id uuid;
  v_existing_draft_status text;
  v_existing_draft_slug text;
begin
  -- Migration-time governed RPC calls should follow the same admin-gated path
  -- used by service-role automation.
  perform set_config('request.jwt.claim.role', 'service_role', true);

  for v_spec in
    select *
    from jsonb_array_elements(
      '[
        {
          "normalized_text": "lievito",
          "raw_example": "lievito",
          "canonical_name_it": "Lievito",
          "canonical_name_en": "Yeast",
          "suggested_slug": "yeast",
          "suggested_aliases": ["lievito", "yeast"],
          "default_unit": "g",
          "supported_units": ["g"],
          "confidence_score": 0.85,
          "reasoning_summary": "Recurring Smart Import unresolved ingredient. Ambiguous fresh/dry/baking leavening term; must be reviewed before canonical creation.",
          "reviewer_note": "Review-driven canonical candidate only. Confirm yeast vs baking powder/fresh yeast hierarchy before creation."
        },
        {
          "normalized_text": "latte di cocco",
          "raw_example": "latte di cocco",
          "canonical_name_it": "Latte di cocco",
          "canonical_name_en": "Coconut milk",
          "suggested_slug": "coconut_milk",
          "suggested_aliases": ["latte di cocco", "coconut milk"],
          "default_unit": "ml",
          "supported_units": ["ml", "g"],
          "confidence_score": 0.9,
          "reasoning_summary": "Recurring Smart Import unresolved pantry ingredient; distinct from milk and must not be aliased to milk.",
          "reviewer_note": "Review-driven canonical candidate only. Do not auto-promote or alias to milk."
        },
        {
          "normalized_text": "orata",
          "raw_example": "orata",
          "canonical_name_it": "Orata",
          "canonical_name_en": "Sea bream",
          "suggested_slug": "sea_bream",
          "suggested_aliases": ["orata", "sea bream"],
          "default_unit": "g",
          "supported_units": ["g"],
          "confidence_score": 0.9,
          "reasoning_summary": "Recurring Smart Import unresolved fish species; distinct ingredient candidate, not safe to alias to generic fish.",
          "reviewer_note": "Review-driven canonical candidate only. Do not auto-promote without admin review."
        },
        {
          "normalized_text": "pesce spada",
          "raw_example": "pesce spada",
          "canonical_name_it": "Pesce spada",
          "canonical_name_en": "Swordfish",
          "suggested_slug": "swordfish",
          "suggested_aliases": ["pesce spada", "swordfish"],
          "default_unit": "g",
          "supported_units": ["g"],
          "confidence_score": 0.9,
          "reasoning_summary": "Recurring Smart Import unresolved fish species; distinct ingredient candidate, not safe to alias to generic fish.",
          "reviewer_note": "Review-driven canonical candidate only. Do not auto-promote without admin review."
        }
      ]'::jsonb
    )
  loop
    v_existing_canonical_id := null;
    v_existing_draft_status := null;
    v_existing_draft_slug := null;

    perform public.observe_custom_ingredient(
      p_normalized_text => v_spec->>'normalized_text',
      p_raw_example => v_spec->>'raw_example',
      p_language_code => 'it',
      p_source => 'autopilot_round4_canonical_only',
      p_latest_recipe_id => null
    );

    select i.id into v_existing_canonical_id
    from public.ingredients i
    where i.slug = v_spec->>'suggested_slug'
    limit 1;

    if v_existing_canonical_id is not null then
      raise notice 'skipping draft %: canonical slug % already exists',
        v_spec->>'normalized_text',
        v_spec->>'suggested_slug';
      continue;
    end if;

    select d.status, d.suggested_slug
    into v_existing_draft_status, v_existing_draft_slug
    from public.catalog_ingredient_enrichment_drafts d
    where d.normalized_text = v_spec->>'normalized_text'
    limit 1;

    if v_existing_draft_status is not null then
      raise notice 'skipping draft %: existing draft status=%, suggested_slug=%',
        v_spec->>'normalized_text',
        v_existing_draft_status,
        v_existing_draft_slug;
      continue;
    end if;

    perform *
    from public.upsert_catalog_ingredient_enrichment_draft(
      p_normalized_text => v_spec->>'normalized_text',
      p_status => 'pending',
      p_ingredient_type => 'basic',
      p_canonical_name_it => v_spec->>'canonical_name_it',
      p_canonical_name_en => v_spec->>'canonical_name_en',
      p_suggested_slug => v_spec->>'suggested_slug',
      p_suggested_aliases => v_spec->'suggested_aliases',
      p_default_unit => v_spec->>'default_unit',
      p_supported_units => array(
        select jsonb_array_elements_text(v_spec->'supported_units')
      ),
      p_is_seasonal => false,
      p_season_months => '{}'::int[],
      p_nutrition_fields => '{}'::jsonb,
      p_confidence_score => (v_spec->>'confidence_score')::double precision,
      p_needs_manual_review => true,
      p_reasoning_summary => v_spec->>'reasoning_summary',
      p_reviewer_note => v_spec->>'reviewer_note'
    );
  end loop;
end
$$;

-- Verification helpers:
-- select normalized_text, occurrence_count, source, raw_examples, status
-- from public.custom_ingredient_observations
-- where normalized_text in ('lievito', 'latte di cocco', 'orata', 'pesce spada')
-- order by normalized_text;
--
-- select normalized_text, status, ingredient_type, suggested_slug, canonical_name_it, canonical_name_en,
--        default_unit, supported_units, needs_manual_review, validated_ready, confidence_score
-- from public.catalog_ingredient_enrichment_drafts
-- where normalized_text in ('lievito', 'latte di cocco', 'orata', 'pesce spada')
-- order by normalized_text;
--
-- select slug
-- from public.ingredients
-- where slug in ('yeast', 'coconut_milk', 'sea_bream', 'swordfish')
-- order by slug;
