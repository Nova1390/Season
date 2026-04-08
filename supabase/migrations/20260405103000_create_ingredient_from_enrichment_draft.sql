-- Admin-only wrapper: create canonical ingredient from a validated enrichment draft.
-- Reuses create_catalog_ingredient_from_candidate(...) to preserve existing governance/audit behavior.

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
begin
  perform public.assert_catalog_admin(v_user);

  if v_normalized = '' then
    raise exception 'normalized_text is required';
  end if;

  select d.*
  into v_draft
  from public.catalog_ingredient_enrichment_drafts d
  where d.normalized_text = v_normalized
  limit 1;

  if not found then
    raise exception 'enrichment draft not found for normalized_text: %', v_normalized;
  end if;

  if v_draft.status <> 'ready' then
    raise exception 'draft_status_not_ready: status=%', v_draft.status;
  end if;

  -- Re-validate at apply time to prevent stale/invalid readiness.
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
    update public.catalog_ingredient_enrichment_drafts
    set
      validated_ready = false,
      validated_errors = to_jsonb(v_validation_errors),
      last_validated_at = now(),
      updated_by = v_user,
      updated_at = now()
    where normalized_text = v_normalized;

    raise exception 'draft_not_ready: %', array_to_string(v_validation_errors, ', ');
  end if;

  if not coalesce(v_draft.validated_ready, false) then
    raise exception 'draft_not_validated_ready';
  end if;

  -- Alias seed preference:
  -- 1) first draft suggested alias (string or object.text)
  -- 2) fallback to candidate normalized_text
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

  return query
  select *
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
  );

  update public.catalog_ingredient_enrichment_drafts
  set
    reviewed_by = v_user,
    reviewer_note = coalesce(v_reviewer_note, reviewer_note),
    validated_ready = true,
    validated_errors = '[]'::jsonb,
    last_validated_at = now(),
    updated_by = v_user,
    updated_at = now()
  where normalized_text = v_normalized;
end;
$$;

revoke all on function public.create_catalog_ingredient_from_enrichment_draft(text, text, double precision) from public;
grant execute on function public.create_catalog_ingredient_from_enrichment_draft(text, text, double precision) to authenticated;
grant execute on function public.create_catalog_ingredient_from_enrichment_draft(text, text, double precision) to service_role;
