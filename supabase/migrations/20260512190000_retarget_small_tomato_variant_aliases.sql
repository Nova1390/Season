begin;

-- Small tomato variants must not leak into the base tomato context. After the
-- dedicated pomodorini child canonical exists, variant aliases should point to
-- that child instead of the generic tomato node.

do $$
declare
  v_now timestamptz := now();
  v_pomodorini_id uuid;
  v_tomato_id uuid;
begin
  select i.id into v_pomodorini_id
  from public.ingredients i
  where i.slug = 'pomodorini'
    and i.quality_status = 'active'
  limit 1;

  if v_pomodorini_id is null then
    raise exception 'small tomato alias retarget failed: active canonical slug pomodorini not found';
  end if;

  select i.id into v_tomato_id
  from public.ingredients i
  where i.slug = 'tomato'
    and i.quality_status = 'active'
  limit 1;

  if v_tomato_id is null then
    raise exception 'small tomato alias retarget failed: active canonical slug tomato not found';
  end if;

  update public.ingredient_aliases_v2 a
  set
    ingredient_id = v_pomodorini_id,
    alias_text = 'pomodorini ciliegino',
    language_code = 'it',
    source = 'manual_governance',
    confidence = greatest(coalesce(a.confidence, 0), 0.99),
    confidence_score = greatest(coalesce(a.confidence_score, 0), 0.99),
    is_active = true,
    status = 'approved',
    approval_source = 'manual',
    approved_at = coalesce(a.approved_at, v_now),
    review_notes = 'Governed meaningful variant: "pomodorini ciliegino" is a small-tomato variant and should target pomodorini, not base tomato.',
    updated_at = v_now
  where a.normalized_alias_text = 'pomodorini ciliegino'
    and coalesce(a.is_active, true);

  if not found then
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
      v_pomodorini_id,
      'pomodorini ciliegino',
      'pomodorini ciliegino',
      'it',
      'manual_governance',
      0.99,
      0.99,
      true,
      'approved',
      'manual',
      v_now,
      'Governed meaningful variant: "pomodorini ciliegino" is a small-tomato variant and should target pomodorini, not base tomato.',
      v_now,
      v_now
    );
  end if;

  update public.custom_ingredient_observations o
  set
    status = 'resolved_alias',
    updated_at = v_now
  where o.normalized_text = 'pomodorini ciliegino';

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
    'pomodorini ciliegino',
    'approve_alias',
    v_pomodorini_id,
    'pomodorini ciliegino',
    'it',
    0.99,
    'Governance decision: small/cherry tomato variants target the pomodorini child canonical instead of base tomato.',
    'resolved_alias',
    'approved',
    v_now,
    v_now
  where not exists (
    select 1
    from public.catalog_candidate_decisions d
    where d.normalized_text = 'pomodorini ciliegino'
      and d.action = 'approve_alias'
      and d.ingredient_id = v_pomodorini_id
  );

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
    'pomodorini ciliegino',
    'duplicate_identity_risk',
    'medium',
    'implemented',
    jsonb_build_object(
      'source', 'context_quality_gate',
      'previous_target_slug', 'tomato',
      'correct_target_slug', 'pomodorini'
    ),
    'Small tomato variant aliases were leaking base tomato into the pre-LLM context for pomodorini.',
    'Map small/cherry tomato surface forms to pomodorini when the child canonical exists.',
    'Variant aliases should prefer the most specific active child canonical; parent tomato remains useful only as hierarchy context.',
    'Golden context replay should fail when pomodorini context includes tomato as an applyable target candidate.',
    'When a candidate phrase contains an identity-bearing variant marker and a matching child canonical exists, target the child canonical rather than the generic parent.',
    v_now,
    v_now
  where not exists (
    select 1
    from public.catalog_agent_learnings l
    where l.normalized_text = 'pomodorini ciliegino'
      and l.status = 'implemented'
      and l.corrected_decision = 'Map small/cherry tomato surface forms to pomodorini when the child canonical exists.'
  );
end $$;

commit;
