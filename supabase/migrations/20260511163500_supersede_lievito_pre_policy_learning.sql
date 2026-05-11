begin;

-- The generic lievito catalog policy is now implemented. Older caution-only
-- lessons should stop competing with the implemented policy in runtime memory.

update public.catalog_agent_learnings l
set
  status = 'superseded',
  updated_at = now()
where l.normalized_text = 'lievito'
  and l.status = 'needs_review'
  and l.learning_type in ('ambiguity', 'policy_gap')
  and exists (
    select 1
    from public.catalog_agent_learnings implemented
    where implemented.normalized_text = 'lievito'
      and implemented.status = 'implemented'
      and implemented.corrected_decision ilike '%canonical slug "lievito"%'
  );

commit;
