-- Non-destructive duplicate consolidation for the unified ingredient catalog.
--
-- Instead of deleting duplicate ingredients, keep a canonical redirect map.
-- This lets readers resolve deprecated duplicate ingredient IDs to one
-- canonical ID while preserving audit history and existing foreign keys.

create table if not exists public.ingredient_canonical_redirects (
  ingredient_id uuid primary key references public.ingredients(id) on delete cascade,
  canonical_ingredient_id uuid not null references public.ingredients(id) on delete restrict,
  reason text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ingredient_canonical_redirects_not_self_check
    check (ingredient_id <> canonical_ingredient_id)
);

create index if not exists ingredient_canonical_redirects_canonical_idx
  on public.ingredient_canonical_redirects(canonical_ingredient_id);

do $$
declare
  v_redirect jsonb;
  v_duplicate_id uuid;
  v_canonical_id uuid;
begin
  for v_redirect in
    select *
    from jsonb_array_elements(
      '[
        {"duplicate_slug": "basilico", "canonical_slug": "basil", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "alloro", "canonical_slug": "bay_leaf", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "pepe_nero", "canonical_slug": "black_pepper", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "burro", "canonical_slug": "butter", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "sedano", "canonical_slug": "celery", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "uova", "canonical_slug": "eggs", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "noce_moscata", "canonical_slug": "nutmeg", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "prezzemolo", "canonical_slug": "parsley", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "scalogno", "canonical_slug": "shallot", "reason": "duplicate_localization_with_legacy_bridge"},
        {"duplicate_slug": "zucchine", "canonical_slug": "zucchini", "reason": "duplicate_localization_with_legacy_bridge"}
      ]'::jsonb
    )
  loop
    select i.id into v_duplicate_id
    from public.ingredients i
    where i.slug = v_redirect->>'duplicate_slug'
    limit 1;

    select i.id into v_canonical_id
    from public.ingredients i
    where i.slug = v_redirect->>'canonical_slug'
    limit 1;

    if v_duplicate_id is null then
      raise notice 'duplicate ingredient slug not found: %, skipping redirect', v_redirect->>'duplicate_slug';
      continue;
    end if;

    if v_canonical_id is null then
      raise notice 'canonical ingredient slug not found: %, skipping redirect', v_redirect->>'canonical_slug';
      continue;
    end if;

    insert into public.ingredient_canonical_redirects (
      ingredient_id,
      canonical_ingredient_id,
      reason
    )
    values (
      v_duplicate_id,
      v_canonical_id,
      v_redirect->>'reason'
    )
    on conflict (ingredient_id) do update
    set
      canonical_ingredient_id = excluded.canonical_ingredient_id,
      reason = excluded.reason,
      updated_at = now();

    update public.ingredients i
    set
      quality_status = 'deprecated_duplicate',
      updated_at = now()
    where i.id = v_duplicate_id
      and i.quality_status = 'active';
  end loop;
end $$;

create or replace view public.ingredient_catalog_canonical_summary as
select
  i.id as ingredient_id,
  coalesce(r.canonical_ingredient_id, i.id) as canonical_ingredient_id,
  i.slug,
  canonical.slug as canonical_slug,
  i.ingredient_type,
  i.quality_status,
  (r.ingredient_id is not null) as is_redirected_duplicate,
  r.reason as redirect_reason,
  i.is_seasonal,
  i.season_months,
  i.default_unit,
  i.supported_units,
  i.calories_per_100g,
  i.protein_per_100g,
  i.carbs_per_100g,
  i.fat_per_100g,
  i.fiber_per_100g,
  i.vitamin_c_per_100g,
  i.potassium_per_100g,
  lm.legacy_produce_id,
  lm.legacy_basic_id
from public.ingredients i
left join public.ingredient_canonical_redirects r
  on r.ingredient_id = i.id
join public.ingredients canonical
  on canonical.id = coalesce(r.canonical_ingredient_id, i.id)
left join public.legacy_ingredient_mapping lm
  on lm.ingredient_id = coalesce(r.canonical_ingredient_id, i.id);

create or replace view public.catalog_unresolved_duplicate_localization_candidates as
select
  l.language_code,
  lower(trim(l.display_name)) as normalized_display_name,
  count(distinct coalesce(r.canonical_ingredient_id, l.ingredient_id))::bigint as canonical_ingredient_count,
  array_agg(distinct i.slug order by i.slug) as slugs,
  array_agg(distinct coalesce(r.canonical_ingredient_id, l.ingredient_id)::text order by coalesce(r.canonical_ingredient_id, l.ingredient_id)::text) as canonical_ingredient_ids
from public.ingredient_localizations l
join public.ingredients i
  on i.id = l.ingredient_id
left join public.ingredient_canonical_redirects r
  on r.ingredient_id = l.ingredient_id
where nullif(trim(l.display_name), '') is not null
group by l.language_code, lower(trim(l.display_name))
having count(distinct coalesce(r.canonical_ingredient_id, l.ingredient_id)) > 1;

grant select on public.ingredient_canonical_redirects to authenticated;
grant select on public.ingredient_canonical_redirects to service_role;
grant select on public.ingredient_catalog_canonical_summary to authenticated;
grant select on public.ingredient_catalog_canonical_summary to service_role;
grant select on public.catalog_unresolved_duplicate_localization_candidates to authenticated;
grant select on public.catalog_unresolved_duplicate_localization_candidates to service_role;
