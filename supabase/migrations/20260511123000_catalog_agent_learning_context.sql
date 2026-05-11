begin;

-- Expose reviewed / actionable learning memory as a compact runtime context
-- packet. The agent uses this as a sidecar before asking the LLM, so it can
-- avoid repeating previously observed mistakes without bloating the base
-- triage snapshot.

create or replace function public.get_catalog_agent_learning_context(
  p_normalized_texts text[] default array[]::text[],
  p_limit_per_term integer default 3
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := least(10, greatest(1, coalesce(p_limit_per_term, 3)));
  v_terms text[] := array[]::text[];
  v_term_learnings jsonb := '{}'::jsonb;
  v_global_learnings jsonb := '[]'::jsonb;
begin
  perform public.assert_catalog_admin(v_user);

  select coalesce(array_agg(term order by term), array[]::text[])
  into v_terms
  from (
    select distinct lower(trim(raw_term)) as term
    from unnest(coalesce(p_normalized_texts, array[]::text[])) as raw(raw_term)
    where nullif(lower(trim(raw_term)), '') is not null
    limit 100
  ) normalized_terms;

  with ranked as (
    select
      l.*,
      row_number() over (
        partition by l.normalized_text
        order by
          case l.status
            when 'implemented' then 1
            when 'accepted' then 2
            when 'needs_review' then 3
            else 9
          end,
          case l.severity
            when 'critical' then 1
            when 'high' then 2
            when 'medium' then 3
            else 4
          end,
          l.created_at desc,
          l.id desc
      ) as memory_rank
    from public.catalog_agent_learnings l
    where l.normalized_text = any(v_terms)
      and l.status in ('needs_review', 'accepted', 'implemented')
  ),
  grouped as (
    select
      r.normalized_text,
      jsonb_agg(
        jsonb_strip_nulls(
          jsonb_build_object(
            'learning_id', r.id,
            'learning_type', r.learning_type,
            'severity', r.severity,
            'status', r.status,
            'observed_problem', r.observed_problem,
            'corrected_decision', r.corrected_decision,
            'policy_implication', r.policy_implication,
            'prompt_recommendation', r.prompt_recommendation,
            'validator_recommendation', r.validator_recommendation,
            'evaluation_recommendation', r.evaluation_recommendation,
            'source_proposal_id', r.proposal_id,
            'source_run_id', r.run_id,
            'created_at', r.created_at,
            'reviewed_at', r.reviewed_at,
            'original_recommendation', jsonb_strip_nulls(
              jsonb_build_object(
                'proposal_type', r.original_recommendation->>'proposal_type',
                'target_slug', r.original_recommendation->>'target_slug',
                'proposed_slug', r.original_recommendation->>'proposed_slug',
                'confidence_score', r.original_recommendation->'confidence_score',
                'risk_level', r.original_recommendation->>'risk_level',
                'status', r.original_recommendation->>'status'
              )
            )
          )
        )
        order by r.memory_rank
      ) as learnings
    from ranked r
    where r.memory_rank <= v_limit
    group by r.normalized_text
  )
  select coalesce(jsonb_object_agg(g.normalized_text, g.learnings), '{}'::jsonb)
  into v_term_learnings
  from grouped g;

  select coalesce(
    jsonb_agg(
      jsonb_strip_nulls(
        jsonb_build_object(
          'learning_id', global_learning.id,
          'learning_type', global_learning.learning_type,
          'severity', global_learning.severity,
          'status', global_learning.status,
          'observed_problem', global_learning.observed_problem,
          'corrected_decision', global_learning.corrected_decision,
          'policy_implication', global_learning.policy_implication,
          'prompt_recommendation', global_learning.prompt_recommendation,
          'validator_recommendation', global_learning.validator_recommendation,
          'evaluation_recommendation', global_learning.evaluation_recommendation,
          'source_proposal_id', global_learning.proposal_id,
          'source_run_id', global_learning.run_id,
          'created_at', global_learning.created_at,
          'reviewed_at', global_learning.reviewed_at
        )
      )
      order by
        case global_learning.status
          when 'implemented' then 1
          when 'accepted' then 2
          when 'needs_review' then 3
          else 9
        end,
        case global_learning.severity
          when 'critical' then 1
          when 'high' then 2
          when 'medium' then 3
          else 4
        end,
        global_learning.created_at desc,
        global_learning.id desc
    ),
    '[]'::jsonb
  )
  into v_global_learnings
  from (
    select l.*
    from public.catalog_agent_learnings l
    where l.normalized_text is null
      and l.status in ('needs_review', 'accepted', 'implemented')
      and l.learning_type in (
        'policy_gap',
        'prompt_improvement',
        'validator_failure',
        'manual_apply_failure',
        'duplicate_identity_risk',
        'other'
      )
    order by
      case l.status
        when 'implemented' then 1
        when 'accepted' then 2
        when 'needs_review' then 3
        else 9
      end,
      case l.severity
        when 'critical' then 1
        when 'high' then 2
        when 'medium' then 3
        else 4
      end,
      l.created_at desc,
      l.id desc
    limit v_limit * 2
  ) global_learning;

  return jsonb_build_object(
    'metadata', jsonb_build_object(
      'generated_at', now(),
      'source', 'catalog_agent_learning_context_v1',
      'terms_requested', coalesce(array_length(v_terms, 1), 0),
      'terms_with_learning', (
        select count(*)
        from jsonb_object_keys(v_term_learnings)
      ),
      'limit_per_term', v_limit,
      'included_statuses', array['needs_review', 'accepted', 'implemented']
    ),
    'term_learnings', v_term_learnings,
    'global_learnings', v_global_learnings,
    'runtime_instruction', jsonb_build_object(
      'use_learning_memory', 'Use relevant_learning_memory as prior operational memory, not as unquestionable truth.',
      'status_semantics', jsonb_build_object(
        'implemented', 'Policy or system behavior has already changed; follow it.',
        'accepted', 'Human-reviewed lesson; strongly prefer it unless current evidence contradicts it.',
        'needs_review', 'Useful warning from a failure or operator observation; treat as caution and cite if relevant.'
      ),
      'do_not_repeat', 'If a previous recommendation was rejected or failed validation/apply, do not repeat it unless new evidence resolves the recorded problem.',
      'still_required', 'All proposal targets must still come from current work-item context and pass deterministic validation.'
    )
  );
end;
$$;

revoke all on function public.get_catalog_agent_learning_context(text[], integer) from public;
grant execute on function public.get_catalog_agent_learning_context(text[], integer) to authenticated;
grant execute on function public.get_catalog_agent_learning_context(text[], integer) to service_role;

comment on function public.get_catalog_agent_learning_context(text[], integer) is
  'Read-only runtime learning memory sidecar for the Catalog Governance Agent. Returns compact term-specific and global lessons for LLM context.';

commit;
