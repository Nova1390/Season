-- Harden phase-1 recipe ingredient reconciliation for imported recipes.
-- Adds ingredient_id-aware safety checks and a richer preview report surface.

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
    n.produce_id is null
    and n.basic_ingredient_id is null
    and n.ingredient_id is null
    and coalesce(ams.canonical_target_count, 0) = 1
    and (
      coalesce(ams.has_alias_match, false)
      or coalesce(ams.has_localization_match, false)
    )
    and not (
      char_length(trim(coalesce(n.normalized_text, ''))) < 3
      or n.normalized_text ~* '^(https?://|www\\.)'
      or n.normalized_text ~ '^[0-9\\s\\W_]+$'
      or n.normalized_text ~ '^[^a-zA-Z]{3,}$'
    )
    and coalesce(obs.candidate_status, '') not in ('rejected', 'ignored', 'conflict', 'deprecated')
  ) as safe_to_apply,
  case
    when n.produce_id is not null or n.basic_ingredient_id is not null or n.ingredient_id is not null then 'already_resolved'
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
  n.basic_ingredient_id,
  n.ingredient_id
from normalized_rows n
left join allowed_match_summary ams
  on ams.recipe_id = n.recipe_id
 and ams.ingredient_index = n.ingredient_index
left join alias_exact_stats aes
  on aes.recipe_id = n.recipe_id
 and aes.ingredient_index = n.ingredient_index
left join observation_status obs
  on obs.normalized_text = n.normalized_text;

create or replace function public.apply_recipe_ingredient_reconciliation(
  p_limit integer default 100,
  p_recipe_ids text[] default null
)
returns table (
  batch_id uuid,
  recipe_id text,
  recipe_ingredient_row_id text,
  ingredient_index integer,
  matched_ingredient_id uuid,
  match_source text,
  applied boolean,
  apply_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch_id uuid := gen_random_uuid();
  v_user uuid := auth.uid();
  v_now timestamptz := now();
  v_limit integer := greatest(1, coalesce(p_limit, 100));
  v_recipe_ingredients jsonb;
  v_old_ingredient jsonb;
  v_new_ingredient jsonb;
  v_new_ingredients jsonb;
  rec record;
begin
  perform public.assert_catalog_admin(v_user);

  for rec in
    select
      p.recipe_id,
      p.recipe_ingredient_row_id,
      p.ingredient_index,
      p.matched_ingredient_id,
      p.match_source,
      lm.legacy_produce_id,
      lm.legacy_basic_id
    from public.recipe_ingredient_reconciliation_safety_preview p
    join public.legacy_ingredient_mapping lm
      on lm.ingredient_id = p.matched_ingredient_id
    where p.safe_to_apply = true
      and (
        p_recipe_ids is null
        or cardinality(p_recipe_ids) = 0
        or p.recipe_id = any(p_recipe_ids)
      )
    order by p.recipe_id asc, p.ingredient_index asc
    limit v_limit
  loop
    select r.ingredients::jsonb
    into v_recipe_ingredients
    from public.recipes r
    where r.id::text = rec.recipe_id
    for update;

    if v_recipe_ingredients is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'recipe_not_found_or_no_ingredients'::text;
      continue;
    end if;

    select e.elem
    into v_old_ingredient
    from jsonb_array_elements(v_recipe_ingredients) with ordinality as e(elem, ord)
    where e.ord = rec.ingredient_index;

    if v_old_ingredient is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'ingredient_index_not_found'::text;
      continue;
    end if;

    if nullif(trim(coalesce(v_old_ingredient ->> 'produce_id', '')), '') is not null
       or nullif(trim(coalesce(v_old_ingredient ->> 'basic_ingredient_id', '')), '') is not null
       or nullif(trim(coalesce(v_old_ingredient ->> 'ingredient_id', '')), '') is not null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'already_resolved'::text;
      continue;
    end if;

    v_new_ingredient :=
      (v_old_ingredient - 'produce_id' - 'basic_ingredient_id')
      || jsonb_build_object(
        'produce_id', to_jsonb(rec.legacy_produce_id),
        'basic_ingredient_id', to_jsonb(rec.legacy_basic_id)
      );

    select jsonb_agg(
      case
        when e.ord = rec.ingredient_index then v_new_ingredient
        else e.elem
      end
      order by e.ord
    )
    into v_new_ingredients
    from jsonb_array_elements(v_recipe_ingredients) with ordinality as e(elem, ord);

    if v_new_ingredients is null then
      return query
      select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, false, 'failed_to_build_updated_ingredients'::text;
      continue;
    end if;

    update public.recipes
    set ingredients = v_new_ingredients
    where id::text = rec.recipe_id;

    insert into public.recipe_ingredient_reconciliation_audit (
      batch_id,
      recipe_id,
      recipe_ingredient_row_id,
      ingredient_index,
      matched_ingredient_id,
      match_source,
      legacy_produce_id,
      legacy_basic_id,
      previous_ingredient_json,
      updated_ingredient_json,
      applied_at,
      applied_by,
      mechanism,
      created_at,
      updated_at
    )
    values (
      v_batch_id,
      rec.recipe_id,
      rec.recipe_ingredient_row_id,
      rec.ingredient_index,
      rec.matched_ingredient_id,
      rec.match_source,
      rec.legacy_produce_id,
      rec.legacy_basic_id,
      v_old_ingredient,
      v_new_ingredient,
      v_now,
      v_user,
      'phase1_safe_preview_apply',
      v_now,
      v_now
    );

    return query
    select v_batch_id, rec.recipe_id, rec.recipe_ingredient_row_id, rec.ingredient_index, rec.matched_ingredient_id, rec.match_source, true, 'applied'::text;
  end loop;
end;
$$;

create or replace function public.preview_safe_recipe_ingredient_reconciliation(
  p_limit integer default 500,
  p_only_safe boolean default false
)
returns table (
  recipe_id text,
  recipe_title text,
  recipe_ingredient_row_id text,
  ingredient_index integer,
  ingredient_raw_name text,
  current_mapping_state text,
  proposed_ingredient_id uuid,
  proposed_ingredient_slug text,
  proposed_ingredient_name text,
  confidence_source text,
  safe_to_apply boolean,
  safety_reason text
)
language sql
stable
set search_path = public
as $$
  with target_name as (
    select
      il.ingredient_id,
      max(case when il.language_code = 'it' then il.display_name end) as it_name,
      max(case when il.language_code = 'en' then il.display_name end) as en_name
    from public.ingredient_localizations il
    group by il.ingredient_id
  )
  select
    v.recipe_id,
    coalesce(nullif(trim(r.title), ''), 'Untitled recipe') as recipe_title,
    v.recipe_ingredient_row_id,
    v.ingredient_index,
    v.current_text as ingredient_raw_name,
    case
      when v.ingredient_id is not null then 'ingredient_id'
      when v.produce_id is not null then 'produce_id'
      when v.basic_ingredient_id is not null then 'basic_ingredient_id'
      else 'unmapped'
    end as current_mapping_state,
    v.matched_ingredient_id as proposed_ingredient_id,
    i.slug as proposed_ingredient_slug,
    coalesce(nullif(trim(tn.it_name), ''), nullif(trim(tn.en_name), ''), i.slug) as proposed_ingredient_name,
    v.match_source as confidence_source,
    v.safe_to_apply,
    v.safety_reason
  from public.recipe_ingredient_reconciliation_safety_preview v
  left join public.recipes r
    on r.id::text = v.recipe_id
  left join public.ingredients i
    on i.id = v.matched_ingredient_id
  left join target_name tn
    on tn.ingredient_id = i.id
  where (not p_only_safe) or v.safe_to_apply
  order by v.safe_to_apply desc, v.recipe_id asc, v.ingredient_index asc
  limit greatest(1, coalesce(p_limit, 500));
$$;

revoke all on function public.preview_safe_recipe_ingredient_reconciliation(integer, boolean) from public;
grant execute on function public.preview_safe_recipe_ingredient_reconciliation(integer, boolean) to authenticated;
grant execute on function public.preview_safe_recipe_ingredient_reconciliation(integer, boolean) to service_role;
