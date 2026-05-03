-- Read-only plan for pending enrichment drafts that are technically valid.
--
-- The goal is to keep the catalog source-of-truth flow measurable before
-- mutating data: a draft can be promoted only after we know it is not better
-- represented as an alias of an existing canonical ingredient.

create or replace view public.catalog_pending_validated_draft_resolution_plan as
with pending_drafts as (
  select
    d.normalized_text,
    d.ingredient_type,
    d.canonical_name_it,
    d.canonical_name_en,
    d.suggested_slug,
    d.default_unit,
    d.supported_units,
    d.is_seasonal,
    d.season_months,
    d.confidence_score,
    d.needs_manual_review,
    d.validated_ready,
    d.validated_errors,
    d.last_validated_at,
    d.updated_at,
    coalesce(o.occurrence_count, 0) as occurrence_count,
    coalesce(o.status, 'none') as observation_status,
    public.catalog_enrichment_validation_errors(
      d.ingredient_type,
      'ready',
      d.canonical_name_it,
      d.canonical_name_en,
      d.suggested_slug,
      d.default_unit,
      d.supported_units,
      d.is_seasonal,
      d.season_months
    ) as ready_validation_errors
  from public.catalog_ingredient_enrichment_drafts d
  left join public.custom_ingredient_observations o
    on o.normalized_text = d.normalized_text
  where d.status = 'pending'
    and coalesce(d.validated_ready, false)
),
prepared as (
  select
    p.*,
    regexp_replace(lower(trim(p.normalized_text)), '[^a-z0-9]+', '', 'g') as compact_normalized_text,
    regexp_replace(lower(trim(replace(coalesce(p.suggested_slug, ''), '_', ' '))), '[^a-z0-9]+', '', 'g') as compact_suggested_slug,
    (
      char_length(trim(coalesce(p.normalized_text, ''))) < 3
      or p.normalized_text ~* '&(?:[a-z]{2,12}|#\d{2,6}|#x[0-9a-f]{2,6});?'
      or p.normalized_text ~* '\b\d+(?:\/\d+|(?:[.,]\d+)?)\s*(?:g|kg|gr|mg|ml|l|cl|pizzico|pizzichi|mazzetto|mazzetti|ciuffo|ciuffi|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|foglia|foglie|cup|tbsp|tsp)\.?\b'
      or p.normalized_text ~* '\b(?:g|kg|gr|mg|ml|l|cl)\s*\d+(?:[.,]\d+)?\b'
      or p.normalized_text ~* '\s\d+(?:[.,]\d+)?$'
    ) as looks_noisy
  from pending_drafts p
),
canonical_keys as (
  select
    c.ingredient_id,
    c.slug as ingredient_slug,
    'slug'::text as key_source,
    c.slug as key_text,
    regexp_replace(lower(trim(replace(c.slug, '_', ' '))), '[^a-z0-9]+', '', 'g') as compact_key
  from public.ingredient_catalog_app_summary c
  where c.quality_status = 'active'

  union all

  select
    c.ingredient_id,
    c.slug as ingredient_slug,
    'it_localization'::text as key_source,
    c.it_name as key_text,
    regexp_replace(lower(trim(c.it_name)), '[^a-z0-9]+', '', 'g') as compact_key
  from public.ingredient_catalog_app_summary c
  where c.quality_status = 'active'
    and nullif(trim(coalesce(c.it_name, '')), '') is not null

  union all

  select
    c.ingredient_id,
    c.slug as ingredient_slug,
    'en_localization'::text as key_source,
    c.en_name as key_text,
    regexp_replace(lower(trim(c.en_name)), '[^a-z0-9]+', '', 'g') as compact_key
  from public.ingredient_catalog_app_summary c
  where c.quality_status = 'active'
    and nullif(trim(coalesce(c.en_name, '')), '') is not null

  union all

  select
    a.ingredient_id,
    a.ingredient_slug,
    'approved_alias'::text as key_source,
    a.alias_text as key_text,
    regexp_replace(lower(trim(coalesce(a.normalized_alias_text, a.alias_text))), '[^a-z0-9]+', '', 'g') as compact_key
  from public.ingredient_alias_app_summary a
  where nullif(trim(coalesce(a.normalized_alias_text, a.alias_text, '')), '') is not null
),
match_rollup as (
  select
    p.normalized_text,
    count(distinct ck.ingredient_id) filter (
      where ck.compact_key = p.compact_normalized_text
        and p.compact_normalized_text <> ''
    )::integer as normalized_match_count,
    ((array_agg(distinct ck.ingredient_id::text order by ck.ingredient_id::text) filter (
      where ck.compact_key = p.compact_normalized_text
        and p.compact_normalized_text <> ''
    ))[1])::uuid as normalized_match_ingredient_id,
    (array_agg(distinct ck.ingredient_slug order by ck.ingredient_slug) filter (
      where ck.compact_key = p.compact_normalized_text
        and p.compact_normalized_text <> ''
    ))[1] as normalized_match_slug,
    count(distinct ck.ingredient_id) filter (
      where ck.compact_key = p.compact_suggested_slug
        and p.compact_suggested_slug <> ''
    )::integer as suggested_slug_match_count,
    ((array_agg(distinct ck.ingredient_id::text order by ck.ingredient_id::text) filter (
      where ck.compact_key = p.compact_suggested_slug
        and p.compact_suggested_slug <> ''
    ))[1])::uuid as suggested_slug_match_ingredient_id,
    (array_agg(distinct ck.ingredient_slug order by ck.ingredient_slug) filter (
      where ck.compact_key = p.compact_suggested_slug
        and p.compact_suggested_slug <> ''
    ))[1] as suggested_slug_match_slug
  from prepared p
  left join canonical_keys ck
    on ck.compact_key in (p.compact_normalized_text, p.compact_suggested_slug)
  group by p.normalized_text
),
classified as (
  select
    p.*,
    coalesce(m.normalized_match_count, 0) as normalized_match_count,
    m.normalized_match_ingredient_id,
    m.normalized_match_slug,
    coalesce(m.suggested_slug_match_count, 0) as suggested_slug_match_count,
    m.suggested_slug_match_ingredient_id,
    m.suggested_slug_match_slug,
    coalesce(array_length(p.ready_validation_errors, 1), 0) as ready_validation_error_count,
    case
      when coalesce(array_length(p.ready_validation_errors, 1), 0) > 0 then 'hold_invalid_ready_payload'
      when p.looks_noisy then 'hold_noisy_text'
      when coalesce(m.normalized_match_count, 0) > 1
        or coalesce(m.suggested_slug_match_count, 0) > 1 then 'manual_review_ambiguous_catalog_match'
      when coalesce(m.normalized_match_count, 0) = 1 then 'already_resolvable_by_catalog'
      when coalesce(m.suggested_slug_match_count, 0) = 1 then 'add_alias_to_existing_catalog'
      when coalesce(p.confidence_score, 0) >= 0.9
        and p.ingredient_type in ('basic', 'produce') then 'promote_to_ready_for_creation'
      when coalesce(p.confidence_score, 0) >= 0.8
        and p.ingredient_type in ('basic', 'produce') then 'manual_review_candidate'
      else 'hold_low_confidence'
    end as suggested_action,
    case
      when coalesce(array_length(p.ready_validation_errors, 1), 0) > 0 then 'Draft would fail ready-time validation.'
      when p.looks_noisy then 'Normalized text appears quantity-contaminated, too short, or entity-noisy.'
      when coalesce(m.normalized_match_count, 0) > 1
        or coalesce(m.suggested_slug_match_count, 0) > 1 then 'More than one canonical ingredient matches; operator review required.'
      when coalesce(m.normalized_match_count, 0) = 1 then 'The normalized text already maps to one catalog key; prefer reconciliation/alias before creating anything.'
      when coalesce(m.suggested_slug_match_count, 0) = 1 then 'The suggested slug points to an existing ingredient; create an alias instead of a duplicate ingredient.'
      when coalesce(p.confidence_score, 0) >= 0.9
        and p.ingredient_type in ('basic', 'produce') then 'High-confidence valid draft with no existing catalog collision.'
      when coalesce(p.confidence_score, 0) >= 0.8
        and p.ingredient_type in ('basic', 'produce') then 'Valid draft, but confidence is below the automatic promotion threshold.'
      else 'Low confidence or unclassified draft; keep out of automatic creation.'
    end as action_reason
  from prepared p
  left join match_rollup m
    on m.normalized_text = p.normalized_text
)
select
  normalized_text,
  occurrence_count,
  observation_status,
  ingredient_type,
  canonical_name_it,
  canonical_name_en,
  suggested_slug,
  confidence_score,
  needs_manual_review,
  validated_ready,
  ready_validation_errors,
  ready_validation_error_count,
  looks_noisy,
  normalized_match_count,
  normalized_match_ingredient_id,
  normalized_match_slug,
  suggested_slug_match_count,
  suggested_slug_match_ingredient_id,
  suggested_slug_match_slug,
  suggested_action,
  action_reason,
  last_validated_at,
  updated_at
from classified;

create or replace view public.catalog_pending_validated_draft_resolution_summary as
select
  suggested_action,
  count(*)::bigint as draft_count,
  count(*) filter (where confidence_score >= 0.9)::bigint as high_confidence_count,
  count(*) filter (where occurrence_count > 1)::bigint as recurring_count,
  min(updated_at) as oldest_updated_at,
  max(updated_at) as newest_updated_at
from public.catalog_pending_validated_draft_resolution_plan
group by suggested_action;

grant select on public.catalog_pending_validated_draft_resolution_plan to authenticated;
grant select on public.catalog_pending_validated_draft_resolution_plan to service_role;
grant select on public.catalog_pending_validated_draft_resolution_summary to authenticated;
grant select on public.catalog_pending_validated_draft_resolution_summary to service_role;
