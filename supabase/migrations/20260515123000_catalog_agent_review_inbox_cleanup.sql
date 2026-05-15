begin;

-- Keep the Catalog Agent review inbox readable without deleting audit history.
-- The cleanup is intentionally conservative: it only supersedes older open
-- proposals for the same normalized term, preserving the single best open item.

create or replace function public.cleanup_catalog_agent_review_inbox(
  p_run_id bigint default null,
  p_reason text default 'agent_start',
  p_limit integer default 500
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role text := coalesce(current_setting('request.jwt.claim.role', true), auth.role(), '');
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
  v_superseded_ids bigint[] := '{}'::bigint[];
begin
  if v_role is distinct from 'service_role' then
    perform public.assert_catalog_admin(v_user);
  end if;

  if v_reason is null then
    v_reason := 'agent_start';
  end if;

  with open_proposals as (
    select
      p.id,
      p.normalized_text,
      row_number() over (
        partition by p.normalized_text
        order by
          case p.status
            when 'validated' then 0
            when 'queued_for_validation' then 1
            when 'draft' then 2
            when 'failed_validation' then 3
            when 'needs_human_review' then 4
            else 9
          end,
          case p.risk_level
            when 'low' then 0
            when 'medium' then 1
            when 'high' then 2
            when 'critical' then 3
            when 'unknown' then 4
            else 9
          end,
          p.created_at desc,
          p.id desc
      ) as keep_rank,
      count(*) over (partition by p.normalized_text) as term_open_count
    from public.catalog_agent_proposals p
    where p.status in (
      'draft',
      'queued_for_validation',
      'validated',
      'needs_human_review',
      'failed_validation'
    )
  ),
  to_supersede as (
    select op.id
    from open_proposals op
    where op.term_open_count > 1
      and op.keep_rank > 1
    order by op.id
    limit v_limit
  ),
  updated as (
    update public.catalog_agent_proposals p
    set
      status = 'superseded',
      updated_at = now()
    where p.id in (select id from to_supersede)
    returning p.id
  )
  select coalesce(array_agg(id order by id), '{}'::bigint[])
  into v_superseded_ids
  from updated;

  if cardinality(v_superseded_ids) > 0 then
    insert into public.catalog_agent_proposal_events (
      proposal_id,
      run_id,
      event_type,
      event_payload,
      created_by
    )
    select
      proposal_id,
      p_run_id,
      'proposal_superseded_by_inbox_cleanup',
      jsonb_build_object(
        'source', 'cleanup_catalog_agent_review_inbox',
        'reason', v_reason,
        'cleanup_limit', v_limit
      ),
      v_user
    from unnest(v_superseded_ids) as proposal_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'source', 'cleanup_catalog_agent_review_inbox_v1',
    'reason', v_reason,
    'run_id', p_run_id,
    'superseded_count', cardinality(v_superseded_ids),
    'superseded_ids', to_jsonb(v_superseded_ids)
  );
end;
$$;

revoke all on function public.cleanup_catalog_agent_review_inbox(bigint, text, integer) from public, anon;
grant execute on function public.cleanup_catalog_agent_review_inbox(bigint, text, integer) to authenticated, service_role;

comment on function public.cleanup_catalog_agent_review_inbox(bigint, text, integer) is
  'Conservative Catalog Agent inbox cleanup. Supersedes older duplicate open proposals per normalized term, preserving audit history and the best current open proposal.';

commit;
