-- Let Catalog Agent training signals match punctuation/apostrophe variants
-- such as "fiocchi d avena" vs "fiocchi d'avena" without hardcoding terms.

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
    select distinct
      regexp_replace(lower(btrim(term)), '\s+', ' ', 'g') as normalized_text,
      regexp_replace(lower(btrim(term)), '[^[:alnum:]]+', ' ', 'g') as simplified_text
    from unnest(coalesce(p_normalized_texts, array[]::text[])) as term
    where btrim(coalesce(term, '')) <> ''
  ),
  ranked as (
    select
      rt.normalized_text as requested_normalized_text,
      s.*,
      row_number() over (
        partition by rt.normalized_text
        order by
          case s.status
            when 'implemented' then 1
            when 'accepted' then 2
            when 'needs_review' then 3
            else 9
          end,
          case when s.normalized_text = rt.normalized_text then 0 else 1 end,
          s.occurrence_count desc,
          s.updated_at desc
      ) as term_rank
    from requested_terms rt
    join public.catalog_agent_training_signals s
      on s.normalized_text = rt.normalized_text
      or regexp_replace(lower(btrim(s.normalized_text)), '[^[:alnum:]]+', ' ', 'g') = rt.simplified_text
    where s.status in ('needs_review', 'accepted', 'implemented')
  ),
  limited as (
    select *
    from ranked
    where term_rank <= greatest(coalesce(p_limit_per_term, 3), 1)
  ),
  grouped as (
    select
      requested_normalized_text,
      jsonb_agg(
        jsonb_build_object(
          'id', id,
          'normalized_text', normalized_text,
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
    group by requested_normalized_text
  )
  select jsonb_build_object(
    'metadata', jsonb_build_object(
      'source', 'catalog_agent_training_signal_context_v2_broadened_lookup',
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
      jsonb_object_agg(requested_normalized_text, signals),
      '{}'::jsonb
    )
  )
  from grouped;
$$;

comment on function public.get_catalog_agent_training_signal_context(text[], integer) is
  'Returns advisory Smart Import corpus signals for Catalog Agent context with punctuation-tolerant lookup and invoker RLS.';
