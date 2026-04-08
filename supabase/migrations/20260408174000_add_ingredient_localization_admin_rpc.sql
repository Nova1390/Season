-- Minimal admin-only localization action for coverage blockers.
-- Adds/updates missing localization safely without duplicate inserts.

create or replace function public.add_ingredient_localization(
  p_ingredient_id uuid,
  p_text text,
  p_language_code text default 'it'
)
returns table (
  applied boolean,
  status text,
  ingredient_id uuid,
  language_code text,
  display_name text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_ingredient_id uuid := p_ingredient_id;
  v_text text := nullif(trim(coalesce(p_text, '')), '');
  v_language_code text := lower(trim(coalesce(p_language_code, 'it')));
  v_existing_text text;
begin
  v_user := auth.uid();
  perform public.assert_catalog_admin(v_user);

  if v_ingredient_id is null then
    raise exception 'ingredient_id is required';
  end if;

  if v_text is null then
    raise exception 'text is required';
  end if;

  if v_language_code is null or v_language_code = '' then
    v_language_code := 'it';
  end if;

  select l.display_name
  into v_existing_text
  from public.ingredient_localizations l
  where l.ingredient_id = v_ingredient_id
    and l.language_code = v_language_code;

  if v_existing_text is not null and lower(trim(v_existing_text)) = lower(trim(v_text)) then
    return query
    select
      false as applied,
      'already_exists'::text as status,
      v_ingredient_id,
      v_language_code,
      v_existing_text;
    return;
  end if;

  if v_existing_text is not null then
    return query
    select
      false as applied,
      'language_already_present'::text as status,
      v_ingredient_id,
      v_language_code,
      v_existing_text;
    return;
  end if;

  insert into public.ingredient_localizations (
    ingredient_id,
    language_code,
    display_name,
    created_at,
    updated_at
  )
  values (
    v_ingredient_id,
    v_language_code,
    v_text,
    now(),
    now()
  );

  return query
  select
    true as applied,
    'inserted'::text as status,
    v_ingredient_id,
    v_language_code,
    v_text;
end;
$$;

revoke all on function public.add_ingredient_localization(uuid, text, text) from public;
grant execute on function public.add_ingredient_localization(uuid, text, text) to authenticated;
grant execute on function public.add_ingredient_localization(uuid, text, text) to service_role;
