-- Recreate live function with explicit slug/normalized_text qualification to avoid 42702 ambiguity.

create or replace function public.create_catalog_ingredient_from_candidate(
  p_normalized_text text,
  p_slug text default null,
  p_ingredient_type text default 'basic',
  p_display_name text default null,
  p_language_code text default 'en',
  p_default_unit text default 'piece',
  p_supported_units text[] default null,
  p_is_seasonal boolean default false,
  p_season_months int[] default null,
  p_create_alias boolean default true,
  p_alias_text text default null,
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
  v_now timestamptz := now();
  v_user uuid := auth.uid();
  v_normalized text := lower(trim(coalesce(p_normalized_text, '')));
  v_ingredient_type text := lower(trim(coalesce(p_ingredient_type, 'basic')));
  v_language_code text := lower(trim(coalesce(p_language_code, 'en')));
  v_default_unit text := lower(trim(coalesce(p_default_unit, 'piece')));
  v_display_name text := nullif(trim(coalesce(p_display_name, '')), '');
  v_slug text := nullif(trim(coalesce(p_slug, '')), '');
  v_alias_text text := nullif(trim(coalesce(p_alias_text, '')), '');
  v_alias_normalized text;
  v_supported_units text[] := coalesce(p_supported_units, array[v_default_unit]::text[]);
  v_season_months int[] := coalesce(p_season_months, '{}'::int[]);
  v_candidate_status text;
  v_existing_ingredient_id uuid;
  v_created_ingredient_id uuid;
  v_created_slug text;
  v_observation_status text := 'ingredient_created';
  v_decision_action text;
  v_alias_created boolean := false;
begin
  perform public.assert_catalog_admin(v_user);

  if v_normalized = '' then
    raise exception 'normalized_text is required';
  end if;

  if v_ingredient_type not in ('produce', 'basic') then
    raise exception 'ingredient_type must be produce or basic';
  end if;

  if v_language_code = '' then
    raise exception 'language_code is required';
  end if;

  if v_default_unit = '' then
    raise exception 'default_unit is required';
  end if;

  if p_confidence_score is not null and (p_confidence_score < 0 or p_confidence_score > 1) then
    raise exception 'confidence_score must be between 0 and 1';
  end if;

  select o.status
  into v_candidate_status
  from public.custom_ingredient_observations as o
  where o.normalized_text = v_normalized;

  if v_candidate_status is null then
    raise exception 'candidate not found for normalized_text: %', v_normalized;
  end if;

  if v_display_name is null then
    select nullif(trim(coalesce(o.raw_examples ->> (jsonb_array_length(o.raw_examples) - 1), '')), '')
    into v_display_name
    from public.custom_ingredient_observations as o
    where o.normalized_text = v_normalized;
  end if;

  if v_display_name is null then
    v_display_name := initcap(replace(v_normalized, '_', ' '));
  end if;

  if v_slug is null then
    v_slug := lower(regexp_replace(v_normalized, '[^a-z0-9]+', '_', 'g'));
    v_slug := regexp_replace(v_slug, '^_+|_+$', '', 'g');
  end if;

  if v_slug is null or v_slug = '' then
    raise exception 'unable to derive slug from normalized_text';
  end if;

  if p_create_alias then
    if v_alias_text is null then
      v_alias_text := v_display_name;
    end if;
    v_alias_normalized := lower(trim(v_alias_text));
  else
    v_alias_normalized := null;
  end if;

  select i.id
  into v_existing_ingredient_id
  from public.ingredients as i
  where i.slug = v_slug
  limit 1;

  if v_existing_ingredient_id is null then
    select l.ingredient_id
    into v_existing_ingredient_id
    from public.ingredient_localizations as l
    where lower(trim(l.display_name)) = v_normalized
    limit 1;
  end if;

  if v_existing_ingredient_id is null then
    select a.ingredient_id
    into v_existing_ingredient_id
    from public.ingredient_aliases_v2 as a
    where a.normalized_alias_text = v_normalized
      and coalesce(a.is_active, true)
      and a.status = 'approved'
    limit 1;
  end if;

  if v_existing_ingredient_id is not null then
    v_created_ingredient_id := v_existing_ingredient_id;
    v_created_slug := v_slug;
    v_decision_action := 'create_ingredient_from_candidate_existing';
  else
    insert into public.ingredients as i (
      slug,
      ingredient_type,
      is_seasonal,
      season_months,
      default_unit,
      supported_units,
      created_at,
      updated_at
    )
    values (
      v_slug,
      v_ingredient_type,
      coalesce(p_is_seasonal, false),
      v_season_months,
      v_default_unit,
      v_supported_units,
      v_now,
      v_now
    )
    returning i.id, i.slug into v_created_ingredient_id, v_created_slug;

    insert into public.ingredient_localizations (
      ingredient_id,
      language_code,
      display_name,
      created_at,
      updated_at
    )
    values (
      v_created_ingredient_id,
      v_language_code,
      v_display_name,
      v_now,
      v_now
    )
    on conflict (ingredient_id, language_code) do update
    set display_name = excluded.display_name,
        updated_at = excluded.updated_at;

    v_decision_action := 'create_ingredient_from_candidate';
  end if;

  if p_create_alias and v_alias_normalized is not null and v_alias_normalized <> '' then
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
      v_created_ingredient_id,
      v_alias_text,
      v_alias_normalized,
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
    )
    on conflict (normalized_alias_text)
    where is_active = true
    do update
    set ingredient_id = excluded.ingredient_id,
        alias_text = excluded.alias_text,
        language_code = coalesce(excluded.language_code, public.ingredient_aliases_v2.language_code),
        status = 'approved',
        approval_source = 'manual',
        is_active = true,
        confidence = coalesce(excluded.confidence, public.ingredient_aliases_v2.confidence),
        confidence_score = coalesce(excluded.confidence_score, public.ingredient_aliases_v2.confidence_score, public.ingredient_aliases_v2.confidence),
        approved_at = coalesce(public.ingredient_aliases_v2.approved_at, excluded.approved_at),
        approved_by = coalesce(excluded.approved_by, public.ingredient_aliases_v2.approved_by),
        review_notes = coalesce(excluded.review_notes, public.ingredient_aliases_v2.review_notes),
        updated_at = excluded.updated_at;

    v_alias_created := true;
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
    v_decision_action,
    v_created_ingredient_id,
    case when p_create_alias then v_alias_text else null end,
    v_language_code,
    p_confidence_score,
    nullif(trim(coalesce(p_reviewer_note, '')), ''),
    v_user,
    v_observation_status,
    'approved',
    v_now,
    v_now
  );

  return query
  select
    v_created_ingredient_id,
    v_normalized,
    v_created_slug,
    (v_existing_ingredient_id is null),
    v_alias_created,
    v_observation_status;
end;
$$;

revoke all on function public.create_catalog_ingredient_from_candidate(
  text, text, text, text, text, text, text[], boolean, int[], boolean, text, text, double precision
) from public;
grant execute on function public.create_catalog_ingredient_from_candidate(
  text, text, text, text, text, text, text[], boolean, int[], boolean, text, text, double precision
) to authenticated;
grant execute on function public.create_catalog_ingredient_from_candidate(
  text, text, text, text, text, text, text[], boolean, int[], boolean, text, text, double precision
) to service_role;
