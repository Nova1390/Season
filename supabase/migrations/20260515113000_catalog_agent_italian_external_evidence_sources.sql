begin;

-- Add Italian/EU-facing source slots to the external evidence layer.
-- These sources are grounding evidence for the Catalog Governance Agent only:
-- they do not become Season catalog truth and cannot bypass validators/workers.

do $$
declare
  v_constraint_name text;
begin
  for v_constraint_name in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.catalog_agent_external_evidence'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%source_key%'
  loop
    execute format(
      'alter table public.catalog_agent_external_evidence drop constraint %I',
      v_constraint_name
    );
  end loop;
end $$;

alter table public.catalog_agent_external_evidence
  add constraint catalog_agent_external_evidence_source_key_check
  check (
    source_key in (
      'usda_fdc',
      'wikidata',
      'foodon',
      'open_food_facts',
      'manual_open_source_review',
      'crea_alimenti_nutrizione',
      'ieo_bda',
      'masaf_pat',
      'regional_pat'
    )
  );

create or replace function public.upsert_catalog_agent_external_evidence(
  p_normalized_text text,
  p_source_key text,
  p_source_license text,
  p_evidence_type text,
  p_evidence_summary text,
  p_source_record_id text default null,
  p_source_url text default null,
  p_source_license_url text default null,
  p_trust_level text default 'medium',
  p_confidence_score numeric default null,
  p_language_code text default null,
  p_canonical_label text default null,
  p_aliases jsonb default '[]'::jsonb,
  p_metadata jsonb default '{}'::jsonb,
  p_raw_payload jsonb default '{}'::jsonb,
  p_status text default 'needs_review'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_normalized_text text := regexp_replace(lower(btrim(coalesce(p_normalized_text, ''))), '\s+', ' ', 'g');
  v_source_key text := lower(btrim(coalesce(p_source_key, '')));
  v_source_license text := btrim(coalesce(p_source_license, ''));
  v_evidence_type text := lower(btrim(coalesce(p_evidence_type, '')));
  v_evidence_summary text := btrim(coalesce(p_evidence_summary, ''));
  v_source_record_id text := nullif(btrim(coalesce(p_source_record_id, '')), '');
  v_trust_level text := lower(btrim(coalesce(p_trust_level, 'medium')));
  v_status text := lower(btrim(coalesce(p_status, 'needs_review')));
  v_aliases jsonb := coalesce(p_aliases, '[]'::jsonb);
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_raw_payload jsonb := coalesce(p_raw_payload, '{}'::jsonb);
  v_row public.catalog_agent_external_evidence%rowtype;
begin
  perform public.assert_catalog_admin(auth.uid());

  if v_normalized_text = '' then
    raise exception 'normalized_text is required';
  end if;

  if v_source_key not in (
    'usda_fdc',
    'wikidata',
    'foodon',
    'open_food_facts',
    'manual_open_source_review',
    'crea_alimenti_nutrizione',
    'ieo_bda',
    'masaf_pat',
    'regional_pat'
  ) then
    raise exception 'unsupported_source_key: %', v_source_key;
  end if;

  if v_source_license = '' then
    raise exception 'source_license is required';
  end if;

  if v_evidence_type not in (
    'ingredient_identity',
    'variant_identity',
    'synonym_or_label',
    'taxonomy',
    'nutrition',
    'branded_product',
    'packaged_product',
    'not_catalog_identity',
    'ambiguous_identity'
  ) then
    raise exception 'unsupported_evidence_type: %', v_evidence_type;
  end if;

  if v_trust_level not in ('low', 'medium', 'high') then
    raise exception 'unsupported_trust_level: %', v_trust_level;
  end if;

  if v_status not in ('needs_review', 'accepted', 'implemented', 'rejected', 'superseded') then
    raise exception 'unsupported_status: %', v_status;
  end if;

  if v_evidence_summary = '' then
    raise exception 'evidence_summary is required';
  end if;

  if p_confidence_score is not null and (p_confidence_score < 0 or p_confidence_score > 1) then
    raise exception 'confidence_score must be between 0 and 1';
  end if;

  if jsonb_typeof(v_aliases) <> 'array' then
    raise exception 'aliases must be a JSON array';
  end if;

  if jsonb_typeof(v_metadata) <> 'object' then
    raise exception 'metadata must be a JSON object';
  end if;

  if jsonb_typeof(v_raw_payload) <> 'object' then
    raise exception 'raw_payload must be a JSON object';
  end if;

  insert into public.catalog_agent_external_evidence (
    normalized_text,
    source_key,
    source_record_id,
    source_url,
    source_license,
    source_license_url,
    evidence_type,
    trust_level,
    confidence_score,
    language_code,
    canonical_label,
    aliases,
    evidence_summary,
    metadata,
    raw_payload,
    status,
    first_observed_at,
    last_observed_at,
    created_by,
    created_at,
    updated_at
  )
  values (
    v_normalized_text,
    v_source_key,
    v_source_record_id,
    nullif(btrim(coalesce(p_source_url, '')), ''),
    v_source_license,
    nullif(btrim(coalesce(p_source_license_url, '')), ''),
    v_evidence_type,
    v_trust_level,
    p_confidence_score,
    nullif(lower(btrim(coalesce(p_language_code, ''))), ''),
    nullif(btrim(coalesce(p_canonical_label, '')), ''),
    v_aliases,
    v_evidence_summary,
    v_metadata,
    v_raw_payload,
    v_status,
    v_now,
    v_now,
    auth.uid(),
    v_now,
    v_now
  )
  on conflict (normalized_text, source_key, coalesce(source_record_id, ''), evidence_type) do update
  set
    source_url = excluded.source_url,
    source_license = excluded.source_license,
    source_license_url = excluded.source_license_url,
    trust_level = excluded.trust_level,
    confidence_score = excluded.confidence_score,
    language_code = excluded.language_code,
    canonical_label = excluded.canonical_label,
    aliases = excluded.aliases,
    evidence_summary = excluded.evidence_summary,
    metadata = public.catalog_agent_external_evidence.metadata || excluded.metadata,
    raw_payload = excluded.raw_payload,
    status = case
      when public.catalog_agent_external_evidence.status in ('implemented', 'accepted')
        then public.catalog_agent_external_evidence.status
      else excluded.status
    end,
    last_observed_at = v_now,
    updated_at = v_now
  returning * into v_row;

  return jsonb_build_object(
    'id', v_row.id,
    'normalized_text', v_row.normalized_text,
    'source_key', v_row.source_key,
    'evidence_type', v_row.evidence_type,
    'trust_level', v_row.trust_level,
    'confidence_score', v_row.confidence_score,
    'status', v_row.status
  );
end;
$$;

create or replace function public.get_catalog_agent_external_evidence_context(
  p_normalized_texts text[],
  p_limit_per_term integer default 4
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with requested_terms as (
    select distinct regexp_replace(lower(btrim(term)), '\s+', ' ', 'g') as normalized_text
    from unnest(coalesce(p_normalized_texts, array[]::text[])) as term
    where btrim(coalesce(term, '')) <> ''
  ),
  ranked as (
    select
      e.normalized_text,
      e.id,
      e.source_key,
      e.source_record_id,
      e.source_url,
      e.source_license,
      e.source_license_url,
      e.evidence_type,
      e.trust_level,
      e.confidence_score,
      e.language_code,
      e.canonical_label,
      e.aliases,
      e.evidence_summary,
      e.metadata,
      e.status,
      e.updated_at,
      row_number() over (
        partition by e.normalized_text
        order by
          case e.status
            when 'implemented' then 1
            when 'accepted' then 2
            when 'needs_review' then 3
            else 9
          end,
          case e.trust_level
            when 'high' then 1
            when 'medium' then 2
            else 3
          end,
          coalesce(e.confidence_score, 0) desc,
          e.updated_at desc
      ) as rn
    from public.catalog_agent_external_evidence e
    join requested_terms r
      on r.normalized_text = e.normalized_text
    where e.status in ('needs_review', 'accepted', 'implemented')
  ),
  limited as (
    select *
    from ranked
    where rn <= greatest(1, coalesce(p_limit_per_term, 4))
  ),
  term_map as (
    select
      normalized_text,
      jsonb_agg(
        jsonb_build_object(
          'id', id,
          'source_key', source_key,
          'source_record_id', source_record_id,
          'source_url', source_url,
          'source_license', source_license,
          'source_license_url', source_license_url,
          'evidence_type', evidence_type,
          'trust_level', trust_level,
          'confidence_score', confidence_score,
          'language_code', language_code,
          'canonical_label', canonical_label,
          'aliases', aliases,
          'evidence_summary', evidence_summary,
          'metadata', metadata,
          'status', status,
          'updated_at', updated_at
        )
        order by rn
      ) as evidence
    from limited
    group by normalized_text
  )
  select jsonb_build_object(
    'metadata', jsonb_build_object(
      'source', 'catalog_agent_external_evidence_context_v1',
      'terms_requested', (select count(*) from requested_terms),
      'terms_with_external_evidence', (select count(*) from term_map),
      'included_statuses', jsonb_build_array('implemented', 'accepted', 'needs_review')
    ),
    'runtime_instruction', jsonb_build_object(
      'policy', 'External catalog evidence is grounding evidence only. It can support identity, variant, taxonomy, synonym, or nutrition reasoning, but it is not Season catalog truth and must not bypass catalog_matcher, learning memory, deterministic validators, or apply gates.',
      'source_semantics', jsonb_build_object(
        'usda_fdc', 'high-trust nutrition and generic food identity evidence; strongest for nutrients, weaker for Italian culinary localization',
        'wikidata', 'CC0 multilingual/taxonomy evidence; useful for labels and identity hints, not sufficient alone for nutrition or apply',
        'foodon', 'ontology/taxonomy evidence; useful for family/classification, not sufficient alone for recipe-specific identity',
        'open_food_facts', 'ODbL branded/packaged product evidence; useful for packaged products, requires license-aware attribution and should be used cautiously',
        'manual_open_source_review', 'operator-reviewed external evidence summary',
        'crea_alimenti_nutrizione', 'Italian food-composition and nutrition evidence; strong for Italian generic foods and culinary labels, but still grounding-only',
        'ieo_bda', 'Italian food-composition reference evidence; use as compact reviewed summaries only until license/redistribution obligations are confirmed',
        'masaf_pat', 'Italian traditional agri-food product evidence; useful for regional identity and protected/traditional product boundaries, not nutrition alone',
        'regional_pat', 'Regional Italian traditional-product evidence; useful for local names and product identity, weaker unless tied to an official regional source URL'
      ),
      'status_semantics', jsonb_build_object(
        'implemented', 'external evidence already reflected in governed behavior; follow unless current evidence contradicts it',
        'accepted', 'reviewed grounding evidence; strongly prefer it as supporting evidence',
        'needs_review', 'unreviewed external evidence; use only as weak support or to ask better questions'
      )
    ),
    'term_external_evidence', coalesce(
      (select jsonb_object_agg(normalized_text, evidence) from term_map),
      '{}'::jsonb
    )
  );
$$;

comment on constraint catalog_agent_external_evidence_source_key_check
  on public.catalog_agent_external_evidence is
  'Supported external evidence sources. Italian sources are grounding-only and must not bypass Season validators.';

comment on function public.upsert_catalog_agent_external_evidence(text, text, text, text, text, text, text, text, text, numeric, text, text, jsonb, jsonb, jsonb, text) is
  'Catalog-admin/service-role helper to upsert license-aware external evidence, including Italian source summaries. Does not mutate Season catalog identity.';

comment on function public.get_catalog_agent_external_evidence_context(text[], integer) is
  'Returns compact global and Italian external evidence context for Catalog Governance Agent work items.';

commit;
