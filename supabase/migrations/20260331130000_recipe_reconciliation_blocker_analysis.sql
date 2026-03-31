-- Phase 1 blocker analysis: prioritize unresolved historical ingredient texts.
-- Read-only, SQL-first triage layer built on existing reconciliation artifacts.

create or replace view public.recipe_reconciliation_unresolved_text_analysis as
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

create or replace function public.top_recipe_reconciliation_blockers(
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
    -- prioritize cross-recipe impact first, then absolute unresolved volume.
    a.recipe_count desc,
    a.row_count desc,
    a.normalized_text asc
  limit greatest(1, coalesce(p_limit, 100));
$$;

create or replace view public.recipe_reconciliation_next_action_summary as
select
  a.recommended_next_action,
  count(*)::bigint as text_count,
  sum(a.row_count)::bigint as total_row_count,
  sum(a.recipe_count)::bigint as total_recipe_count
from public.recipe_reconciliation_unresolved_text_analysis a
group by a.recommended_next_action
order by total_recipe_count desc, total_row_count desc, a.recommended_next_action asc;

grant select on public.recipe_reconciliation_unresolved_text_analysis to authenticated;
grant select on public.recipe_reconciliation_next_action_summary to authenticated;
grant execute on function public.top_recipe_reconciliation_blockers(integer) to authenticated;
grant execute on function public.top_recipe_reconciliation_blockers(integer) to service_role;

