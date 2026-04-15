-- Admin read-only hierarchy visibility for ingredient catalog.
-- Purpose: inspect parent-child structure safely in internal tooling.

create or replace function public.list_catalog_ingredient_hierarchy(
  p_limit integer default 200
)
returns table (
  ingredient_id uuid,
  ingredient_slug text,
  parent_ingredient_id uuid,
  parent_slug text,
  ingredient_type text,
  specificity_rank smallint,
  variant_kind text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := greatest(1, coalesce(p_limit, 200));
begin
  perform public.assert_catalog_admin(v_user);

  return query
  select
    child.id as ingredient_id,
    child.slug as ingredient_slug,
    child.parent_ingredient_id,
    parent.slug as parent_slug,
    child.ingredient_type,
    child.specificity_rank,
    child.variant_kind
  from public.ingredients child
  left join public.ingredients parent
    on parent.id = child.parent_ingredient_id
  order by
    coalesce(parent.slug, child.slug) asc,
    child.specificity_rank asc,
    child.slug asc
  limit v_limit;
end;
$$;

revoke all on function public.list_catalog_ingredient_hierarchy(integer) from public;
grant execute on function public.list_catalog_ingredient_hierarchy(integer) to authenticated;
grant execute on function public.list_catalog_ingredient_hierarchy(integer) to service_role;
