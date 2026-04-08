-- Harden backend authorization for admin-only Catalog Intelligence mutation RPCs.
-- Enforces admin checks in database functions, not only in client UI.

create table if not exists public.catalog_admin_allowlist (
  user_id uuid primary key references auth.users(id) on delete cascade,
  note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.catalog_admin_allowlist enable row level security;

revoke all on public.catalog_admin_allowlist from anon, authenticated;
revoke all on public.catalog_admin_allowlist from public;
grant all on public.catalog_admin_allowlist to service_role;

create or replace function public.is_catalog_admin(
  p_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean := false;
  v_has_profiles_table boolean := false;
  v_has_is_admin_column boolean := false;
begin
  -- Service-role workflows are trusted backend operations.
  if coalesce(auth.role(), '') = 'service_role' then
    return true;
  end if;

  if p_user_id is null then
    return false;
  end if;

  select to_regclass('public.profiles') is not null
  into v_has_profiles_table;

  if v_has_profiles_table then
    select exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'profiles'
        and c.column_name = 'is_admin'
    )
    into v_has_is_admin_column;
  end if;

  if v_has_is_admin_column then
    execute $query$
      select coalesce(
        (
          select p.is_admin
          from public.profiles p
          where p.id = $1
          limit 1
        ),
        false
      )
    $query$
    into v_is_admin
    using p_user_id;
  end if;

  if not coalesce(v_is_admin, false) then
    select exists (
      select 1
      from public.catalog_admin_allowlist a
      where a.user_id = p_user_id
        and coalesce(a.is_active, true)
    )
    into v_is_admin;
  end if;

  return coalesce(v_is_admin, false);
end;
$$;

create or replace function public.assert_catalog_admin(
  p_user_id uuid default auth.uid()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_catalog_admin(p_user_id) then
    raise exception 'admin_required'
      using errcode = '42501',
            detail = 'Catalog admin privileges are required for this action.';
  end if;
end;
$$;

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
  v_existing_alias_id bigint;
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
    from public.custom_ingredient_observations o
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
    if not exists (
      select 1
      from public.ingredients i
      where i.id = p_ingredient_id
    ) then
      raise exception 'ingredient_id not found: %', p_ingredient_id;
    end if;

    select a.id
    into v_existing_alias_id
    from public.ingredient_aliases_v2 a
    where a.normalized_alias_text = v_alias_normalized
    order by coalesce(a.is_active, true) desc, a.id desc
    limit 1;

    if v_existing_alias_id is null then
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
        v_alias_normalized,
        nullif(trim(coalesce(p_language_code, '')), ''),
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
        ingredient_id = p_ingredient_id,
        alias_text = v_alias_text,
        normalized_alias_text = v_alias_normalized,
        language_code = coalesce(nullif(trim(coalesce(p_language_code, '')), ''), language_code),
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
      where id = v_existing_alias_id;
    end if;

    v_observation_status := 'resolved_alias';
    v_alias_status := 'approved';
  elsif v_action = 'reject_alias' then
    if v_alias_text is not null then
      update public.ingredient_aliases_v2
      set
        status = 'rejected',
        approval_source = 'manual',
        review_notes = coalesce(nullif(trim(coalesce(p_reviewer_note, '')), ''), review_notes),
        is_active = false,
        updated_at = v_now
      where normalized_alias_text = v_alias_normalized;
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

  update public.custom_ingredient_observations
  set
    status = v_observation_status,
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
  from public.custom_ingredient_observations o
  where o.normalized_text = v_normalized;

  if v_candidate_status is null then
    raise exception 'candidate not found for normalized_text: %', v_normalized;
  end if;

  if v_display_name is null then
    select nullif(trim(coalesce(o.raw_examples ->> (jsonb_array_length(o.raw_examples) - 1), '')), '')
    into v_display_name
    from public.custom_ingredient_observations o
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
  from public.ingredients i
  where i.slug = v_slug
  limit 1;

  if v_existing_ingredient_id is null then
    select l.ingredient_id
    into v_existing_ingredient_id
    from public.ingredient_localizations l
    where lower(trim(l.display_name)) = v_normalized
    limit 1;
  end if;

  if v_existing_ingredient_id is null then
    select a.ingredient_id
    into v_existing_ingredient_id
    from public.ingredient_aliases_v2 a
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
    insert into public.ingredients (
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
    returning id, slug into v_created_ingredient_id, v_created_slug;

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

  update public.custom_ingredient_observations
  set
    status = v_observation_status,
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
  perform public.assert_catalog_admin(v_user);

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

create or replace function public.upsert_legacy_ingredient_mapping(
  p_ingredient_id uuid,
  p_legacy_produce_id text default null,
  p_legacy_basic_id text default null,
  p_source_domain text default 'manual_ops',
  p_reviewer_note text default null
)
returns table (
  ingredient_id uuid,
  legacy_produce_id text,
  legacy_basic_id text,
  source_domain text,
  mapping_action text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ingredient_type text;
  v_legacy_produce_id text := nullif(trim(coalesce(p_legacy_produce_id, '')), '');
  v_legacy_basic_id text := nullif(trim(coalesce(p_legacy_basic_id, '')), '');
  v_source_domain text := nullif(trim(coalesce(p_source_domain, '')), '');
  v_existing_for_ingredient public.legacy_ingredient_mapping%rowtype;
  v_conflict_ingredient_for_produce uuid;
  v_conflict_ingredient_for_basic uuid;
  v_action text := 'inserted';
  v_now timestamptz := now();
begin
  perform public.assert_catalog_admin(auth.uid());

  if p_ingredient_id is null then
    raise exception 'ingredient_id is required';
  end if;

  select i.ingredient_type
  into v_ingredient_type
  from public.ingredients i
  where i.id = p_ingredient_id;

  if v_ingredient_type is null then
    raise exception 'ingredient_id not found: %', p_ingredient_id;
  end if;

  if (case when v_legacy_produce_id is null then 0 else 1 end)
     + (case when v_legacy_basic_id is null then 0 else 1 end) <> 1 then
    raise exception 'exactly one of legacy_produce_id or legacy_basic_id must be provided';
  end if;

  if v_ingredient_type = 'produce' and v_legacy_produce_id is null then
    raise exception 'produce ingredient requires legacy_produce_id';
  end if;

  if v_ingredient_type = 'basic' and v_legacy_basic_id is null then
    raise exception 'basic ingredient requires legacy_basic_id';
  end if;

  if v_source_domain is null then
    v_source_domain := 'manual_ops';
  end if;

  if v_legacy_produce_id is not null then
    select lm.ingredient_id
    into v_conflict_ingredient_for_produce
    from public.legacy_ingredient_mapping lm
    where lm.legacy_produce_id = v_legacy_produce_id
    limit 1;

    if v_conflict_ingredient_for_produce is not null and v_conflict_ingredient_for_produce <> p_ingredient_id then
      raise exception
        'legacy_produce_id % is already mapped to ingredient_id %',
        v_legacy_produce_id,
        v_conflict_ingredient_for_produce;
    end if;
  end if;

  if v_legacy_basic_id is not null then
    select lm.ingredient_id
    into v_conflict_ingredient_for_basic
    from public.legacy_ingredient_mapping lm
    where lm.legacy_basic_id = v_legacy_basic_id
    limit 1;

    if v_conflict_ingredient_for_basic is not null and v_conflict_ingredient_for_basic <> p_ingredient_id then
      raise exception
        'legacy_basic_id % is already mapped to ingredient_id %',
        v_legacy_basic_id,
        v_conflict_ingredient_for_basic;
    end if;
  end if;

  select *
  into v_existing_for_ingredient
  from public.legacy_ingredient_mapping lm
  where lm.ingredient_id = p_ingredient_id
  limit 1;

  if found then
    if (
      coalesce(v_existing_for_ingredient.legacy_produce_id, '') <> coalesce(v_legacy_produce_id, '')
      or coalesce(v_existing_for_ingredient.legacy_basic_id, '') <> coalesce(v_legacy_basic_id, '')
    ) then
      raise exception
        'ingredient_id % already has a different legacy mapping (produce=% basic=%)',
        p_ingredient_id,
        v_existing_for_ingredient.legacy_produce_id,
        v_existing_for_ingredient.legacy_basic_id;
    end if;

    update public.legacy_ingredient_mapping
    set
      source_domain = v_source_domain,
      updated_at = v_now
    where ingredient_id = p_ingredient_id;
    v_action := 'unchanged_refreshed';
  else
    insert into public.legacy_ingredient_mapping (
      ingredient_id,
      legacy_produce_id,
      legacy_basic_id,
      source_domain,
      created_at,
      updated_at
    )
    values (
      p_ingredient_id,
      v_legacy_produce_id,
      v_legacy_basic_id,
      v_source_domain,
      v_now,
      v_now
    );
    v_action := 'inserted';
  end if;

  return query
  select
    p_ingredient_id,
    v_legacy_produce_id,
    v_legacy_basic_id,
    v_source_domain,
    v_action;
end;
$$;

create or replace function public.apply_recipe_ingredient_reconciliation(
  p_limit integer default 100,
  p_recipe_ids text[] default null
)
returns table (
  batch_id uuid,
  recipe_id text,
  recipe_ingredient_row_id text,
  ingredient_index integer,
  matched_ingredient_id uuid,
  match_source text,
  applied boolean,
  apply_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch_id uuid := gen_random_uuid();
  v_user uuid := auth.uid();
  v_now timestamptz := now();
  v_limit integer := greatest(1, coalesce(p_limit, 100));
  v_recipe_ingredients jsonb;
  v_old_ingredient jsonb;
  v_new_ingredient jsonb;
  v_new_ingredients jsonb;
  rec record;
begin
  perform public.assert_catalog_admin(v_user);

  for rec in
    select
      p.recipe_id,
      p.recipe_ingredient_row_id,
      p.ingredient_index,
      p.matched_ingredient_id,
      p.match_source,
      lm.legacy_produce_id,
      lm.legacy_basic_id
    from public.recipe_ingredient_reconciliation_safety_preview p
    join public.legacy_ingredient_mapping lm
      on lm.ingredient_id = p.matched_ingredient_id
    where p.safe_to_apply = true
      and (
        p_recipe_ids is null
        or cardinality(p_recipe_ids) = 0
        or p.recipe_id = any(p_recipe_ids)
      )
    order by p.recipe_id asc, p.ingredient_index asc
    limit v_limit
  loop
    select r.ingredients::jsonb
    into v_recipe_ingredients
    from public.recipes r
    where r.id::text = rec.recipe_id
    for update;

    if v_recipe_ingredients is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'recipe_not_found_or_no_ingredients'::text;
      continue;
    end if;

    select e.elem
    into v_old_ingredient
    from jsonb_array_elements(v_recipe_ingredients) with ordinality as e(elem, ord)
    where e.ord = rec.ingredient_index;

    if v_old_ingredient is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'ingredient_index_not_found'::text;
      continue;
    end if;

    if nullif(trim(coalesce(v_old_ingredient ->> 'produce_id', '')), '') is not null
       or nullif(trim(coalesce(v_old_ingredient ->> 'basic_ingredient_id', '')), '') is not null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'already_resolved'::text;
      continue;
    end if;

    v_new_ingredient :=
      (v_old_ingredient - 'produce_id' - 'basic_ingredient_id')
      || jsonb_build_object(
        'produce_id', to_jsonb(rec.legacy_produce_id),
        'basic_ingredient_id', to_jsonb(rec.legacy_basic_id)
      );

    select jsonb_agg(
      case
        when e.ord = rec.ingredient_index then v_new_ingredient
        else e.elem
      end
      order by e.ord
    )
    into v_new_ingredients
    from jsonb_array_elements(v_recipe_ingredients) with ordinality as e(elem, ord);

    if v_new_ingredients is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'failed_to_build_updated_ingredients'::text;
      continue;
    end if;

    update public.recipes
    set ingredients = v_new_ingredients
    where id::text = rec.recipe_id;

    insert into public.recipe_ingredient_reconciliation_audit (
      batch_id,
      recipe_id,
      recipe_ingredient_row_id,
      ingredient_index,
      matched_ingredient_id,
      match_source,
      legacy_produce_id,
      legacy_basic_id,
      previous_ingredient_json,
      updated_ingredient_json,
      applied_at,
      applied_by,
      mechanism,
      created_at,
      updated_at
    )
    values (
      v_batch_id,
      rec.recipe_id,
      rec.recipe_ingredient_row_id,
      rec.ingredient_index,
      rec.matched_ingredient_id,
      rec.match_source,
      rec.legacy_produce_id,
      rec.legacy_basic_id,
      v_old_ingredient,
      v_new_ingredient,
      v_now,
      v_user,
      'phase1_safe_preview_apply',
      v_now,
      v_now
    );

    return query
    select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, true, 'applied'::text;
  end loop;
end;
$$;

revoke all on function public.apply_catalog_candidate_decision(text, text, uuid, text, text, double precision, text) from public;
grant execute on function public.apply_catalog_candidate_decision(text, text, uuid, text, text, double precision, text) to authenticated;
grant execute on function public.apply_catalog_candidate_decision(text, text, uuid, text, text, double precision, text) to service_role;

revoke all on function public.create_catalog_ingredient_from_candidate(
  text, text, text, text, text, text, text[], boolean, int[], boolean, text, text, double precision
) from public;
grant execute on function public.create_catalog_ingredient_from_candidate(
  text, text, text, text, text, text, text[], boolean, int[], boolean, text, text, double precision
) to authenticated;
grant execute on function public.create_catalog_ingredient_from_candidate(
  text, text, text, text, text, text, text[], boolean, int[], boolean, text, text, double precision
) to service_role;

revoke all on function public.approve_reconciliation_alias(text, uuid, text, text, text, double precision) from public;
grant execute on function public.approve_reconciliation_alias(text, uuid, text, text, text, double precision) to authenticated;
grant execute on function public.approve_reconciliation_alias(text, uuid, text, text, text, double precision) to service_role;

revoke all on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) from public;
grant execute on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) to authenticated;
grant execute on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) to service_role;

revoke all on function public.apply_recipe_ingredient_reconciliation(integer, text[]) from public;
grant execute on function public.apply_recipe_ingredient_reconciliation(integer, text[]) to authenticated;
grant execute on function public.apply_recipe_ingredient_reconciliation(integer, text[]) to service_role;
