-- Bootstrap baseline for core app tables required by recipe/catalog/reconciliation flows.
-- This migration is intentionally foundational and idempotent.

create extension if not exists pgcrypto;

-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  display_name text,
  season_username text,
  is_admin boolean not null default false,
  avatar_url text,
  preferred_language text,
  is_public boolean not null default true,
  instagram_url text,
  tiktok_url text
);

create unique index if not exists profiles_season_username_unique_idx
  on public.profiles (lower(season_username))
  where season_username is not null;

-- Recipes
create table if not exists public.recipes (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  ingredients jsonb not null default '[]'::jsonb,
  steps jsonb not null default '[]'::jsonb,
  servings integer not null default 1,
  image_url text,
  instagram_url text,
  tiktok_url text,
  source_url text,
  source_name text,
  source_type text,
  created_at timestamptz not null default now()
);

create index if not exists recipes_user_id_idx
  on public.recipes(user_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'recipes_source_type_check'
  ) then
    alter table public.recipes
      add constraint recipes_source_type_check
      check (
        source_type is null
        or source_type in ('curated_import', 'user_generated', 'seed_web')
      );
  end if;
end
$$;

-- User recipe states
create table if not exists public.user_recipe_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recipe_id text not null references public.recipes(id) on delete cascade,
  is_saved boolean not null default false,
  is_crispied boolean not null default false,
  is_archived boolean not null default false,
  updated_at timestamptz not null default now()
);

create unique index if not exists user_recipe_states_user_recipe_unique_idx
  on public.user_recipe_states(user_id, recipe_id);

create index if not exists user_recipe_states_user_id_idx
  on public.user_recipe_states(user_id);

-- Linked social accounts
create table if not exists public.linked_social_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  provider_user_id text,
  display_name text,
  handle text,
  profile_image_url text,
  is_verified boolean,
  linked_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create unique index if not exists linked_social_accounts_user_provider_unique_idx
  on public.linked_social_accounts(user_id, provider);

create index if not exists linked_social_accounts_user_id_idx
  on public.linked_social_accounts(user_id);

-- Shopping list
create table if not exists public.shopping_list_items (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ingredient_type text not null,
  ingredient_id text,
  custom_name text,
  quantity double precision,
  unit text,
  source_recipe_id text,
  is_checked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists shopping_list_items_user_id_idx
  on public.shopping_list_items(user_id);

-- Fridge
create table if not exists public.fridge_items (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ingredient_type text not null,
  ingredient_id text,
  custom_name text,
  quantity double precision,
  unit text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fridge_items_user_id_idx
  on public.fridge_items(user_id);

-- Follows
create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint follows_no_self_follow check (follower_id <> following_id)
);

create unique index if not exists follows_follower_following_unique_idx
  on public.follows(follower_id, following_id);

create index if not exists follows_follower_id_idx
  on public.follows(follower_id);

create index if not exists follows_following_id_idx
  on public.follows(following_id);

-- Minimal RLS for user-scoped tables.
alter table if exists public.profiles enable row level security;
alter table if exists public.user_recipe_states enable row level security;
alter table if exists public.linked_social_accounts enable row level security;
alter table if exists public.shopping_list_items enable row level security;
alter table if exists public.fridge_items enable row level security;
alter table if exists public.follows enable row level security;

drop policy if exists profiles_authenticated_read on public.profiles;
create policy profiles_authenticated_read
on public.profiles
for select
to authenticated
using (true);

drop policy if exists profiles_authenticated_insert_self on public.profiles;
create policy profiles_authenticated_insert_self
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists profiles_authenticated_update_self on public.profiles;
create policy profiles_authenticated_update_self
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists user_recipe_states_authenticated_all on public.user_recipe_states;
create policy user_recipe_states_authenticated_all
on public.user_recipe_states
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists linked_social_accounts_authenticated_all on public.linked_social_accounts;
create policy linked_social_accounts_authenticated_all
on public.linked_social_accounts
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists shopping_list_items_authenticated_all on public.shopping_list_items;
create policy shopping_list_items_authenticated_all
on public.shopping_list_items
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists fridge_items_authenticated_all on public.fridge_items;
create policy fridge_items_authenticated_all
on public.fridge_items
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists follows_authenticated_select_own on public.follows;
create policy follows_authenticated_select_own
on public.follows
for select
to authenticated
using (auth.uid() = follower_id or auth.uid() = following_id);

drop policy if exists follows_authenticated_insert_own on public.follows;
create policy follows_authenticated_insert_own
on public.follows
for insert
to authenticated
with check (auth.uid() = follower_id);

drop policy if exists follows_authenticated_delete_own on public.follows;
create policy follows_authenticated_delete_own
on public.follows
for delete
to authenticated
using (auth.uid() = follower_id);

revoke all on table public.profiles from anon;
revoke all on table public.recipes from anon;
revoke all on table public.user_recipe_states from anon;
revoke all on table public.linked_social_accounts from anon;
revoke all on table public.shopping_list_items from anon;
revoke all on table public.fridge_items from anon;
revoke all on table public.follows from anon;

grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.recipes to authenticated;
grant select, insert, update, delete on table public.user_recipe_states to authenticated;
grant select, insert, update, delete on table public.linked_social_accounts to authenticated;
grant select, insert, update, delete on table public.shopping_list_items to authenticated;
grant select, insert, update, delete on table public.fridge_items to authenticated;
grant select, insert, delete on table public.follows to authenticated;
