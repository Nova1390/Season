begin;

-- Guardrail: small tomato variants are meaningful catalog identities.
-- They must not be approved as aliases of the generic tomato base ingredient.

create or replace function public.catalog_agent_blocks_base_tomato_alias(
  p_alias_text text,
  p_normalized_text text,
  p_target_slug text
)
returns boolean
language sql
immutable
set search_path = public
as $$
  with normalized as (
    select
      regexp_replace(
        regexp_replace(
          lower(trim(coalesce(p_alias_text, p_normalized_text, ''))),
          '[^[:alnum:][:space:]]+',
          ' ',
          'g'
        ),
        '\s+',
        ' ',
        'g'
      ) as alias_text,
      regexp_replace(
        regexp_replace(
          lower(trim(coalesce(p_normalized_text, p_alias_text, ''))),
          '[^[:alnum:][:space:]]+',
          ' ',
          'g'
        ),
        '\s+',
        ' ',
        'g'
      ) as normalized_text,
      lower(trim(coalesce(p_target_slug, ''))) as target_slug
  )
  select
    target_slug = 'tomato'
    and (
      alias_text ~ '(^| )(pomodorini|pomodorino|ciliegini|ciliegino|datterini|datterino)( |$)'
      or alias_text ~ '(^| )cherry tomato(es)?( |$)'
      or normalized_text ~ '(^| )(pomodorini|pomodorino|ciliegini|ciliegino|datterini|datterino)( |$)'
      or normalized_text ~ '(^| )cherry tomato(es)?( |$)'
    )
  from normalized;
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
      if v_target.id is not null
         and public.catalog_agent_blocks_base_tomato_alias(
           v_alias_normalized,
           v_row.normalized_text,
           v_target.slug
         ) then
        v_errors := v_errors || jsonb_build_array(
          public.catalog_agent_validation_error(
            'meaningful_tomato_variant_requires_child_target',
            'Small tomato terms such as pomodorini/ciliegini/cherry tomatoes must target an explicit child variant, not the generic tomato base.',
            'error'
          )
        );
      end if;

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
      'validator_version', 'catalog-agent-validator-v1-tomato-variant-guard',
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

revoke all on function public.catalog_agent_blocks_base_tomato_alias(text, text, text) from public;
grant execute on function public.catalog_agent_blocks_base_tomato_alias(text, text, text) to authenticated;
grant execute on function public.catalog_agent_blocks_base_tomato_alias(text, text, text) to service_role;

comment on function public.catalog_agent_blocks_base_tomato_alias(text, text, text) is
  'Returns true when a small tomato variant term would be incorrectly approved as an alias of the generic tomato base.';

comment on function public.validate_catalog_agent_proposal(bigint) is
  'Admin-only deterministic validator for Catalog Governance Agent proposals. Blocks meaningful small tomato variants from aliasing to generic tomato.';

commit;
