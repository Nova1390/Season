-- Read-only operator clarity layer for observed ingredient coverage state.
-- Explains why observations may not appear in unresolved candidate queue.

create or replace function public.catalog_observation_coverage_state(
  p_limit integer default 100,
  p_only_status_new boolean default true
)
returns table (
  normalized_text text,
  observation_status text,
  occurrence_count integer,
  last_seen_at timestamptz,
  coverage_state text,
  coverage_reason text,
  canonical_target_ingredient_id uuid,
  canonical_target_slug text,
  canonical_target_name text,
  alias_target_ingredient_id uuid,
  alias_target_slug text,
  alias_target_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := greatest(1, coalesce(p_limit, 100));
begin
  perform public.assert_catalog_admin(v_user);

  return query
  with observations as (
    select
      o.normalized_text,
      o.status,
      o.occurrence_count,
      o.last_seen_at
    from public.custom_ingredient_observations o
    where (not p_only_status_new) or o.status = 'new'
  ),
  unresolved_candidates as (
    select c.normalized_text
    from public.catalog_resolution_candidate_queue c
  ),
  alias_rollup as (
    select
      a.normalized_alias_text as normalized_text,
      count(*) > 0 as has_any_alias_match,
      bool_or(a.status = 'approved' and coalesce(a.is_active, true)) as has_approved_alias,
      (
        array_agg(a.ingredient_id order by
          case
            when a.status = 'approved' and coalesce(a.is_active, true) then 0
            when coalesce(a.is_active, true) then 1
            else 2
          end,
          a.updated_at desc nulls last,
          a.id desc
        )
      )[1] as alias_target_ingredient_id,
      (
        array_agg(coalesce(a.status, 'unknown') order by
          case
            when a.status = 'approved' and coalesce(a.is_active, true) then 0
            when coalesce(a.is_active, true) then 1
            else 2
          end,
          a.updated_at desc nulls last,
          a.id desc
        )
      )[1] as alias_match_status,
      (
        array_agg(coalesce(a.is_active, true) order by
          case
            when a.status = 'approved' and coalesce(a.is_active, true) then 0
            when coalesce(a.is_active, true) then 1
            else 2
          end,
          a.updated_at desc nulls last,
          a.id desc
        )
      )[1] as alias_is_active
    from public.ingredient_aliases_v2 a
    group by a.normalized_alias_text
  ),
  ingredient_names as (
    select
      i.id as ingredient_id,
      i.slug,
      coalesce(
        max(case when l.language_code = 'it' then nullif(trim(l.display_name), '') end),
        max(case when l.language_code = 'en' then nullif(trim(l.display_name), '') end),
        replace(i.slug, '_', ' ')
      ) as display_name
    from public.ingredients i
    left join public.ingredient_localizations l
      on l.ingredient_id = i.id
    group by i.id, i.slug
  ),
  canonical_keys as (
    select
      i.id as ingredient_id,
      i.slug,
      n.display_name,
      regexp_replace(lower(trim(replace(i.slug, '_', ' '))), '\\s+', ' ', 'g') as normalized_text
    from public.ingredients i
    left join ingredient_names n
      on n.ingredient_id = i.id

    union all

    select
      l.ingredient_id,
      i.slug,
      l.display_name,
      regexp_replace(lower(trim(l.display_name)), '\\s+', ' ', 'g') as normalized_text
    from public.ingredient_localizations l
    join public.ingredients i
      on i.id = l.ingredient_id
    where l.display_name is not null
      and trim(l.display_name) <> ''
  ),
  canonical_rollup as (
    select
      ck.normalized_text,
      count(distinct ck.ingredient_id) as canonical_match_count,
      (array_agg(distinct ck.ingredient_id order by ck.ingredient_id))[1] as canonical_target_ingredient_id,
      (array_agg(distinct ck.slug order by ck.slug))[1] as canonical_target_slug,
      (array_agg(distinct ck.display_name order by ck.display_name))[1] as canonical_target_name
    from canonical_keys ck
    where ck.normalized_text <> ''
    group by ck.normalized_text
  )
  select
    o.normalized_text,
    coalesce(o.status, 'unknown') as observation_status,
    o.occurrence_count,
    o.last_seen_at,
    case
      when uc.normalized_text is not null then 'unresolved_candidate'
      when coalesce(ar.has_any_alias_match, false) then 'covered_by_alias'
      when coalesce(cr.canonical_match_count, 0) > 0 then 'covered_by_canonical'
      else 'other_excluded'
    end::text as coverage_state,
    case
      when uc.normalized_text is not null then 'passes_unresolved_candidate_filters'
      when coalesce(ar.has_any_alias_match, false) then
        case
          when ar.has_approved_alias and coalesce(ar.alias_is_active, true) then 'approved_active_alias_match_exists'
          when ar.alias_match_status = 'suggested' then 'non_approved_alias_match_exists_suggested'
          when ar.alias_match_status = 'deprecated' then 'non_approved_alias_match_exists_deprecated'
          when ar.alias_match_status = 'rejected' then 'non_approved_alias_match_exists_rejected'
          else 'alias_match_exists'
        end
      when coalesce(cr.canonical_match_count, 0) = 1 then 'canonical_exact_match'
      when coalesce(cr.canonical_match_count, 0) > 1 then 'canonical_match_ambiguous_multiple_targets'
      when coalesce(o.status, 'new') <> 'new' then 'observation_status_not_new'
      else 'excluded_other'
    end::text as coverage_reason,
    case when coalesce(cr.canonical_match_count, 0) = 1 then cr.canonical_target_ingredient_id else null end as canonical_target_ingredient_id,
    case when coalesce(cr.canonical_match_count, 0) = 1 then cr.canonical_target_slug else null end as canonical_target_slug,
    case when coalesce(cr.canonical_match_count, 0) = 1 then cr.canonical_target_name else null end as canonical_target_name,
    ar.alias_target_ingredient_id,
    ai.slug as alias_target_slug,
    ai.display_name as alias_target_name
  from observations o
  left join unresolved_candidates uc
    on uc.normalized_text = o.normalized_text
  left join alias_rollup ar
    on ar.normalized_text = o.normalized_text
  left join canonical_rollup cr
    on cr.normalized_text = o.normalized_text
  left join ingredient_names ai
    on ai.ingredient_id = ar.alias_target_ingredient_id
  order by
    case
      when uc.normalized_text is not null then 0
      when coalesce(ar.has_any_alias_match, false) then 1
      when coalesce(cr.canonical_match_count, 0) > 0 then 2
      else 3
    end,
    o.occurrence_count desc,
    o.last_seen_at desc,
    o.normalized_text asc
  limit v_limit;
end;
$$;

create or replace function public.get_catalog_admin_ops_snapshot(
  p_candidates_limit integer default 50,
  p_coverage_blockers_limit integer default 30,
  p_ready_drafts_limit integer default 50,
  p_focus_alias_localization boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_now timestamptz := now();
  v_candidates_limit integer := greatest(1, coalesce(p_candidates_limit, 50));
  v_blockers_limit integer := greatest(1, coalesce(p_coverage_blockers_limit, 30));
  v_ready_limit integer := greatest(1, coalesce(p_ready_drafts_limit, 50));
  v_candidates jsonb := '[]'::jsonb;
  v_coverage_blockers jsonb := '[]'::jsonb;
  v_ready_enrichment_drafts jsonb := '[]'::jsonb;
  v_observation_coverage jsonb := '[]'::jsonb;
begin
  perform public.assert_catalog_admin(v_user);

  select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
  into v_candidates
  from (
    select
      c.normalized_text,
      c.occurrence_count,
      c.suggested_resolution_type,
      c.existing_alias_status,
      c.priority_score
    from public.catalog_resolution_candidates(v_candidates_limit, true) c
  ) c;

  select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb)
  into v_coverage_blockers
  from (
    select
      b.normalized_text,
      b.row_count,
      b.recipe_count,
      b.occurrence_count,
      b.priority_score,
      b.likely_fix_type,
      b.canonical_candidate_ingredient_id,
      b.canonical_candidate_slug,
      b.canonical_candidate_name,
      b.suggested_resolution_type,
      b.blocker_reason,
      b.recommended_next_action
    from public.top_catalog_coverage_blockers(v_blockers_limit, p_focus_alias_localization) b
  ) b;

  select coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb)
  into v_ready_enrichment_drafts
  from (
    select
      d.normalized_text,
      d.ingredient_type,
      d.canonical_name_it,
      d.canonical_name_en,
      d.suggested_slug,
      d.confidence_score,
      d.needs_manual_review,
      d.updated_at
    from public.list_ready_catalog_enrichment_drafts(v_ready_limit) d
  ) d;

  select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb)
  into v_observation_coverage
  from (
    select
      o.normalized_text,
      o.observation_status,
      o.occurrence_count,
      o.last_seen_at,
      o.coverage_state,
      o.coverage_reason,
      o.canonical_target_ingredient_id,
      o.canonical_target_slug,
      o.canonical_target_name,
      o.alias_target_ingredient_id,
      o.alias_target_slug,
      o.alias_target_name
    from public.catalog_observation_coverage_state(100, true) o
  ) o;

  return jsonb_build_object(
    'candidates', v_candidates,
    'coverage_blockers', v_coverage_blockers,
    'ready_enrichment_drafts', v_ready_enrichment_drafts,
    'observation_coverage', v_observation_coverage,
    'metadata', jsonb_build_object(
      'generated_at', v_now,
      'counts', jsonb_build_object(
        'candidates', jsonb_array_length(v_candidates),
        'coverage_blockers', jsonb_array_length(v_coverage_blockers),
        'ready_enrichment_drafts', jsonb_array_length(v_ready_enrichment_drafts),
        'observation_coverage', jsonb_array_length(v_observation_coverage)
      ),
      'source', 'catalog_admin_ops_snapshot_v2'
    )
  );
end;
$$;

revoke all on function public.catalog_observation_coverage_state(integer, boolean) from public;
grant execute on function public.catalog_observation_coverage_state(integer, boolean) to authenticated;
grant execute on function public.catalog_observation_coverage_state(integer, boolean) to service_role;

revoke all on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) from public;
grant execute on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) to authenticated;
grant execute on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) to service_role;
