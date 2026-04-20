-- Enable RLS for recipes while keeping the app's intended public-read,
-- owner-write model. We intentionally do not FORCE RLS so existing
-- SECURITY DEFINER admin/reconciliation RPCs can continue to operate.

alter table if exists public.recipes enable row level security;

-- Public reads require both table privileges and an RLS SELECT policy.
grant select on table public.recipes to anon;
grant select, insert, update, delete on table public.recipes to authenticated;

drop policy if exists recipes_select_public on public.recipes;
create policy recipes_select_public
on public.recipes
for select
to anon, authenticated
using (true);

drop policy if exists recipes_insert_owner on public.recipes;
create policy recipes_insert_owner
on public.recipes
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists recipes_update_owner on public.recipes;
create policy recipes_update_owner
on public.recipes
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists recipes_delete_owner on public.recipes;
create policy recipes_delete_owner
on public.recipes
for delete
to authenticated
using (user_id = auth.uid());
