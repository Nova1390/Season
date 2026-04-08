-- Backend source-of-truth admin status RPC for client visibility checks.
-- Uses centralized catalog admin authorization logic.

create or replace function public.is_current_user_catalog_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_catalog_admin(auth.uid());
$$;

revoke all on function public.is_current_user_catalog_admin() from public;
grant execute on function public.is_current_user_catalog_admin() to authenticated;
grant execute on function public.is_current_user_catalog_admin() to service_role;
