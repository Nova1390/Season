-- Follow-up hierarchy seed: cipolla family only.
-- Creates missing child variants under existing cipolla root and keeps root semantics stable.

-- Keep cipolla root normalized as base/root (if present).
update public.ingredients i
set
  parent_ingredient_id = null,
  specificity_rank = 0,
  variant_kind = 'base'
where i.slug = 'cipolla';

-- Insert approved cipolla child variants only if missing.
with parent as (
  select id
  from public.ingredients
  where slug = 'cipolla'
  limit 1
),
children(slug) as (
  values
    ('cipolla_bianca'::text),
    ('cipolla_dorata'::text),
    ('cipolla_rossa'::text)
)
insert into public.ingredients (
  slug,
  ingredient_type,
  parent_ingredient_id,
  specificity_rank,
  variant_kind
)
select
  c.slug,
  'produce'::text,
  p.id,
  1,
  'variety'::text
from children c
cross join parent p
where not exists (
  select 1
  from public.ingredients i
  where i.slug = c.slug
);

-- Ensure all approved cipolla children point to cipolla and carry child metadata.
with parent as (
  select id
  from public.ingredients
  where slug = 'cipolla'
  limit 1
)
update public.ingredients i
set
  parent_ingredient_id = p.id,
  specificity_rank = 1,
  variant_kind = 'variety'
from parent p
where i.slug in ('cipolla_bianca', 'cipolla_dorata', 'cipolla_rossa');

-- canonical_root_id is optional in current schema; update only if present.
do $$
declare
  v_parent_id uuid;
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ingredients'
      and column_name = 'canonical_root_id'
  ) then
    select i.id
    into v_parent_id
    from public.ingredients i
    where i.slug = 'cipolla'
    limit 1;

    if v_parent_id is not null then
      update public.ingredients i
      set canonical_root_id = i.id
      where i.id = v_parent_id;

      update public.ingredients i
      set canonical_root_id = v_parent_id
      where i.slug in ('cipolla_bianca', 'cipolla_dorata', 'cipolla_rossa');
    end if;
  end if;
end;
$$;

-- verification query
-- select
--   child.slug as ingredient_slug,
--   parent.slug as parent_slug,
--   child.ingredient_type,
--   child.specificity_rank,
--   child.variant_kind
-- from public.ingredients child
-- left join public.ingredients parent
--   on parent.id = child.parent_ingredient_id
-- where child.slug in ('cipolla', 'cipolla_bianca', 'cipolla_dorata', 'cipolla_rossa')
-- order by child.slug;
