begin;

-- Seed reusable learning for the current target-gap failures. This does not
-- mutate catalog identity, aliases, localizations, recipes, or proposals.
-- It gives the agent enough fresh memory to reconsider these terms on the next
-- controlled dev run instead of being blocked by recent proposal dedupe.

with learning_input as (
  select *
  from (
    values
      (
        'pomodori'::text,
        'prompt_improvement'::text,
        'medium'::text,
        'The agent kept base plural "pomodori" in human review even though the provided target was active canonical tomato and no size/cultivar/product-form variant was implied.',
        'Use approve_alias to canonical tomato for base plural/localized tomato forms when semantic evidence does not indicate an identity-bearing variant.',
        'Base singular/plural localized forms are aliases; meaningful market variants such as small tomatoes remain separate child targets.',
        'Golden case should pass when "pomodori" becomes approve_alias -> tomato while "pomodorini" does not collapse to tomato.',
        'For base plural or singular localized forms with no identity-bearing variant evidence, choose approve_alias to the active base canonical when the target is present.'
      ),
      (
        'pomodorini'::text,
        'prompt_improvement'::text,
        'medium'::text,
        'The historical proposal treated "pomodorini" as a missing canonical before the child canonical existed. Future runs should use the new child target rather than recreate it or collapse it into tomato.',
        'When active canonical pomodorini is available, use approve_alias to pomodorini. Use create_canonical only if the child/specialized target is missing.',
        'Once a meaningful child variant has been created, future surface forms for that variant should target the child canonical, never the parent base.',
        'Golden case should pass after a rerun when "pomodorini" targets active child canonical pomodorini.',
        'If learning or catalog context shows a meaningful child target already exists, prefer approve_alias to that child over create_canonical or parent-base aliasing.'
      ),
      (
        'fiocchi d avena'::text,
        'catalog_gap'::text,
        'medium'::text,
        'The agent treated oat flakes as vague human review, but the term is a clear oat product-form identity when the catalog lacks a dedicated rolled/oat-flakes child.',
        'Prefer create_canonical draft for a clear oat-flake product identity under oats when no safe dedicated target exists; approve_alias only if a dedicated rolled_oats/oat_flakes target is present.',
        'Product-form terms can be real catalog identities when they affect shopping/fridge matching and cooking semantics; missing child target should become catalog-gap proposal, not vague review.',
        'Golden case should pass when "fiocchi d avena" becomes create_canonical for oat_flakes/rolled_oats or approve_alias to an existing dedicated target.',
        'For clear product-form identities such as flakes, powder, or whole grain, propose create_canonical when the child target is missing and the parent alone would be too generic.'
      )
  ) as v(
    normalized_text,
    learning_type,
    severity,
    observed_problem,
    corrected_decision,
    policy_implication,
    evaluation_recommendation,
    prompt_recommendation
  )
),
latest_proposal as (
  select distinct on (p.normalized_text)
    p.normalized_text,
    p.id as proposal_id,
    p.run_id,
    jsonb_strip_nulls(
      jsonb_build_object(
        'proposal_id', p.id,
        'proposal_type', p.proposal_type,
        'target_slug', p.target_slug,
        'proposed_slug', p.proposed_slug,
        'confidence_score', p.confidence_score,
        'risk_level', p.risk_level,
        'status', p.status,
        'source', 'golden_case_target_gap_baseline'
      )
    ) as original_recommendation
  from public.catalog_agent_proposals p
  where p.normalized_text in (
    select li.normalized_text
    from learning_input li
  )
  order by p.normalized_text, p.id desc
)
insert into public.catalog_agent_learnings (
  proposal_id,
  run_id,
  normalized_text,
  learning_type,
  severity,
  status,
  original_recommendation,
  observed_problem,
  corrected_decision,
  policy_implication,
  evaluation_recommendation,
  prompt_recommendation,
  created_at,
  updated_at
)
select
  lp.proposal_id,
  lp.run_id,
  li.normalized_text,
  li.learning_type,
  li.severity,
  'implemented',
  coalesce(lp.original_recommendation, '{}'::jsonb),
  li.observed_problem,
  li.corrected_decision,
  li.policy_implication,
  li.evaluation_recommendation,
  li.prompt_recommendation,
  now(),
  now()
from learning_input li
left join latest_proposal lp on lp.normalized_text = li.normalized_text
where not exists (
  select 1
  from public.catalog_agent_learnings existing
  where existing.normalized_text = li.normalized_text
    and existing.status = 'implemented'
    and existing.corrected_decision = li.corrected_decision
);

commit;
