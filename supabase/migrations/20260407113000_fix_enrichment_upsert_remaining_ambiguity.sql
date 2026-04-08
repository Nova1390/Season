-- Recreate live enrichment draft upsert RPC with fully explicit conflict/match references.
-- Fixes remaining 42702 ambiguity around normalized_text in PL/pgSQL scope.

create or replace function public.upsert_catalog_ingredient_enrichment_draft(
  p_normalized_text text,
  p_status text default 'pending',
  p_ingredient_type text default 'unknown',
  p_canonical_name_it text default null,
  p_canonical_name_en text default null,
  p_suggested_slug text default null,
  p_suggested_aliases jsonb default '[]'::jsonb,
  p_default_unit text default null,
  p_supported_units text[] default null,
  p_is_seasonal boolean default null,
  p_season_months int[] default null,
  p_nutrition_fields jsonb default '{}'::jsonb,
  p_confidence_score double precision default null,
  p_needs_manual_review boolean default true,
  p_reasoning_summary text default null,
  p_reviewer_note text default null
)
returns table (
  normalized_text text,
  status text,
  ingredient_type text,
  validated_ready boolean,
  validation_errors text[]
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_user uuid := auth.uid();
  v_normalized text := lower(trim(coalesce(p_normalized_text, '')));
  v_status text := lower(trim(coalesce(p_status, 'pending')));
  v_type text := lower(trim(coalesce(p_ingredient_type, 'unknown')));
  v_slug text := nullif(lower(trim(coalesce(p_suggested_slug, ''))), '');
  v_default_unit text := nullif(lower(trim(coalesce(p_default_unit, ''))), '');
  v_name_it text := nullif(trim(coalesce(p_canonical_name_it, '')), '');
  v_name_en text := nullif(trim(coalesce(p_canonical_name_en, '')), '');
  v_supported_units text[] := coalesce(
    p_supported_units,
    case when v_default_unit is null then '{}'::text[] else array[v_default_unit]::text[] end
  );
  v_season_months int[] := coalesce(p_season_months, '{}'::int[]);
  v_aliases jsonb := coalesce(p_suggested_aliases, '[]'::jsonb);
  v_nutrition jsonb := coalesce(p_nutrition_fields, '{}'::jsonb);
  v_errors text[];
  v_is_ready boolean;
begin
  perform public.assert_catalog_admin(v_user);

  if v_normalized = '' then
    raise exception 'normalized_text is required';
  end if;

  if not exists (
    select 1
    from public.custom_ingredient_observations as o
    where o.normalized_text = v_normalized
  ) then
    raise exception 'candidate not found for normalized_text: %', v_normalized;
  end if;

  if jsonb_typeof(v_aliases) <> 'array' then
    raise exception 'suggested_aliases must be a JSON array';
  end if;

  if jsonb_typeof(v_nutrition) <> 'object' then
    raise exception 'nutrition_fields must be a JSON object';
  end if;

  v_errors := public.catalog_enrichment_validation_errors(
    v_type,
    v_status,
    v_name_it,
    v_name_en,
    v_slug,
    v_default_unit,
    v_supported_units,
    p_is_seasonal,
    v_season_months
  );

  v_is_ready := coalesce(array_length(v_errors, 1), 0) = 0 and v_status = 'ready';

  if v_status = 'ready' and not v_is_ready then
    raise exception 'draft_not_ready: %', array_to_string(v_errors, ', ');
  end if;

  insert into public.catalog_ingredient_enrichment_drafts as d (
    normalized_text,
    status,
    ingredient_type,
    canonical_name_it,
    canonical_name_en,
    suggested_slug,
    suggested_aliases,
    default_unit,
    supported_units,
    is_seasonal,
    season_months,
    nutrition_fields,
    confidence_score,
    needs_manual_review,
    reasoning_summary,
    reviewer_note,
    validated_ready,
    validated_errors,
    last_validated_at,
    created_by,
    updated_by,
    reviewed_by,
    created_at,
    updated_at
  )
  values (
    v_normalized,
    v_status,
    v_type,
    v_name_it,
    v_name_en,
    v_slug,
    v_aliases,
    v_default_unit,
    v_supported_units,
    p_is_seasonal,
    v_season_months,
    v_nutrition,
    p_confidence_score,
    coalesce(p_needs_manual_review, true),
    nullif(trim(coalesce(p_reasoning_summary, '')), ''),
    nullif(trim(coalesce(p_reviewer_note, '')), ''),
    v_is_ready,
    to_jsonb(v_errors),
    v_now,
    v_user,
    v_user,
    case when v_status in ('ready', 'rejected') then v_user else null end,
    v_now,
    v_now
  )
  on conflict on constraint catalog_ingredient_enrichment_drafts_normalized_text_key
  do update
  set
    status = excluded.status,
    ingredient_type = excluded.ingredient_type,
    canonical_name_it = excluded.canonical_name_it,
    canonical_name_en = excluded.canonical_name_en,
    suggested_slug = excluded.suggested_slug,
    suggested_aliases = excluded.suggested_aliases,
    default_unit = excluded.default_unit,
    supported_units = excluded.supported_units,
    is_seasonal = excluded.is_seasonal,
    season_months = excluded.season_months,
    nutrition_fields = excluded.nutrition_fields,
    confidence_score = excluded.confidence_score,
    needs_manual_review = excluded.needs_manual_review,
    reasoning_summary = excluded.reasoning_summary,
    reviewer_note = excluded.reviewer_note,
    validated_ready = excluded.validated_ready,
    validated_errors = excluded.validated_errors,
    last_validated_at = excluded.last_validated_at,
    updated_by = excluded.updated_by,
    reviewed_by = case
      when excluded.status in ('ready', 'rejected') then excluded.updated_by
      else d.reviewed_by
    end,
    updated_at = excluded.updated_at;

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

revoke all on function public.upsert_catalog_ingredient_enrichment_draft(
  text, text, text, text, text, text, jsonb, text, text[], boolean, int[], jsonb, double precision, boolean, text, text
) from public;

grant execute on function public.upsert_catalog_ingredient_enrichment_draft(
  text, text, text, text, text, text, jsonb, text, text[], boolean, int[], jsonb, double precision, boolean, text, text
) to authenticated;

grant execute on function public.upsert_catalog_ingredient_enrichment_draft(
  text, text, text, text, text, text, jsonb, text, text[], boolean, int[], jsonb, double precision, boolean, text, text
) to service_role;
