-- Unify catalog alias approval through the governed alias writer and make the
-- enrichment-draft wrapper own the successful applied lifecycle transition.

create or replace function public.apply_catalog_candidate_decision(
  p_normalized_text text,
  p_action text,
  p_ingredient_id uuid default null,
  p_alias_text text default null,
  p_language_code text default null,
  p_confidence_score double precision default null,
  p_reviewer_note text default null
)
returns table (
  decision_id bigint,
  normalized_text text,
  action text,
  resulting_observation_status text,
  resulting_alias_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_user uuid := auth.uid();
  v_normalized text := lower(trim(coalesce(p_normalized_text, '')));
  v_action text := lower(trim(coalesce(p_action, '')));
  v_alias_text text := nullif(trim(coalesce(p_alias_text, '')), '');
  v_alias_normalized text := case
    when v_alias_text is null then null
    else lower(trim(v_alias_text))
  end;
  v_observation_status text;
  v_alias_status text := null;
  v_decision_id bigint;
  v_decision_floor bigint := 0;
begin
  perform public.assert_catalog_admin(v_user);

  if v_normalized = '' then
    raise exception 'normalized_text is required';
  end if;

  if v_action not in ('approve_alias', 'reject_alias', 'create_new_ingredient', 'ignore') then
    raise exception 'unsupported action: %', v_action;
  end if;

  if not exists (
    select 1
    from public.custom_ingredient_observations as o
    where o.normalized_text = v_normalized
  ) then
    raise exception 'candidate not found for normalized_text: %', v_normalized;
  end if;

  if v_action = 'approve_alias' then
    if p_ingredient_id is null then
      raise exception 'approve_alias requires ingredient_id';
    end if;
    if v_alias_text is null then
      raise exception 'approve_alias requires alias_text';
    end if;

    select coalesce(max(d.id), 0)
    into v_decision_floor
    from public.catalog_candidate_decisions as d;

    perform
      aa.normalized_text
    from public.approve_reconciliation_alias(
      p_normalized_text => v_normalized,
      p_ingredient_id => p_ingredient_id,
      p_alias_text => v_alias_text,
      p_language_code => p_language_code,
      p_reviewer_note => p_reviewer_note,
      p_confidence_score => p_confidence_score
    ) as aa;

    select d.id
    into v_decision_id
    from public.catalog_candidate_decisions as d
    where d.id > v_decision_floor
      and d.normalized_text = v_normalized
      and d.action = 'approve_alias'
      and (
        d.reviewer_id is not distinct from v_user
        or coalesce(auth.role(), '') = 'service_role'
      )
    order by d.id desc
    limit 1;

    return query
    select
      v_decision_id,
      v_normalized,
      v_action,
      'resolved_alias'::text,
      'approved'::text;
    return;
  elsif v_action = 'reject_alias' then
    if v_alias_text is not null then
      update public.ingredient_aliases_v2 as a
      set
        status = 'rejected',
        approval_source = 'manual',
        review_notes = coalesce(nullif(trim(coalesce(p_reviewer_note, '')), ''), a.review_notes),
        is_active = false,
        updated_at = v_now
      where a.normalized_alias_text = v_alias_normalized;
      v_alias_status := 'rejected';
    else
      v_alias_status := null;
    end if;
    v_observation_status := 'rejected';
  elsif v_action = 'create_new_ingredient' then
    v_observation_status := 'create_new_candidate';
    v_alias_status := null;
  else
    v_observation_status := 'ignored';
    v_alias_status := null;
  end if;

  update public.custom_ingredient_observations as o
  set
    status = v_observation_status,
    updated_at = v_now
  where o.normalized_text = v_normalized;

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
    v_action,
    p_ingredient_id,
    v_alias_text,
    nullif(trim(coalesce(p_language_code, '')), ''),
    p_confidence_score,
    nullif(trim(coalesce(p_reviewer_note, '')), ''),
    v_user,
    v_observation_status,
    v_alias_status,
    v_now,
    v_now
  )
  returning id into v_decision_id;

  return query
  select
    v_decision_id,
    v_normalized,
    v_action,
    v_observation_status,
    v_alias_status;
end;
$$;

revoke all on function public.apply_catalog_candidate_decision(text, text, uuid, text, text, double precision, text) from public;
grant execute on function public.apply_catalog_candidate_decision(text, text, uuid, text, text, double precision, text) to authenticated;
grant execute on function public.apply_catalog_candidate_decision(text, text, uuid, text, text, double precision, text) to service_role;

create or replace function public.create_catalog_ingredient_from_enrichment_draft(
  p_normalized_text text,
  p_reviewer_note text default null,
  p_confidence_score double precision default null
)
returns table (
  ingredient_id uuid,
  normalized_text text,
  slug text,
  created_new boolean,
  alias_created boolean,
  resulting_observation_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_normalized text := lower(trim(coalesce(p_normalized_text, '')));
  v_draft public.catalog_ingredient_enrichment_drafts%rowtype;
  v_validation_errors text[];
  v_alias_text text := null;
  v_reviewer_note text := nullif(trim(coalesce(p_reviewer_note, '')), '');
  v_confidence double precision := p_confidence_score;
  v_result_ingredient_id uuid;
  v_result_normalized_text text;
  v_result_slug text;
  v_result_created_new boolean;
  v_result_alias_created boolean;
  v_resulting_observation_status text;
  v_parent_candidate_id uuid;
  v_variant_kind text;
  v_specificity_rank smallint;
begin
  perform public.assert_catalog_admin(v_user);

  if v_normalized = '' then
    raise exception 'normalized_text is required';
  end if;

  select d.*
  into v_draft
  from public.catalog_ingredient_enrichment_drafts as d
  where d.normalized_text = v_normalized
  limit 1;

  if not found then
    raise exception 'enrichment draft not found for normalized_text: %', v_normalized;
  end if;

  if v_draft.status <> 'ready' then
    raise exception 'draft_status_not_ready: status=%', v_draft.status;
  end if;

  v_validation_errors := public.catalog_enrichment_validation_errors(
    v_draft.ingredient_type,
    v_draft.status,
    v_draft.canonical_name_it,
    v_draft.canonical_name_en,
    v_draft.suggested_slug,
    v_draft.default_unit,
    v_draft.supported_units,
    v_draft.is_seasonal,
    v_draft.season_months
  );

  if coalesce(array_length(v_validation_errors, 1), 0) > 0 then
    update public.catalog_ingredient_enrichment_drafts as d
    set
      validated_ready = false,
      validated_errors = to_jsonb(v_validation_errors),
      last_validated_at = now(),
      updated_by = v_user,
      updated_at = now()
    where d.normalized_text = v_normalized;

    raise exception 'draft_not_ready: %', array_to_string(v_validation_errors, ', ');
  end if;

  if not coalesce(v_draft.validated_ready, false) then
    raise exception 'draft_not_validated_ready';
  end if;

  select
    case
      when jsonb_typeof(alias_item.value) = 'string'
        then nullif(trim(alias_item.value #>> '{}'), '')
      when jsonb_typeof(alias_item.value) = 'object'
        then nullif(trim(alias_item.value ->> 'text'), '')
      else null
    end
  into v_alias_text
  from jsonb_array_elements(coalesce(v_draft.suggested_aliases, '[]'::jsonb)) with ordinality as alias_item(value, idx)
  where
    (
      jsonb_typeof(alias_item.value) = 'string'
      and nullif(trim(alias_item.value #>> '{}'), '') is not null
    )
    or
    (
      jsonb_typeof(alias_item.value) = 'object'
      and nullif(trim(alias_item.value ->> 'text'), '') is not null
    )
  order by alias_item.idx
  limit 1;

  if v_alias_text is null then
    v_alias_text := v_normalized;
  end if;

  if v_reviewer_note is null then
    v_reviewer_note := v_draft.reviewer_note;
  end if;

  if v_confidence is null then
    v_confidence := v_draft.confidence_score;
  end if;

  select
    r.ingredient_id,
    r.normalized_text,
    r.slug,
    r.created_new,
    r.alias_created,
    r.resulting_observation_status
  into
    v_result_ingredient_id,
    v_result_normalized_text,
    v_result_slug,
    v_result_created_new,
    v_result_alias_created,
    v_resulting_observation_status
  from public.create_catalog_ingredient_from_candidate(
    p_normalized_text => v_normalized,
    p_slug => v_draft.suggested_slug,
    p_ingredient_type => v_draft.ingredient_type,
    p_display_name => coalesce(
      nullif(trim(v_draft.canonical_name_en), ''),
      nullif(trim(v_draft.canonical_name_it), '')
    ),
    p_language_code => case
      when nullif(trim(v_draft.canonical_name_en), '') is not null then 'en'
      when nullif(trim(v_draft.canonical_name_it), '') is not null then 'it'
      else 'en'
    end,
    p_default_unit => coalesce(v_draft.default_unit, 'piece'),
    p_supported_units => v_draft.supported_units,
    p_is_seasonal => coalesce(v_draft.is_seasonal, false),
    p_season_months => v_draft.season_months,
    p_create_alias => true,
    p_alias_text => v_alias_text,
    p_reviewer_note => v_reviewer_note,
    p_confidence_score => v_confidence
  ) as r
  limit 1;

  if coalesce(v_result_created_new, false) then
    v_variant_kind := nullif(lower(trim(coalesce(v_draft.variant_kind, ''))), '');
    v_specificity_rank := v_draft.specificity_rank_suggestion;

    select i.id
    into v_parent_candidate_id
    from public.ingredients as i
    where i.slug = nullif(lower(trim(coalesce(v_draft.parent_candidate_slug, ''))), '')
    limit 1;

    if v_parent_candidate_id is not null
      and v_parent_candidate_id <> v_result_ingredient_id
      and v_variant_kind is not null
      and v_specificity_rank is not null
      and v_specificity_rank >= 1 then
      update public.ingredients as i
      set
        parent_ingredient_id = v_parent_candidate_id,
        specificity_rank = v_specificity_rank,
        variant_kind = v_variant_kind,
        updated_at = now()
      where i.id = v_result_ingredient_id;
    else
      update public.ingredients as i
      set
        parent_ingredient_id = null,
        specificity_rank = 0,
        variant_kind = 'base',
        updated_at = now()
      where i.id = v_result_ingredient_id;
    end if;
  end if;

  update public.catalog_ingredient_enrichment_drafts as d
  set
    status = 'applied',
    reviewed_by = v_user,
    reviewer_note = coalesce(v_reviewer_note, d.reviewer_note),
    validated_ready = true,
    validated_errors = '[]'::jsonb,
    last_validated_at = now(),
    updated_by = v_user,
    updated_at = now()
  where d.normalized_text = v_normalized;

  return query
  select
    v_result_ingredient_id,
    v_result_normalized_text,
    v_result_slug,
    v_result_created_new,
    v_result_alias_created,
    v_resulting_observation_status;
end;
$$;

revoke all on function public.create_catalog_ingredient_from_enrichment_draft(text, text, double precision) from public;
grant execute on function public.create_catalog_ingredient_from_enrichment_draft(text, text, double precision) to authenticated;
grant execute on function public.create_catalog_ingredient_from_enrichment_draft(text, text, double precision) to service_role;
