-- Admin-only queue for validated enrichment drafts ready for canonical creation.
-- Read-only artifact for internal tooling; excludes already-consumed drafts.

create or replace view public.catalog_ready_enrichment_draft_queue as
with decision_rollup as (
  select
    d.normalized_text,
    bool_or(
      d.action in ('create_ingredient_from_candidate', 'create_ingredient_from_candidate_existing')
    ) as has_creation_decision
  from public.catalog_candidate_decisions d
  group by d.normalized_text
)
select
  e.normalized_text,
  e.ingredient_type,
  e.canonical_name_it,
  e.canonical_name_en,
  e.suggested_slug,
  e.confidence_score,
  e.needs_manual_review,
  e.updated_at
from public.catalog_ingredient_enrichment_drafts e
left join decision_rollup dr
  on dr.normalized_text = e.normalized_text
left join public.custom_ingredient_observations o
  on o.normalized_text = e.normalized_text
where
  e.status = 'ready'
  and coalesce(e.validated_ready, false)
  and not coalesce(dr.has_creation_decision, false)
  and coalesce(o.status, 'new') <> 'ingredient_created';

create or replace function public.list_ready_catalog_enrichment_drafts(
  limit_count integer default 100
)
returns table (
  normalized_text text,
  ingredient_type text,
  canonical_name_it text,
  canonical_name_en text,
  suggested_slug text,
  confidence_score double precision,
  needs_manual_review boolean,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  perform public.assert_catalog_admin(v_user);

  return query
  select
    q.normalized_text,
    q.ingredient_type,
    q.canonical_name_it,
    q.canonical_name_en,
    q.suggested_slug,
    q.confidence_score,
    q.needs_manual_review,
    q.updated_at
  from public.catalog_ready_enrichment_draft_queue q
  order by q.updated_at desc, q.normalized_text asc
  limit greatest(1, coalesce(limit_count, 100));
end;
$$;

revoke all on function public.list_ready_catalog_enrichment_drafts(integer) from public;
grant execute on function public.list_ready_catalog_enrichment_drafts(integer) to authenticated;
grant execute on function public.list_ready_catalog_enrichment_drafts(integer) to service_role;

