-- Final reconciliation cleanup pass.
-- Scope:
-- - keep already-resolved rows out of blocker/unresolved work queues
-- - match only obvious trailing quantity-contaminated ingredient text
-- - do not change parser, aliases, canonical ingredients, or apply behavior.

create or replace view public.recipe_ingredient_reconciliation_safety_preview as
with recipe_ingredient_rows as (
  select
    r.id::text as recipe_id,
    i.ingredient as ingredient_json,
    i.ordinality::integer as ingredient_index
  from public.recipes r
  cross join lateral jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as i(ingredient, ordinality)
),
normalized_rows_base as (
  select
    rir.recipe_id,
    rir.ingredient_index,
    rir.ingredient_json,
    nullif(trim(coalesce(rir.ingredient_json ->> 'produce_id', '')), '') as produce_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'basic_ingredient_id', '')), '') as basic_ingredient_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'ingredient_id', '')), '') as ingredient_id,
    nullif(trim(coalesce(rir.ingredient_json ->> 'name', '')), '') as current_text,
    lower(trim(coalesce(rir.ingredient_json ->> 'name', ''))) as normalized_text
  from recipe_ingredient_rows rir
),
normalized_rows as (
  select
    nrb.*,
    case
      when nullif(
        trim(
          regexp_replace(
            regexp_replace(
              nrb.normalized_text,
              '\s+[0-9]+([,.][0-9]+)?\s*(g|gr|grammi|kg|ml|l|lt)\.?\s*$',
              '',
              'i'
            ),
            '\s+[0-9]+\s*$',
            '',
            'i'
          )
        ),
        ''
      ) is null then nrb.normalized_text
      else trim(
        regexp_replace(
          regexp_replace(
            nrb.normalized_text,
            '\s+[0-9]+([,.][0-9]+)?\s*(g|gr|grammi|kg|ml|l|lt)\.?\s*$',
            '',
            'i'
          ),
          '\s+[0-9]+\s*$',
          '',
          'i'
        )
      )
    end as reconciliation_match_text
  from normalized_rows_base nrb
),
observation_status as (
  select
    o.normalized_text,
    o.status as candidate_status
  from public.custom_ingredient_observations o
),
alias_exact_stats as (
  select
    n.recipe_id,
    n.ingredient_index,
    count(*) filter (where a.status = 'approved' and coalesce(a.is_active, true)) as approved_active_alias_count,
    count(*) filter (where a.status = 'approved' and not coalesce(a.is_active, true)) as approved_inactive_alias_count,
    count(*) filter (where a.status <> 'approved') as non_approved_alias_count
  from normalized_rows n
  left join public.ingredient_aliases_v2 a
    on a.normalized_alias_text = n.reconciliation_match_text
  group by n.recipe_id, n.ingredient_index
),
allowed_match_candidates as (
  select
    n.recipe_id,
    n.ingredient_index,
    a.ingredient_id,
    'approved_alias'::text as match_source
  from normalized_rows n
  join public.ingredient_aliases_v2 a
    on a.normalized_alias_text = n.reconciliation_match_text
   and a.status = 'approved'
   and coalesce(a.is_active, true)

  union all

  select
    n.recipe_id,
    n.ingredient_index,
    l.ingredient_id,
    'canonical_localization'::text as match_source
  from normalized_rows n
  join public.ingredient_localizations l
    on lower(trim(l.display_name)) = n.reconciliation_match_text
),
allowed_match_summary as (
  select
    amc.recipe_id,
    amc.ingredient_index,
    count(distinct amc.ingredient_id) as canonical_target_count,
    (array_agg(amc.ingredient_id order by amc.ingredient_id::text))[1] as matched_ingredient_id,
    bool_or(amc.match_source = 'approved_alias') as has_alias_match,
    bool_or(amc.match_source = 'canonical_localization') as has_localization_match
  from allowed_match_candidates amc
  group by amc.recipe_id, amc.ingredient_index
)
select
  n.recipe_id,
  (n.recipe_id || '#' || n.ingredient_index::text) as recipe_ingredient_row_id,
  n.ingredient_index,
  n.current_text,
  n.normalized_text,
  ams.matched_ingredient_id,
  case
    when coalesce(ams.canonical_target_count, 0) > 1 then 'multiple'
    when coalesce(ams.canonical_target_count, 0) = 1 and coalesce(ams.has_alias_match, false) then 'approved_alias'
    when coalesce(ams.canonical_target_count, 0) = 1 and coalesce(ams.has_localization_match, false) then 'canonical_localization'
    else 'none'
  end as match_source,
  (
    n.produce_id is null
    and n.basic_ingredient_id is null
    and n.ingredient_id is null
    and coalesce(ams.canonical_target_count, 0) = 1
    and (
      coalesce(ams.has_alias_match, false)
      or coalesce(ams.has_localization_match, false)
    )
    and not (
      char_length(trim(coalesce(n.reconciliation_match_text, ''))) < 3
      or n.reconciliation_match_text ~* '^(https?://|www\\.)'
      or n.reconciliation_match_text ~ '^[0-9\\s\\W_]+$'
      or n.reconciliation_match_text ~ '^[^a-zA-Z]{3,}$'
    )
    and coalesce(obs.candidate_status, '') not in ('rejected', 'ignored', 'conflict', 'deprecated')
  ) as safe_to_apply,
  case
    when n.produce_id is not null or n.basic_ingredient_id is not null or n.ingredient_id is not null then 'already_resolved'
    when n.normalized_text is null or n.normalized_text = '' then 'no_match'
    when (
      char_length(trim(coalesce(n.reconciliation_match_text, ''))) < 3
      or n.reconciliation_match_text ~* '^(https?://|www\\.)'
      or n.reconciliation_match_text ~ '^[0-9\\s\\W_]+$'
      or n.reconciliation_match_text ~ '^[^a-zA-Z]{3,}$'
    ) then 'text_is_noise'
    when coalesce(obs.candidate_status, '') in ('rejected', 'ignored', 'conflict', 'deprecated') then 'candidate_rejected_or_ignored'
    when coalesce(ams.canonical_target_count, 0) > 1 then 'multiple_matches'
    when coalesce(ams.canonical_target_count, 0) = 1 and coalesce(ams.has_alias_match, false) then 'approved_alias_exact_match'
    when coalesce(ams.canonical_target_count, 0) = 1 and coalesce(ams.has_localization_match, false) then 'canonical_localization_exact_match'
    when coalesce(aes.approved_active_alias_count, 0) = 0 and coalesce(aes.non_approved_alias_count, 0) > 0 then 'alias_not_approved'
    when coalesce(aes.approved_active_alias_count, 0) = 0 and coalesce(aes.approved_inactive_alias_count, 0) > 0 then 'alias_inactive'
    else 'no_match'
  end as safety_reason,
  coalesce(obs.candidate_status, 'none') as candidate_status,
  coalesce(ams.canonical_target_count, 0) as canonical_target_count,
  n.produce_id,
  n.basic_ingredient_id,
  n.ingredient_id,
  n.reconciliation_match_text
from normalized_rows n
left join allowed_match_summary ams
  on ams.recipe_id = n.recipe_id
 and ams.ingredient_index = n.ingredient_index
left join alias_exact_stats aes
  on aes.recipe_id = n.recipe_id
 and aes.ingredient_index = n.ingredient_index
left join observation_status obs
  on obs.normalized_text = n.reconciliation_match_text;

create or replace view public.recipe_reconciliation_impact_summary as
with preview as (
  select
    p.recipe_ingredient_row_id,
    p.safe_to_apply,
    p.safety_reason,
    p.normalized_text,
    p.match_source,
    p.matched_ingredient_id
  from public.recipe_ingredient_reconciliation_safety_preview p
),
actionable_preview as (
  select *
  from preview
  where safety_reason <> 'already_resolved'
),
applied_unique as (
  select distinct a.recipe_ingredient_row_id
  from public.recipe_ingredient_reconciliation_audit a
),
safe_rows as (
  select p.recipe_ingredient_row_id, p.matched_ingredient_id
  from actionable_preview p
  where p.safe_to_apply
),
safe_missing_legacy_mapping as (
  select s.recipe_ingredient_row_id
  from safe_rows s
  left join public.legacy_ingredient_mapping lm
    on lm.ingredient_id = s.matched_ingredient_id
  where lm.ingredient_id is null
)
select
  count(*)::bigint as inspected_rows,
  count(*) filter (where p.safe_to_apply)::bigint as safe_to_apply_rows,
  count(*) filter (where au.recipe_ingredient_row_id is not null)::bigint as applied_rows,
  count(*) filter (where p.safe_to_apply and au.recipe_ingredient_row_id is not null)::bigint as safe_and_applied_rows,
  count(*) filter (where p.safe_to_apply and au.recipe_ingredient_row_id is null)::bigint as safe_not_applied_rows,
  count(*) filter (where not p.safe_to_apply)::bigint as blocked_rows,
  coalesce(
    round(
      (count(*) filter (where p.safe_to_apply)::numeric / nullif(count(*)::numeric, 0)) * 100.0,
      2
    ),
    0
  ) as safe_coverage_rate_pct,
  coalesce(
    round(
      (count(*) filter (where au.recipe_ingredient_row_id is not null)::numeric / nullif(count(*)::numeric, 0)) * 100.0,
      2
    ),
    0
  ) as applied_coverage_rate_pct,
  coalesce(
    round(
      (
        count(*) filter (where p.safe_to_apply and au.recipe_ingredient_row_id is not null)::numeric
        / nullif(count(*) filter (where p.safe_to_apply)::numeric, 0)
      ) * 100.0,
      2
    ),
    0
  ) as applied_of_safe_rate_pct,
  (select count(*)::bigint from safe_missing_legacy_mapping) as safe_rows_missing_legacy_mapping
from actionable_preview p
left join applied_unique au
  on au.recipe_ingredient_row_id = p.recipe_ingredient_row_id;

create or replace view public.recipe_reconciliation_blockers as
with preview as (
  select
    p.recipe_ingredient_row_id,
    p.safe_to_apply,
    p.safety_reason,
    p.matched_ingredient_id
  from public.recipe_ingredient_reconciliation_safety_preview p
  where p.safety_reason <> 'already_resolved'
),
safe_missing_legacy_mapping as (
  select p.recipe_ingredient_row_id
  from preview p
  left join public.legacy_ingredient_mapping lm
    on lm.ingredient_id = p.matched_ingredient_id
  where p.safe_to_apply
    and lm.ingredient_id is null
)
select
  p.safety_reason as blocker_category,
  count(*)::bigint as blocked_row_count
from preview p
where not p.safe_to_apply
group by p.safety_reason

union all

select
  'missing_legacy_mapping'::text as blocker_category,
  count(*)::bigint as blocked_row_count
from safe_missing_legacy_mapping;

create or replace view public.recipe_reconciliation_unresolved_text_analysis as
with unresolved_rows as (
  select
    p.recipe_id,
    p.recipe_ingredient_row_id,
    p.normalized_text,
    p.reconciliation_match_text,
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
    and p.safety_reason <> 'already_resolved'
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
  on ar.normalized_text = u.reconciliation_match_text
left join observation_rollup orw
  on orw.normalized_text = u.reconciliation_match_text
left join candidate_policy_rollup cpr
  on cpr.normalized_text = u.reconciliation_match_text
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
