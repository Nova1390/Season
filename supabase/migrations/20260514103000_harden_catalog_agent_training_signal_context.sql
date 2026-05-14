-- Harden the Smart Import training-signal context helper so authenticated
-- callers still go through the table RLS catalog-admin policy.

create or replace function public.get_catalog_agent_training_signal_context(
  p_normalized_texts text[],
  p_limit_per_term integer default 3
)
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with requested_terms as (
    select distinct regexp_replace(lower(btrim(term)), '\s+', ' ', 'g') as normalized_text
    from unnest(coalesce(p_normalized_texts, array[]::text[])) as term
    where nullif(trim(term), '') is not null
  ),
  ranked as (
    select
      s.*,
      row_number() over (
        partition by s.normalized_text
        order by
          case s.status
            when 'implemented' then 1
            when 'accepted' then 2
            when 'needs_review' then 3
            else 9
          end,
          s.occurrence_count desc,
          s.updated_at desc
      ) as term_rank
    from public.catalog_agent_training_signals s
    join requested_terms rt on rt.normalized_text = s.normalized_text
    where s.status in ('needs_review', 'accepted', 'implemented')
  ),
  limited as (
    select *
    from ranked
    where term_rank <= greatest(coalesce(p_limit_per_term, 3), 1)
  ),
  grouped as (
    select
      normalized_text,
      jsonb_agg(
        jsonb_build_object(
          'id', id,
          'training_signal', training_signal,
          'status', status,
          'occurrence_count', occurrence_count,
          'source', source,
          'metadata', metadata,
          'example_sources', example_sources,
          'last_observed_at', last_observed_at,
          'updated_at', updated_at
        )
        order by occurrence_count desc, updated_at desc
      ) as signals
    from limited
    group by normalized_text
  )
  select jsonb_build_object(
    'metadata', jsonb_build_object(
      'source', 'catalog_agent_training_signal_context_v1',
      'terms_requested', (select count(*) from requested_terms),
      'terms_with_training_signals', (select count(*) from grouped),
      'included_statuses', jsonb_build_array('implemented', 'accepted', 'needs_review')
    ),
    'runtime_instruction', jsonb_build_object(
      'policy', 'Training signals are advisory corpus evidence. They can influence proposal priority, evidence, and questions, but they are not catalog truth and must not bypass validators.',
      'mutation_boundary', 'read_only',
      'status_semantics', jsonb_build_object(
        'implemented', 'durable behavior already changed; follow unless current evidence contradicts it',
        'accepted', 'reviewed guidance; strongly prefer it',
        'needs_review', 'unreviewed corpus pattern; use only as caution/evidence'
      )
    ),
    'term_training_signals',
    coalesce(
      jsonb_object_agg(normalized_text, signals),
      '{}'::jsonb
    )
  )
  from grouped;
$$;

comment on function public.get_catalog_agent_training_signal_context(text[], integer) is
  'Returns advisory Smart Import corpus signals for Catalog Agent context using invoker privileges so RLS remains enforced for authenticated callers.';
