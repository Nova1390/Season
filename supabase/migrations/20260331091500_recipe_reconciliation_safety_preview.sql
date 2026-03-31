-- Phase 1 reconciliation preview safety policy (read-only).
-- Defines conservative `safe_to_apply` rules without mutating recipe ingredient rows.

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
    nullif(trim(coalesce(rir.ingredient_json ->> 'name', '')), '') as current_text,
    lower(trim(coalesce(rir.ingredient_json ->> 'name', ''))) as normalized_text
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
    on a.normalized_alias_text = n.normalized_text
  group by n.recipe_id, n.ingredient_index
),
allowed_match_candidates as (
  select
    n.recipe_id,
    n.ingredient_index,
    a.ingredient_id,
    'approved_alias'::text as match_source
  from normalized_rows n
  join public.ingredient_aliases_v2 a
    on a.normalized_alias_text = n.normalized_text
   and a.status = 'approved'
   and coalesce(a.is_active, true)

  union all

  select
    n.recipe_id,
    n.ingredient_index,
    l.ingredient_id,
    'canonical_localization'::text as match_source
  from normalized_rows n
  join public.ingredient_localizations l
    on lower(trim(l.display_name)) = n.normalized_text
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
    -- 1) not already resolved
    n.produce_id is null
    and n.basic_ingredient_id is null
    -- 2) exactly one canonical target
    and coalesce(ams.canonical_target_count, 0) = 1
    -- 3) exact-match high-confidence sources only
    and (
      coalesce(ams.has_alias_match, false)
      or coalesce(ams.has_localization_match, false)
    )
    -- 6) source text must not look noisy
    and not (
      char_length(trim(coalesce(n.normalized_text, ''))) < 3
      or n.normalized_text ~* '^(https?://|www\\.)'
      or n.normalized_text ~ '^[0-9\\s\\W_]+$'
      or n.normalized_text ~ '^[^a-zA-Z]{3,}$'
    )
    -- 7) conflicting ops signals excluded
    and coalesce(obs.candidate_status, '') not in ('rejected', 'ignored', 'conflict', 'deprecated')
  ) as safe_to_apply,
  case
    when n.produce_id is not null or n.basic_ingredient_id is not null then 'already_resolved'
    when n.normalized_text is null or n.normalized_text = '' then 'no_match'
    when (
      char_length(trim(coalesce(n.normalized_text, ''))) < 3
      or n.normalized_text ~* '^(https?://|www\\.)'
      or n.normalized_text ~ '^[0-9\\s\\W_]+$'
      or n.normalized_text ~ '^[^a-zA-Z]{3,}$'
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
  n.basic_ingredient_id
from normalized_rows n
left join allowed_match_summary ams
  on ams.recipe_id = n.recipe_id
 and ams.ingredient_index = n.ingredient_index
left join alias_exact_stats aes
  on aes.recipe_id = n.recipe_id
 and aes.ingredient_index = n.ingredient_index
left join observation_status obs
  on obs.normalized_text = n.normalized_text;

create or replace function public.preview_recipe_ingredient_reconciliation_safety(
  p_limit integer default 500,
  p_only_safe boolean default false
)
returns table (
  recipe_id text,
  recipe_ingredient_row_id text,
  ingredient_index integer,
  current_text text,
  normalized_text text,
  matched_ingredient_id uuid,
  match_source text,
  safe_to_apply boolean,
  safety_reason text,
  candidate_status text,
  canonical_target_count integer,
  produce_id text,
  basic_ingredient_id text
)
language sql
stable
set search_path = public
as $$
  select
    v.recipe_id,
    v.recipe_ingredient_row_id,
    v.ingredient_index,
    v.current_text,
    v.normalized_text,
    v.matched_ingredient_id,
    v.match_source,
    v.safe_to_apply,
    v.safety_reason,
    v.candidate_status,
    v.canonical_target_count,
    v.produce_id,
    v.basic_ingredient_id
  from public.recipe_ingredient_reconciliation_safety_preview v
  where (not p_only_safe) or v.safe_to_apply
  order by v.safe_to_apply desc, v.recipe_id asc, v.ingredient_index asc
  limit greatest(1, coalesce(p_limit, 500));
$$;

grant select on public.recipe_ingredient_reconciliation_safety_preview to authenticated;
grant execute on function public.preview_recipe_ingredient_reconciliation_safety(integer, boolean) to authenticated;
grant execute on function public.preview_recipe_ingredient_reconciliation_safety(integer, boolean) to service_role;
