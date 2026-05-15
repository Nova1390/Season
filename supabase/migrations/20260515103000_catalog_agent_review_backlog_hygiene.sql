begin;

-- Dev-only backlog hygiene for the Catalog Agent review inbox.
-- This keeps audit history intact while removing stale duplicate open work from
-- the operator queue. It does not approve aliases, create canonical
-- ingredients, or mutate recipe/catalog truth.

with ranked_open as (
  select
    p.id,
    p.normalized_text,
    row_number() over (
      partition by p.normalized_text
      order by
        case p.proposal_type
          when 'approve_alias' then 0
          when 'create_canonical' then 1
          when 'add_localization' then 2
          when 'needs_human_review' then 3
          else 9
        end,
        p.created_at desc,
        p.id desc
    ) as keep_rank
  from public.catalog_agent_proposals p
  where p.status in ('needs_human_review', 'draft', 'failed_validation', 'queued_for_validation', 'validated')
),
superseded_duplicates as (
  update public.catalog_agent_proposals p
  set
    status = 'superseded',
    rejection_reason = coalesce(
      p.rejection_reason,
      'Superseded by Catalog Agent inbox hygiene: a newer or more actionable open proposal exists for the same normalized text.'
    ),
    updated_at = now()
  from ranked_open r
  where p.id = r.id
    and r.keep_rank > 1
  returning p.id, p.normalized_text, p.run_id
),
resolved_terms as (
  update public.catalog_agent_proposals p
  set
    status = 'superseded',
    rejection_reason = coalesce(
      p.rejection_reason,
      case p.normalized_text
        when 'pomodorini' then 'Superseded by Catalog Agent inbox hygiene: pomodorini now exists as an active canonical child of tomato.'
        when 'acqua di cottura' then 'Superseded by Catalog Agent inbox hygiene: cooking water is recipe process/context, not a canonical ingredient identity.'
        else 'Superseded by Catalog Agent inbox hygiene.'
      end
    ),
    updated_at = now()
  where p.normalized_text in ('pomodorini', 'acqua di cottura')
    and p.status in ('needs_human_review', 'draft', 'failed_validation', 'queued_for_validation', 'validated')
  returning p.id, p.normalized_text, p.run_id
),
all_superseded as (
  select * from superseded_duplicates
  union all
  select * from resolved_terms
)
insert into public.catalog_agent_proposal_events (
  proposal_id,
  run_id,
  event_type,
  event_payload,
  created_at
)
select
  s.id,
  s.run_id,
  'proposal_superseded_by_backlog_hygiene',
  jsonb_build_object(
    'normalized_text', s.normalized_text,
    'reason', 'latest_per_term_backlog_cleanup',
    'mutation_scope', 'proposal_status_only'
  ),
  now()
from all_superseded s;

insert into public.catalog_agent_learnings (
  normalized_text,
  learning_type,
  severity,
  status,
  observed_problem,
  corrected_decision,
  policy_implication,
  evaluation_recommendation,
  prompt_recommendation,
  created_at,
  updated_at
)
values (
  'acqua di cottura',
  'state_vs_identity',
  'medium',
  'implemented',
  'Cooking water appeared as an open catalog-agent review item, but it is process/context from a recipe rather than a durable ingredient identity.',
  'Do not create a canonical ingredient for cooking water from recipe captions; keep it in method/context unless future evidence proves a purchasable catalog item.',
  'Preparation/process artifacts should be filtered before canonical creation and should not create repeated human-review work.',
  'Add state/process terms to review-inbox and context-quality checks when they recur in Smart Import captions.',
  'When a candidate is recipe process/context, propose no catalog mutation and explain the blocking reason precisely instead of returning generic needs_human_review.',
  now(),
  now()
)
on conflict do nothing;

commit;
