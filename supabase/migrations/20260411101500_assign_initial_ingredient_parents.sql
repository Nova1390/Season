-- Phase 2: selective parent-child assignment (tiny curated wave).
-- Scope is intentionally limited to approved families only:
-- farina/farina_00, cipolla/*, riso/riso_carnaroli.
--
-- Defensive behavior:
-- - Updates are slug-conditional.
-- - Missing slugs are skipped (no failure).
-- - canonical_root_id is updated only if that column already exists.

with approved_roots(slug) as (
  values
    ('farina'::text),
    ('cipolla'::text),
    ('riso'::text)
)
update public.ingredients i
set
  parent_ingredient_id = null,
  specificity_rank = 0,
  variant_kind = 'base'
from approved_roots r
where i.slug = r.slug;

with approved_children(child_slug, parent_slug) as (
  values
    ('farina_00'::text, 'farina'::text),
    ('cipolla_bianca'::text, 'cipolla'::text),
    ('cipolla_dorata'::text, 'cipolla'::text),
    ('cipolla_rossa'::text, 'cipolla'::text),
    ('riso_carnaroli'::text, 'riso'::text)
)
update public.ingredients child
set
  parent_ingredient_id = parent.id,
  specificity_rank = 1,
  variant_kind = 'variety'
from approved_children c
join public.ingredients parent
  on parent.slug = c.parent_slug
where child.slug = c.child_slug;

-- canonical_root_id is optional in this phase.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ingredients'
      and column_name = 'canonical_root_id'
  ) then
    with approved_roots(slug) as (
      values
        ('farina'::text),
        ('cipolla'::text),
        ('riso'::text)
    )
    update public.ingredients i
    set canonical_root_id = i.id
    from approved_roots r
    where i.slug = r.slug;

    with approved_children(child_slug, parent_slug) as (
      values
        ('farina_00'::text, 'farina'::text),
        ('cipolla_bianca'::text, 'cipolla'::text),
        ('cipolla_dorata'::text, 'cipolla'::text),
        ('cipolla_rossa'::text, 'cipolla'::text),
        ('riso_carnaroli'::text, 'riso'::text)
    )
    update public.ingredients child
    set canonical_root_id = parent.id
    from approved_children c
    join public.ingredients parent
      on parent.slug = c.parent_slug
    where child.slug = c.child_slug;
  end if;
end;
$$;

-- verify approved family assignments
-- select slug, parent_ingredient_id, specificity_rank, variant_kind
-- from public.ingredients
-- where slug in (
--   'farina', 'farina_00',
--   'cipolla', 'cipolla_bianca', 'cipolla_dorata', 'cipolla_rossa',
--   'riso', 'riso_carnaroli'
-- )
-- order by slug;

-- optional readable join
-- select
--   child.slug as child_slug,
--   parent.slug as parent_slug,
--   child.specificity_rank,
--   child.variant_kind
-- from public.ingredients child
-- left join public.ingredients parent
--   on parent.id = child.parent_ingredient_id
-- where child.slug in (
--   'farina', 'farina_00',
--   'cipolla', 'cipolla_bianca', 'cipolla_dorata', 'cipolla_rossa',
--   'riso', 'riso_carnaroli'
-- )
-- order by child.slug;

-- verify which approved slugs are missing (if any)
-- with expected(slug) as (
--   values
--     ('farina'::text), ('farina_00'::text),
--     ('cipolla'::text), ('cipolla_bianca'::text), ('cipolla_dorata'::text), ('cipolla_rossa'::text),
--     ('riso'::text), ('riso_carnaroli'::text)
-- )
-- select e.slug as missing_slug
-- from expected e
-- left join public.ingredients i
--   on i.slug = e.slug
-- where i.id is null
-- order by e.slug;
