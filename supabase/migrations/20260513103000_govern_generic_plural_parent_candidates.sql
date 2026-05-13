begin;

-- Clean one duplicate candidate that made the agent over-escalate generic
-- plural forms. This does not approve the "cipolle" alias; it only keeps the
-- candidate set unambiguous enough for the agent and validator to reason.

do $$
declare
  v_now timestamptz := now();
  v_duplicate_id uuid;
  v_canonical_id uuid;
  v_latest_proposal_id bigint;
  v_latest_run_id bigint;
  v_latest_original_recommendation jsonb := '{}'::jsonb;
begin
  select i.id
  into v_duplicate_id
  from public.ingredients i
  where i.slug = 'cipolla'
  limit 1;

  select i.id
  into v_canonical_id
  from public.ingredients i
  where i.slug = 'onion'
    and i.quality_status = 'active'
  limit 1;

  if v_duplicate_id is not null and v_canonical_id is not null and v_duplicate_id <> v_canonical_id then
    insert into public.ingredient_canonical_redirects (
      ingredient_id,
      canonical_ingredient_id,
      reason,
      created_at,
      updated_at
    )
    values (
      v_duplicate_id,
      v_canonical_id,
      'duplicate_localization_with_parent_candidate_cleanup',
      v_now,
      v_now
    )
    on conflict (ingredient_id) do update
    set
      canonical_ingredient_id = excluded.canonical_ingredient_id,
      reason = excluded.reason,
      updated_at = excluded.updated_at;

    update public.ingredients i
    set
      quality_status = 'deprecated_duplicate',
      updated_at = v_now
    where i.id = v_duplicate_id
      and i.quality_status = 'active';
  end if;

  select
    p.id,
    p.run_id,
    jsonb_strip_nulls(
      jsonb_build_object(
        'proposal_id', p.id,
        'proposal_type', p.proposal_type,
        'risk_level', p.risk_level,
        'status', p.status,
        'target_slug', p.target_slug,
        'source', 'level_5_parent_candidate_cleanup'
      )
    ) as original_recommendation
  into
    v_latest_proposal_id,
    v_latest_run_id,
    v_latest_original_recommendation
  from public.catalog_agent_proposals p
  where p.normalized_text = 'cipolle'
  order by p.id desc
  limit 1;

  insert into public.catalog_agent_learnings (
    proposal_id,
    run_id,
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
  values (
    v_latest_proposal_id,
    v_latest_run_id,
    'cipolle',
    'prompt_improvement',
    'medium',
    'implemented',
    coalesce(v_latest_original_recommendation, '{}'::jsonb),
    'The agent escalated an unqualified plural base vegetable even though an active parent canonical existed. Duplicate/localized base candidates and color-specific child variants made the target set look more ambiguous than the recipe evidence required.',
    'For unqualified plural or singular base produce terms, use approve_alias to the active parent canonical when the recipe provides no color/cultivar/product-form modifier and the candidate set contains that parent.',
    'Meaningful variants such as red/yellow/white onions stay distinct child or sibling targets, but their existence should not block a generic parent mapping for an unqualified base term.',
    'Add evaluation coverage where generic plural produce maps to the parent canonical while explicitly qualified color/cultivar variants remain separate.',
    'When a term is an unqualified localized plural/singular base produce form and an active parent canonical is present, prefer approve_alias to the parent; only escalate when recipe evidence includes an identity-bearing modifier or no parent candidate exists.',
    v_now,
    v_now
  )
  on conflict do nothing;

  update public.catalog_agent_proposals p
  set
    status = 'superseded',
    rejection_reason = coalesce(
      p.rejection_reason,
      'Superseded by implemented parent-candidate cleanup learning for unqualified generic plural produce terms.'
    ),
    updated_at = v_now
  where p.normalized_text = 'cipolle'
    and p.status in ('draft', 'queued_for_validation', 'validated', 'needs_human_review', 'failed_validation');
end $$;

commit;
