#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${PROJECT_REF:-gyuedxycbnqljryenapx}"

supabase link --project-ref "$PROJECT_REF" >/dev/null

supabase db query --linked <<'SQL'
select set_config('request.jwt.claim.role', 'service_role', true);

with guard as (
  select public.catalog_agent_dev_schedule_guard('dev') as payload
),
digest as (
  select public.catalog_agent_build_daily_digest(current_date, 'dev') as payload
)
select jsonb_pretty(jsonb_build_object(
  'guard', (select payload from guard),
  'digest', (select payload - 'summary' from digest)
)) as scheduled_autonomy_smoke;
SQL

