begin;

-- Real creator captions often use bare "olive" as a generic ingredient.
-- Treat the bare term as a valid base catalog identity/gap, while keeping
-- specific forms such as green/black/taggiasche/brined olives as child variants.

insert into public.catalog_agent_lexical_candidate_overrides (
  source_term,
  candidate_term,
  expansion_source,
  notes,
  is_active
)
values
  (
    'olive',
    'olives',
    'governed_generic_base_lookup',
    'Bare Italian olive is a common creator-facing generic ingredient term. It should surface/create a base olives identity when no exact base exists; specific olive forms remain child variants.',
    true
  ),
  (
    'oliva',
    'olives',
    'governed_generic_base_lookup',
    'Singular Italian oliva should surface/create the generic olives base identity when no exact base exists.',
    true
  )
on conflict (source_term, candidate_term, expansion_source) do update
set
  notes = excluded.notes,
  is_active = excluded.is_active,
  updated_at = now();

commit;
