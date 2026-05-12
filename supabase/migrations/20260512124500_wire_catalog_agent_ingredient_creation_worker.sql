begin;

alter table public.catalog_agent_worker_jobs
  drop constraint if exists catalog_agent_worker_jobs_worker_name_check;

alter table public.catalog_agent_worker_jobs
  add constraint catalog_agent_worker_jobs_worker_name_check
  check (
    worker_name in (
      'enrichment_draft_batch',
      'ingredient_creation_batch',
      'reconciliation_preview',
      'low_risk_apply_batch'
    )
  );

alter table public.catalog_agent_worker_jobs
  drop constraint if exists catalog_agent_worker_jobs_requested_action_check;

alter table public.catalog_agent_worker_jobs
  add constraint catalog_agent_worker_jobs_requested_action_check
  check (
    requested_action in (
      'run',
      'dry_run',
      'preview',
      'validate',
      'apply_low_risk',
      'create_ingredient'
    )
  );

create or replace function public.create_catalog_agent_worker_job(
  p_agent_run_id bigint,
  p_worker_name text,
  p_requested_action text default 'run',
  p_source_domain text default null,
  p_risk_ceiling text default 'low',
  p_item_limit integer default 10,
  p_budget_limit_usd numeric default null,
  p_dry_run boolean default true,
  p_request_payload jsonb default '{}'::jsonb
)
returns table (
  id bigint,
  agent_run_id bigint,
  worker_name text,
  worker_function text,
  requested_action text,
  status text,
  item_limit integer,
  dry_run boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_worker_name text := lower(btrim(coalesce(p_worker_name, '')));
  v_requested_action text := lower(btrim(coalesce(p_requested_action, 'run')));
  v_risk_ceiling text := lower(btrim(coalesce(p_risk_ceiling, 'low')));
  v_item_limit integer := greatest(1, least(100, coalesce(p_item_limit, 10)));
  v_worker_function text;
begin
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role' then
    perform public.assert_catalog_admin(v_user);
  end if;

  if v_worker_name = 'enrichment_draft_batch' then
    v_worker_function := 'run-catalog-enrichment-draft-batch';
  elsif v_worker_name = 'ingredient_creation_batch' then
    v_worker_function := 'run-catalog-ingredient-creation-batch';
  elsif v_worker_name = 'reconciliation_preview' then
    v_worker_function := 'recipe-reconciliation-preview';
  elsif v_worker_name = 'low_risk_apply_batch' then
    v_worker_function := 'catalog-low-risk-apply-batch';
  else
    raise exception 'unsupported_worker_name: %', p_worker_name
      using errcode = '22023';
  end if;

  if v_requested_action not in ('run', 'dry_run', 'preview', 'validate', 'apply_low_risk', 'create_ingredient') then
    raise exception 'unsupported_requested_action: %', p_requested_action
      using errcode = '22023';
  end if;

  if v_worker_name = 'ingredient_creation_batch' and v_requested_action <> 'create_ingredient' then
    raise exception 'ingredient_creation_worker_requires_create_ingredient_action'
      using errcode = '22023';
  end if;

  if v_risk_ceiling not in ('low', 'medium', 'high', 'critical') then
    raise exception 'unsupported_risk_ceiling: %', p_risk_ceiling
      using errcode = '22023';
  end if;

  return query
  insert into public.catalog_agent_worker_jobs (
    agent_run_id,
    environment,
    worker_name,
    worker_function,
    requested_action,
    source_domain,
    risk_ceiling,
    item_limit,
    budget_limit_usd,
    dry_run,
    request_payload,
    created_by,
    created_at,
    updated_at
  )
  values (
    p_agent_run_id,
    'dev',
    v_worker_name,
    v_worker_function,
    v_requested_action,
    nullif(btrim(coalesce(p_source_domain, '')), ''),
    v_risk_ceiling,
    v_item_limit,
    p_budget_limit_usd,
    coalesce(p_dry_run, true),
    coalesce(p_request_payload, '{}'::jsonb),
    v_user,
    now(),
    now()
  )
  returning
    catalog_agent_worker_jobs.id,
    catalog_agent_worker_jobs.agent_run_id,
    catalog_agent_worker_jobs.worker_name,
    catalog_agent_worker_jobs.worker_function,
    catalog_agent_worker_jobs.requested_action,
    catalog_agent_worker_jobs.status,
    catalog_agent_worker_jobs.item_limit,
    catalog_agent_worker_jobs.dry_run;
end;
$$;

comment on function public.create_catalog_agent_worker_job(bigint, text, text, text, text, integer, numeric, boolean, jsonb) is
  'Creates a bounded Catalog Governance Agent worker job ledger row for approved Autopilot workers, including ingredient creation from ready drafts.';

commit;
