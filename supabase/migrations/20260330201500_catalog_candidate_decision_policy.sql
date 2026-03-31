-- Conservative, auditable decision policy for catalog candidate triage.
-- This does not approve aliases or run reconciliation; it only recommends actions.

create or replace view public.catalog_resolution_candidate_policy as
with base as (
  select
    c.normalized_text,
    c.occurrence_count,
    c.latest_example,
    c.language_code,
    c.source,
    c.first_seen_at,
    c.last_seen_at,
    c.priority_score,
    c.existing_alias_status,
    c.has_approved_alias,
    c.has_any_alias_match,
    c.suggested_resolution_type,
    c.status as observation_status,
    -- Conservative noise flags: very short strings, URL-ish payloads, numeric-only, or mostly punctuation.
    (
      char_length(trim(c.normalized_text)) < 3
      or c.normalized_text ~* '^(https?://|www\\.)'
      or c.normalized_text ~ '^[0-9\\s\\W_]+$'
      or c.normalized_text ~ '^[^a-zA-Z]{3,}$'
    ) as is_likely_noise,
    (
      not c.has_any_alias_match
      and c.occurrence_count >= 8
      and c.priority_score >= 9
    ) as meets_create_new_threshold
  from public.catalog_resolution_candidate_queue c
)
select
  b.normalized_text,
  b.occurrence_count,
  b.latest_example,
  b.language_code,
  b.source,
  b.first_seen_at,
  b.last_seen_at,
  b.priority_score,
  b.existing_alias_status,
  b.has_approved_alias,
  b.has_any_alias_match,
  b.suggested_resolution_type,
  b.observation_status,
  b.meets_create_new_threshold,
  b.is_likely_noise,
  case
    when b.has_approved_alias then 'alias_existing'
    when b.is_likely_noise then 'ignore'
    when b.has_any_alias_match and b.existing_alias_status in ('suggested', 'deprecated') then 'alias_existing'
    when b.has_any_alias_match and b.existing_alias_status = 'rejected' then 'unknown'
    when b.meets_create_new_threshold and not b.is_likely_noise then 'create_new_ingredient'
    when b.occurrence_count <= 1 and b.priority_score < 3 then 'ignore'
    else 'unknown'
  end::text as recommended_action,
  case
    when b.has_approved_alias then 'approved_alias_match_exists'
    when b.is_likely_noise then 'low_signal_or_noisy_text'
    when b.has_any_alias_match and b.existing_alias_status in ('suggested', 'deprecated') then 'non_approved_alias_exists'
    when b.has_any_alias_match and b.existing_alias_status = 'rejected' then 'rejected_alias_exists_requires_manual_review'
    when b.meets_create_new_threshold and not b.is_likely_noise then 'high_recurrence_without_alias_match'
    when b.occurrence_count <= 1 and b.priority_score < 3 then 'very_low_recurrence_and_priority'
    else 'insufficient_signal'
  end::text as decision_reason,
  case
    when b.has_approved_alias then 0.95
    when b.is_likely_noise then 0.90
    when b.has_any_alias_match and b.existing_alias_status in ('suggested', 'deprecated') then 0.70
    when b.has_any_alias_match and b.existing_alias_status = 'rejected' then 0.60
    when b.meets_create_new_threshold and not b.is_likely_noise then 0.75
    when b.occurrence_count <= 1 and b.priority_score < 3 then 0.80
    else 0.50
  end::numeric(4,2) as decision_confidence
from base b;

create or replace function public.catalog_resolution_candidate_decisions(
  limit_count integer default 100,
  only_status_new boolean default true
)
returns table (
  normalized_text text,
  occurrence_count integer,
  latest_example text,
  language_code text,
  source text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  priority_score numeric,
  existing_alias_status text,
  has_approved_alias boolean,
  has_any_alias_match boolean,
  suggested_resolution_type text,
  observation_status text,
  recommended_action text,
  decision_reason text,
  decision_confidence numeric,
  meets_create_new_threshold boolean,
  is_likely_noise boolean
)
language sql
stable
set search_path = public
as $$
  select
    p.normalized_text,
    p.occurrence_count,
    p.latest_example,
    p.language_code,
    p.source,
    p.first_seen_at,
    p.last_seen_at,
    p.priority_score,
    p.existing_alias_status,
    p.has_approved_alias,
    p.has_any_alias_match,
    p.suggested_resolution_type,
    p.observation_status,
    p.recommended_action,
    p.decision_reason,
    p.decision_confidence,
    p.meets_create_new_threshold,
    p.is_likely_noise
  from public.catalog_resolution_candidate_policy p
  where (not only_status_new) or p.observation_status = 'new'
  order by p.priority_score desc, p.occurrence_count desc, p.last_seen_at desc, p.normalized_text asc
  limit greatest(1, coalesce(limit_count, 100));
$$;

grant select on public.catalog_resolution_candidate_policy to authenticated;
grant execute on function public.catalog_resolution_candidate_decisions(integer, boolean) to authenticated;
grant execute on function public.catalog_resolution_candidate_decisions(integer, boolean) to service_role;
