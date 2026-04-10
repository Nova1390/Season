-- Backend-native batch triage workflow for unresolved catalog candidates.
-- Safe outcomes only:
--   - approve_alias
--   - ignore
--   - prepare_enrichment_draft
-- This is admin-guarded, item-by-item, and auditable via existing decision artifacts.

create or replace function public.execute_catalog_candidate_batch_triage(
  p_items jsonb,
  p_default_language_code text default null,
  p_reviewer_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_now timestamptz := now();
  v_items jsonb := coalesce(p_items, '[]'::jsonb);
  v_default_language_code text := nullif(lower(trim(coalesce(p_default_language_code, ''))), '');
  v_default_note text := nullif(trim(coalesce(p_reviewer_note, '')), '');

  v_total integer := 0;
  v_succeeded integer := 0;
  v_failed integer := 0;
  v_skipped integer := 0;
  v_results jsonb := '[]'::jsonb;

  v_item jsonb;
  v_normalized text;
  v_action_raw text;
  v_action text;
  v_language_code text;
  v_reviewer_note text;
  v_alias_text text;
  v_ingredient_id uuid;
  v_confidence_score double precision;

  v_result_status text;
  v_detail text;
  v_draft_status text;
  v_draft_validated_ready boolean;
  v_existing_observation_status text;
  v_alias_already_approved boolean;
begin
  perform public.assert_catalog_admin(v_user);

  if jsonb_typeof(v_items) <> 'array' then
    raise exception 'p_items must be a JSON array';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(v_items)
  loop
    v_total := v_total + 1;
    v_normalized := '';
    v_action_raw := '';
    v_action := '';
    v_language_code := null;
    v_reviewer_note := null;
    v_alias_text := null;
    v_ingredient_id := null;
    v_confidence_score := null;
    v_result_status := 'failed';
    v_detail := null;
    v_draft_status := null;
    v_draft_validated_ready := null;
    v_existing_observation_status := null;
    v_alias_already_approved := false;

    begin
      v_normalized := lower(trim(coalesce(v_item ->> 'normalized_text', '')));
      v_action_raw := lower(trim(coalesce(v_item ->> 'action', '')));

      if v_normalized = '' then
        raise exception 'normalized_text is required';
      end if;

      v_action := case
        when v_action_raw in ('approve_alias', 'approve-alias', 'alias', 'approvealias') then 'approve_alias'
        when v_action_raw in ('ignore', 'ignored') then 'ignore'
        when v_action_raw in ('prepare_enrichment_draft', 'prepare-draft', 'prepare_draft', 'enrichment_draft') then 'prepare_enrichment_draft'
        else v_action_raw
      end;

      if v_action not in ('approve_alias', 'ignore', 'prepare_enrichment_draft') then
        raise exception 'unsupported action: %', v_action_raw;
      end if;

      v_language_code := coalesce(
        nullif(lower(trim(coalesce(v_item ->> 'language_code', ''))), ''),
        v_default_language_code
      );
      v_reviewer_note := coalesce(
        nullif(trim(coalesce(v_item ->> 'reviewer_note', '')), ''),
        v_default_note
      );
      v_alias_text := nullif(trim(coalesce(v_item ->> 'alias_text', '')), '');

      if coalesce(v_item ->> 'ingredient_id', '') <> '' then
        v_ingredient_id := (v_item ->> 'ingredient_id')::uuid;
      end if;

      if coalesce(v_item ->> 'confidence_score', '') <> '' then
        v_confidence_score := (v_item ->> 'confidence_score')::double precision;
      end if;

      select o.status
      into v_existing_observation_status
      from public.custom_ingredient_observations o
      where o.normalized_text = v_normalized
      limit 1;

      if v_existing_observation_status is null then
        raise exception 'candidate not found for normalized_text: %', v_normalized;
      end if;

      if v_action = 'approve_alias' then
        if v_ingredient_id is null then
          raise exception 'approve_alias requires ingredient_id';
        end if;

        select exists (
          select 1
          from public.ingredient_aliases_v2 a
          where a.normalized_alias_text = v_normalized
            and a.ingredient_id = v_ingredient_id
            and coalesce(a.is_active, true)
            and coalesce(a.status, 'approved') = 'approved'
        )
        into v_alias_already_approved;

        if v_alias_already_approved then
          v_result_status := 'skipped';
          v_detail := 'alias_already_approved';
          v_skipped := v_skipped + 1;
        else
          perform
            a.normalized_text
          from public.approve_reconciliation_alias(
            p_normalized_text => v_normalized,
            p_ingredient_id => v_ingredient_id,
            p_alias_text => v_alias_text,
            p_language_code => v_language_code,
            p_reviewer_note => v_reviewer_note,
            p_confidence_score => v_confidence_score
          ) a;

          v_result_status := 'succeeded';
          v_detail := 'alias_approved';
          v_succeeded := v_succeeded + 1;
        end if;
      elsif v_action = 'ignore' then
        if coalesce(v_existing_observation_status, '') = 'ignored' then
          v_result_status := 'skipped';
          v_detail := 'already_ignored';
          v_skipped := v_skipped + 1;
        else
          perform
            d.decision_id
          from public.apply_catalog_candidate_decision(
            p_normalized_text => v_normalized,
            p_action => 'ignore',
            p_ingredient_id => null,
            p_alias_text => null,
            p_language_code => v_language_code,
            p_confidence_score => v_confidence_score,
            p_reviewer_note => v_reviewer_note
          ) d;

          v_result_status := 'succeeded';
          v_detail := 'candidate_ignored';
          v_succeeded := v_succeeded + 1;
        end if;
      else
        select
          d.status,
          d.validated_ready
        into
          v_draft_status,
          v_draft_validated_ready
        from public.catalog_ingredient_enrichment_drafts d
        where d.normalized_text = v_normalized
        limit 1;

        if v_draft_status is not null then
          v_result_status := 'skipped';
          v_detail := 'draft_already_exists';
          v_skipped := v_skipped + 1;
        else
          select
            d.status,
            d.validated_ready
          into
            v_draft_status,
            v_draft_validated_ready
          from public.upsert_catalog_ingredient_enrichment_draft(
            p_normalized_text => v_normalized,
            p_status => 'pending',
            p_ingredient_type => 'unknown',
            p_canonical_name_it => initcap(replace(v_normalized, '_', ' ')),
            p_canonical_name_en => null,
            p_suggested_slug => replace(v_normalized, ' ', '_'),
            p_suggested_aliases => '[]'::jsonb,
            p_default_unit => 'piece',
            p_supported_units => array['piece']::text[],
            p_is_seasonal => null,
            p_season_months => '{}'::int[],
            p_nutrition_fields => '{}'::jsonb,
            p_confidence_score => v_confidence_score,
            p_needs_manual_review => true,
            p_reasoning_summary => coalesce(v_reviewer_note, 'Prepared from batch triage'),
            p_reviewer_note => v_reviewer_note
          ) d
          limit 1;

          perform
            c.decision_id
          from public.apply_catalog_candidate_decision(
            p_normalized_text => v_normalized,
            p_action => 'create_new_ingredient',
            p_ingredient_id => null,
            p_alias_text => null,
            p_language_code => v_language_code,
            p_confidence_score => v_confidence_score,
            p_reviewer_note => coalesce(v_reviewer_note, 'Prepared enrichment draft via batch triage')
          ) c;

          v_result_status := 'succeeded';
          v_detail := 'enrichment_draft_prepared';
          v_succeeded := v_succeeded + 1;
        end if;
      end if;
    exception
      when others then
        v_result_status := 'failed';
        v_detail := coalesce(sqlerrm, 'unknown_error');
        v_failed := v_failed + 1;
    end;

    v_results := v_results || jsonb_build_array(
      jsonb_build_object(
        'normalized_text', v_normalized,
        'intended_action', v_action,
        'result_status', v_result_status,
        'detail', v_detail,
        'ingredient_id', v_ingredient_id,
        'alias_text', v_alias_text,
        'draft_status', v_draft_status,
        'draft_validated_ready', v_draft_validated_ready
      )
    );
  end loop;

  return jsonb_build_object(
    'summary', jsonb_build_object(
      'total', v_total,
      'succeeded', v_succeeded,
      'failed', v_failed,
      'skipped', v_skipped
    ),
    'items', v_results,
    'metadata', jsonb_build_object(
      'processed_at', v_now,
      'processed_by', v_user,
      'source', 'catalog_candidate_batch_triage_v1'
    )
  );
end;
$$;

revoke all on function public.execute_catalog_candidate_batch_triage(jsonb, text, text) from public;
grant execute on function public.execute_catalog_candidate_batch_triage(jsonb, text, text) to authenticated;
grant execute on function public.execute_catalog_candidate_batch_triage(jsonb, text, text) to service_role;
