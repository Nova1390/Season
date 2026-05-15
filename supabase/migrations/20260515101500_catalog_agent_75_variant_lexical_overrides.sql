-- Add documented lexical expansion hints discovered by the 7.5 remote
-- context-quality gate. These rows do not mutate catalog truth; they only
-- help the pre-LLM matcher find existing canonical targets before deciding
-- whether an alias, canonical draft, or human review is appropriate.

insert into public.catalog_agent_lexical_candidate_overrides (
  source_term,
  candidate_term,
  expansion_source,
  notes,
  is_active
)
values
  (
    'pepe',
    'pepe nero',
    'governed_override',
    'Bare Italian pepper should surface the existing black pepper candidate while remaining conservative when context is insufficient.',
    true
  ),
  (
    'patate dolci',
    'sweet potato',
    'governed_override',
    'Italian sweet potatoes are a meaningful variant and should surface the existing sweet_potato canonical instead of collapsing to potatoes.',
    true
  ),
  (
    'patata dolce',
    'sweet potato',
    'governed_override',
    'Singular Italian sweet potato should surface the existing sweet_potato canonical.',
    true
  )
on conflict (source_term, candidate_term, expansion_source) do update
set
  expansion_source = excluded.expansion_source,
  notes = excluded.notes,
  is_active = excluded.is_active,
  updated_at = now();
