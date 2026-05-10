begin;

-- Close remaining Supabase Security Advisor public-schema findings:
-- - older diagnostic/reporting views still using SECURITY DEFINER semantics;
-- - internal catalog function debug tables without RLS.

alter table if exists public.catalog_function_debug_runs enable row level security;
alter table if exists public.catalog_function_debug_events enable row level security;

revoke all on table public.catalog_function_debug_runs from public, anon, authenticated;
revoke all on table public.catalog_function_debug_events from public, anon, authenticated;

grant select on table public.catalog_function_debug_runs to authenticated;
grant select on table public.catalog_function_debug_events to authenticated;
grant all on table public.catalog_function_debug_runs to service_role;
grant all on table public.catalog_function_debug_events to service_role;

drop policy if exists catalog_function_debug_runs_catalog_admin_select on public.catalog_function_debug_runs;
create policy catalog_function_debug_runs_catalog_admin_select
on public.catalog_function_debug_runs
for select
to authenticated
using (public.is_catalog_admin(auth.uid()));

drop policy if exists catalog_function_debug_events_catalog_admin_select on public.catalog_function_debug_events;
create policy catalog_function_debug_events_catalog_admin_select
on public.catalog_function_debug_events
for select
to authenticated
using (public.is_catalog_admin(auth.uid()));

alter view if exists public.catalog_duplicate_localization_candidates set (security_invoker = true);
alter view if exists public.catalog_ready_enrichment_draft_queue set (security_invoker = true);
alter view if exists public.catalog_unified_readiness_summary set (security_invoker = true);
alter view if exists public.giallozafferano_autopilot_replay_audit set (security_invoker = true);
alter view if exists public.giallozafferano_autopilot_replay_gap_summary set (security_invoker = true);
alter view if exists public.giallozafferano_autopilot_replay_summary set (security_invoker = true);
alter view if exists public.giallozafferano_ingredient_identity_guardrail set (security_invoker = true);
alter view if exists public.giallozafferano_ingredient_identity_guardrail_summary set (security_invoker = true);
alter view if exists public.giallozafferano_variant_policy_audit set (security_invoker = true);
alter view if exists public.giallozafferano_variant_policy_summary set (security_invoker = true);
alter view if exists public.ingredient_catalog_canonical_summary set (security_invoker = true);
alter view if exists public.recipe_ingredient_identity_readiness set (security_invoker = true);
alter view if exists public.recipe_ingredient_qualifier_reconciliation_preview set (security_invoker = true);
alter view if exists public.recipe_source_ingredient_catalog_coverage set (security_invoker = true);

commit;
