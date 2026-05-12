begin;

-- Run 41 showed the agent can find the right target for common surface forms,
-- but may choose add_localization where an alias is safer. Keep canonical
-- display names stable and map plural/surface forms as aliases.

do $$
declare
  v_now timestamptz := now();
  v_apple_id uuid;
  v_corn_id uuid;
  v_conflict record;
begin
  select i.id into v_apple_id
  from public.ingredients i
  where i.slug = 'apple'
    and i.quality_status = 'active'
  limit 1;

  if v_apple_id is null then
    raise exception 'mele alias governance failed: active canonical slug apple not found';
  end if;

  select i.id into v_corn_id
  from public.ingredients i
  where i.slug = 'corn'
    and i.quality_status = 'active'
  limit 1;

  if v_corn_id is null then
    raise exception 'mais alias governance failed: active canonical slug corn not found';
  end if;

  select a.normalized_alias_text, a.ingredient_id, i.slug
  into v_conflict
  from public.ingredient_aliases_v2 a
  join public.ingredients i on i.id = a.ingredient_id
  where a.normalized_alias_text = 'mele'
    and coalesce(a.is_active, true)
    and a.ingredient_id is distinct from v_apple_id
  limit 1;

  if found then
    raise exception 'active alias conflict for mele: existing target %, requested apple', v_conflict.slug;
  end if;

  select a.normalized_alias_text, a.ingredient_id, i.slug
  into v_conflict
  from public.ingredient_aliases_v2 a
  join public.ingredients i on i.id = a.ingredient_id
  where a.normalized_alias_text = 'mais'
    and coalesce(a.is_active, true)
    and a.ingredient_id is distinct from v_corn_id
  limit 1;

  if found then
    raise exception 'active alias conflict for mais: existing target %, requested corn', v_conflict.slug;
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
      v_apple_id,
      'mele',
      'mele',
      'it',
      'manual_governance',
      0.98,
      0.98,
      true,
      'approved',
      'manual',
      v_now,
      'Governed plural surface form: Italian plural "mele" maps to canonical apple; canonical display remains singular "Mela".',
      v_now,
      v_now
    ),
    (
      v_corn_id,
      'mais',
      'mais',
      'it',
      'manual_governance',
      0.97,
      0.97,
      true,
      'approved',
      'manual',
      v_now,
      'Governed surface form: "mais" maps to canonical corn; it should not overwrite the existing Italian display name.',
      v_now,
      v_now
    )
  on conflict do nothing;

  update public.ingredient_aliases_v2 a
  set
    alias_text = case a.normalized_alias_text when 'mele' then 'mele' else 'mais' end,
    language_code = 'it',
    source = 'manual_governance',
    confidence = greatest(coalesce(a.confidence, 0), case a.normalized_alias_text when 'mele' then 0.98 else 0.97 end),
    confidence_score = greatest(coalesce(a.confidence_score, 0), case a.normalized_alias_text when 'mele' then 0.98 else 0.97 end),
    is_active = true,
    status = 'approved',
    approval_source = 'manual',
    approved_at = coalesce(a.approved_at, v_now),
    review_notes = case a.normalized_alias_text
      when 'mele' then 'Governed plural surface form: Italian plural "mele" maps to canonical apple; canonical display remains singular "Mela".'
      else 'Governed surface form: "mais" maps to canonical corn; it should not overwrite the existing Italian display name.'
    end,
    updated_at = v_now
  where (a.normalized_alias_text = 'mele' and a.ingredient_id = v_apple_id)
     or (a.normalized_alias_text = 'mais' and a.ingredient_id = v_corn_id);

  update public.custom_ingredient_observations o
  set
    status = 'resolved_alias',
    updated_at = v_now
  where o.normalized_text in ('mele', 'mais');

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
        'mele'::text,
        v_apple_id,
        'mele'::text,
        0.98::double precision,
        'Governance decision: Italian plural "mele" is a surface alias of apple, not a replacement Italian display name.'
      ),
      (
        'mais'::text,
        v_corn_id,
        'mais'::text,
        0.97::double precision,
        'Governance decision: "mais" is a surface alias of corn because canonical corn already has an Italian display name.'
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
        when 'mele' then 'Superseded by governed alias mele -> apple; plural surface forms should not replace canonical localization.'
        when 'mais' then 'Superseded by governed alias mais -> corn; surface forms should not replace canonical localization.'
        else 'Superseded by manual governance decision.'
      end
    ),
    updated_at = v_now
  where p.normalized_text in ('mele', 'mais')
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
    'prompt_improvement',
    'medium',
    'implemented',
    learning.original_recommendation,
    learning.observed_problem,
    learning.corrected_decision,
    learning.policy_implication,
    learning.evaluation_recommendation,
    prompt.prompt_recommendation,
    v_now,
    v_now
  from (
    values
      (
        'mele'::text,
        jsonb_build_object('source', 'catalog_agent_run_41', 'proposal_id', 22, 'proposal_type', 'add_localization'),
        'The agent correctly found target apple, but proposed add_localization for an Italian plural surface form.',
        'Use approve_alias for plural/surface forms when a canonical localization already exists.',
        'Plural localized forms should preserve the canonical display name and become aliases unless they are the intended display name.',
        'Add fixtures where "mele" resolves to approve_alias apple, not add_localization.'
      ),
      (
        'mais'::text,
        jsonb_build_object('source', 'catalog_agent_run_41', 'proposal_id', 21, 'proposal_type', 'add_localization'),
        'The agent correctly found target corn, but proposed add_localization even though corn already has an Italian display name.',
        'Use approve_alias for surface terms when a target localization is already present.',
        'Localized surface terms should become aliases when they would otherwise overwrite a curated display name.',
        'Add fixtures where "mais" resolves to approve_alias corn when the target already has Italian localization.'
      )
  ) as learning(
    normalized_text,
    original_recommendation,
    observed_problem,
    corrected_decision,
    policy_implication,
    evaluation_recommendation
  )
  cross join lateral (
    select 'When the model identifies a target for a plural/localized surface form and that target already has a curated localization, prefer approve_alias over add_localization.'::text as prompt_recommendation
  ) prompt
  where not exists (
    select 1
    from public.catalog_agent_learnings l
    where l.normalized_text = learning.normalized_text
      and l.status = 'implemented'
      and l.corrected_decision = learning.corrected_decision
  );
end $$;

commit;
