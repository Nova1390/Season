-- Operator-safe visibility for safe reconciliation rows blocked by missing legacy bridge mappings.
-- Adds:
-- 1) read-only gap preview
-- 2) conservative admin-only backfill helper that requires explicit mapping inputs

create or replace function public.preview_reconciliation_legacy_bridge_gaps(
  p_limit integer default 100
)
returns table (
  matched_ingredient_id uuid,
  matched_ingredient_slug text,
  matched_ingredient_name text,
  ingredient_type text,
  safe_blocked_row_count bigint,
  safe_blocked_recipe_count bigint,
  sample_recipe_id text,
  sample_recipe_title text,
  sample_ingredient_raw_name text,
  legacy_mapping_missing boolean,
  missing_legacy_produce_id boolean,
  missing_legacy_basic_id boolean
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
  ),
  blocked as (
    select
      p.recipe_id,
      p.recipe_ingredient_row_id,
      p.ingredient_index,
      p.current_text,
      p.matched_ingredient_id
    from public.recipe_ingredient_reconciliation_safety_preview p
    left join (
      select distinct a.recipe_ingredient_row_id
      from public.recipe_ingredient_reconciliation_audit a
    ) ra
      on ra.recipe_ingredient_row_id = p.recipe_ingredient_row_id
    left join public.legacy_ingredient_mapping lm
      on lm.ingredient_id = p.matched_ingredient_id
    where p.safe_to_apply = true
      and p.matched_ingredient_id is not null
      and ra.recipe_ingredient_row_id is null
      and lm.ingredient_id is null
  ),
  aggregated as (
    select
      b.matched_ingredient_id,
      count(*)::bigint as safe_blocked_row_count,
      count(distinct b.recipe_id)::bigint as safe_blocked_recipe_count
    from blocked b
    group by b.matched_ingredient_id
  ),
  sample_rows as (
    select
      b.matched_ingredient_id,
      b.recipe_id,
      b.current_text,
      row_number() over (
        partition by b.matched_ingredient_id
        order by b.recipe_id asc, b.ingredient_index asc
      ) as rn
    from blocked b
  )
  select
    agg.matched_ingredient_id,
    i.slug as matched_ingredient_slug,
    coalesce(nullif(trim(tn.it_name), ''), nullif(trim(tn.en_name), ''), i.slug) as matched_ingredient_name,
    i.ingredient_type,
    agg.safe_blocked_row_count,
    agg.safe_blocked_recipe_count,
    sr.recipe_id as sample_recipe_id,
    coalesce(nullif(trim(r.title), ''), 'Untitled recipe') as sample_recipe_title,
    sr.current_text as sample_ingredient_raw_name,
    true as legacy_mapping_missing,
    (i.ingredient_type = 'produce') as missing_legacy_produce_id,
    (i.ingredient_type = 'basic') as missing_legacy_basic_id
  from aggregated agg
  join public.ingredients i
    on i.id = agg.matched_ingredient_id
  left join target_name tn
    on tn.ingredient_id = i.id
  left join sample_rows sr
    on sr.matched_ingredient_id = agg.matched_ingredient_id
   and sr.rn = 1
  left join public.recipes r
    on r.id::text = sr.recipe_id
  order by agg.safe_blocked_recipe_count desc, agg.safe_blocked_row_count desc, i.slug asc
  limit greatest(1, coalesce(p_limit, 100));
$$;

revoke all on function public.preview_reconciliation_legacy_bridge_gaps(integer) from public;
grant execute on function public.preview_reconciliation_legacy_bridge_gaps(integer) to authenticated;
grant execute on function public.preview_reconciliation_legacy_bridge_gaps(integer) to service_role;

create or replace function public.backfill_reconciliation_legacy_mappings(
  p_mappings jsonb,
  p_source_domain text default 'reconciliation_backfill',
  p_reviewer_note text default null
)
returns table (
  ingredient_id uuid,
  ingredient_slug text,
  legacy_produce_id text,
  legacy_basic_id text,
  result_status text,
  detail text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_item jsonb;
  v_ingredient_id uuid;
  v_legacy_produce_id text;
  v_legacy_basic_id text;
  v_ingredient_slug text;
  v_mapping_action text;
  v_error text;
begin
  perform public.assert_catalog_admin(v_user);

  if p_mappings is null or jsonb_typeof(p_mappings) <> 'array' then
    raise exception 'p_mappings must be a JSON array';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_mappings)
  loop
    v_ingredient_id := null;
    v_legacy_produce_id := null;
    v_legacy_basic_id := null;
    v_ingredient_slug := null;
    v_mapping_action := null;
    v_error := null;

    begin
      v_ingredient_id := nullif(trim(coalesce(v_item ->> 'ingredient_id', '')), '')::uuid;
    exception
      when others then
        v_error := 'invalid ingredient_id';
    end;

    if v_error is null then
      v_legacy_produce_id := nullif(trim(coalesce(v_item ->> 'legacy_produce_id', '')), '');
      v_legacy_basic_id := nullif(trim(coalesce(v_item ->> 'legacy_basic_id', '')), '');

      if (
        (case when v_legacy_produce_id is null then 0 else 1 end) +
        (case when v_legacy_basic_id is null then 0 else 1 end)
      ) <> 1 then
        v_error := 'exactly one of legacy_produce_id or legacy_basic_id is required';
      end if;
    end if;

    if v_error is null then
      begin
        select i.slug
        into v_ingredient_slug
        from public.ingredients i
        where i.id = v_ingredient_id;

        if v_ingredient_slug is null then
          v_error := 'ingredient_id not found';
        else
          select m.mapping_action
          into v_mapping_action
          from public.upsert_legacy_ingredient_mapping(
            p_ingredient_id => v_ingredient_id,
            p_legacy_produce_id => v_legacy_produce_id,
            p_legacy_basic_id => v_legacy_basic_id,
            p_source_domain => coalesce(nullif(trim(coalesce(p_source_domain, '')), ''), 'reconciliation_backfill'),
            p_reviewer_note => p_reviewer_note
          ) m;
        end if;
      exception
        when others then
          v_error := sqlerrm;
      end;
    end if;

    if v_error is null then
      return query
      select
        v_ingredient_id,
        v_ingredient_slug,
        v_legacy_produce_id,
        v_legacy_basic_id,
        'succeeded'::text,
        coalesce(v_mapping_action, 'inserted');
    else
      return query
      select
        v_ingredient_id,
        v_ingredient_slug,
        v_legacy_produce_id,
        v_legacy_basic_id,
        'failed'::text,
        v_error;
    end if;
  end loop;
end;
$$;

revoke all on function public.backfill_reconciliation_legacy_mappings(jsonb, text, text) from public;
grant execute on function public.backfill_reconciliation_legacy_mappings(jsonb, text, text) to authenticated;
grant execute on function public.backfill_reconciliation_legacy_mappings(jsonb, text, text) to service_role;
