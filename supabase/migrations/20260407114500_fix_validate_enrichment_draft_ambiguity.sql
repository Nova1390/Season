-- Recreate live validate enrichment draft RPC with fully qualified references.
-- Fixes 42702 ambiguity on normalized_text for already-applied environments.

create or replace function public.validate_catalog_ingredient_enrichment_draft(
  p_normalized_text text
)
returns table (
  normalized_text text,
  status text,
  ingredient_type text,
  is_ready boolean,
  validation_errors text[]
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_normalized text := lower(trim(coalesce(p_normalized_text, '')));
  v_now timestamptz := now();
  v_errors text[];
  v_is_ready boolean;
begin
  perform public.assert_catalog_admin(v_user);

  if v_normalized = '' then
    raise exception 'normalized_text is required';
  end if;

  if not exists (
    select 1
    from public.catalog_ingredient_enrichment_drafts as d
    where d.normalized_text = v_normalized
  ) then
    raise exception 'enrichment draft not found for normalized_text: %', v_normalized;
  end if;

  select public.catalog_enrichment_validation_errors(
      d.ingredient_type,
      d.status,
      d.canonical_name_it,
      d.canonical_name_en,
      d.suggested_slug,
      d.default_unit,
      d.supported_units,
      d.is_seasonal,
      d.season_months
    )
  into v_errors
  from public.catalog_ingredient_enrichment_drafts as d
  where d.normalized_text = v_normalized
  limit 1;

  select (
      coalesce(array_length(v_errors, 1), 0) = 0
      and d.status = 'ready'
    )
  into v_is_ready
  from public.catalog_ingredient_enrichment_drafts as d
  where d.normalized_text = v_normalized
  limit 1;

  update public.catalog_ingredient_enrichment_drafts as d
  set
    validated_ready = coalesce(v_is_ready, false),
    validated_errors = to_jsonb(coalesce(v_errors, '{}'::text[])),
    last_validated_at = v_now,
    updated_by = v_user,
    updated_at = v_now
  where d.normalized_text = v_normalized;

  return query
  select
    d.normalized_text,
    d.status,
    d.ingredient_type,
    d.validated_ready,
    array(select jsonb_array_elements_text(d.validated_errors)) as validation_errors
  from public.catalog_ingredient_enrichment_drafts as d
  where d.normalized_text = v_normalized
  limit 1;
end;
$$;

revoke all on function public.validate_catalog_ingredient_enrichment_draft(text) from public;
grant execute on function public.validate_catalog_ingredient_enrichment_draft(text) to authenticated;
grant execute on function public.validate_catalog_ingredient_enrichment_draft(text) to service_role;
