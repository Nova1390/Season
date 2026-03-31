-- Controlled alias expansion workflow for high-impact reconciliation blockers.
-- Backend-only, explicit, and governance-safe.

create or replace function public.top_alias_expansion_blockers(
  p_limit integer default 50,
  p_min_row_count bigint default 1,
  p_min_recipe_count bigint default 1
)
returns table (
  normalized_text text,
  row_count bigint,
  recipe_count bigint,
  top_safety_reason text,
  candidate_status text,
  has_candidate_signal boolean,
  has_approved_alias boolean,
  has_any_alias_match boolean,
  has_legacy_mapping boolean
)
language sql
stable
set search_path = public
as $$
  select
    a.normalized_text,
    a.row_count,
    a.recipe_count,
    a.top_safety_reason,
    a.candidate_status,
    a.has_candidate_signal,
    a.has_approved_alias,
    a.has_any_alias_match,
    a.has_legacy_mapping
  from public.recipe_reconciliation_unresolved_text_analysis a
  where a.recommended_next_action = 'add_alias'
    and a.row_count >= greatest(1, coalesce(p_min_row_count, 1))
    and a.recipe_count >= greatest(1, coalesce(p_min_recipe_count, 1))
    and not coalesce(a.has_approved_alias, false)
  order by a.recipe_count desc, a.row_count desc, a.normalized_text asc
  limit greatest(1, coalesce(p_limit, 50));
$$;

create or replace function public.approve_reconciliation_alias(
  p_normalized_text text,
  p_ingredient_id uuid,
  p_alias_text text default null,
  p_language_code text default null,
  p_reviewer_note text default null,
  p_confidence_score double precision default null
)
returns table (
  normalized_text text,
  ingredient_id uuid,
  alias_text text,
  alias_status text,
  decision_logged boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_user uuid := auth.uid();
  v_normalized text := lower(trim(coalesce(p_normalized_text, '')));
  v_alias_text text := nullif(trim(coalesce(p_alias_text, '')), '');
  v_language_code text := nullif(lower(trim(coalesce(p_language_code, ''))), '');
  v_active_alias_id bigint;
  v_active_alias_ingredient_id uuid;
  v_decision_id bigint;
begin
  if v_normalized = '' then
    raise exception 'normalized_text is required';
  end if;

  if p_ingredient_id is null then
    raise exception 'ingredient_id is required';
  end if;

  if p_confidence_score is not null and (p_confidence_score < 0 or p_confidence_score > 1) then
    raise exception 'confidence_score must be between 0 and 1';
  end if;

  if not exists (
    select 1 from public.ingredients i where i.id = p_ingredient_id
  ) then
    raise exception 'ingredient_id not found: %', p_ingredient_id;
  end if;

  if v_alias_text is null then
    v_alias_text := initcap(replace(v_normalized, '_', ' '));
  end if;

  select a.id, a.ingredient_id
  into v_active_alias_id, v_active_alias_ingredient_id
  from public.ingredient_aliases_v2 a
  where a.normalized_alias_text = v_normalized
    and coalesce(a.is_active, true)
  order by a.id desc
  limit 1;

  -- Conservative safety: never re-point an active alias to a different ingredient implicitly.
  if v_active_alias_id is not null and v_active_alias_ingredient_id is distinct from p_ingredient_id then
    raise exception
      'conflicting active alias exists for %, ingredient_id=% (requested=%)',
      v_normalized,
      v_active_alias_ingredient_id,
      p_ingredient_id;
  end if;

  if v_active_alias_id is null then
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
      approved_by,
      review_notes,
      created_at,
      updated_at
    )
    values (
      p_ingredient_id,
      v_alias_text,
      v_normalized,
      v_language_code,
      'manual',
      p_confidence_score,
      p_confidence_score,
      true,
      'approved',
      'manual',
      v_now,
      v_user,
      nullif(trim(coalesce(p_reviewer_note, '')), ''),
      v_now,
      v_now
    );
  else
    update public.ingredient_aliases_v2
    set
      alias_text = v_alias_text,
      language_code = coalesce(v_language_code, language_code),
      source = 'manual',
      confidence = coalesce(p_confidence_score, confidence),
      confidence_score = coalesce(p_confidence_score, confidence_score, confidence),
      is_active = true,
      status = 'approved',
      approval_source = 'manual',
      approved_at = coalesce(approved_at, v_now),
      approved_by = coalesce(v_user, approved_by),
      review_notes = coalesce(nullif(trim(coalesce(p_reviewer_note, '')), ''), review_notes),
      updated_at = v_now
    where id = v_active_alias_id;
  end if;

  update public.custom_ingredient_observations
  set
    status = 'resolved_alias',
    updated_at = v_now
  where normalized_text = v_normalized;

  insert into public.catalog_candidate_decisions (
    normalized_text,
    action,
    ingredient_id,
    alias_text,
    language_code,
    confidence_score,
    reviewer_note,
    reviewer_id,
    resulting_observation_status,
    resulting_alias_status,
    created_at,
    updated_at
  )
  values (
    v_normalized,
    'approve_alias',
    p_ingredient_id,
    v_alias_text,
    v_language_code,
    p_confidence_score,
    nullif(trim(coalesce(p_reviewer_note, '')), ''),
    v_user,
    'resolved_alias',
    'approved',
    v_now,
    v_now
  )
  returning id into v_decision_id;

  return query
  select
    v_normalized,
    p_ingredient_id,
    v_alias_text,
    'approved'::text,
    (v_decision_id is not null);
end;
$$;

revoke all on function public.top_alias_expansion_blockers(integer, bigint, bigint) from public;
grant execute on function public.top_alias_expansion_blockers(integer, bigint, bigint) to authenticated;
grant execute on function public.top_alias_expansion_blockers(integer, bigint, bigint) to service_role;

revoke all on function public.approve_reconciliation_alias(text, uuid, text, text, text, double precision) from public;
grant execute on function public.approve_reconciliation_alias(text, uuid, text, text, text, double precision) to authenticated;
grant execute on function public.approve_reconciliation_alias(text, uuid, text, text, text, double precision) to service_role;

