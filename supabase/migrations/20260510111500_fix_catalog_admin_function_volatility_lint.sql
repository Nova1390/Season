begin;

-- These admin read functions perform authorization checks through
-- assert_catalog_admin(...). Mark them VOLATILE so Supabase lint does not flag
-- stable routines that call auth/request-context dependent code.

alter function public.list_ready_catalog_enrichment_drafts(integer) volatile;
alter function public.catalog_observation_coverage_state(integer, boolean) volatile;

commit;
