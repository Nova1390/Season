-- Add hierarchy-aware advisory signals to admin ops snapshot (read-only guidance).
-- No matching behavior changes; admin/catalog interpretation only.

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
      'source', 'catalog_admin_ops_snapshot_v3_hierarchy'
    )
  );
end;
$$;

revoke all on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) from public;
grant execute on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) to authenticated;
grant execute on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) to service_role;
