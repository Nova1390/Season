#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-gyuedxycbnqljryenapx}"
EXPECTED_LINKED_REF="${EXPECTED_LINKED_REF:-$PROJECT_REF}"
TARGET_SLUG="${TARGET_SLUG:-sale_fino}"
SMOKE_SUFFIX="${SMOKE_SUFFIX:-$(date -u +%Y%m%d%H%M%S)}"
SMOKE_ALIAS="${SMOKE_ALIAS:-season rollback smoke sale fino ${SMOKE_SUFFIX}}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "SUPABASE_ACCESS_TOKEN is required." >&2
  exit 2
fi

for bin in supabase jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required." >&2
    exit 2
  fi
done

linked_ref="$(cat supabase/.temp/project-ref 2>/dev/null || true)"
if [[ "$linked_ref" != "$EXPECTED_LINKED_REF" ]]; then
  echo "Refusing to run: linked project is '${linked_ref:-none}', expected '$EXPECTED_LINKED_REF'." >&2
  exit 2
fi

if [[ "$TARGET_SLUG$SMOKE_SUFFIX$SMOKE_ALIAS" == *"'"* ]]; then
  echo "TARGET_SLUG, SMOKE_SUFFIX, and SMOKE_ALIAS cannot contain single quotes." >&2
  exit 2
fi

apply_sql="
select set_config('request.jwt.claim.role', 'service_role', true);

with smoke_run as (
  insert into public.catalog_agent_runs (
    environment,
    agent_name,
    agent_version,
    model,
    prompt_version,
    mode,
    source_domain,
    input_snapshot_hash,
    input_summary,
    status,
    finished_at,
    summary
  )
  values (
    'dev',
    'catalog-governance-agent',
    'level-5.0-rollback-smoke',
    'manual-smoke',
    'manual-smoke',
    'proposal_only',
    'dev-smoke',
    'level-5.0-rollback-smoke-${SMOKE_SUFFIX}',
    jsonb_build_object('purpose', 'level_5_rollback_smoke', 'target_slug', '${TARGET_SLUG}'),
    'completed',
    now(),
    jsonb_build_object('purpose', 'level_5_rollback_smoke')
  )
  returning id
),
target as (
  select id
  from public.ingredients
  where slug = '${TARGET_SLUG}'
    and quality_status = 'active'
  limit 1
),
proposal as (
  insert into public.catalog_agent_proposals (
    run_id,
    proposal_type,
    normalized_text,
    source_observation_ids,
    target_ingredient_id,
    target_slug,
    proposed_alias_text,
    proposed_language_code,
    confidence_score,
    risk_level,
    auto_apply_eligible,
    rationale,
    evidence,
    blocking_questions,
    raw_agent_output,
    status,
    validation_errors,
    created_at,
    updated_at
  )
  select
    smoke_run.id,
    'approve_alias',
    '${SMOKE_ALIAS}',
    array[]::bigint[],
    target.id,
    '${TARGET_SLUG}',
    '${SMOKE_ALIAS}',
    'it',
    0.99,
    'low',
    true,
    'Level 5.0 rollback smoke: intentionally reversible low-risk alias for ${TARGET_SLUG} on Season-dev.',
    jsonb_build_array(jsonb_build_object('source', 'level_5_rollback_smoke', 'target_slug', '${TARGET_SLUG}')),
    '[]'::jsonb,
    jsonb_build_object('source', 'level_5_rollback_smoke'),
    'validated',
    '[]'::jsonb,
    now(),
    now()
  from smoke_run, target
  returning id, run_id
),
applied as (
  select
    p.id as proposal_id,
    p.run_id,
    public.apply_catalog_agent_low_risk_proposal(
      p.id,
      null,
      'Level 5.0 rollback smoke: apply reversible dev alias.'
    ) as apply_result
  from proposal p
),
rolled as (
  select
    a.proposal_id,
    a.run_id,
    a.apply_result,
    public.rollback_catalog_agent_apply(
      (a.apply_result->>'apply_audit_id')::bigint,
      'Level 5.0 rollback smoke: verify rollback path deletes inserted alias.'
    ) as rollback_result
  from applied a
)
select
  r.run_id,
  r.proposal_id,
  (r.apply_result->>'apply_audit_id')::bigint as apply_audit_id,
  r.apply_result,
  r.rollback_result,
  (
    select count(*)
    from public.ingredient_aliases_v2
    where normalized_alias_text = '${SMOKE_ALIAS}'
  ) as remaining_alias_rows
from rolled r;
"

result="$(
  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase db query --linked "$apply_sql"
)"

echo "$result" | jq .

if [[ "$(echo "$result" | jq -r '.rows[0].apply_result.ok')" != "true" ]]; then
  echo "Rollback smoke apply step failed." >&2
  exit 1
fi

if [[ "$(echo "$result" | jq -r '.rows[0].rollback_result.ok')" != "true" ]]; then
  echo "Rollback smoke revert step failed." >&2
  exit 1
fi

proposal_id="$(echo "$result" | jq -r '.rows[0].proposal_id')"
apply_audit_id="$(echo "$result" | jq -r '.rows[0].apply_audit_id')"

verify_sql="
select
  p.id as proposal_id,
  p.run_id,
  p.status as proposal_status,
  a.id as apply_audit_id,
  a.status as audit_status,
  a.rollback_plan,
  count(alias.id) as remaining_alias_rows,
  exists (
    select 1
    from public.catalog_agent_proposal_events e
    where e.proposal_id = p.id
      and e.event_type = 'auto_apply_succeeded'
  ) as apply_event_present,
  exists (
    select 1
    from public.catalog_agent_proposal_events e
    where e.proposal_id = p.id
      and e.event_type = 'auto_apply_rollback_succeeded'
  ) as rollback_event_present,
  (
    p.status = 'validated'
    and a.status = 'reverted'
    and count(alias.id) = 0
    and exists (
      select 1
      from public.catalog_agent_proposal_events e
      where e.proposal_id = p.id
        and e.event_type = 'auto_apply_succeeded'
    )
    and exists (
      select 1
      from public.catalog_agent_proposal_events e
      where e.proposal_id = p.id
        and e.event_type = 'auto_apply_rollback_succeeded'
    )
  ) as rollback_smoke_ok
from public.catalog_agent_proposals p
join public.catalog_agent_apply_audit a on a.proposal_id = p.id
left join public.ingredient_aliases_v2 alias on alias.normalized_alias_text = p.normalized_text
where p.id = ${proposal_id}
  and a.id = ${apply_audit_id}
group by p.id, a.id;
"

verification="$(
  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase db query --linked "$verify_sql"
)"

echo "$verification" | jq .

if [[ "$(echo "$verification" | jq -r '.rows[0].rollback_smoke_ok')" != "true" ]]; then
  echo "Rollback smoke verification failed for proposal ${proposal_id}, audit ${apply_audit_id}." >&2
  exit 1
fi

retire_sql="
with retired as (
  update public.catalog_agent_proposals
  set
    status = 'superseded',
    updated_at = now()
  where id = ${proposal_id}
    and status = 'validated'
    and normalized_text = '${SMOKE_ALIAS}'
  returning id, run_id
)
insert into public.catalog_agent_proposal_events (
  proposal_id,
  run_id,
  event_type,
  event_payload
)
select
  id,
  run_id,
  'rollback_smoke_retired',
  jsonb_build_object(
    'reason',
    'Retire reversible smoke proposal after rollback verification so real low-risk apply batches do not re-apply test aliases.',
    'previous_status',
    'validated',
    'next_status',
    'superseded'
  )
from retired
returning proposal_id, event_type;
"

retirement="$(
  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase db query --linked "$retire_sql"
)"

echo "$retirement" | jq .

if [[ "$(echo "$retirement" | jq -r '.rows[0].event_type')" != "rollback_smoke_retired" ]]; then
  echo "Rollback smoke passed, but proposal retirement failed for proposal ${proposal_id}." >&2
  exit 1
fi

echo "Rollback smoke passed and retired for proposal ${proposal_id}, audit ${apply_audit_id}."
