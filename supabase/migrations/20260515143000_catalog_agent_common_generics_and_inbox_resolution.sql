begin;

-- Catalog Agent 8.0 step: reduce unnecessary human-review loops for common
-- creator-facing ingredient terms. These are governed matcher hints only: they
-- do not approve aliases, create catalog rows, or mutate recipes.

insert into public.catalog_agent_lexical_candidate_overrides (
  source_term,
  candidate_term,
  expansion_source,
  notes,
  is_active
)
values
  (
    'pollo',
    'petto di pollo',
    'governed_common_generic_to_catalog_base',
    'Creator captions often use bare pollo. Season currently models the generic chicken base as slug chicken / Petto di pollo; use that as the safe target when no cut/state modifier is present.',
    true
  ),
  (
    'tacchino',
    'petto di tacchino',
    'governed_common_generic_to_catalog_base',
    'Creator captions often use bare tacchino. Season currently models the generic turkey base as slug turkey / Petto di tacchino; use that as the safe target when no deli/sliced/ham modifier is present.',
    true
  ),
  (
    'carne macinata',
    'ground meat',
    'governed_generic_base_lookup',
    'Bare carne macinata is a common creator-facing generic base term. Create/use a generic ground_meat canonical when species is not specified; keep beef, pork, mixed, or sausage mince as variants.',
    true
  ),
  (
    'macinato',
    'ground meat',
    'governed_generic_base_lookup',
    'Bare macinato should surface the generic ground_meat base identity when no species is provided.',
    true
  )
on conflict (source_term, candidate_term, expansion_source) do update
set
  notes = excluded.notes,
  is_active = excluded.is_active,
  updated_at = now();

with learning_rows as (
  select *
  from (
    values
      (
        'pollo'::text,
        'alias_policy'::text,
        'implemented'::text,
        'Bare pollo generated human-review work because catalog candidates exposed chicken-breast wording instead of the creator-facing generic term.',
        'Treat bare pollo as an alias/search surface for the Season chicken base when no cut, frozen state, or product modifier is present.',
        'Common creator generics should be easy to publish; specific cuts and states remain variants when explicitly present.',
        'Add context/golden coverage where pollo resolves to chicken while petto/sovracoscia/frozen wording remains specific.'
      ),
      (
        'tacchino'::text,
        'alias_policy'::text,
        'implemented'::text,
        'Bare tacchino generated human-review work because multiple turkey products existed but the recipe used plain turkey meat wording.',
        'Treat bare tacchino as an alias/search surface for the Season turkey base when no sliced, deli, ham, or cured modifier is present.',
        'Generic meat/poultry terms can map to the catalog base convention; explicit product-form modifiers remain child/specific targets.',
        'Add context/golden coverage where tacchino resolves to turkey while fesa affettata/prosciutto di tacchino remain distinct.'
      ),
      (
        'carne macinata'::text,
        'catalog_gap'::text,
        'implemented'::text,
        'Bare carne macinata was escalated even though creators commonly omit species in quick recipes.',
        'When no species is provided, propose a generic ground_meat canonical draft instead of forcing review. Species-specific mince remains a child/specific target.',
        'A missing generic base can be safer than repeatedly guessing beef/pork/mixed meat from weak context.',
        'Add regression coverage where carne macinata creates/uses ground_meat and macinato di manzo remains beef-specific.'
      ),
      (
        'stracchino'::text,
        'catalog_gap'::text,
        'implemented'::text,
        'Stracchino was escalated despite being a clear Italian fresh-cheese identity with no safe existing target in the packet.',
        'Propose create_canonical for stracchino when no exact active target exists; do not collapse it to generic cheese.',
        'Clear named Italian cheese identities are catalog gaps, not vague review items, unless an existing target conflict appears.',
        'Add regression coverage where stracchino is a catalog-gap draft and protected/designation cheeses still obey variant policy.'
      )
  ) as v(normalized_text, learning_type, status, observed_problem, corrected_decision, policy_implication, evaluation_recommendation)
)
insert into public.catalog_agent_learnings (
  normalized_text,
  learning_type,
  severity,
  status,
  observed_problem,
  corrected_decision,
  policy_implication,
  evaluation_recommendation,
  prompt_recommendation,
  created_at,
  updated_at
)
select
  lr.normalized_text,
  lr.learning_type,
  'medium',
  lr.status,
  lr.observed_problem,
  lr.corrected_decision,
  lr.policy_implication,
  lr.evaluation_recommendation,
  'Prefer actionable alias/create-canonical proposals for common concrete creator ingredients when matcher evidence provides a safe base convention or a clear catalog gap.',
  now(),
  now()
from learning_rows lr
where not exists (
  select 1
  from public.catalog_agent_learnings existing
  where existing.normalized_text = lr.normalized_text
    and existing.learning_type = lr.learning_type
    and existing.status in ('accepted', 'implemented')
    and existing.corrected_decision = lr.corrected_decision
);

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
  v_reason_counts jsonb := '{}'::jsonb;
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
    select
      op.id,
      'duplicate_open_proposal'::text as cleanup_reason
    from open_proposals op
    where op.term_open_count > 1
      and op.keep_rank > 1

    union

    select
      p.id,
      'already_resolved_by_active_alias'::text as cleanup_reason
    from public.catalog_agent_proposals p
    where p.status in ('draft', 'queued_for_validation', 'validated', 'needs_human_review', 'failed_validation')
      and exists (
        select 1
        from public.ingredient_alias_app_summary a
        where a.normalized_alias_text = p.normalized_text
          and a.is_active
          and a.status = 'approved'
          and (
            p.target_slug is null
            or a.ingredient_slug = p.target_slug
          )
      )

    union

    select
      p.id,
      'already_resolved_by_active_canonical'::text as cleanup_reason
    from public.catalog_agent_proposals p
    where p.status in ('draft', 'queued_for_validation', 'validated', 'needs_human_review', 'failed_validation')
      and exists (
        select 1
        from public.ingredient_catalog_app_summary i
        where i.quality_status = 'active'
          and (
            lower(coalesce(i.it_name, '')) = p.normalized_text
            or lower(coalesce(i.en_name, '')) = p.normalized_text
            or lower(replace(coalesce(i.slug, ''), '_', ' ')) = p.normalized_text
          )
      )

    union

    select
      p.id,
      'validated_ignore_noise_completed'::text as cleanup_reason
    from public.catalog_agent_proposals p
    where p.status = 'validated'
      and p.proposal_type = 'ignore_noise'
  ),
  limited as (
    select distinct on (id)
      id,
      cleanup_reason
    from to_supersede
    order by id, cleanup_reason
    limit v_limit
  ),
  updated as (
    update public.catalog_agent_proposals p
    set
      status = 'superseded',
      rejection_reason = coalesce(
        p.rejection_reason,
        case l.cleanup_reason
          when 'duplicate_open_proposal' then 'Superseded by Catalog Agent inbox cleanup: a newer or more actionable open proposal exists for the same normalized text.'
          when 'already_resolved_by_active_alias' then 'Superseded by Catalog Agent inbox cleanup: this term is already resolved by an active approved alias.'
          when 'already_resolved_by_active_canonical' then 'Superseded by Catalog Agent inbox cleanup: this term is already represented by an active canonical ingredient.'
          when 'validated_ignore_noise_completed' then 'Superseded by Catalog Agent inbox cleanup: validated ignore-noise proposal is complete and does not require operator action.'
          else 'Superseded by Catalog Agent inbox cleanup.'
        end
      ),
      updated_at = now()
    from limited l
    where p.id = l.id
    returning p.id, l.cleanup_reason
  ),
  reason_counts as (
    select cleanup_reason, count(*)::integer as item_count
    from updated
    group by cleanup_reason
  )
  select
    coalesce(array_agg(id order by id), '{}'::bigint[]),
    coalesce(jsonb_object_agg(cleanup_reason, item_count), '{}'::jsonb)
  into v_superseded_ids, v_reason_counts
  from updated
  left join reason_counts using (cleanup_reason);

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
        'cleanup_limit', v_limit,
        'cleanup_version', 'v2_resolved_and_duplicate_hygiene'
      ),
      v_user
    from unnest(v_superseded_ids) as proposal_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'source', 'cleanup_catalog_agent_review_inbox_v2',
    'reason', v_reason,
    'run_id', p_run_id,
    'superseded_count', cardinality(v_superseded_ids),
    'superseded_ids', to_jsonb(v_superseded_ids),
    'reason_counts', v_reason_counts
  );
end;
$$;

revoke all on function public.cleanup_catalog_agent_review_inbox(bigint, text, integer) from public, anon;
grant execute on function public.cleanup_catalog_agent_review_inbox(bigint, text, integer) to authenticated, service_role;

comment on function public.cleanup_catalog_agent_review_inbox(bigint, text, integer) is
  'Catalog Agent inbox cleanup. Supersedes duplicate open proposals and proposals already resolved by active aliases/canonicals or completed ignore-noise validation, preserving audit history.';

commit;
