-- Improve recipe ingredient reconciliation for noisy imported recipe text.
--
-- This is intentionally conservative:
-- - it does not create aliases or ingredients;
-- - it does not mutate recipe JSON directly;
-- - it only lets the existing safe-apply workflow match cleaned text against
--   already approved aliases or unambiguous canonical localizations.

create or replace function public.normalize_recipe_ingredient_text_for_matching(p_text text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_text text := lower(trim(coalesce(p_text, '')));
begin
  if v_text = '' then
    return '';
  end if;

  v_text := replace(v_text, '&nbsp;', ' ');
  v_text := replace(v_text, '&amp;', '&');
  v_text := regexp_replace(v_text, '&frac(?:12|14|34);?', ' ', 'gi');
  v_text := translate(v_text, '½¼¾', '   ');

  -- Giallo Zafferano often keeps prep notes in the ingredient name.
  v_text := regexp_replace(v_text, '\s*\([^)]*\)', ' ', 'g');
  v_text := regexp_replace(
    v_text,
    '\s*,?\s*(?:da\s+(?:pulire|grattugiare|ridurre\s+in\s+polvere|tritare|tagliare|sbucciare|mondare)|a\s+temperatura\s+ambiente|ammorbidit[oaie]|fredd[oaie]\s+di\s+frigo|per\s+(?:decorare|guarnire|friggere))\b.*$',
    '',
    'gi'
  );

  -- Remove trailing quantity contamination while preserving canonical variants
  -- such as "farina 00".
  if v_text !~* '\bfarina\s+00\b' then
    v_text := regexp_replace(
      v_text,
      '\s+[0-9]+(?:[,.][0-9]+)?\s*(?:g|gr|grammi|kg|mg|ml|cl|l|lt|litri|cucchiaio|cucchiai|cucchiaino|cucchiaini|bicchiere|bicchieri|pizzico|pizzichi|spicchio|spicchi|foglia|foglie|pezzo|pezzi)\.?\s*$',
      '',
      'gi'
    );
    v_text := regexp_replace(v_text, '\s+[0-9]+(?:[,.][0-9]+)?\s*$', '', 'gi');
  end if;

  -- If a fraction left only a unit word at the end, drop that serving measure.
  v_text := regexp_replace(
    v_text,
    '\s+(?:bicchiere|bicchieri|cucchiaio|cucchiai|cucchiaino|cucchiaini|pizzico|pizzichi)\s*$',
    '',
    'gi'
  );

  v_text := regexp_replace(v_text, '\s+', ' ', 'g');
  v_text := trim(both ' ,;:-' from v_text);

  return v_text;
end;
$$;

create or replace view public.recipe_ingredient_reconciliation_safety_preview as
with recipe_ingredient_rows as (
  select
    r.id::text as recipe_id,
    i.ingredient as ingredient_json,
    i.ordinality::integer as ingredient_index
  from public.recipes r
  cross join lateral jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as i(ingredient, ordinality)
),
normalized_rows as (
  select
    rir.recipe_id,
    rir.ingredient_index,
    rir.ingredient_json,
    nullif(trim(coalesce(rir.ingredient_json ->> 'produce_id', '')), '') as produce_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'basic_ingredient_id', '')), '') as basic_ingredient_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'ingredient_id', '')), '') as ingredient_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'name', '')), '') as current_text,
    lower(trim(coalesce(rir.ingredient_json ->> 'name', ''))) as normalized_text,
    public.normalize_recipe_ingredient_text_for_matching(rir.ingredient_json ->> 'name') as reconciliation_match_text
  from recipe_ingredient_rows rir
),
observation_status as (
  select
    o.normalized_text,
    o.status as candidate_status
  from public.custom_ingredient_observations o
),
alias_exact_stats as (
  select
    n.recipe_id,
    n.ingredient_index,
    count(*) filter (where a.status = 'approved' and coalesce(a.is_active, true)) as approved_active_alias_count,
    count(*) filter (where a.status = 'approved' and not coalesce(a.is_active, true)) as approved_inactive_alias_count,
    count(*) filter (where a.status <> 'approved') as non_approved_alias_count
  from normalized_rows n
  left join public.ingredient_aliases_v2 a
    on a.normalized_alias_text = n.reconciliation_match_text
  group by n.recipe_id, n.ingredient_index
),
approved_alias_candidates as (
  select
    n.recipe_id,
    n.ingredient_index,
    a.ingredient_id,
    'approved_alias'::text as match_source
  from normalized_rows n
  join public.ingredient_aliases_v2 a
    on a.normalized_alias_text = n.reconciliation_match_text
   and a.status = 'approved'
   and coalesce(a.is_active, true)
),
canonical_localization_candidates as (
  select
    n.recipe_id,
    n.ingredient_index,
    l.ingredient_id,
    'canonical_localization'::text as match_source
  from normalized_rows n
  join public.ingredient_localizations l
    on lower(trim(l.display_name)) = n.reconciliation_match_text
  where not exists (
    select 1
    from approved_alias_candidates a
    where a.recipe_id = n.recipe_id
      and a.ingredient_index = n.ingredient_index
  )
),
allowed_match_candidates as (
  select * from approved_alias_candidates
  union all
  select * from canonical_localization_candidates
),
allowed_match_summary as (
  select
    amc.recipe_id,
    amc.ingredient_index,
    count(distinct amc.ingredient_id) as canonical_target_count,
    (array_agg(amc.ingredient_id order by amc.ingredient_id::text))[1] as matched_ingredient_id,
    bool_or(amc.match_source = 'approved_alias') as has_alias_match,
    bool_or(amc.match_source = 'canonical_localization') as has_localization_match
  from allowed_match_candidates amc
  group by amc.recipe_id, amc.ingredient_index
)
select
  n.recipe_id,
  (n.recipe_id || '#' || n.ingredient_index::text) as recipe_ingredient_row_id,
  n.ingredient_index,
  n.current_text,
  n.normalized_text,
  ams.matched_ingredient_id,
  case
    when coalesce(ams.canonical_target_count, 0) > 1 then 'multiple'
    when coalesce(ams.canonical_target_count, 0) = 1 and coalesce(ams.has_alias_match, false) then 'approved_alias'
    when coalesce(ams.canonical_target_count, 0) = 1 and coalesce(ams.has_localization_match, false) then 'canonical_localization'
    else 'none'
  end as match_source,
  (
    n.produce_id is null
    and n.basic_ingredient_id is null
    and n.ingredient_id is null
    and coalesce(ams.canonical_target_count, 0) = 1
    and (
      coalesce(ams.has_alias_match, false)
      or coalesce(ams.has_localization_match, false)
    )
    and not (
      char_length(trim(coalesce(n.reconciliation_match_text, ''))) < 3
      or n.reconciliation_match_text ~* '^(https?://|www\.)'
      or n.reconciliation_match_text ~ '^[0-9\s\W_]+$'
      or n.reconciliation_match_text ~ '^[^a-zA-Z]{3,}$'
    )
    and coalesce(obs.candidate_status, '') not in ('rejected', 'ignored', 'conflict', 'deprecated')
  ) as safe_to_apply,
  case
    when n.produce_id is not null or n.basic_ingredient_id is not null or n.ingredient_id is not null then 'already_resolved'
    when n.normalized_text is null or n.normalized_text = '' then 'no_match'
    when (
      char_length(trim(coalesce(n.reconciliation_match_text, ''))) < 3
      or n.reconciliation_match_text ~* '^(https?://|www\.)'
      or n.reconciliation_match_text ~ '^[0-9\s\W_]+$'
      or n.reconciliation_match_text ~ '^[^a-zA-Z]{3,}$'
    ) then 'text_is_noise'
    when coalesce(obs.candidate_status, '') in ('rejected', 'ignored', 'conflict', 'deprecated') then 'candidate_rejected_or_ignored'
    when coalesce(ams.canonical_target_count, 0) > 1 then 'multiple_matches'
    when coalesce(ams.canonical_target_count, 0) = 1 and coalesce(ams.has_alias_match, false) then 'approved_alias_exact_match'
    when coalesce(ams.canonical_target_count, 0) = 1 and coalesce(ams.has_localization_match, false) then 'canonical_localization_exact_match'
    when coalesce(aes.approved_active_alias_count, 0) = 0 and coalesce(aes.non_approved_alias_count, 0) > 0 then 'alias_not_approved'
    when coalesce(aes.approved_active_alias_count, 0) = 0 and coalesce(aes.approved_inactive_alias_count, 0) > 0 then 'alias_inactive'
    else 'no_match'
  end as safety_reason,
  coalesce(obs.candidate_status, 'none') as candidate_status,
  coalesce(ams.canonical_target_count, 0) as canonical_target_count,
  n.produce_id,
  n.basic_ingredient_id,
  n.ingredient_id,
  n.reconciliation_match_text
from normalized_rows n
left join allowed_match_summary ams
  on ams.recipe_id = n.recipe_id
 and ams.ingredient_index = n.ingredient_index
left join alias_exact_stats aes
  on aes.recipe_id = n.recipe_id
 and aes.ingredient_index = n.ingredient_index
left join observation_status obs
  on obs.normalized_text = n.reconciliation_match_text;

create or replace view public.recipe_source_ingredient_catalog_coverage as
with recipe_ingredient_rows as (
  select
    coalesce(nullif(trim(r.source_name), ''), 'unknown') as source_name,
    coalesce(nullif(trim(r.source_type), ''), 'unknown') as source_type,
    r.id::text as recipe_id,
    i.ingredient as ingredient_json
  from public.recipes r
  cross join lateral jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as i(ingredient, ordinality)
),
classified as (
  select
    source_name,
    source_type,
    recipe_id,
    nullif(trim(coalesce(ingredient_json ->> 'ingredient_id', '')), '') as ingredient_id,
    nullif(trim(coalesce(ingredient_json ->> 'produce_id', '')), '') as produce_id,
    nullif(trim(coalesce(ingredient_json ->> 'basic_ingredient_id', '')), '') as basic_ingredient_id
  from recipe_ingredient_rows
)
select
  source_name,
  source_type,
  count(distinct recipe_id)::bigint as recipe_count,
  count(*)::bigint as ingredient_row_count,
  count(*) filter (where ingredient_id is not null)::bigint as modern_ingredient_id_count,
  count(*) filter (where produce_id is not null)::bigint as legacy_produce_id_count,
  count(*) filter (where basic_ingredient_id is not null)::bigint as legacy_basic_ingredient_id_count,
  count(*) filter (
    where ingredient_id is null
      and produce_id is null
      and basic_ingredient_id is null
  )::bigint as custom_ingredient_count,
  round(
    (
      count(*) filter (
        where ingredient_id is not null
          or produce_id is not null
          or basic_ingredient_id is not null
      )::numeric
      / nullif(count(*)::numeric, 0)
    ) * 100.0,
    2
  ) as catalog_coverage_pct
from classified
group by source_name, source_type;

grant execute on function public.normalize_recipe_ingredient_text_for_matching(text) to authenticated;
grant execute on function public.normalize_recipe_ingredient_text_for_matching(text) to service_role;
grant select on public.recipe_source_ingredient_catalog_coverage to authenticated;
grant select on public.recipe_source_ingredient_catalog_coverage to service_role;
