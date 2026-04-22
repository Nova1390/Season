-- Allow unauthenticated app/runtime reads of governed catalog aliases.
-- This keeps writes and non-approved aliases protected while allowing Smart Import
-- to consume safe Autopilot alias coverage before sign-in.

grant select on public.ingredient_aliases_v2 to anon;

drop policy if exists ingredient_aliases_v2_anon_select_active_approved
on public.ingredient_aliases_v2;

create policy ingredient_aliases_v2_anon_select_active_approved
on public.ingredient_aliases_v2
for select
to anon
using (
  is_active = true
  and status = 'approved'
);

-- Verification queries:
--
-- Check anon-readable governed alias rows:
-- set local role anon;
-- select alias_text, normalized_alias_text, ingredient_id, is_active, status, approval_source, approved_at
-- from public.ingredient_aliases_v2
-- where is_active = true
--   and status = 'approved'
-- order by normalized_alias_text
-- limit 50;
--
-- Check Smart Import coverage aliases:
-- set local role anon;
-- select
--   a.alias_text,
--   a.normalized_alias_text,
--   i.slug,
--   a.is_active,
--   a.status,
--   a.approval_source,
--   a.approved_at
-- from public.ingredient_aliases_v2 a
-- join public.ingredients i on i.id = a.ingredient_id
-- where a.normalized_alias_text in (
--   'curry',
--   'acciughe sott''olio',
--   'olive nere',
--   'capperi sotto sale'
-- )
-- order by a.normalized_alias_text;
