begin;

-- Close create_canonical proposals once their governed enrichment draft has
-- already produced the canonical ingredient. This keeps the review inbox from
-- showing completed work as still actionable while preserving the event trail.

with applied_candidates as (
  select
    p.id as proposal_id,
    p.run_id,
    p.normalized_text,
    p.proposed_slug,
    d.status as draft_status,
    i.id as ingredient_id,
    i.slug as ingredient_slug
  from public.catalog_agent_proposals p
  join public.catalog_ingredient_enrichment_drafts d
    on d.normalized_text = p.normalized_text
  join public.ingredients i
    on i.slug = d.suggested_slug
  where p.proposal_type = 'create_canonical'
    and p.status in ('draft', 'queued_for_validation', 'validated')
    and d.status = 'applied'
    and i.quality_status = 'active'
),
updated as (
  update public.catalog_agent_proposals p
  set
    status = 'applied',
    applied_at = now(),
    updated_at = now(),
    validation_errors = coalesce(nullif(p.validation_errors, 'null'::jsonb), '[]'::jsonb)
  from applied_candidates c
  where p.id = c.proposal_id
  returning
    p.id as proposal_id,
    p.run_id,
    c.normalized_text,
    c.proposed_slug,
    c.draft_status,
    c.ingredient_id,
    c.ingredient_slug
)
insert into public.catalog_agent_proposal_events (
  proposal_id,
  run_id,
  event_type,
  event_payload,
  created_by
)
select
  u.proposal_id,
  u.run_id,
  'canonical_proposal_closed_after_draft_applied',
  jsonb_build_object(
    'normalized_text', u.normalized_text,
    'proposed_slug', u.proposed_slug,
    'ingredient_id', u.ingredient_id,
    'ingredient_slug', u.ingredient_slug,
    'draft_status', u.draft_status,
    'mutation_scope', 'proposal_lifecycle_only'
  ),
  null
from updated u
where not exists (
  select 1
  from public.catalog_agent_proposal_events e
  where e.proposal_id = u.proposal_id
    and e.event_type = 'canonical_proposal_closed_after_draft_applied'
);

commit;
