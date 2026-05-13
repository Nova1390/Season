begin;

-- Supabase Data API grant compatibility.
--
-- Supabase is changing default privileges for tables created in public:
-- new projects after 2026-05-30, existing projects after 2026-10-30.
-- Keep privileges explicit so fresh dev/staging/prod rebuilds behave like
-- the current projects.
--
-- Important: these GRANTs do not bypass RLS. Sensitive ops/audit tables keep
-- their direct client access blocked by the existing RLS policy posture and
-- are intended for RPC/service-role workflows only.

-- Backend/service-role workflows.
grant all privileges on table public.catalog_admin_allowlist to service_role;
grant all privileges on table public.catalog_agent_apply_audit to service_role;
grant all privileges on table public.catalog_agent_daily_digests to service_role;
grant all privileges on table public.catalog_agent_dev_schedule_config to service_role;
grant all privileges on table public.catalog_agent_dev_shift_runs to service_role;
grant all privileges on table public.catalog_agent_learnings to service_role;
grant all privileges on table public.catalog_agent_meaningful_variant_guardrails to service_role;
grant all privileges on table public.catalog_agent_proposal_events to service_role;
grant all privileges on table public.catalog_agent_proposals to service_role;
grant all privileges on table public.catalog_agent_runs to service_role;
grant all privileges on table public.catalog_agent_worker_jobs to service_role;
grant all privileges on table public.catalog_ai_usage_events to service_role;
grant all privileges on table public.catalog_alias_auto_apply_audit to service_role;
grant all privileges on table public.catalog_automation_invocation_tokens to service_role;
grant all privileges on table public.catalog_candidate_decisions to service_role;
grant all privileges on table public.catalog_draft_auto_promotion_audit to service_role;
grant all privileges on table public.catalog_function_debug_events to service_role;
grant all privileges on table public.catalog_function_debug_runs to service_role;
grant all privileges on table public.catalog_ingredient_enrichment_drafts to service_role;
grant all privileges on table public.catalog_localization_auto_apply_audit to service_role;
grant all privileges on table public.catalog_ready_draft_creation_audit to service_role;
grant all privileges on table public.custom_ingredient_observations to service_role;
grant all privileges on table public.follows to service_role;
grant all privileges on table public.fridge_items to service_role;
grant all privileges on table public.ingredient_aliases to service_role;
grant all privileges on table public.ingredient_aliases_v2 to service_role;
grant all privileges on table public.ingredient_canonical_redirects to service_role;
grant all privileges on table public.ingredient_localizations to service_role;
grant all privileges on table public.ingredients to service_role;
grant all privileges on table public.legacy_ingredient_mapping to service_role;
grant all privileges on table public.linked_social_accounts to service_role;
grant all privileges on table public.profiles to service_role;
grant all privileges on table public.recipe_import_usage to service_role;
grant all privileges on table public.recipe_ingredient_reconciliation_audit to service_role;
grant all privileges on table public.recipe_unresolved_ingredient_observation_recovery_audit to service_role;
grant all privileges on table public.recipes to service_role;
grant all privileges on table public.shopping_list_items to service_role;
grant all privileges on table public.user_recipe_states to service_role;

grant usage, select, update on all sequences in schema public to service_role;

-- Public/app Data API read surfaces.
grant select on table public.recipes to anon;
grant select on table public.ingredient_aliases_v2 to anon;
grant select on table public.ingredient_canonical_redirects to anon;

grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.recipes to authenticated;
grant select, insert, update, delete on table public.user_recipe_states to authenticated;
grant select, insert, update, delete on table public.linked_social_accounts to authenticated;
grant select, insert, update, delete on table public.shopping_list_items to authenticated;
grant select, insert, update, delete on table public.fridge_items to authenticated;
grant select, insert, delete on table public.follows to authenticated;

grant select on table public.ingredient_aliases to authenticated;
grant select on table public.ingredient_aliases_v2 to authenticated;
grant select on table public.ingredient_canonical_redirects to authenticated;
grant select on table public.ingredient_localizations to authenticated;
grant select on table public.ingredients to authenticated;
grant select on table public.legacy_ingredient_mapping to authenticated;

-- Catalog-admin console read surfaces. Authorization still depends on RLS and
-- catalog admin policies, not on these grants alone.
grant select on table public.catalog_agent_apply_audit to authenticated;
grant select on table public.catalog_agent_daily_digests to authenticated;
grant select on table public.catalog_agent_dev_schedule_config to authenticated;
grant select on table public.catalog_agent_dev_shift_runs to authenticated;
grant select on table public.catalog_agent_learnings to authenticated;
grant select on table public.catalog_agent_meaningful_variant_guardrails to authenticated;
grant select on table public.catalog_agent_proposal_events to authenticated;
grant select on table public.catalog_agent_proposals to authenticated;
grant select on table public.catalog_agent_runs to authenticated;
grant select on table public.catalog_agent_worker_jobs to authenticated;
grant select on table public.catalog_ai_usage_events to authenticated;
grant select on table public.catalog_function_debug_events to authenticated;
grant select on table public.catalog_function_debug_runs to authenticated;
grant select on table public.catalog_ingredient_enrichment_drafts to authenticated;

commit;
