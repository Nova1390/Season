create or replace function public.auto_apply_safe_aliases(
  p_limit integer default 50,
  p_language_code text default 'it'
)
returns table (
  normalized_text text,
  canonical_candidate_ingredient_id uuid,
  canonical_candidate_slug text,
  language_code text,
  attempted_alias_text text,
  match_method text,
  result_status text,
  detail text,
  error_message text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 500));
  v_language_code text := lower(trim(coalesce(p_language_code, 'it')));
  v_existing_alias_ingredient_id uuid;
  v_compact_candidate text;
  v_compact_reduced text;
  v_alias_text text;
  v_status text;
  v_detail text;
  v_error text;
  v_match_method text;
  r record;
begin
  perform public.assert_catalog_admin(v_user);

  if v_language_code = '' then
    v_language_code := 'it';
  end if;

  for r in
    with candidate_source as (
      select
        c.normalized_text,
        c.occurrence_count,
        c.suggested_resolution_type
      from public.catalog_resolution_candidates(v_limit * 4, true) c
      where c.suggested_resolution_type = 'alias_existing'
    ),
    prepared as (
      select
        cs.normalized_text,
        cs.occurrence_count,
        regexp_replace(
          lower(trim(cs.normalized_text)),
          '[^a-z0-9]+',
          '',
          'g'
        ) as compact_candidate,
        regexp_replace(
          regexp_replace(
            lower(trim(cs.normalized_text)),
            '\b(ammorbidito|da grattugiare|in grani|a temperatura ambiente|freddo di frigo|fresco|fresca|intero|intera|fino|fina|grosso|grossa)\b',
            ' ',
            'gi'
          ),
          '[^a-z0-9]+',
          '',
          'g'
        ) as compact_reduced
      from candidate_source cs
    ),
    canonical_keys as (
      select
        i.id as ingredient_id,
        i.slug as ingredient_slug,
        regexp_replace(lower(trim(replace(i.slug, '_', ' '))), '[^a-z0-9]+', '', 'g') as compact_key
      from public.ingredients i

      union all

      select
        l.ingredient_id,
        i.slug as ingredient_slug,
        regexp_replace(lower(trim(l.display_name)), '[^a-z0-9]+', '', 'g') as compact_key
      from public.ingredient_localizations l
      join public.ingredients i
        on i.id = l.ingredient_id
      where l.display_name is not null
        and trim(l.display_name) <> ''
    ),
    exact_match_candidates as (
      select
        p.normalized_text,
        ck.ingredient_id,
        ck.ingredient_slug
      from prepared p
      join canonical_keys ck
        on ck.compact_key = p.compact_candidate
      where p.compact_candidate <> ''
    ),
    exact_match as (
      select
        emc.normalized_text,
        count(distinct emc.ingredient_id)::integer as target_count,
        (array_agg(emc.ingredient_id order by emc.ingredient_slug asc, emc.ingredient_id asc))[1] as ingredient_id,
        (array_agg(emc.ingredient_slug order by emc.ingredient_slug asc, emc.ingredient_id asc))[1] as ingredient_slug
      from exact_match_candidates emc
      group by emc.normalized_text
    ),
    reduced_match_candidates as (
      select
        p.normalized_text,
        ck.ingredient_id,
        ck.ingredient_slug
      from prepared p
      join canonical_keys ck
        on ck.compact_key = p.compact_reduced
      where p.compact_reduced <> ''
        and p.compact_reduced <> p.compact_candidate
    ),
    reduced_match as (
      select
        rmc.normalized_text,
        count(distinct rmc.ingredient_id)::integer as target_count,
        (array_agg(rmc.ingredient_id order by rmc.ingredient_slug asc, rmc.ingredient_id asc))[1] as ingredient_id,
        (array_agg(rmc.ingredient_slug order by rmc.ingredient_slug asc, rmc.ingredient_id asc))[1] as ingredient_slug
      from reduced_match_candidates rmc
      group by rmc.normalized_text
    ),
    blocker_hints as (
      select
        b.normalized_text,
        b.recommended_next_action,
        b.likely_fix_type
      from public.catalog_coverage_blocker_terms b
    )
    select
      p.normalized_text,
      p.occurrence_count,
      bh.recommended_next_action,
      bh.likely_fix_type,
      case
        when em.target_count = 1 then em.ingredient_id
        when rm.target_count = 1 then rm.ingredient_id
        else null
      end as ingredient_id,
      case
        when em.target_count = 1 then em.ingredient_slug
        when rm.target_count = 1 then rm.ingredient_slug
        else null
      end as ingredient_slug,
      case
        when em.target_count = 1 then 'exact_compact_match'
        when rm.target_count = 1 then 'descriptor_reduced_match'
        else null
      end as match_method
    from prepared p
    left join exact_match em
      on em.normalized_text = p.normalized_text
    left join reduced_match rm
      on rm.normalized_text = p.normalized_text
    left join blocker_hints bh
      on bh.normalized_text = p.normalized_text
    where coalesce(bh.recommended_next_action, 'add_alias') = 'add_alias'
      and (bh.likely_fix_type is null or bh.likely_fix_type in ('alias', 'unknown'))
    order by
      p.occurrence_count desc,
      p.normalized_text asc
    limit v_limit
  loop
    v_status := null;
    v_detail := null;
    v_error := null;
    v_alias_text := null;
    v_match_method := r.match_method;
    v_existing_alias_ingredient_id := null;

    begin
      normalized_text := trim(coalesce(r.normalized_text, ''));
      canonical_candidate_ingredient_id := r.ingredient_id;
      canonical_candidate_slug := r.ingredient_slug;
      language_code := v_language_code;
      attempted_alias_text := null;
      match_method := v_match_method;

      if normalized_text = '' then
        v_status := 'skipped';
        v_detail := 'invalid_normalized_text';
      elsif canonical_candidate_ingredient_id is null or canonical_candidate_slug is null then
        v_status := 'skipped';
        v_detail := 'no_unambiguous_canonical_target';
      elsif match_method is null then
        v_status := 'skipped';
        v_detail := 'low_confidence_alias_candidate';
      else
        select a.ingredient_id
        into v_existing_alias_ingredient_id
        from public.ingredient_aliases_v2 a
        where a.normalized_alias_text = normalized_text
          and coalesce(a.is_active, true)
          and coalesce(a.status, 'approved') = 'approved'
        order by a.id desc
        limit 1;

        if v_existing_alias_ingredient_id is not null
           and v_existing_alias_ingredient_id is distinct from canonical_candidate_ingredient_id then
          v_status := 'skipped';
          v_detail := 'conflict_existing_approved_alias_other_target';
        else
          v_compact_candidate := regexp_replace(lower(trim(normalized_text)), '[^a-z0-9]+', '', 'g');
          v_compact_reduced := regexp_replace(
            regexp_replace(
              lower(trim(normalized_text)),
              '\b(ammorbidito|da grattugiare|in grani|a temperatura ambiente|freddo di frigo|fresco|fresca|intero|intera|fino|fina|grosso|grossa)\b',
              ' ',
              'gi'
            ),
            '[^a-z0-9]+',
            '',
            'g'
          );

          if v_match_method = 'descriptor_reduced_match'
             and (v_compact_reduced = '' or v_compact_reduced = v_compact_candidate) then
            v_status := 'skipped';
            v_detail := 'insufficient_descriptor_reduction_confidence';
          else
            v_alias_text := initcap(replace(normalized_text, '_', ' '));
            attempted_alias_text := v_alias_text;

            perform
              aa.normalized_text
            from public.approve_reconciliation_alias(
              p_normalized_text => normalized_text,
              p_ingredient_id => canonical_candidate_ingredient_id,
              p_alias_text => v_alias_text,
              p_language_code => language_code,
              p_reviewer_note => 'auto_safe_alias',
              p_confidence_score => 0.98
            ) aa;

            v_status := 'succeeded';
            v_detail := case
              when v_existing_alias_ingredient_id is null then 'alias_auto_approved'
              else 'alias_already_approved_same_target'
            end;
          end if;
        end if;
      end if;
    exception when others then
      v_status := 'failed';
      v_detail := 'auto_alias_failed';
      v_error := sqlerrm;
      raise notice '[SEASON_CATALOG_AUTO_ALIAS] normalized_text=% ingredient_id=% error=%', normalized_text, canonical_candidate_ingredient_id, v_error;
    end;

    result_status := coalesce(v_status, 'failed');
    detail := coalesce(v_detail, 'unknown');
    error_message := v_error;

    insert into public.catalog_alias_auto_apply_audit (
      normalized_text,
      ingredient_id,
      ingredient_slug,
      match_method,
      attempted_alias_text,
      result_status,
      detail,
      error_message,
      actor_user_id
    ) values (
      coalesce(normalized_text, ''),
      canonical_candidate_ingredient_id,
      canonical_candidate_slug,
      match_method,
      attempted_alias_text,
      result_status,
      detail,
      error_message,
      v_user
    );

    return next;
  end loop;

  return;
end;
$$;

revoke all on function public.auto_apply_safe_aliases(integer, text) from public;
grant execute on function public.auto_apply_safe_aliases(integer, text) to authenticated;
grant execute on function public.auto_apply_safe_aliases(integer, text) to service_role;
