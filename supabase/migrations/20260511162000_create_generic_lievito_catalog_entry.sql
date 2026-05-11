begin;

-- Govern the generic Italian "lievito" term as its own base catalog item.
--
-- This intentionally does not collapse baking powder, brewer's yeast, or
-- sourdough starter into the generic item. Specific recipe wording should keep
-- using specific variants; unspecified "lievito" can safely map here.

do $$
declare
  v_now timestamptz := now();
  v_lievito_id uuid;
  v_conflicting_alias record;
  v_has_conflicting_alias boolean := false;
begin
  insert into public.ingredients (
    slug,
    ingredient_type,
    is_seasonal,
    season_months,
    default_unit,
    supported_units,
    quality_status,
    parent_ingredient_id,
    specificity_rank,
    variant_kind,
    created_at,
    updated_at
  )
  values (
    'lievito',
    'basic',
    false,
    '{}'::int[],
    'g',
    array['g', 'kg', 'tsp', 'tbsp', 'packet']::text[],
    'active',
    null,
    0,
    'base',
    v_now,
    v_now
  )
  on conflict (slug) do update
  set
    ingredient_type = coalesce(public.ingredients.ingredient_type, excluded.ingredient_type),
    is_seasonal = false,
    season_months = '{}'::int[],
    default_unit = coalesce(public.ingredients.default_unit, excluded.default_unit),
    supported_units = (
      select array(
        select distinct unit
        from unnest(coalesce(public.ingredients.supported_units, '{}'::text[]) || excluded.supported_units) as unit
        order by unit
      )
    ),
    quality_status = 'active',
    parent_ingredient_id = null,
    specificity_rank = 0,
    variant_kind = 'base',
    updated_at = excluded.updated_at
  returning id into v_lievito_id;

  insert into public.ingredient_localizations (
    ingredient_id,
    language_code,
    display_name,
    short_name,
    created_at,
    updated_at
  )
  values
    (v_lievito_id, 'it', 'Lievito', 'Lievito', v_now, v_now),
    (v_lievito_id, 'en', 'Yeast', 'Yeast', v_now, v_now)
  on conflict on constraint ingredient_localizations_pkey do update
  set
    display_name = excluded.display_name,
    short_name = excluded.short_name,
    updated_at = excluded.updated_at;

  select a.id, a.normalized_alias_text, a.ingredient_id, i.slug
  into v_conflicting_alias
  from public.ingredient_aliases_v2 a
  join public.ingredients i on i.id = a.ingredient_id
  where a.normalized_alias_text in ('lievito', 'yeast')
    and coalesce(a.is_active, true)
    and a.ingredient_id is distinct from v_lievito_id
  order by a.id
  limit 1;
  v_has_conflicting_alias := found;

  if v_has_conflicting_alias then
    raise exception
      'active alias conflict for %, existing target %, requested lievito',
      v_conflicting_alias.normalized_alias_text,
      v_conflicting_alias.slug;
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
  values
    (
      v_lievito_id,
      'lievito',
      'lievito',
      'it',
      'manual_governance',
      0.97,
      0.97,
      true,
      'approved',
      'manual',
      v_now,
      'Generic leavening policy: unspecified Italian "lievito" maps to the generic base ingredient.',
      v_now,
      v_now
    ),
    (
      v_lievito_id,
      'yeast',
      'yeast',
      'en',
      'manual_governance',
      0.90,
      0.90,
      true,
      'approved',
      'manual',
      v_now,
      'English generic alias for the governed base leavening ingredient.',
      v_now,
      v_now
    )
  on conflict do nothing;

  update public.custom_ingredient_observations o
  set
    status = 'resolved_alias',
    updated_at = v_now
  where o.normalized_text = 'lievito';

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
    'lievito',
    'approve_alias',
    v_lievito_id,
    'lievito',
    'it',
    0.97,
    'Generic leavening policy: if a recipe only says "lievito", map it to the generic base ingredient. Use specific variants only when the text provides that evidence.',
    'resolved_alias',
    'approved',
    v_now,
    v_now
  where not exists (
    select 1
    from public.catalog_candidate_decisions d
    where d.normalized_text = 'lievito'
      and d.action = 'approve_alias'
      and d.ingredient_id = v_lievito_id
  );

  update public.catalog_ingredient_enrichment_drafts d
  set
    status = 'applied',
    suggested_slug = 'lievito',
    canonical_name_it = 'Lievito',
    canonical_name_en = 'Yeast',
    suggested_aliases = '["lievito", "yeast"]'::jsonb,
    default_unit = coalesce(nullif(btrim(d.default_unit), ''), 'g'),
    supported_units = case
      when cardinality(coalesce(d.supported_units, '{}'::text[])) = 0
      then array['g', 'kg', 'tsp', 'tbsp', 'packet']::text[]
      else d.supported_units
    end,
    needs_manual_review = false,
    reviewer_note = 'Applied by governance migration: generic unspecified lievito is now a base catalog ingredient.',
    validated_ready = true,
    validated_errors = '[]'::jsonb,
    last_validated_at = v_now,
    updated_at = v_now
  where d.normalized_text = 'lievito';

  update public.catalog_agent_proposals p
  set
    status = 'superseded',
    rejection_reason = coalesce(
      p.rejection_reason,
      'Superseded by governed generic lievito catalog entry and approved alias.'
    ),
    updated_at = v_now
  where p.normalized_text = 'lievito'
    and p.status in ('draft', 'queued_for_validation', 'validated', 'needs_human_review');

  insert into public.catalog_agent_learnings (
    normalized_text,
    learning_type,
    severity,
    status,
    original_recommendation,
    observed_problem,
    corrected_decision,
    policy_implication,
    evaluation_recommendation,
    prompt_recommendation,
    created_at,
    updated_at
  )
  select
    'lievito',
    'policy_gap',
    'medium',
    'implemented',
    jsonb_build_object(
      'source', 'manual_governance_migration',
      'implemented_slug', 'lievito'
    ),
    'The catalog did not have a safe generic target for unspecified Italian "lievito", forcing repeated human-review proposals.',
    'Create and use canonical slug "lievito" for unspecified generic leavening terms.',
    'Map bare "lievito" to the generic base ingredient only when the recipe does not specify baking powder, brewer''s yeast, sourdough starter, fresh/dry yeast, or another specific variant.',
    'Add fixtures where bare "lievito" resolves to the generic ingredient and specific wording resolves to the correct variant.',
    'When a work item has the canonical candidate "lievito" and no contextual evidence for a more specific leavening variant, prefer approve_alias to "lievito" over needs_human_review.',
    v_now,
    v_now
  where not exists (
    select 1
    from public.catalog_agent_learnings l
    where l.normalized_text = 'lievito'
      and l.status = 'implemented'
      and l.corrected_decision ilike '%canonical slug "lievito"%'
  );
end $$;

commit;
