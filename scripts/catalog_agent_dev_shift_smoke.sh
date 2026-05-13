#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-gyuedxycbnqljryenapx}"
EXPECTED_LINKED_REF="${EXPECTED_LINKED_REF:-$PROJECT_REF}"
SHIFT_LIMIT="${SHIFT_LIMIT:-1}"
SMOKE_TOKEN="${CATALOG_AGENT_OPERATOR_TOKEN_VALUE:-codex-dev-shift-dryrun-$(date -u +%Y%m%d%H%M%S)-$$}"
FUNCTION_URL="https://${PROJECT_REF}.supabase.co/functions/v1/run-catalog-agent-dev-shift"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "SUPABASE_ACCESS_TOKEN is required." >&2
  exit 2
fi

for bin in supabase curl jq; do
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

if [[ ! "$SHIFT_LIMIT" =~ ^[0-9]+$ ]] || (( SHIFT_LIMIT < 1 || SHIFT_LIMIT > 3 )); then
  echo "SHIFT_LIMIT must be an integer between 1 and 3." >&2
  exit 2
fi

cleanup() {
  set +e
  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase db query --linked "
update public.catalog_agent_dev_schedule_config
set
  enabled = false,
  triage_enabled = false,
  low_risk_dry_run_enabled = true,
  low_risk_apply_enabled = false,
  max_agent_runs_per_day = 3,
  max_worker_jobs_per_day = 5,
  max_real_applies_per_day = 1,
  max_llm_tokens_per_day = 80000,
  max_estimated_cost_usd_per_day = 1.000000,
  notes = 'Disabled after catalog_agent_dev_shift_smoke cleanup.',
  updated_at = now()
where environment = 'dev';
" >/dev/null
  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase secrets set \
    CATALOG_AGENT_ORCHESTRATOR_ENABLED=false \
    --project-ref "$PROJECT_REF" >/dev/null
  printf 'Y\n' | SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase secrets unset \
    CATALOG_AGENT_OPERATOR_TOKEN \
    --project-ref "$PROJECT_REF" >/dev/null
}

trap cleanup EXIT

SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase db query --linked "
update public.catalog_agent_dev_schedule_config
set
  enabled = true,
  triage_enabled = false,
  low_risk_dry_run_enabled = true,
  low_risk_apply_enabled = false,
  max_agent_runs_per_day = 24,
  max_worker_jobs_per_day = 100,
  max_real_applies_per_day = 20,
  max_llm_tokens_per_day = 200000,
  max_estimated_cost_usd_per_day = 1.000000,
  notes = 'Temporary catalog_agent_dev_shift_smoke. No LLM triage and no real apply.',
  updated_at = now()
where environment = 'dev';
select environment, enabled, triage_enabled, low_risk_dry_run_enabled, low_risk_apply_enabled
from public.catalog_agent_dev_schedule_config
where environment = 'dev';
" | jq .

SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase secrets set \
  CATALOG_AGENT_OPERATOR_TOKEN="$SMOKE_TOKEN" \
  CATALOG_AGENT_ORCHESTRATOR_ENABLED=true \
  --project-ref "$PROJECT_REF" >/dev/null

response="$(
  curl -s \
    -X POST "$FUNCTION_URL" \
    -H "content-type: application/json" \
    -H "x-season-catalog-agent-token: ${SMOKE_TOKEN}" \
    --data "{\"limit\":${SHIFT_LIMIT},\"dry_run\":true,\"run_low_risk_preview\":true,\"run_triage\":false,\"debug\":false}"
)"

echo "$response" | jq .

if [[ "$(echo "$response" | jq -r '.ok')" != "true" ]]; then
  echo "Dev shift smoke failed: response ok was not true." >&2
  exit 1
fi

if [[ "$(echo "$response" | jq -r '.skipped')" != "false" ]]; then
  echo "Dev shift smoke failed: shift was skipped." >&2
  exit 1
fi

if [[ "$(echo "$response" | jq -r '.guard.ok')" != "true" ]]; then
  echo "Dev shift smoke failed: guard did not allow the controlled dry shift." >&2
  exit 1
fi

if [[ "$(echo "$response" | jq -r '.guard.allowed.low_risk_dry_run')" != "true" ]]; then
  echo "Dev shift smoke failed: low-risk dry-run was not allowed." >&2
  exit 1
fi

if [[ "$(echo "$response" | jq -r '.guard.allowed.triage')" != "false" ]]; then
  echo "Dev shift smoke failed: triage unexpectedly allowed." >&2
  exit 1
fi

if [[ "$(echo "$response" | jq -r '.guard.allowed.low_risk_apply')" != "false" ]]; then
  echo "Dev shift smoke failed: real low-risk apply unexpectedly allowed." >&2
  exit 1
fi

if [[ "$(echo "$response" | jq -r '.worker_results | length')" != "1" ]]; then
  echo "Dev shift smoke failed: expected exactly one worker result." >&2
  exit 1
fi

if [[ "$(echo "$response" | jq -r '.worker_results[0].worker_result.dry_run')" != "true" ]]; then
  echo "Dev shift smoke failed: worker did not run in dry-run mode." >&2
  exit 1
fi

if [[ "$(echo "$response" | jq -r '.worker_results[0].worker_result.summary.applied')" != "0" ]]; then
  echo "Dev shift smoke failed: dry-run worker reported applied mutations." >&2
  exit 1
fi

post_cleanup_check() {
  cleanup
  trap - EXIT

  unauthorized="$(
    curl -s \
      -X POST "$FUNCTION_URL" \
      -H "content-type: application/json" \
      -H "x-season-catalog-agent-token: ${SMOKE_TOKEN}" \
      --data "{\"limit\":${SHIFT_LIMIT},\"dry_run\":true,\"run_low_risk_preview\":true}"
  )"
  echo "$unauthorized" | jq .

  if [[ "$(echo "$unauthorized" | jq -r '.error.code')" != "UNAUTHORIZED" ]]; then
    echo "Dev shift smoke cleanup failed: temporary token still worked." >&2
    exit 1
  fi

  guard_result="$(
    SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase db query --linked <<'SQL'
select set_config('request.jwt.claim.role', 'service_role', true);
select public.catalog_agent_dev_schedule_guard('dev') as guard;
SQL
  )"
  echo "$guard_result" | jq .

  if [[ "$(echo "$guard_result" | jq -r '.rows[0].guard.reason')" != "schedule_disabled" ]]; then
    echo "Dev shift smoke cleanup failed: guard is not schedule_disabled." >&2
    exit 1
  fi
}

post_cleanup_check

run_id="$(echo "$response" | jq -r '.worker_results[0].run_id')"
worker_job_id="$(echo "$response" | jq -r '.worker_results[0].worker_job_id')"
echo "Dev shift dry-run smoke passed. run_id=${run_id}, worker_job_id=${worker_job_id}."
