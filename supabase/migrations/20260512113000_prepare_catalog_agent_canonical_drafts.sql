begin;

-- Bridge actionable create_canonical proposals into the enrichment-draft
-- worker lane. This keeps catalog creation governed: the agent can identify a
-- missing canonical ingredient, but Autopilot still enriches the draft and the
-- existing validators/creation RPCs remain the mutation gate.

create or replace function public.prepare_catalog_agent_canonical_enrichment_draft(
  p_proposal_id bigint,
  p_reviewer_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_proposal public.catalog_agent_proposals%rowtype;
  v_existing_draft public.catalog_ingredient_enrichment_drafts%rowtype;
  v_note text := nullif(btrim(coalesce(p_reviewer_note, '')), '');
  v_language_code text;
  v_name_it text := null;
  v_name_en text := null;
  v_draft_status text;
  v_created_or_refreshed boolean := false;
  v_event_payload jsonb;
begin
  perform public.assert_catalog_admin(v_user);

  if p_proposal_id is null then
    raise exception 'proposal_id_required'
      using errcode = '22023';
  end if;

  select *
  into v_proposal
  from public.catalog_agent_proposals p
  where p.id = p_proposal_id
  for update;

  if not found then
    raise exception 'catalog_agent_proposal_not_found: %', p_proposal_id
      using errcode = 'P0002';
  end if;

  if v_proposal.proposal_type <> 'create_canonical' then
    raise exception 'proposal_type_not_create_canonical: %', v_proposal.proposal_type
      using errcode = '22023';
  end if;

  if v_proposal.status in ('applied', 'auto_applied', 'rejected', 'superseded') then
    raise exception 'proposal_status_closed: %', v_proposal.status
      using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(v_proposal.normalized_text, '')), '') is null then
    raise exception 'normalized_text_required'
      using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(v_proposal.proposed_slug, '')), '') is null then
    raise exception 'proposed_slug_required'
      using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(v_proposal.proposed_localized_name, '')), '') is null then
    raise exception 'proposed_localized_name_required'
      using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(v_proposal.proposed_language_code, '')), '') is null then
    raise exception 'proposed_language_code_required'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.ingredients i
    where i.slug = btrim(v_proposal.proposed_slug)
  ) then
    raise exception 'proposed_slug_conflict: %', v_proposal.proposed_slug
      using errcode = '23505';
  end if;

  if not exists (
    select 1
    from public.custom_ingredient_observations o
    where o.normalized_text = v_proposal.normalized_text
  ) then
    raise exception 'custom_observation_not_found: %', v_proposal.normalized_text
      using errcode = 'P0002';
  end if;

  v_language_code := lower(btrim(v_proposal.proposed_language_code));
  if v_language_code = 'it' then
    v_name_it := v_proposal.proposed_localized_name;
  elsif v_language_code = 'en' then
    v_name_en := v_proposal.proposed_localized_name;
  else
    -- The enrichment worker can refine additional languages later; the draft
    -- schema currently stores canonical Italian/English names only.
    v_name_en := v_proposal.proposed_localized_name;
  end if;

  select *
  into v_existing_draft
  from public.catalog_ingredient_enrichment_drafts d
  where d.normalized_text = v_proposal.normalized_text
  for update;

  if found and v_existing_draft.status = 'ready' then
    v_draft_status := v_existing_draft.status;
  else
    select result_row.status
    into v_draft_status
    from public.upsert_catalog_ingredient_enrichment_draft(
      p_normalized_text => v_proposal.normalized_text,
      p_status => 'pending',
      p_ingredient_type => 'unknown',
      p_canonical_name_it => v_name_it,
      p_canonical_name_en => v_name_en,
      p_suggested_slug => v_proposal.proposed_slug,
      p_suggested_aliases => jsonb_build_array(v_proposal.normalized_text),
      p_default_unit => null,
      p_supported_units => null,
      p_is_seasonal => null,
      p_season_months => null,
      p_nutrition_fields => '{}'::jsonb,
      p_confidence_score => v_proposal.confidence_score,
      p_needs_manual_review => true,
      p_reasoning_summary => left(
        concat(
          'catalog_agent_create_canonical proposal #',
          v_proposal.id,
          ': ',
          coalesce(v_proposal.rationale, '')
        ),
        1000
      ),
      p_reviewer_note => coalesce(
        v_note,
        'Prepared from Catalog Governance Agent create_canonical proposal.'
      )
    ) as result_row;
    v_created_or_refreshed := true;
  end if;

  v_event_payload := jsonb_build_object(
    'proposal_type', v_proposal.proposal_type,
    'normalized_text', v_proposal.normalized_text,
    'proposed_slug', v_proposal.proposed_slug,
    'draft_status', coalesce(v_draft_status, v_existing_draft.status),
    'draft_created_or_refreshed', v_created_or_refreshed,
    'reviewer_note', v_note,
    'mutation_scope', 'enrichment_draft_only'
  );

  insert into public.catalog_agent_proposal_events (
    proposal_id,
    run_id,
    event_type,
    event_payload,
    created_by
  )
  values (
    v_proposal.id,
    v_proposal.run_id,
    'canonical_enrichment_draft_prepared',
    v_event_payload,
    v_user
  );

  return jsonb_build_object(
    'ok', true,
    'proposal_id', v_proposal.id,
    'run_id', v_proposal.run_id,
    'normalized_text', v_proposal.normalized_text,
    'proposed_slug', v_proposal.proposed_slug,
    'draft_status', coalesce(v_draft_status, v_existing_draft.status),
    'draft_created_or_refreshed', v_created_or_refreshed,
    'next_worker', 'enrichment_draft_batch'
  );
end;
$$;

revoke all on function public.prepare_catalog_agent_canonical_enrichment_draft(bigint, text) from public, anon;
grant execute on function public.prepare_catalog_agent_canonical_enrichment_draft(bigint, text) to authenticated, service_role;

comment on function public.prepare_catalog_agent_canonical_enrichment_draft(bigint, text) is
  'Admin-only bridge from create_canonical agent proposals to pending enrichment drafts. Does not create catalog ingredients.';

commit;
