#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-gyuedxycbnqljryenapx}"
EXPECTED_LINKED_REF="${EXPECTED_LINKED_REF:-$PROJECT_REF}"
SUPABASE_URL="${SUPABASE_URL:-https://${PROJECT_REF}.supabase.co}"
WORKER_NAME="${WORKER_NAME:-low_risk_apply_batch}"
WORKER_ACTION="${WORKER_ACTION:-dry_run}"
WORKER_LIMIT="${WORKER_LIMIT:-1}"
WORKER_DRY_RUN="${WORKER_DRY_RUN:-true}"
OPERATOR_TOKEN="${CATALOG_AGENT_OPERATOR_TOKEN:-season-dev-agent-ledger-smoke-token}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "SUPABASE_ACCESS_TOKEN is required." >&2
  exit 2
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "SUPABASE_ANON_KEY is required." >&2
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

cleanup() {
  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase secrets set \
    CATALOG_AGENT_ORCHESTRATOR_ENABLED=false \
    CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=false \
    CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN=5 \
    --project-ref "$PROJECT_REF" >/dev/null || true

  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase secrets unset \
    CATALOG_AGENT_OPERATOR_TOKEN \
    --project-ref "$PROJECT_REF" \
    --yes >/dev/null || true
}
trap cleanup EXIT

SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase secrets set \
  CATALOG_AGENT_ORCHESTRATOR_ENABLED=true \
  CATALOG_AGENT_OPERATOR_TOKEN="$OPERATOR_TOKEN" \
  CATALOG_AGENT_MAX_WORKER_ITEMS_PER_RUN="$WORKER_LIMIT" \
  CATALOG_AGENT_INGREDIENT_CREATION_ENABLED=false \
  --project-ref "$PROJECT_REF" >/dev/null

response="$(
  curl -s -X POST "${SUPABASE_URL}/functions/v1/run-catalog-agent-orchestrator" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "content-type: application/json" \
    -H "x-season-catalog-agent-token: ${OPERATOR_TOKEN}" \
    --data "$(jq -n \
      --arg worker_name "$WORKER_NAME" \
      --arg action "$WORKER_ACTION" \
      --argjson limit "$WORKER_LIMIT" \
      --argjson dry_run "$WORKER_DRY_RUN" \
      '{worker_name:$worker_name, action:$action, limit:$limit, dry_run:$dry_run, debug:true}')"
)"

echo "$response" | jq .

if [[ "$(echo "$response" | jq -r '.ok')" != "true" ]]; then
  echo "Orchestrator smoke failed." >&2
  exit 1
fi

run_id="$(echo "$response" | jq -r '.run_id')"
worker_job_id="$(echo "$response" | jq -r '.worker_job_id')"

verify_sql="
select
  r.id as run_id,
  w.id as worker_job_id,
  r.status as run_status,
  w.status as worker_status,
  w.started_at is not null as worker_started,
  w.finished_at is not null as worker_finished,
  coalesce(w.summary, '{}'::jsonb) <> '{}'::jsonb as worker_summary_present,
  ((r.summary->>'worker_job_id')::bigint = w.id) as run_links_worker,
  (w.agent_run_id = r.id) as worker_links_run,
  (
    r.status = 'completed'
    and w.status = 'completed'
    and w.started_at is not null
    and w.finished_at is not null
    and coalesce(w.summary, '{}'::jsonb) <> '{}'::jsonb
    and ((r.summary->>'worker_job_id')::bigint = w.id)
    and w.agent_run_id = r.id
  ) as ledger_ok,
  r.summary as run_summary,
  w.summary as worker_summary
from public.catalog_agent_runs r
join public.catalog_agent_worker_jobs w on w.agent_run_id = r.id
where r.id = ${run_id}
  and w.id = ${worker_job_id};
"

verification="$(
  SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" supabase db query --linked "$verify_sql"
)"

echo "$verification" | jq .

if [[ "$(echo "$verification" | jq -r '.rows[0].ledger_ok')" != "true" ]]; then
  echo "Worker ledger regression failed for run ${run_id}, worker job ${worker_job_id}." >&2
  exit 1
fi

echo "Worker ledger regression passed for run ${run_id}, worker job ${worker_job_id}."
