-- Consolidated read-only admin ops snapshot for Catalog Intelligence.
-- This keeps existing source artifacts authoritative and returns one payload:
-- candidates + coverage_blockers + ready_enrichment_drafts + metadata.

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

  return jsonb_build_object(
    'candidates', v_candidates,
    'coverage_blockers', v_coverage_blockers,
    'ready_enrichment_drafts', v_ready_enrichment_drafts,
    'metadata', jsonb_build_object(
      'generated_at', v_now,
      'counts', jsonb_build_object(
        'candidates', jsonb_array_length(v_candidates),
        'coverage_blockers', jsonb_array_length(v_coverage_blockers),
        'ready_enrichment_drafts', jsonb_array_length(v_ready_enrichment_drafts)
      ),
      'source', 'catalog_admin_ops_snapshot_v1'
    )
  );
end;
$$;

revoke all on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) from public;
grant execute on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) to authenticated;
grant execute on function public.get_catalog_admin_ops_snapshot(integer, integer, integer, boolean) to service_role;
