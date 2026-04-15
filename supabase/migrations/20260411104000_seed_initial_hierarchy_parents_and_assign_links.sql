-- Phase 2 (curated): create missing generic parent nodes for initial families,
-- then assign approved parent-child links.
--
-- Scope-limited families only:
-- - farina / farina_00
-- - cipolla / cipolla_bianca, cipolla_dorata, cipolla_rossa
-- - riso / riso_carnaroli
--
-- Defensive behavior:
-- - parent insertion is conditional on slug absence
-- - assignment is conditional on parent+child existence
-- - no other families are touched

with approved_parents(parent_slug, fallback_type) as (
  values
    ('farina'::text, 'basic'::text),
    ('riso'::text, 'basic'::text),
    ('cipolla'::text, 'produce'::text)
),
approved_children(child_slug, parent_slug) as (
  values
    ('farina_00'::text, 'farina'::text),
    ('cipolla_bianca'::text, 'cipolla'::text),
    ('cipolla_dorata'::text, 'cipolla'::text),
    ('cipolla_rossa'::text, 'cipolla'::text),
    ('riso_carnaroli'::text, 'riso'::text)
),
resolved_parent_types as (
  select
    p.parent_slug,
    coalesce(
      (
        select c.ingredient_type
        from approved_children ac
        join public.ingredients c
          on c.slug = ac.child_slug
        where ac.parent_slug = p.parent_slug
        order by c.slug
        limit 1
      ),
      p.fallback_type
    ) as parent_type
  from approved_parents p
)
insert into public.ingredients (
  slug,
  ingredient_type,
  parent_ingredient_id,
  specificity_rank,
  variant_kind
)
select
  rpt.parent_slug,
  rpt.parent_type,
  null,
  0,
  'base'
from resolved_parent_types rpt
where not exists (
  select 1
  from public.ingredients i
  where i.slug = rpt.parent_slug
);

-- Ensure approved roots are normalized as roots.
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

-- Assign approved child links only when both nodes exist.
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

-- canonical_root_id is optional in current schema; update only if present.
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

-- verify parent roots now exist
-- select slug, ingredient_type, parent_ingredient_id, specificity_rank, variant_kind
-- from public.ingredients
-- where slug in ('farina', 'cipolla', 'riso')
-- order by slug;

-- verify approved child links
-- select
--   child.slug as child_slug,
--   parent.slug as parent_slug,
--   child.specificity_rank,
--   child.variant_kind
-- from public.ingredients child
-- left join public.ingredients parent
--   on parent.id = child.parent_ingredient_id
-- where child.slug in (
--   'farina_00',
--   'cipolla_bianca', 'cipolla_dorata', 'cipolla_rossa',
--   'riso_carnaroli'
-- )
-- order by child.slug;

-- verify approved slugs still missing (should be empty for existing children + seeded parents)
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
