begin;

-- Deterministic validator for Catalog Governance Agent proposals.
--
-- This stage is still non-applicative: it can move proposals to
-- validated/failed_validation and write audit events, but it must not create
-- aliases, ingredients, localizations, recipe rewrites, or observations.

create or replace function public.catalog_agent_validation_error(
  p_code text,
  p_message text,
  p_level text default 'error'
)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select jsonb_build_object(
    'code', p_code,
    'message', p_message,
    'level', coalesce(nullif(btrim(p_level), ''), 'error')
  );
$$;

create or replace function public.validate_catalog_agent_proposal(
  p_proposal_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_row public.catalog_agent_proposals%rowtype;
  v_errors jsonb := '[]'::jsonb;
  v_target public.ingredients%rowtype;
  v_target_from_slug public.ingredients%rowtype;
  v_alias_normalized text;
  v_existing_alias_ingredient_id uuid;
  v_existing_alias_slug text;
  v_existing_localization_ingredient_id uuid;
  v_existing_localization_slug text;
  v_existing_target_localization text;
  v_conflict_slug text;
  v_previous_status text;
  v_next_status text;
  v_event_type text;
begin
  perform public.assert_catalog_admin(v_user);

  if p_proposal_id is null then
    raise exception 'proposal_id_required'
      using errcode = '22023';
  end if;

  select *
  into v_row
  from public.catalog_agent_proposals p
  where p.id = p_proposal_id
  for update;

  if not found then
    raise exception 'catalog_agent_proposal_not_found: %', p_proposal_id
      using errcode = 'P0002';
  end if;

  v_previous_status := v_row.status;

  if v_previous_status <> 'queued_for_validation' then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error(
        'proposal_not_queued_for_validation',
        'Proposal must be queued_for_validation before deterministic validation.',
        'error'
      )
    );
  end if;

  if nullif(btrim(coalesce(v_row.normalized_text, '')), '') is null then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error('normalized_text_blank', 'normalized_text is required.', 'error')
    );
  end if;

  if v_row.proposal_type not in (
    'approve_alias',
    'create_canonical',
    'add_localization',
    'ignore_noise',
    'needs_human_review'
  ) then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error('unsupported_proposal_type', 'Proposal type is not supported by validator v1.', 'error')
    );
  end if;

  if v_row.risk_level not in ('low', 'medium', 'high', 'critical', 'unknown') then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error('unsupported_risk_level', 'risk_level is not supported.', 'error')
    );
  end if;

  if v_row.confidence_score is not null and (v_row.confidence_score < 0 or v_row.confidence_score > 1) then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error('confidence_score_out_of_range', 'confidence_score must be between 0 and 1.', 'error')
    );
  end if;

  if v_row.auto_apply_eligible and v_row.risk_level <> 'low' then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error('auto_apply_requires_low_risk', 'auto_apply_eligible requires low risk.', 'error')
    );
  end if;

  if nullif(btrim(coalesce(v_row.rationale, '')), '') is null then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error('rationale_required', 'A policy rationale is required.', 'error')
    );
  end if;

  if v_row.target_ingredient_id is not null then
    select *
    into v_target
    from public.ingredients i
    where i.id = v_row.target_ingredient_id;

    if not found then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('target_ingredient_not_found', 'target_ingredient_id does not exist.', 'error')
      );
    elsif coalesce(v_target.quality_status, '') <> 'active' then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('target_ingredient_not_active', 'Target ingredient is not active.', 'error')
      );
    end if;
  end if;

  if nullif(btrim(coalesce(v_row.target_slug, '')), '') is not null then
    select *
    into v_target_from_slug
    from public.ingredients i
    where i.slug = btrim(v_row.target_slug)
    limit 1;

    if not found then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('target_slug_not_found', 'target_slug does not exist.', 'error')
      );
    elsif coalesce(v_target_from_slug.quality_status, '') <> 'active' then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('target_slug_not_active', 'target_slug points to a non-active ingredient.', 'error')
      );
    elsif v_row.target_ingredient_id is not null and v_target_from_slug.id <> v_row.target_ingredient_id then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('target_id_slug_mismatch', 'target_ingredient_id and target_slug point to different ingredients.', 'error')
      );
    elsif v_row.target_ingredient_id is null then
      v_target := v_target_from_slug;
    end if;
  end if;

  if v_row.proposal_type in ('approve_alias', 'add_localization') and v_target.id is null then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error('target_required', 'This proposal type requires a valid target ingredient.', 'error')
    );
  end if;

  if v_row.proposal_type = 'approve_alias' then
    v_alias_normalized := lower(btrim(coalesce(v_row.proposed_alias_text, v_row.normalized_text, '')));

    if nullif(v_alias_normalized, '') is null then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('alias_text_required', 'approve_alias requires proposed_alias_text or normalized_text.', 'error')
      );
    else
      select a.ingredient_id, i.slug
      into v_existing_alias_ingredient_id, v_existing_alias_slug
      from public.ingredient_aliases_v2 a
      join public.ingredients i on i.id = a.ingredient_id
      where a.normalized_alias_text = v_alias_normalized
        and coalesce(a.is_active, true)
      order by a.id desc
      limit 1;

      if v_existing_alias_ingredient_id is not null
         and v_target.id is not null
         and v_existing_alias_ingredient_id <> v_target.id then
        v_errors := v_errors || jsonb_build_array(
          public.catalog_agent_validation_error(
            'active_alias_conflict',
            format('Active alias already points to %s.', v_existing_alias_slug),
            'error'
          )
        );
      end if;

      select l.ingredient_id, i.slug
      into v_existing_localization_ingredient_id, v_existing_localization_slug
      from public.ingredient_localizations l
      join public.ingredients i on i.id = l.ingredient_id
      where lower(btrim(l.display_name)) = v_alias_normalized
      order by l.updated_at desc
      limit 1;

      if v_existing_localization_ingredient_id is not null
         and v_target.id is not null
         and v_existing_localization_ingredient_id <> v_target.id then
        v_errors := v_errors || jsonb_build_array(
          public.catalog_agent_validation_error(
            'alias_matches_other_localization',
            format('Alias text matches localization for %s.', v_existing_localization_slug),
            'error'
          )
        );
      end if;
    end if;
  end if;

  if v_row.proposal_type = 'add_localization' then
    if nullif(btrim(coalesce(v_row.proposed_localized_name, '')), '') is null then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('localized_name_required', 'add_localization requires proposed_localized_name.', 'error')
      );
    end if;

    if nullif(btrim(coalesce(v_row.proposed_language_code, '')), '') is null then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('language_code_required', 'add_localization requires proposed_language_code.', 'error')
      );
    end if;

    if v_target.id is not null
       and nullif(btrim(coalesce(v_row.proposed_language_code, '')), '') is not null then
      select l.display_name
      into v_existing_target_localization
      from public.ingredient_localizations l
      where l.ingredient_id = v_target.id
        and l.language_code = btrim(v_row.proposed_language_code)
      limit 1;

      if v_existing_target_localization is not null
         and lower(btrim(v_existing_target_localization)) <> lower(btrim(coalesce(v_row.proposed_localized_name, ''))) then
        v_errors := v_errors || jsonb_build_array(
          public.catalog_agent_validation_error(
            'target_localization_already_exists',
            'Target ingredient already has a different localization for this language.',
            'error'
          )
        );
      end if;
    end if;

    if nullif(btrim(coalesce(v_row.proposed_localized_name, '')), '') is not null
       and nullif(btrim(coalesce(v_row.proposed_language_code, '')), '') is not null then
      select l.ingredient_id, i.slug
      into v_existing_localization_ingredient_id, v_existing_localization_slug
      from public.ingredient_localizations l
      join public.ingredients i on i.id = l.ingredient_id
      where l.language_code = btrim(v_row.proposed_language_code)
        and lower(btrim(l.display_name)) = lower(btrim(v_row.proposed_localized_name))
      order by l.updated_at desc
      limit 1;

      if v_existing_localization_ingredient_id is not null
         and v_target.id is not null
         and v_existing_localization_ingredient_id <> v_target.id then
        v_errors := v_errors || jsonb_build_array(
          public.catalog_agent_validation_error(
            'localization_conflicts_other_ingredient',
            format('Localization already belongs to %s.', v_existing_localization_slug),
            'error'
          )
        );
      end if;
    end if;
  end if;

  if v_row.proposal_type = 'create_canonical' then
    if nullif(btrim(coalesce(v_row.proposed_slug, '')), '') is null then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('proposed_slug_required', 'create_canonical requires proposed_slug.', 'error')
      );
    else
      select i.slug
      into v_conflict_slug
      from public.ingredients i
      where i.slug = btrim(v_row.proposed_slug)
      limit 1;

      if v_conflict_slug is not null then
        v_errors := v_errors || jsonb_build_array(
          public.catalog_agent_validation_error('proposed_slug_conflict', 'proposed_slug already exists in ingredients.', 'error')
        );
      end if;
    end if;

    if nullif(btrim(coalesce(v_row.proposed_localized_name, '')), '') is null then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('canonical_localized_name_required', 'create_canonical requires proposed_localized_name.', 'error')
      );
    end if;

    if nullif(btrim(coalesce(v_row.proposed_language_code, '')), '') is null then
      v_errors := v_errors || jsonb_build_array(
        public.catalog_agent_validation_error('canonical_language_code_required', 'create_canonical requires proposed_language_code.', 'error')
      );
    end if;

    if nullif(btrim(coalesce(v_row.proposed_localized_name, '')), '') is not null
       and nullif(btrim(coalesce(v_row.proposed_language_code, '')), '') is not null then
      select l.ingredient_id, i.slug
      into v_existing_localization_ingredient_id, v_existing_localization_slug
      from public.ingredient_localizations l
      join public.ingredients i on i.id = l.ingredient_id
      where l.language_code = btrim(v_row.proposed_language_code)
        and lower(btrim(l.display_name)) = lower(btrim(v_row.proposed_localized_name))
      order by l.updated_at desc
      limit 1;

      if v_existing_localization_ingredient_id is not null then
        v_errors := v_errors || jsonb_build_array(
          public.catalog_agent_validation_error(
            'canonical_localization_conflict',
            format('Localized name already belongs to %s.', v_existing_localization_slug),
            'error'
          )
        );
      end if;
    end if;
  end if;

  if v_row.proposal_type = 'needs_human_review' then
    v_errors := v_errors || jsonb_build_array(
      public.catalog_agent_validation_error(
        'human_review_proposal_not_actionable',
        'needs_human_review proposals are triage outcomes and cannot be validated for apply.',
        'error'
      )
    );
  end if;

  if jsonb_array_length(v_errors) = 0 then
    v_next_status := 'validated';
    v_event_type := 'validator_passed';
  else
    v_next_status := 'failed_validation';
    v_event_type := 'validator_failed';
  end if;

  update public.catalog_agent_proposals p
  set
    status = v_next_status,
    validation_errors = v_errors,
    auto_apply_eligible = case
      when v_next_status = 'validated' and p.risk_level = 'low' then p.auto_apply_eligible
      else false
    end,
    updated_at = now()
  where p.id = v_row.id
  returning *
  into v_row;

  insert into public.catalog_agent_proposal_events (
    proposal_id,
    run_id,
    event_type,
    event_payload,
    created_by
  )
  values (
    v_row.id,
    v_row.run_id,
    v_event_type,
    jsonb_build_object(
      'previous_status', v_previous_status,
      'next_status', v_next_status,
      'validation_errors', v_errors,
      'validator_version', 'catalog-agent-validator-v1',
      'mutation_scope', 'proposal_status_only'
    ),
    v_user
  );

  return jsonb_build_object(
    'ok', jsonb_array_length(v_errors) = 0,
    'proposal_id', v_row.id,
    'run_id', v_row.run_id,
    'status', v_next_status,
    'validation_errors', v_errors
  );
end;
$$;

create or replace function public.validate_catalog_agent_proposal_batch(
  p_limit integer default 25
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 100);
  v_result jsonb;
  v_results jsonb := '[]'::jsonb;
  v_validated_count integer := 0;
  v_failed_count integer := 0;
  v_total_count integer := 0;
  v_proposal_id bigint;
begin
  perform public.assert_catalog_admin(v_user);

  for v_proposal_id in
    select p.id
    from public.catalog_agent_proposals p
    where p.status = 'queued_for_validation'
    order by p.created_at asc, p.id asc
    limit v_limit
  loop
    v_result := public.validate_catalog_agent_proposal(v_proposal_id);
    v_results := v_results || jsonb_build_array(v_result);
    v_total_count := v_total_count + 1;

    if coalesce((v_result->>'ok')::boolean, false) then
      v_validated_count := v_validated_count + 1;
    else
      v_failed_count := v_failed_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'processed', v_total_count,
    'validated', v_validated_count,
    'failed_validation', v_failed_count,
    'results', v_results
  );
end;
$$;

revoke all on function public.validate_catalog_agent_proposal(bigint) from public;
grant execute on function public.validate_catalog_agent_proposal(bigint) to authenticated;
grant execute on function public.validate_catalog_agent_proposal(bigint) to service_role;

revoke all on function public.validate_catalog_agent_proposal_batch(integer) from public;
grant execute on function public.validate_catalog_agent_proposal_batch(integer) to authenticated;
grant execute on function public.validate_catalog_agent_proposal_batch(integer) to service_role;

revoke all on function public.catalog_agent_validation_error(text, text, text) from public;
grant execute on function public.catalog_agent_validation_error(text, text, text) to authenticated;
grant execute on function public.catalog_agent_validation_error(text, text, text) to service_role;

comment on function public.validate_catalog_agent_proposal(bigint) is
  'Admin-only deterministic validator for Catalog Governance Agent proposals. Updates proposal status/events only; no catalog mutation.';

comment on function public.validate_catalog_agent_proposal_batch(integer) is
  'Admin-only batch wrapper for queued Catalog Governance Agent proposal validation. No catalog mutation.';

comment on function public.catalog_agent_validation_error(text, text, text) is
  'Builds structured Catalog Governance Agent validation error JSON.';

commit;
