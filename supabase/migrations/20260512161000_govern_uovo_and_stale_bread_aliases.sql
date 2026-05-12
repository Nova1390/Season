begin;

-- Encode two reviewed catalog-governance decisions discovered during the
-- controlled agent batch:
-- 1. Italian singular "uovo" is an alias of the existing canonical "eggs".
-- 2. "pane raffermo" is not a separate product identity; map it to "bread"
--    and keep the stale/preparation state in recipe instructions or notes.

do $$
declare
  v_now timestamptz := now();
  v_eggs_id uuid;
  v_bread_id uuid;
  v_conflict record;
begin
  select i.id into v_eggs_id
  from public.ingredients i
  where i.slug = 'eggs'
    and i.quality_status = 'active'
  limit 1;

  if v_eggs_id is null then
    raise exception 'uovo governance failed: active canonical slug eggs not found';
  end if;

  select i.id into v_bread_id
  from public.ingredients i
  where i.slug = 'bread'
    and i.quality_status = 'active'
  limit 1;

  if v_bread_id is null then
    raise exception 'pane raffermo governance failed: active canonical slug bread not found';
  end if;

  select a.normalized_alias_text, a.ingredient_id, i.slug
  into v_conflict
  from public.ingredient_aliases_v2 a
  join public.ingredients i on i.id = a.ingredient_id
  where a.normalized_alias_text = 'uovo'
    and coalesce(a.is_active, true)
    and a.ingredient_id is distinct from v_eggs_id
  limit 1;

  if found then
    raise exception
      'active alias conflict for uovo: existing target %, requested eggs',
      v_conflict.slug;
  end if;

  select a.normalized_alias_text, a.ingredient_id, i.slug
  into v_conflict
  from public.ingredient_aliases_v2 a
  join public.ingredients i on i.id = a.ingredient_id
  where a.normalized_alias_text = 'pane raffermo'
    and coalesce(a.is_active, true)
    and a.ingredient_id is distinct from v_bread_id
  limit 1;

  if found then
    raise exception
      'active alias conflict for pane raffermo: existing target %, requested bread',
      v_conflict.slug;
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
      v_eggs_id,
      'uovo',
      'uovo',
      'it',
      'manual_governance',
      0.99,
      0.99,
      true,
      'approved',
      'manual',
      v_now,
      'Governed singular Italian alias: bare "uovo" maps to canonical eggs unless a recipe specifies a different egg product.',
      v_now,
      v_now
    ),
    (
      v_bread_id,
      'pane raffermo',
      'pane raffermo',
      'it',
      'manual_governance',
      0.94,
      0.94,
      true,
      'approved',
      'manual',
      v_now,
      'Governed preparation-state alias: stale bread maps to canonical bread; staleness should remain recipe context, not a distinct catalog identity.',
      v_now,
      v_now
    )
  on conflict do nothing;

  update public.ingredient_aliases_v2 a
  set
    alias_text = 'uovo',
    language_code = 'it',
    source = 'manual_governance',
    confidence = greatest(coalesce(a.confidence, 0), 0.99),
    confidence_score = greatest(coalesce(a.confidence_score, 0), 0.99),
    is_active = true,
    status = 'approved',
    approval_source = 'manual',
    approved_at = coalesce(a.approved_at, v_now),
    review_notes = 'Governed singular Italian alias: bare "uovo" maps to canonical eggs unless a recipe specifies a different egg product.',
    updated_at = v_now
  where a.normalized_alias_text = 'uovo'
    and a.ingredient_id = v_eggs_id;

  update public.ingredient_aliases_v2 a
  set
    alias_text = 'pane raffermo',
    language_code = 'it',
    source = 'manual_governance',
    confidence = greatest(coalesce(a.confidence, 0), 0.94),
    confidence_score = greatest(coalesce(a.confidence_score, 0), 0.94),
    is_active = true,
    status = 'approved',
    approval_source = 'manual',
    approved_at = coalesce(a.approved_at, v_now),
    review_notes = 'Governed preparation-state alias: stale bread maps to canonical bread; staleness should remain recipe context, not a distinct catalog identity.',
    updated_at = v_now
  where a.normalized_alias_text = 'pane raffermo'
    and a.ingredient_id = v_bread_id;

  update public.custom_ingredient_observations o
  set
    status = 'resolved_alias',
    updated_at = v_now
  where o.normalized_text in ('uovo', 'pane raffermo');

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
    decision.normalized_text,
    'approve_alias',
    decision.ingredient_id,
    decision.alias_text,
    'it',
    decision.confidence_score,
    decision.reviewer_note,
    'resolved_alias',
    'approved',
    v_now,
    v_now
  from (
    values
      (
        'uovo'::text,
        v_eggs_id,
        'uovo'::text,
        0.99::double precision,
        'Governance decision: singular Italian "uovo" maps to canonical eggs for bare recipe usage.'
      ),
      (
        'pane raffermo'::text,
        v_bread_id,
        'pane raffermo'::text,
        0.94::double precision,
        'Governance decision: stale bread maps to canonical bread; stale/raffermo remains recipe preparation context.'
      )
  ) as decision(normalized_text, ingredient_id, alias_text, confidence_score, reviewer_note)
  where not exists (
    select 1
    from public.catalog_candidate_decisions d
    where d.normalized_text = decision.normalized_text
      and d.action = 'approve_alias'
      and d.ingredient_id = decision.ingredient_id
  );

  update public.catalog_agent_proposals p
  set
    status = 'superseded',
    rejection_reason = coalesce(
      p.rejection_reason,
      case p.normalized_text
        when 'uovo' then 'Superseded by governed alias uovo -> eggs.'
        when 'pane raffermo' then 'Superseded by governed preparation-state alias pane raffermo -> bread.'
        else 'Superseded by manual governance decision.'
      end
    ),
    updated_at = v_now
  where p.normalized_text in ('uovo', 'pane raffermo')
    and p.status in ('draft', 'queued_for_validation', 'validated', 'needs_human_review', 'failed_validation');

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
    learning.normalized_text,
    learning.learning_type,
    learning.severity,
    'implemented',
    learning.original_recommendation,
    learning.observed_problem,
    learning.corrected_decision,
    learning.policy_implication,
    learning.evaluation_recommendation,
    learning.prompt_recommendation,
    v_now,
    v_now
  from (
    values
      (
        'uovo'::text,
        'prompt_improvement'::text,
        'medium'::text,
        jsonb_build_object('source', 'catalog_agent_run_34', 'proposal_id', 14),
        'The agent understood "uovo" as a standard egg but lacked an actionable eggs/uova target in the work packet.',
        'Use canonical eggs for bare Italian singular "uovo".',
        'Common singular/plural localized base-food forms should be supplied as deterministic candidates before asking the LLM.',
        'Add fixtures where "uovo" resolves to eggs and does not require human review.',
        'When "uovo" appears without a modifier, prefer approve_alias to canonical eggs when that target is available.'
      ),
      (
        'pane raffermo'::text,
        'policy_gap'::text,
        'medium'::text,
        jsonb_build_object('source', 'catalog_agent_run_34', 'proposal_id', 13),
        'The agent proposed a new canonical for stale bread, but the product identity should remain bread.',
        'Map "pane raffermo" to canonical bread; treat staleness as recipe preparation context.',
        'Preparation/state adjectives such as stale, toasted, chopped, cooked, or grated should not automatically create catalog identities unless they materially change product identity.',
        'Add fixtures where "pane raffermo" resolves to bread and does not create a canonical ingredient.',
        'When a modifier is a preparation or freshness state rather than a product identity, prefer the base canonical and preserve the modifier in recipe context.'
      )
  ) as learning(
    normalized_text,
    learning_type,
    severity,
    original_recommendation,
    observed_problem,
    corrected_decision,
    policy_implication,
    evaluation_recommendation,
    prompt_recommendation
  )
  where not exists (
    select 1
    from public.catalog_agent_learnings l
    where l.normalized_text = learning.normalized_text
      and l.status = 'implemented'
      and l.corrected_decision = learning.corrected_decision
  );
end $$;

commit;
