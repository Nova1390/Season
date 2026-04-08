-- Repair migration: recreate blocker-analysis artifacts when migration history says applied
-- but live objects are missing (remote drift/partial apply).

-- Recreate in dependency order.
drop view if exists public.recipe_reconciliation_next_action_summary;
drop function if exists public.top_recipe_reconciliation_blockers(integer);
drop view if exists public.recipe_reconciliation_unresolved_text_analysis;
drop function if exists public.catalog_resolution_candidate_decisions(integer, boolean);
drop view if exists public.catalog_resolution_candidate_policy;

create view public.catalog_resolution_candidate_policy as
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

create function public.catalog_resolution_candidate_decisions(
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

create view public.recipe_reconciliation_unresolved_text_analysis as
with unresolved_rows as (
  select
    p.recipe_id,
    p.recipe_ingredient_row_id,
    p.normalized_text,
    p.safety_reason,
    p.safe_to_apply,
    p.match_source,
    p.matched_ingredient_id
  from public.recipe_ingredient_reconciliation_safety_preview p
  left join (
    select distinct recipe_ingredient_row_id
    from public.recipe_ingredient_reconciliation_audit
  ) a
    on a.recipe_ingredient_row_id = p.recipe_ingredient_row_id
  where a.recipe_ingredient_row_id is null
    and p.normalized_text is not null
    and p.normalized_text <> ''
),
reason_rank as (
  select
    u.normalized_text,
    u.safety_reason,
    count(*) as reason_count,
    row_number() over (
      partition by u.normalized_text
      order by count(*) desc, u.safety_reason asc
    ) as rn
  from unresolved_rows u
  group by u.normalized_text, u.safety_reason
),
alias_rollup as (
  select
    a.normalized_alias_text as normalized_text,
    bool_or(a.status = 'approved' and coalesce(a.is_active, true)) as has_approved_alias,
    bool_or(coalesce(a.is_active, true)) as has_any_alias_match
  from public.ingredient_aliases_v2 a
  group by a.normalized_alias_text
),
observation_rollup as (
  select
    o.normalized_text,
    o.occurrence_count as candidate_occurrence_count,
    o.status as candidate_status,
    (o.occurrence_count >= 2) as has_candidate_signal
  from public.custom_ingredient_observations o
),
candidate_policy_rollup as (
  select
    c.normalized_text,
    c.recommended_action as policy_recommended_action,
    c.decision_reason as policy_decision_reason,
    c.decision_confidence as policy_decision_confidence
  from public.catalog_resolution_candidate_policy c
),
legacy_mapping_rollup as (
  select
    u.normalized_text,
    bool_or(lm.ingredient_id is not null) as has_legacy_mapping
  from unresolved_rows u
  left join public.legacy_ingredient_mapping lm
    on lm.ingredient_id = u.matched_ingredient_id
  group by u.normalized_text
)
select
  u.normalized_text,
  count(*)::bigint as row_count,
  count(distinct u.recipe_id)::bigint as recipe_count,
  rr.safety_reason as top_safety_reason,
  coalesce(orw.has_candidate_signal, false) as has_candidate_signal,
  orw.candidate_status,
  coalesce(ar.has_approved_alias, false) as has_approved_alias,
  coalesce(ar.has_any_alias_match, false) as has_any_alias_match,
  coalesce(lmr.has_legacy_mapping, false) as has_legacy_mapping,
  cpr.policy_recommended_action,
  cpr.policy_decision_reason,
  cpr.policy_decision_confidence,
  case
    when rr.safety_reason = 'text_is_noise' then 'ignore_noise'
    when rr.safety_reason in ('alias_not_approved', 'alias_inactive') then 'add_alias'
    when rr.safety_reason = 'canonical_localization_exact_match' and not coalesce(lmr.has_legacy_mapping, false) then 'add_legacy_mapping'
    when rr.safety_reason = 'multiple_matches' then 'needs_manual_investigation'
    when rr.safety_reason = 'candidate_rejected_or_ignored' then 'review_candidate'
    when rr.safety_reason = 'no_match' and coalesce(orw.has_candidate_signal, false) then
      case
        when coalesce(cpr.policy_recommended_action, '') = 'create_new_ingredient' then 'create_new_ingredient'
        when coalesce(cpr.policy_recommended_action, '') = 'alias_existing' then 'add_alias'
        when coalesce(cpr.policy_recommended_action, '') = 'ignore' then 'ignore_noise'
        else 'review_candidate'
      end
    when rr.safety_reason = 'no_match' and not coalesce(orw.has_candidate_signal, false) then 'needs_manual_investigation'
    when rr.safety_reason = 'approved_alias_exact_match' and not coalesce(lmr.has_legacy_mapping, false) then 'add_legacy_mapping'
    else 'needs_manual_investigation'
  end::text as recommended_next_action
from unresolved_rows u
left join reason_rank rr
  on rr.normalized_text = u.normalized_text
 and rr.rn = 1
left join alias_rollup ar
  on ar.normalized_text = u.normalized_text
left join observation_rollup orw
  on orw.normalized_text = u.normalized_text
left join candidate_policy_rollup cpr
  on cpr.normalized_text = u.normalized_text
left join legacy_mapping_rollup lmr
  on lmr.normalized_text = u.normalized_text
group by
  u.normalized_text,
  rr.safety_reason,
  orw.has_candidate_signal,
  orw.candidate_status,
  ar.has_approved_alias,
  ar.has_any_alias_match,
  lmr.has_legacy_mapping,
  cpr.policy_recommended_action,
  cpr.policy_decision_reason,
  cpr.policy_decision_confidence;

create function public.top_recipe_reconciliation_blockers(
  p_limit integer default 100
)
returns table (
  normalized_text text,
  row_count bigint,
  recipe_count bigint,
  top_safety_reason text,
  has_candidate_signal boolean,
  candidate_status text,
  has_approved_alias boolean,
  has_any_alias_match boolean,
  has_legacy_mapping boolean,
  recommended_next_action text,
  policy_recommended_action text,
  policy_decision_reason text,
  policy_decision_confidence numeric
)
language sql
stable
set search_path = public
as $$
  select
    a.normalized_text,
    a.row_count,
    a.recipe_count,
    a.top_safety_reason,
    a.has_candidate_signal,
    a.candidate_status,
    a.has_approved_alias,
    a.has_any_alias_match,
    a.has_legacy_mapping,
    a.recommended_next_action,
    a.policy_recommended_action,
    a.policy_decision_reason,
    a.policy_decision_confidence
  from public.recipe_reconciliation_unresolved_text_analysis a
  order by
    a.recipe_count desc,
    a.row_count desc,
    a.normalized_text asc
  limit greatest(1, coalesce(p_limit, 100));
$$;

create view public.recipe_reconciliation_next_action_summary as
select
  a.recommended_next_action,
  count(*)::bigint as text_count,
  sum(a.row_count)::bigint as total_row_count,
  sum(a.recipe_count)::bigint as total_recipe_count
from public.recipe_reconciliation_unresolved_text_analysis a
group by a.recommended_next_action
order by total_recipe_count desc, total_row_count desc, a.recommended_next_action asc;

grant select on public.catalog_resolution_candidate_policy to authenticated;
grant execute on function public.catalog_resolution_candidate_decisions(integer, boolean) to authenticated;
grant execute on function public.catalog_resolution_candidate_decisions(integer, boolean) to service_role;
grant select on public.recipe_reconciliation_unresolved_text_analysis to authenticated;
grant select on public.recipe_reconciliation_next_action_summary to authenticated;
grant execute on function public.top_recipe_reconciliation_blockers(integer) to authenticated;
grant execute on function public.top_recipe_reconciliation_blockers(integer) to service_role;
