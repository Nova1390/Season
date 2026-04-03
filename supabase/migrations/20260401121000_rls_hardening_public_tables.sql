-- Security hardening: enable RLS for previously unprotected public tables
-- and apply conservative default policies.
--
-- Catalog tables used by app read paths: authenticated read-only.
-- Ops/audit/sensitive tables: blocked from direct client access.

-- 1) Enable RLS on target tables.
alter table if exists public.catalog_candidate_decisions enable row level security;
alter table if exists public.custom_ingredient_observations enable row level security;
alter table if exists public.ingredient_aliases enable row level security;
alter table if exists public.ingredient_aliases_v2 enable row level security;
alter table if exists public.ingredient_localizations enable row level security;
alter table if exists public.ingredients enable row level security;
alter table if exists public.legacy_ingredient_mapping enable row level security;
alter table if exists public.recipe_import_usage enable row level security;
alter table if exists public.recipe_ingredient_reconciliation_audit enable row level security;

-- 2) Revoke broad client write access explicitly.
revoke insert, update, delete on public.catalog_candidate_decisions from anon, authenticated;
revoke insert, update, delete on public.custom_ingredient_observations from anon, authenticated;
revoke insert, update, delete on public.ingredient_aliases from anon, authenticated;
revoke insert, update, delete on public.ingredient_aliases_v2 from anon, authenticated;
revoke insert, update, delete on public.ingredient_localizations from anon, authenticated;
revoke insert, update, delete on public.ingredients from anon, authenticated;
revoke insert, update, delete on public.legacy_ingredient_mapping from anon, authenticated;
revoke insert, update, delete on public.recipe_import_usage from anon, authenticated;
revoke insert, update, delete on public.recipe_ingredient_reconciliation_audit from anon, authenticated;

-- 3) Catalog tables: authenticated read-only policies.
-- Legacy aliases remain readable for compatibility with existing app fallback paths.
drop policy if exists ingredient_aliases_authenticated_select on public.ingredient_aliases;
create policy ingredient_aliases_authenticated_select
on public.ingredient_aliases
for select
to authenticated
using (true);

drop policy if exists ingredient_aliases_v2_authenticated_select on public.ingredient_aliases_v2;
create policy ingredient_aliases_v2_authenticated_select
on public.ingredient_aliases_v2
for select
to authenticated
using (true);

drop policy if exists ingredients_authenticated_select on public.ingredients;
create policy ingredients_authenticated_select
on public.ingredients
for select
to authenticated
using (true);

drop policy if exists ingredient_localizations_authenticated_select on public.ingredient_localizations;
create policy ingredient_localizations_authenticated_select
on public.ingredient_localizations
for select
to authenticated
using (true);

-- Needed by catalog summary bridging fields used by app read paths.
drop policy if exists legacy_ingredient_mapping_authenticated_select on public.legacy_ingredient_mapping;
create policy legacy_ingredient_mapping_authenticated_select
on public.legacy_ingredient_mapping
for select
to authenticated
using (true);

-- Ensure select grants are explicit for authenticated-only catalog reads.
revoke select on public.ingredient_aliases from anon;
revoke select on public.ingredient_aliases_v2 from anon;
revoke select on public.ingredients from anon;
revoke select on public.ingredient_localizations from anon;
revoke select on public.legacy_ingredient_mapping from anon;

grant select on public.ingredient_aliases to authenticated;
grant select on public.ingredient_aliases_v2 to authenticated;
grant select on public.ingredients to authenticated;
grant select on public.ingredient_localizations to authenticated;
grant select on public.legacy_ingredient_mapping to authenticated;

-- 4) Sensitive ops/audit tables: no client policies (direct access blocked by RLS).
-- Keep function-based/service-role workflows as the intended access path.
drop policy if exists catalog_candidate_decisions_authenticated_select on public.catalog_candidate_decisions;
drop policy if exists custom_ingredient_observations_authenticated_select on public.custom_ingredient_observations;
drop policy if exists recipe_import_usage_authenticated_select on public.recipe_import_usage;
drop policy if exists recipe_ingredient_reconciliation_audit_authenticated_select on public.recipe_ingredient_reconciliation_audit;

revoke select on public.catalog_candidate_decisions from anon, authenticated;
revoke select on public.custom_ingredient_observations from anon, authenticated;
revoke select on public.recipe_import_usage from anon, authenticated;
revoke select on public.recipe_ingredient_reconciliation_audit from anon, authenticated;
