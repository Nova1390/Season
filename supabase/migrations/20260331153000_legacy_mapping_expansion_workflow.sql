-- Controlled legacy bridge mapping expansion for phase-1 reconciliation.
-- Goal: unlock already-safe rows blocked only by missing legacy_ingredient_mapping.

create or replace function public.top_legacy_mapping_blockers(
  p_limit integer default 50
)
returns table (
  ingredient_id uuid,
  ingredient_slug text,
  ingredient_type text,
  row_count bigint,
  recipe_count bigint,
  alias_safe_count bigint,
  localization_safe_count bigint,
  sample_normalized_text text
)
language sql
stable
set search_path = public
as $$
  with safe_unapplied as (
    select
      p.recipe_id,
      p.normalized_text,
      p.matched_ingredient_id,
      p.match_source
    from public.recipe_ingredient_reconciliation_safety_preview p
    left join (
      select distinct recipe_ingredient_row_id
      from public.recipe_ingredient_reconciliation_audit
    ) a
      on a.recipe_ingredient_row_id = p.recipe_ingredient_row_id
    left join public.legacy_ingredient_mapping lm
      on lm.ingredient_id = p.matched_ingredient_id
    where p.safe_to_apply = true
      and a.recipe_ingredient_row_id is null
      and p.matched_ingredient_id is not null
      and lm.ingredient_id is null
  ),
  ranked_sample as (
    select
      s.matched_ingredient_id,
      s.normalized_text,
      count(*) as text_count,
      row_number() over (
        partition by s.matched_ingredient_id
        order by count(*) desc, s.normalized_text asc
      ) as rn
    from safe_unapplied s
    group by s.matched_ingredient_id, s.normalized_text
  )
  select
    s.matched_ingredient_id as ingredient_id,
    i.slug as ingredient_slug,
    i.ingredient_type,
    count(*)::bigint as row_count,
    count(distinct s.recipe_id)::bigint as recipe_count,
    count(*) filter (where s.match_source = 'approved_alias')::bigint as alias_safe_count,
    count(*) filter (where s.match_source = 'canonical_localization')::bigint as localization_safe_count,
    rs.normalized_text as sample_normalized_text
  from safe_unapplied s
  join public.ingredients i
    on i.id = s.matched_ingredient_id
  left join ranked_sample rs
    on rs.matched_ingredient_id = s.matched_ingredient_id
   and rs.rn = 1
  group by s.matched_ingredient_id, i.slug, i.ingredient_type, rs.normalized_text
  order by recipe_count desc, row_count desc, i.slug asc
  limit greatest(1, coalesce(p_limit, 50));
$$;

create or replace function public.upsert_legacy_ingredient_mapping(
  p_ingredient_id uuid,
  p_legacy_produce_id text default null,
  p_legacy_basic_id text default null,
  p_source_domain text default 'manual_ops',
  p_reviewer_note text default null
)
returns table (
  ingredient_id uuid,
  legacy_produce_id text,
  legacy_basic_id text,
  source_domain text,
  mapping_action text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_ingredient_type text;
  v_legacy_produce_id text := nullif(trim(coalesce(p_legacy_produce_id, '')), '');
  v_legacy_basic_id text := nullif(trim(coalesce(p_legacy_basic_id, '')), '');
  v_source_domain text := nullif(trim(coalesce(p_source_domain, '')), '');
  v_existing_for_ingredient public.legacy_ingredient_mapping%rowtype;
  v_conflict_ingredient_for_produce uuid;
  v_conflict_ingredient_for_basic uuid;
  v_action text := 'inserted';
begin
  if p_ingredient_id is null then
    raise exception 'ingredient_id is required';
  end if;

  select i.ingredient_type
  into v_ingredient_type
  from public.ingredients i
  where i.id = p_ingredient_id;

  if v_ingredient_type is null then
    raise exception 'ingredient_id not found: %', p_ingredient_id;
  end if;

  if (case when v_legacy_produce_id is null then 0 else 1 end)
     + (case when v_legacy_basic_id is null then 0 else 1 end) <> 1 then
    raise exception 'exactly one of legacy_produce_id or legacy_basic_id must be provided';
  end if;

  if v_ingredient_type = 'produce' and v_legacy_produce_id is null then
    raise exception 'produce ingredient requires legacy_produce_id';
  end if;

  if v_ingredient_type = 'basic' and v_legacy_basic_id is null then
    raise exception 'basic ingredient requires legacy_basic_id';
  end if;

  if v_source_domain is null then
    v_source_domain := 'manual_ops';
  end if;

  if v_legacy_produce_id is not null then
    select lm.ingredient_id
    into v_conflict_ingredient_for_produce
    from public.legacy_ingredient_mapping lm
    where lm.legacy_produce_id = v_legacy_produce_id
    limit 1;

    if v_conflict_ingredient_for_produce is not null and v_conflict_ingredient_for_produce <> p_ingredient_id then
      raise exception
        'legacy_produce_id % is already mapped to ingredient_id %',
        v_legacy_produce_id,
        v_conflict_ingredient_for_produce;
    end if;
  end if;

  if v_legacy_basic_id is not null then
    select lm.ingredient_id
    into v_conflict_ingredient_for_basic
    from public.legacy_ingredient_mapping lm
    where lm.legacy_basic_id = v_legacy_basic_id
    limit 1;

    if v_conflict_ingredient_for_basic is not null and v_conflict_ingredient_for_basic <> p_ingredient_id then
      raise exception
        'legacy_basic_id % is already mapped to ingredient_id %',
        v_legacy_basic_id,
        v_conflict_ingredient_for_basic;
    end if;
  end if;

  select *
  into v_existing_for_ingredient
  from public.legacy_ingredient_mapping lm
  where lm.ingredient_id = p_ingredient_id
  limit 1;

  if found then
    if (
      coalesce(v_existing_for_ingredient.legacy_produce_id, '') <> coalesce(v_legacy_produce_id, '')
      or coalesce(v_existing_for_ingredient.legacy_basic_id, '') <> coalesce(v_legacy_basic_id, '')
    ) then
      raise exception
        'ingredient_id % already has a different legacy mapping (produce=% basic=%)',
        p_ingredient_id,
        v_existing_for_ingredient.legacy_produce_id,
        v_existing_for_ingredient.legacy_basic_id;
    end if;

    update public.legacy_ingredient_mapping
    set
      source_domain = v_source_domain,
      updated_at = v_now
    where ingredient_id = p_ingredient_id;
    v_action := 'unchanged_refreshed';
  else
    insert into public.legacy_ingredient_mapping (
      ingredient_id,
      legacy_produce_id,
      legacy_basic_id,
      source_domain,
      created_at,
      updated_at
    )
    values (
      p_ingredient_id,
      v_legacy_produce_id,
      v_legacy_basic_id,
      v_source_domain,
      v_now,
      v_now
    );
    v_action := 'inserted';
  end if;

  return query
  select
    p_ingredient_id,
    v_legacy_produce_id,
    v_legacy_basic_id,
    v_source_domain,
    v_action;
end;
$$;

revoke all on function public.top_legacy_mapping_blockers(integer) from public;
grant execute on function public.top_legacy_mapping_blockers(integer) to authenticated;
grant execute on function public.top_legacy_mapping_blockers(integer) to service_role;

revoke all on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) from public;
grant execute on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) to authenticated;
grant execute on function public.upsert_legacy_ingredient_mapping(uuid, text, text, text, text) to service_role;
