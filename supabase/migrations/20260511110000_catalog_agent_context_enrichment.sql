begin;

-- Enrich the Catalog Governance Agent work packet with recipe context and
-- disambiguation hints. This remains read-only and dev-first.

create or replace function public.get_catalog_agent_triage_snapshot(
  p_limit integer default 50,
  p_source_domain text default null,
  p_include_non_new boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := least(100, greatest(1, coalesce(p_limit, 50)));
  v_source_domain text := nullif(lower(trim(coalesce(p_source_domain, ''))), '');
  v_generated_at timestamptz := now();
  v_items jsonb := '[]'::jsonb;
begin
  perform public.assert_catalog_admin(v_user);

  with queue as (
    select
      c.normalized_text,
      c.occurrence_count,
      c.latest_example,
      c.language_code,
      c.source,
      c.first_seen_at,
      c.last_seen_at,
      c.priority_score,
      c.existing_alias_status,
      c.has_approved_alias,
      c.has_any_alias_match,
      c.suggested_resolution_type,
      c.status,
      o.id as observation_id,
      coalesce(o.raw_examples, '[]'::jsonb) as raw_examples,
      o.latest_recipe_id,
      b.row_count as blocker_row_count,
      b.recipe_count as blocker_recipe_count,
      b.likely_fix_type as blocker_likely_fix_type,
      b.canonical_candidate_ingredient_id as blocker_candidate_ingredient_id,
      b.canonical_candidate_slug as blocker_candidate_slug,
      b.canonical_candidate_name as blocker_candidate_name,
      b.blocker_reason,
      b.recommended_next_action,
      regexp_replace(lower(trim(c.normalized_text)), '[^a-z0-9]+', '', 'g') as compact_key
    from public.catalog_resolution_candidate_queue c
    left join public.custom_ingredient_observations o
      on o.normalized_text = c.normalized_text
    left join public.catalog_coverage_blocker_terms b
      on b.normalized_text = c.normalized_text
    where (p_include_non_new or c.status = 'new')
      and (
        v_source_domain is null
        or lower(coalesce(c.source, '')) = v_source_domain
        or lower(coalesce(c.source, '')) like '%' || v_source_domain || '%'
      )
    order by
      c.priority_score desc nulls last,
      c.occurrence_count desc,
      c.last_seen_at desc,
      c.normalized_text asc
    limit v_limit
  ),
  enriched as (
    select
      q.*,
      coalesce(recipe_context.context, '{}'::jsonb) as recipe_context,
      coalesce(canonical_matches.matches, '[]'::jsonb) as possible_canonical_matches,
      coalesce(alias_matches.matches, '[]'::jsonb) as existing_alias_matches,
      coalesce(previous_decisions.decisions, '[]'::jsonb) as previous_catalog_decisions,
      coalesce(previous_proposals.proposals, '[]'::jsonb) as previous_agent_proposals
    from queue q
    left join lateral (
      select jsonb_build_object(
        'recipe_id', r.id,
        'title', r.title,
        'source_name', r.source_name,
        'source_url', r.source_url,
        'source_type', r.source_type,
        'servings', r.servings,
        'matched_ingredient_rows', coalesce(matched_rows.items, '[]'::jsonb),
        'nearby_ingredients', coalesce(nearby_rows.items, '[]'::jsonb),
        'all_ingredient_names', coalesce(all_names.items, '[]'::jsonb),
        'step_snippets', coalesce(step_rows.items, '[]'::jsonb)
      ) as context
      from public.recipes r
      left join lateral (
        select jsonb_agg(
          jsonb_build_object(
            'index', ing.ord,
            'name', ing.elem->>'name',
            'quantity_value', ing.elem->>'quantity_value',
            'quantity_unit', ing.elem->>'quantity_unit',
            'has_canonical_ingredient_id', nullif(trim(coalesce(ing.elem->>'ingredient_id', '')), '') is not null,
            'raw', ing.elem
          )
          order by ing.ord
        ) as items
        from jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as ing(elem, ord)
        where lower(trim(coalesce(ing.elem->>'name', ''))) = q.normalized_text
           or regexp_replace(lower(trim(coalesce(ing.elem->>'name', ''))), '[^a-z0-9]+', '', 'g') = q.compact_key
      ) matched_rows on true
      left join lateral (
        select jsonb_agg(
          jsonb_build_object(
            'index', ing.ord,
            'name', ing.elem->>'name',
            'quantity_value', ing.elem->>'quantity_value',
            'quantity_unit', ing.elem->>'quantity_unit',
            'has_canonical_ingredient_id', nullif(trim(coalesce(ing.elem->>'ingredient_id', '')), '') is not null
          )
          order by ing.ord
        ) as items
        from jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as ing(elem, ord)
        where exists (
          select 1
          from jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as target(elem, target_ord)
          where (
              lower(trim(coalesce(target.elem->>'name', ''))) = q.normalized_text
              or regexp_replace(lower(trim(coalesce(target.elem->>'name', ''))), '[^a-z0-9]+', '', 'g') = q.compact_key
            )
            and abs(ing.ord - target.target_ord) <= 3
        )
        limit 12
      ) nearby_rows on true
      left join lateral (
        select jsonb_agg(ingredient_name order by ord) as items
        from (
          select
            ing.ord,
            nullif(trim(coalesce(ing.elem->>'name', '')), '') as ingredient_name
          from jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as ing(elem, ord)
          where nullif(trim(coalesce(ing.elem->>'name', '')), '') is not null
          order by ing.ord
          limit 30
        ) names
      ) all_names on true
      left join lateral (
        select jsonb_agg(step_text order by ord) as items
        from (
          select
            st.ord,
            left(st.step_text, 240) as step_text
          from jsonb_array_elements_text(coalesce(r.steps::jsonb, '[]'::jsonb)) with ordinality as st(step_text, ord)
          where lower(st.step_text) like '%' || q.normalized_text || '%'
          order by st.ord
          limit 3
        ) snippets
      ) step_rows on true
      where r.id::text = q.latest_recipe_id
      limit 1
    ) recipe_context on true
    left join lateral (
      select coalesce(jsonb_agg(to_jsonb(match_row)), '[]'::jsonb) as matches
      from (
        select
          m.ingredient_id,
          m.slug,
          m.ingredient_type,
          m.quality_status,
          m.parent_ingredient_id,
          m.parent_slug,
          m.specificity_rank,
          m.variant_kind,
          m.it_name,
          m.en_name,
          case
            when lower(coalesce(m.it_name, '')) = q.normalized_text then 'it_name_exact'
            when lower(coalesce(m.en_name, '')) = q.normalized_text then 'en_name_exact'
            when lower(replace(coalesce(m.slug, ''), '_', ' ')) = q.normalized_text then 'slug_exact'
            when q.compact_key <> ''
              and regexp_replace(
                lower(trim(coalesce(m.it_name, m.en_name, replace(m.slug, '_', ' '), ''))),
                '[^a-z0-9]+',
                '',
                'g'
              ) = q.compact_key then 'compact_key'
            when lower(coalesce(m.it_name, '')) like '%' || q.normalized_text || '%' then 'it_name_contains'
            when lower(coalesce(m.en_name, '')) like '%' || q.normalized_text || '%' then 'en_name_contains'
            when lower(replace(coalesce(m.slug, ''), '_', ' ')) like '%' || q.normalized_text || '%' then 'slug_contains'
            else 'catalog_search'
          end as match_reason
        from public.ingredient_catalog_app_summary m
        where m.quality_status <> 'deprecated_duplicate'
          and (
            lower(coalesce(m.it_name, '')) = q.normalized_text
            or lower(coalesce(m.en_name, '')) = q.normalized_text
            or lower(replace(coalesce(m.slug, ''), '_', ' ')) = q.normalized_text
            or (
              q.compact_key <> ''
              and regexp_replace(
                lower(trim(coalesce(m.it_name, m.en_name, replace(m.slug, '_', ' '), ''))),
                '[^a-z0-9]+',
                '',
                'g'
              ) = q.compact_key
            )
            or (
              length(q.normalized_text) >= 5
              and (
                lower(coalesce(m.it_name, '')) like '%' || q.normalized_text || '%'
                or lower(coalesce(m.en_name, '')) like '%' || q.normalized_text || '%'
                or lower(replace(coalesce(m.slug, ''), '_', ' ')) like '%' || q.normalized_text || '%'
              )
            )
          )
        order by
          case
            when lower(coalesce(m.it_name, '')) = q.normalized_text then 1
            when lower(coalesce(m.en_name, '')) = q.normalized_text then 2
            when lower(replace(coalesce(m.slug, ''), '_', ' ')) = q.normalized_text then 3
            when lower(coalesce(m.it_name, '')) like q.normalized_text || '%' then 4
            when lower(coalesce(m.en_name, '')) like q.normalized_text || '%' then 5
            else 9
          end,
          coalesce(m.specificity_rank, 999),
          m.slug
        limit 12
      ) match_row
    ) canonical_matches on true
    left join lateral (
      select coalesce(jsonb_agg(to_jsonb(alias_row)), '[]'::jsonb) as matches
      from (
        select
          a.alias_id,
          a.alias_text,
          a.normalized_alias_text,
          a.language_code,
          a.ingredient_id,
          a.ingredient_slug,
          a.confidence_score,
          a.status,
          a.is_active,
          a.approval_source,
          a.approved_at
        from public.ingredient_alias_app_summary a
        where a.normalized_alias_text = q.normalized_text
           or regexp_replace(lower(trim(a.normalized_alias_text)), '[^a-z0-9]+', '', 'g') = q.compact_key
           or (
             length(q.normalized_text) >= 5
             and a.normalized_alias_text like '%' || q.normalized_text || '%'
           )
        order by
          case when a.normalized_alias_text = q.normalized_text then 1 else 2 end,
          a.confidence_score desc nulls last,
          a.approved_at desc nulls last
        limit 12
      ) alias_row
    ) alias_matches on true
    left join lateral (
      select coalesce(jsonb_agg(to_jsonb(decision_row)), '[]'::jsonb) as decisions
      from (
        select
          d.id,
          d.action,
          d.ingredient_id,
          d.alias_text,
          d.language_code,
          d.confidence_score,
          d.resulting_observation_status,
          d.resulting_alias_status,
          d.created_at
        from public.catalog_candidate_decisions d
        where d.normalized_text = q.normalized_text
        order by d.created_at desc
        limit 5
      ) decision_row
    ) previous_decisions on true
    left join lateral (
      select coalesce(jsonb_agg(to_jsonb(proposal_row)), '[]'::jsonb) as proposals
      from (
        select
          p.id,
          p.proposal_type,
          p.target_ingredient_id,
          p.target_slug,
          p.proposed_slug,
          p.confidence_score,
          p.risk_level,
          p.auto_apply_eligible,
          p.status,
          p.created_at
        from public.catalog_agent_proposals p
        where p.normalized_text = q.normalized_text
        order by p.created_at desc
        limit 5
      ) proposal_row
    ) previous_proposals on true
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'normalized_text', e.normalized_text,
        'observation', jsonb_build_object(
          'observation_id', e.observation_id,
          'occurrence_count', e.occurrence_count,
          'latest_example', e.latest_example,
          'raw_examples', e.raw_examples,
          'language_code', e.language_code,
          'source', e.source,
          'latest_recipe_id', e.latest_recipe_id,
          'first_seen_at', e.first_seen_at,
          'last_seen_at', e.last_seen_at,
          'status', e.status
        ),
        'priority', jsonb_build_object(
          'priority_score', e.priority_score,
          'suggested_resolution_type', e.suggested_resolution_type,
          'existing_alias_status', e.existing_alias_status,
          'has_approved_alias', e.has_approved_alias,
          'has_any_alias_match', e.has_any_alias_match
        ),
        'coverage_blocker', jsonb_build_object(
          'row_count', e.blocker_row_count,
          'recipe_count', e.blocker_recipe_count,
          'likely_fix_type', e.blocker_likely_fix_type,
          'canonical_candidate_ingredient_id', e.blocker_candidate_ingredient_id,
          'canonical_candidate_slug', e.blocker_candidate_slug,
          'canonical_candidate_name', e.blocker_candidate_name,
          'blocker_reason', e.blocker_reason,
          'recommended_next_action', e.recommended_next_action
        ),
        'context', jsonb_build_object(
          'recipe_context', e.recipe_context,
          'possible_canonical_matches', e.possible_canonical_matches,
          'existing_alias_matches', e.existing_alias_matches,
          'previous_catalog_decisions', e.previous_catalog_decisions,
          'previous_agent_proposals', e.previous_agent_proposals,
          'semantic_disambiguation', jsonb_build_object(
            'term_is_likely_ingredient_when', array[
              'appears_in_recipe_ingredients',
              'has_quantity_or_unit',
              'appears_near_other_recipe_ingredients',
              'has_catalog_matches_or_alias_matches'
            ],
            'ambiguous_term_guidance', 'If the term is clearly an ingredient but canonical target is ambiguous, propose needs_human_review with candidate_targets in evidence instead of treating confidence as globally low.',
            'use_recipe_context', 'Use title, nearby ingredients, quantity, unit, and step snippets to infer likely culinary identity. Do not invent IDs; use provided candidate targets only.',
            'candidate_target_requirement', 'For approve_alias/add_localization, target_ingredient_id must come from possible_canonical_matches, existing_alias_matches, or coverage_blocker canonical candidate.'
          )
        ),
        'agent_instruction', jsonb_build_object(
          'autonomy_level', 'level_1_propose',
          'allowed_output', array[
            'approve_alias',
            'create_canonical',
            'add_localization',
            'ignore_noise',
            'needs_human_review'
          ],
          'forbidden_output', array[
            'direct_catalog_mutation',
            'direct_recipe_mutation',
            'auto_apply',
            'unreviewed_duplicate_redirect'
          ],
          'default_when_uncertain', 'needs_human_review',
          'when_term_is_ingredient_but_target_is_ambiguous', 'Return needs_human_review with blocking_questions and evidence listing plausible candidate targets and required evidence.'
        )
      )
      order by e.priority_score desc nulls last, e.occurrence_count desc, e.normalized_text asc
    ),
    '[]'::jsonb
  )
  into v_items
  from enriched e;

  return jsonb_build_object(
    'metadata', jsonb_build_object(
      'generated_at', v_generated_at,
      'source', 'catalog_agent_triage_snapshot_v2_context_enriched',
      'environment_policy', 'development_only_until_explicitly_promoted',
      'requested_limit', p_limit,
      'effective_limit', v_limit,
      'source_domain_filter', v_source_domain,
      'include_non_new', p_include_non_new,
      'item_count', jsonb_array_length(v_items)
    ),
    'policy', jsonb_build_object(
      'responsibility_charter', 'docs/catalog-agent-responsibility-charter.md',
      'contracts', 'docs/catalog-ai-agent-contracts.md',
      'operating_plan', 'docs/catalog-ai-agent-operating-plan.md',
      'core_principle', 'Own the backlog. Respect the catalog. Escalate ambiguity. Apply only what is safe.',
      'ingredient_intelligence_principle', 'Do not confuse ingredient existence confidence with canonical-target confidence. A term can be clearly an ingredient and still need target disambiguation.',
      'must_escalate_when', array[
        'multiple_canonical_targets_are_plausible',
        'term_meaning_changes_by_language_or_culture',
        'nutrition_allergy_or_seasonality_may_differ',
        'term_may_be_brand_product_or_package',
        'parent_child_relation_is_not_strictly_justified',
        'decision_could_affect_many_recipes',
        'evidence_is_insufficient'
      ]
    ),
    'work_items', v_items
  );
end;
$$;

revoke all on function public.get_catalog_agent_triage_snapshot(integer, text, boolean) from public;
grant execute on function public.get_catalog_agent_triage_snapshot(integer, text, boolean) to authenticated;
grant execute on function public.get_catalog_agent_triage_snapshot(integer, text, boolean) to service_role;

comment on function public.get_catalog_agent_triage_snapshot(integer, text, boolean) is
  'Read-only context-enriched work packet for the Catalog Governance Agent. Returns bounded candidate context, recipe clues, and policy hints; performs no catalog mutation.';

commit;
