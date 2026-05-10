begin;

-- Security Advisor hardening for TestFlight:
-- - enable RLS on canonical redirects;
-- - keep runtime catalog redirect reads explicit and safe;
-- - convert catalog/reconciliation read views to SECURITY INVOKER;
-- - add admin-only SELECT policies for operational tables used by invoker views.

alter table if exists public.ingredient_canonical_redirects enable row level security;

revoke all on table public.ingredient_canonical_redirects from public;
grant select on table public.ingredient_canonical_redirects to anon, authenticated, service_role;
grant all on table public.ingredient_canonical_redirects to service_role;

drop policy if exists ingredient_canonical_redirects_public_select on public.ingredient_canonical_redirects;
create policy ingredient_canonical_redirects_public_select
on public.ingredient_canonical_redirects
for select
to anon, authenticated
using (true);

drop policy if exists custom_ingredient_observations_catalog_admin_select on public.custom_ingredient_observations;
create policy custom_ingredient_observations_catalog_admin_select
on public.custom_ingredient_observations
for select
to authenticated
using (public.is_catalog_admin(auth.uid()));

drop policy if exists catalog_ingredient_enrichment_drafts_catalog_admin_select on public.catalog_ingredient_enrichment_drafts;
create policy catalog_ingredient_enrichment_drafts_catalog_admin_select
on public.catalog_ingredient_enrichment_drafts
for select
to authenticated
using (public.is_catalog_admin(auth.uid()));

drop policy if exists catalog_candidate_decisions_catalog_admin_select on public.catalog_candidate_decisions;
create policy catalog_candidate_decisions_catalog_admin_select
on public.catalog_candidate_decisions
for select
to authenticated
using (public.is_catalog_admin(auth.uid()));

drop policy if exists recipe_ingredient_reconciliation_audit_catalog_admin_select on public.recipe_ingredient_reconciliation_audit;
create policy recipe_ingredient_reconciliation_audit_catalog_admin_select
on public.recipe_ingredient_reconciliation_audit
for select
to authenticated
using (public.is_catalog_admin(auth.uid()));

drop policy if exists catalog_alias_auto_apply_audit_catalog_admin_select on public.catalog_alias_auto_apply_audit;
create policy catalog_alias_auto_apply_audit_catalog_admin_select
on public.catalog_alias_auto_apply_audit
for select
to authenticated
using (public.is_catalog_admin(auth.uid()));

drop policy if exists catalog_localization_auto_apply_audit_catalog_admin_select on public.catalog_localization_auto_apply_audit;
create policy catalog_localization_auto_apply_audit_catalog_admin_select
on public.catalog_localization_auto_apply_audit
for select
to authenticated
using (public.is_catalog_admin(auth.uid()));

alter view if exists public.ingredient_catalog_summary set (security_invoker = true);
alter view if exists public.ingredient_alias_app_summary set (security_invoker = true);
alter view if exists public.ingredient_catalog_app_summary set (security_invoker = true);
alter view if exists public.ingredient_catalog_app_readiness_summary set (security_invoker = true);
alter view if exists public.catalog_unresolved_duplicate_localization_candidates set (security_invoker = true);

alter view if exists public.custom_ingredient_observation_summary set (security_invoker = true);
alter view if exists public.catalog_resolution_candidate_queue set (security_invoker = true);
alter view if exists public.catalog_resolution_candidate_policy set (security_invoker = true);
alter view if exists public.catalog_coverage_blocker_terms set (security_invoker = true);
alter view if exists public.catalog_pending_validated_draft_resolution_plan set (security_invoker = true);
alter view if exists public.catalog_pending_validated_draft_resolution_summary set (security_invoker = true);

alter view if exists public.recipe_ingredient_reconciliation_safety_preview set (security_invoker = true);
alter view if exists public.recipe_reconciliation_impact_summary set (security_invoker = true);
alter view if exists public.recipe_reconciliation_blockers set (security_invoker = true);
alter view if exists public.recipe_reconciliation_unresolved_text_analysis set (security_invoker = true);
alter view if exists public.recipe_reconciliation_match_source_breakdown set (security_invoker = true);
alter view if exists public.recipe_reconciliation_next_action_summary set (security_invoker = true);

commit;
