begin;

-- The catalog admin console is browser-accessible, so its RPC surface must not
-- be executable by anon. Authorization still lives in assert_catalog_admin(...),
-- but removing anon EXECUTE prevents unauthenticated callers from reaching the
-- admin-only function bodies at all.

revoke all on function public.is_current_user_catalog_admin() from public, anon;
grant execute on function public.is_current_user_catalog_admin() to authenticated, service_role;

revoke all on function public.get_catalog_agent_review_inbox(text[], text, text[], text, integer, integer) from public, anon;
grant execute on function public.get_catalog_agent_review_inbox(text[], text, text[], text, integer, integer) to authenticated, service_role;

revoke all on function public.review_catalog_agent_proposal(bigint, text, text) from public, anon;
grant execute on function public.review_catalog_agent_proposal(bigint, text, text) to authenticated, service_role;

revoke all on function public.validate_catalog_agent_proposal(bigint) from public, anon;
grant execute on function public.validate_catalog_agent_proposal(bigint) to authenticated, service_role;

revoke all on function public.apply_catalog_agent_proposal(bigint, text) from public, anon;
grant execute on function public.apply_catalog_agent_proposal(bigint, text) to authenticated, service_role;

revoke all on function public.get_catalog_agent_learning_context(text[], integer) from public, anon;
grant execute on function public.get_catalog_agent_learning_context(text[], integer) to authenticated, service_role;

comment on function public.is_current_user_catalog_admin() is
  'Authenticated-only catalog admin status check for app/admin surfaces. Returns false for non-admin authenticated users; anon cannot execute.';

commit;
