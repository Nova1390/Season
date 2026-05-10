-- Harden public recipe/profile links before opening staging to external testers.
-- The client validates these URLs for UX, but the database remains the source of truth.

create or replace function public.recipe_url_host(p_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower((regexp_match(trim(p_url), '^https://([^/?#:@]+)(?::[0-9]+)?(?:[/?#]|$)'))[1]);
$$;

create or replace function public.recipe_host_matches_any(p_host text, p_domains text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select exists (
    select 1
    from unnest(p_domains) as allowed_domain
    where p_host = allowed_domain
       or p_host like '%.' || allowed_domain
  );
$$;

create or replace function public.is_allowed_recipe_url(p_url text, p_context text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  with cleaned as (
    select nullif(trim(p_url), '') as value
  ), parsed as (
    select
      value,
      public.recipe_url_host(value) as host
    from cleaned
  )
  select case
    when value is null then true
    when length(value) > 2048 then false
    when value ~ '[[:space:][:cntrl:]]' then false
    when host is null then false
    when p_context = 'instagram_url' then
      public.recipe_host_matches_any(host, array['instagram.com'])
    when p_context = 'tiktok_url' then
      public.recipe_host_matches_any(host, array['tiktok.com'])
    when p_context = 'source_url' then
      public.recipe_host_matches_any(host, array[
        'instagram.com',
        'tiktok.com',
        'giallozafferano.it'
      ])
    when p_context = 'image_url' then
      public.recipe_host_matches_any(host, array[
        'www.giallozafferano.it',
        'giallozafferano.it',
        'gyuedxycbnqljryenapx.supabase.co',
        'czdsnnsizyhldiurlmxd.supabase.co'
      ])
    else false
  end
  from parsed;
$$;

alter table if exists public.recipes
  drop constraint if exists recipes_instagram_url_allowed,
  drop constraint if exists recipes_tiktok_url_allowed,
  drop constraint if exists recipes_source_url_allowed,
  drop constraint if exists recipes_image_url_allowed,
  add constraint recipes_instagram_url_allowed
    check (public.is_allowed_recipe_url(instagram_url, 'instagram_url')) not valid,
  add constraint recipes_tiktok_url_allowed
    check (public.is_allowed_recipe_url(tiktok_url, 'tiktok_url')) not valid,
  add constraint recipes_source_url_allowed
    check (public.is_allowed_recipe_url(source_url, 'source_url')) not valid,
  add constraint recipes_image_url_allowed
    check (public.is_allowed_recipe_url(image_url, 'image_url')) not valid;

alter table if exists public.profiles
  drop constraint if exists profiles_instagram_url_allowed,
  drop constraint if exists profiles_tiktok_url_allowed,
  add constraint profiles_instagram_url_allowed
    check (public.is_allowed_recipe_url(instagram_url, 'instagram_url')) not valid,
  add constraint profiles_tiktok_url_allowed
    check (public.is_allowed_recipe_url(tiktok_url, 'tiktok_url')) not valid;

do $$
declare
  v_constraint text;
begin
  foreach v_constraint in array array[
    'recipes_instagram_url_allowed',
    'recipes_tiktok_url_allowed',
    'recipes_source_url_allowed',
    'recipes_image_url_allowed'
  ]
  loop
    begin
      execute format('alter table public.recipes validate constraint %I', v_constraint);
    exception
      when check_violation then
        raise notice 'existing recipes violate %, leaving constraint NOT VALID for legacy rows; new writes are still enforced', v_constraint;
    end;
  end loop;

  foreach v_constraint in array array[
    'profiles_instagram_url_allowed',
    'profiles_tiktok_url_allowed'
  ]
  loop
    begin
      execute format('alter table public.profiles validate constraint %I', v_constraint);
    exception
      when check_violation then
        raise notice 'existing profiles violate %, leaving constraint NOT VALID for legacy rows; new writes are still enforced', v_constraint;
    end;
  end loop;
end $$;

drop policy if exists recipes_insert_owner on public.recipes;
create policy recipes_insert_owner
on public.recipes
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_allowed_recipe_url(instagram_url, 'instagram_url')
  and public.is_allowed_recipe_url(tiktok_url, 'tiktok_url')
  and public.is_allowed_recipe_url(source_url, 'source_url')
  and public.is_allowed_recipe_url(image_url, 'image_url')
);

drop policy if exists recipes_update_owner on public.recipes;
create policy recipes_update_owner
on public.recipes
for update
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and public.is_allowed_recipe_url(instagram_url, 'instagram_url')
  and public.is_allowed_recipe_url(tiktok_url, 'tiktok_url')
  and public.is_allowed_recipe_url(source_url, 'source_url')
  and public.is_allowed_recipe_url(image_url, 'image_url')
);
