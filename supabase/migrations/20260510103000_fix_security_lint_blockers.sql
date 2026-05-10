begin;

-- Fixes remote Supabase lint blockers before TestFlight:
-- 1) avoid direct dependency on profiles.is_admin, which is absent in some envs;
-- 2) qualify legacy_ingredient_mapping.ingredient_id in UPDATE to avoid PL/pgSQL ambiguity.

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
begin
  -- Service-role workflows are trusted backend operations.
  if coalesce(auth.role(), '') = 'service_role' then
    return true;
  end if;

  if p_user_id is null then
    return false;
  end if;

  if to_regclass('public.profiles') is not null then
    select coalesce((to_jsonb(p) ->> 'is_admin')::boolean, false)
    into v_is_admin
    from public.profiles p
    where p.id = p_user_id
    limit 1;
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

    update public.legacy_ingredient_mapping as lm
    set
      source_domain = v_source_domain,
      updated_at = v_now
    where lm.ingredient_id = p_ingredient_id;
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

revoke all on function public.is_catalog_admin(uuid) from public;
grant execute on function public.is_catalog_admin(uuid) to authenticated;
grant execute on function public.is_catalog_admin(uuid) to service_role;

revoke all on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) from public;
grant execute on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) to authenticated;
grant execute on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) to service_role;

commit;
