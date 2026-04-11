begin;

alter table if exists public.profiles enable row level security;

revoke select, insert, update, delete on table public.profiles from anon;

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

commit;
