-- Add hierarchy-aware advisory decision hints to admin candidate snapshot.
-- Advisory only: no runtime matching/write behavior changes.

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

  select coalesce(jsonb_agg(to_jsonb(cq)), '[]'::jsonb)
  into v_candidates
  from (
    with candidate_base as (
      select
        c.normalized_text,
        c.occurrence_count,
        c.suggested_resolution_type,
        c.existing_alias_status,
        c.priority_score,
        regexp_replace(lower(trim(c.normalized_text)), '[^a-z0-9]+', '', 'g') as compact_key
      from public.catalog_resolution_candidates(v_candidates_limit, true) c
    ),
    canonical_keys as (
      select
        i.id as ingredient_id,
        i.slug,
        i.parent_ingredient_id,
        regexp_replace(lower(trim(replace(i.slug, '_', ' '))), '[^a-z0-9]+', '', 'g') as compact_key
      from public.ingredients i

      union

      select
        l.ingredient_id,
        i.slug,
        i.parent_ingredient_id,
        regexp_replace(lower(trim(l.display_name)), '[^a-z0-9]+', '', 'g') as compact_key
      from public.ingredient_localizations l
      join public.ingredients i
        on i.id = l.ingredient_id
      where l.display_name is not null
        and trim(l.display_name) <> ''
    ),
    root_keys as (
      select
        i.id as root_id,
        i.slug as root_slug,
        regexp_replace(lower(trim(replace(i.slug, '_', ' '))), '[^a-z0-9]+', '', 'g') as root_key
      from public.ingredients i
      where i.parent_ingredient_id is null
    ),
    scored as (
      select
        cb.normalized_text,
        cb.occurrence_count,
        cb.suggested_resolution_type,
        cb.existing_alias_status,
        cb.priority_score,
        ex.match_count,
        ex.exact_match_slug,
        parent_hint.suggested_parent_slug,
        coalesce(child_hint.close_child_exists, false) as close_child_exists
      from candidate_base cb
      left join lateral (
        select
          count(distinct ck.ingredient_id)::integer as match_count,
          min(ck.slug) as exact_match_slug
        from canonical_keys ck
        where ck.compact_key = cb.compact_key
      ) ex on true
      left join lateral (
        select
          rk.root_slug as suggested_parent_slug
        from root_keys rk
        where cb.compact_key <> ''
          and rk.root_key <> ''
          and cb.compact_key <> rk.root_key
          and cb.compact_key like rk.root_key || '%'
        order by char_length(rk.root_key) desc, rk.root_slug asc
        limit 1
      ) parent_hint on true
      left join lateral (
        select exists (
          select 1
          from public.ingredients p
          join public.ingredients ch
            on ch.parent_ingredient_id = p.id
          where p.slug = parent_hint.suggested_parent_slug
            and (
              cb.compact_key like regexp_replace(lower(trim(replace(ch.slug, '_', ' '))), '[^a-z0-9]+', '', 'g') || '%'
              or regexp_replace(lower(trim(replace(ch.slug, '_', ' '))), '[^a-z0-9]+', '', 'g') like cb.compact_key || '%'
            )
        ) as close_child_exists
      ) child_hint on true
    )
    select
      s.normalized_text,
      s.occurrence_count,
      s.suggested_resolution_type,
      s.existing_alias_status,
      s.priority_score,
      (s.suggested_parent_slug is not null) as canonical_parent_exists,
      s.close_child_exists as close_canonical_child_exists,
      case
        when coalesce(s.match_count, 0) = 1 then 'alias'
        when s.suggested_parent_slug is not null then 'new_variant'
        else 'new_root'
      end::text as suggested_action,
      s.suggested_parent_slug,
      case
        when coalesce(s.match_count, 0) = 1 then 'exact canonical text already exists (' || coalesce(s.exact_match_slug, 'matched_node') || ')'
        when s.suggested_parent_slug is not null and s.close_child_exists then 'candidate appears under existing parent and similar children already exist'
        when s.suggested_parent_slug is not null then 'candidate appears as a specific form under existing parent'
        else 'no safe parent context found; likely new root candidate'
      end::text as reasoning_hint
    from scored s
  ) cq;

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
      parent.slug as canonical_candidate_parent_slug,
      (ci.parent_ingredient_id is not null) as canonical_candidate_is_child,
      (ci.parent_ingredient_id is null and ci.id is not null) as canonical_candidate_is_root,
      (parent.id is not null) as generic_parent_exists,
      b.suggested_resolution_type,
      b.blocker_reason,
      b.recommended_next_action
    from public.top_catalog_coverage_blockers(v_blockers_limit, p_focus_alias_localization) b
    left join public.ingredients ci
      on ci.id = b.canonical_candidate_ingredient_id
    left join public.ingredients parent
      on parent.id = ci.parent_ingredient_id
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
      'source', 'catalog_admin_ops_snapshot_v4_hierarchy_hints'
    )
  );
end;
$$;

revoke all on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) from public;
grant execute on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) to authenticated;
grant execute on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) to service_role;
