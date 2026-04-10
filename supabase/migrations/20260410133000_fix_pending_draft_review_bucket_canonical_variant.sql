-- Read-only cleanup/review classifier for already-created pending enrichment drafts.
-- No destructive actions; this only surfaces operator buckets.

create or replace function public.review_pending_catalog_enrichment_drafts(
  p_limit integer default 200
)
returns table (
  normalized_text text,
  occurrence_count integer,
  draft_updated_at timestamptz,
  review_bucket text,
  classification_reason text,
  has_approved_alias boolean,
  has_any_alias_match boolean,
  canonical_match_count integer,
  quantity_contaminated boolean,
  low_risk_qualifier boolean,
  descriptor_alias_like boolean,
  is_pasta_shape boolean,
  recommended_operator_action text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  perform public.assert_catalog_admin(v_user);

  return query
  with pending as (
    select
      d.normalized_text,
      d.updated_at,
      coalesce(o.occurrence_count, 0) as occurrence_count
    from public.catalog_ingredient_enrichment_drafts d
    left join public.custom_ingredient_observations o
      on o.normalized_text = d.normalized_text
    where d.status = 'pending'
  ),
  alias_stats as (
    select
      p.normalized_text,
      bool_or(coalesce(a.is_active, true) and coalesce(a.status, 'approved') = 'approved') as has_approved_alias,
      bool_or(true) as has_any_alias_match
    from pending p
    left join public.ingredient_aliases_v2 a
      on a.normalized_alias_text = p.normalized_text
    group by p.normalized_text
  ),
  canonical_keys as (
    select
      i.id as ingredient_id,
      regexp_replace(lower(trim(replace(i.slug, '_', ' '))), '\\s+', ' ', 'g') as normalized_key
    from public.ingredients i

    union all

    select
      l.ingredient_id,
      regexp_replace(lower(trim(l.display_name)), '\\s+', ' ', 'g') as normalized_key
    from public.ingredient_localizations l
  ),
  canonical_stats as (
    select
      p.normalized_text,
      count(distinct ck.ingredient_id)::integer as canonical_match_count
    from pending p
    left join canonical_keys ck
      on ck.normalized_key = p.normalized_text
    group by p.normalized_text
  ),
  blocker_signals as (
    select
      b.normalized_text,
      lower(coalesce(b.likely_fix_type, 'unknown')) as blocker_likely_fix_type,
      lower(coalesce(b.recommended_next_action, 'unknown')) as blocker_recommended_next_action,
      (b.canonical_candidate_slug is not null and trim(b.canonical_candidate_slug) <> '') as blocker_has_canonical_slug
    from public.catalog_coverage_blocker_terms b
  ),
  features as (
    select
      p.normalized_text,
      p.updated_at,
      p.occurrence_count,
      coalesce(a.has_approved_alias, false) as has_approved_alias,
      coalesce(a.has_any_alias_match, false) as has_any_alias_match,
      coalesce(c.canonical_match_count, 0) as canonical_match_count,
      coalesce(bs.blocker_likely_fix_type, 'unknown') as blocker_likely_fix_type,
      coalesce(bs.blocker_recommended_next_action, 'unknown') as blocker_recommended_next_action,
      coalesce(bs.blocker_has_canonical_slug, false) as blocker_has_canonical_slug,
      (
        p.normalized_text <> 'farina 00'
        and (
          p.normalized_text ~* '\\b\\d+(?:\\/\\d+|(?:[.,]\\d+)?)\\s*(?:g|kg|gr|mg|ml|l|cl|pizzico|pizzichi|mazzetto|mazzetti|cucchiaio|cucchiai|cucchiaino|cucchiaini|spicchio|spicchi|foglia|foglie|cup|tbsp|tsp)\\.?\\b'
          or p.normalized_text ~* '\\b(?:g|kg|gr|mg|ml|l|cl)\\s*\\d+(?:[.,]\\d+)?\\b'
          or p.normalized_text ~* '\\s\\d+(?:[.,]\\d+)?$'
        )
      ) as quantity_contaminated,
      (
        -- Canonical culinary variants: specificity that changes ingredient identity.
        (p.normalized_text ~* '\\bfarina\\s+00\\b')
        or (p.normalized_text ~* '\\briso\\s+(carnaroli|arborio|vialone\\s+nano)\\b')
        or (p.normalized_text ~* '\\bpanna\\s+fresca\\s+liquida\\b')
        or (p.normalized_text ~* '\\b(parmigiano\\s+reggiano|pecorino\\s+romano|gorgonzola\\s+dolce)\\b')
        or (
          p.normalized_text ~* '\\b(dop|igp)\\b'
          and p.normalized_text ~* '\\b(parmigiano|pecorino|grana|prosciutto|aceto\\s+balsamico|mozzarella)\\b'
        )
        or (p.normalized_text ~* '\\b(all''uovo|all uovo)\\b')
      ) as likely_canonical_variant,
      p.normalized_text ~* '(ammorbidito|da grattugiare|in grani|a temperatura ambiente|freddo di frigo|tritato|tritata)' as low_risk_qualifier,
      p.normalized_text ~* '\\b(fino|grosso|extravergine|evo|intero|integrale)\\b' as descriptor_alias_like,
      p.normalized_text ~* '(conchiglioni|spaghettoni|tagliatelle|pappardelle|rigatoni|mezze maniche|penne rigate|fusilli|orecchiette|trofie|paccheri)' as is_pasta_shape
    from pending p
    left join alias_stats a
      on a.normalized_text = p.normalized_text
    left join canonical_stats c
      on c.normalized_text = p.normalized_text
    left join blocker_signals bs
      on bs.normalized_text = p.normalized_text
  )
  select
    f.normalized_text,
    f.occurrence_count,
    f.updated_at as draft_updated_at,
    case
      when f.quantity_contaminated then 'SHOULD_BE_REJECTED_OR_HOLD'
      when f.likely_canonical_variant then 'KEEP_PENDING_FOR_REVIEW'
      when f.blocker_likely_fix_type = 'alias' then 'SHOULD_BE_ALIAS_INSTEAD'
      when f.blocker_recommended_next_action = 'add_alias' then 'SHOULD_BE_ALIAS_INSTEAD'
      when f.has_approved_alias then 'SHOULD_BE_ALIAS_INSTEAD'
      when f.low_risk_qualifier and (f.blocker_has_canonical_slug or f.canonical_match_count = 1) then 'SHOULD_BE_ALIAS_INSTEAD'
      when f.descriptor_alias_like and f.canonical_match_count >= 1 then 'SHOULD_BE_ALIAS_INSTEAD'
      when f.canonical_match_count = 1 and (f.low_risk_qualifier or f.descriptor_alias_like) then 'SHOULD_BE_ALIAS_INSTEAD'
      when f.is_pasta_shape then 'KEEP_PENDING_FOR_REVIEW'
      when f.occurrence_count >= 2 then 'KEEP_PENDING_FOR_REVIEW'
      else 'SHOULD_BE_REJECTED_OR_HOLD'
    end as review_bucket,
    case
      when f.quantity_contaminated then 'quantity_or_unit_contaminated_text'
      when f.likely_canonical_variant then 'canonical_variant_specificity_detected'
      when f.blocker_likely_fix_type = 'alias' then 'coverage_blocker_points_to_alias_fix'
      when f.blocker_recommended_next_action = 'add_alias' then 'recommended_action_add_alias'
      when f.has_approved_alias then 'already_covered_by_approved_alias'
      when f.low_risk_qualifier and (f.blocker_has_canonical_slug or f.canonical_match_count = 1) then 'preparation_or_state_qualifier_variant_with_canonical_target'
      when f.descriptor_alias_like and f.canonical_match_count >= 1 then 'descriptor_variant_of_existing_canonical'
      when f.canonical_match_count = 1 and (f.low_risk_qualifier or f.descriptor_alias_like) then 'single_canonical_match_with_alias_like_form'
      when f.is_pasta_shape then 'pasta_shape_candidate_keep_for_review'
      when f.occurrence_count >= 2 then 'recurring_pending_candidate'
      else 'low_signal_pending_candidate'
    end as classification_reason,
    f.has_approved_alias,
    f.has_any_alias_match,
    f.canonical_match_count,
    f.quantity_contaminated,
    f.low_risk_qualifier,
    f.descriptor_alias_like,
    f.is_pasta_shape,
    case
      when (
        case
          when f.quantity_contaminated then 'SHOULD_BE_REJECTED_OR_HOLD'
          when f.likely_canonical_variant then 'KEEP_PENDING_FOR_REVIEW'
          when f.blocker_likely_fix_type = 'alias' then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.blocker_recommended_next_action = 'add_alias' then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.has_approved_alias then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.low_risk_qualifier and (f.blocker_has_canonical_slug or f.canonical_match_count = 1) then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.descriptor_alias_like and f.canonical_match_count >= 1 then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.canonical_match_count = 1 and (f.low_risk_qualifier or f.descriptor_alias_like) then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.is_pasta_shape then 'KEEP_PENDING_FOR_REVIEW'
          when f.occurrence_count >= 2 then 'KEEP_PENDING_FOR_REVIEW'
          else 'SHOULD_BE_REJECTED_OR_HOLD'
        end
      ) = 'KEEP_PENDING_FOR_REVIEW'
      then 'Continue enrichment review, validate, then mark ready when complete.'
      when (
        case
          when f.quantity_contaminated then 'SHOULD_BE_REJECTED_OR_HOLD'
          when f.likely_canonical_variant then 'KEEP_PENDING_FOR_REVIEW'
          when f.blocker_likely_fix_type = 'alias' then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.blocker_recommended_next_action = 'add_alias' then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.has_approved_alias then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.low_risk_qualifier and (f.blocker_has_canonical_slug or f.canonical_match_count = 1) then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.descriptor_alias_like and f.canonical_match_count >= 1 then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.canonical_match_count = 1 and (f.low_risk_qualifier or f.descriptor_alias_like) then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.is_pasta_shape then 'KEEP_PENDING_FOR_REVIEW'
          when f.occurrence_count >= 2 then 'KEEP_PENDING_FOR_REVIEW'
          else 'SHOULD_BE_REJECTED_OR_HOLD'
        end
      ) = 'SHOULD_BE_ALIAS_INSTEAD'
      then 'Do not create ingredient from this draft; route term through alias approval workflow.'
      else 'Keep on hold or reject after quick review; avoid ingredient creation for noisy text.'
    end as recommended_operator_action
  from features f
  order by
    case
      when (
        case
          when f.quantity_contaminated then 'SHOULD_BE_REJECTED_OR_HOLD'
          when f.likely_canonical_variant then 'KEEP_PENDING_FOR_REVIEW'
          when f.blocker_likely_fix_type = 'alias' then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.blocker_recommended_next_action = 'add_alias' then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.has_approved_alias then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.low_risk_qualifier and (f.blocker_has_canonical_slug or f.canonical_match_count = 1) then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.descriptor_alias_like and f.canonical_match_count >= 1 then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.canonical_match_count = 1 and (f.low_risk_qualifier or f.descriptor_alias_like) then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.is_pasta_shape then 'KEEP_PENDING_FOR_REVIEW'
          when f.occurrence_count >= 2 then 'KEEP_PENDING_FOR_REVIEW'
          else 'SHOULD_BE_REJECTED_OR_HOLD'
        end
      ) = 'KEEP_PENDING_FOR_REVIEW' then 0
      when (
        case
          when f.quantity_contaminated then 'SHOULD_BE_REJECTED_OR_HOLD'
          when f.likely_canonical_variant then 'KEEP_PENDING_FOR_REVIEW'
          when f.blocker_likely_fix_type = 'alias' then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.blocker_recommended_next_action = 'add_alias' then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.has_approved_alias then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.low_risk_qualifier and (f.blocker_has_canonical_slug or f.canonical_match_count = 1) then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.descriptor_alias_like and f.canonical_match_count >= 1 then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.canonical_match_count = 1 and (f.low_risk_qualifier or f.descriptor_alias_like) then 'SHOULD_BE_ALIAS_INSTEAD'
          when f.is_pasta_shape then 'KEEP_PENDING_FOR_REVIEW'
          when f.occurrence_count >= 2 then 'KEEP_PENDING_FOR_REVIEW'
          else 'SHOULD_BE_REJECTED_OR_HOLD'
        end
      ) = 'SHOULD_BE_ALIAS_INSTEAD' then 1
      else 2
    end,
    f.occurrence_count desc,
    f.updated_at desc,
    f.normalized_text asc
  limit greatest(1, coalesce(p_limit, 200));
end;
$$;

revoke all on function public.review_pending_catalog_enrichment_drafts(integer) from public;
grant execute on function public.review_pending_catalog_enrichment_drafts(integer) to authenticated;
grant execute on function public.review_pending_catalog_enrichment_drafts(integer) to service_role;
