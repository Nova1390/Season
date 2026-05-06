-- Replay audit: would today's catalog/autopilot resolver handle the cleaned
-- Giallo Zafferano ingredient texts without falling back to custom?
--
-- This is intentionally read-only. It compares each current Giallo Zafferano
-- recipe ingredient against the target that exact alias/localization matching
-- would choose today, then highlights gaps we should turn into autopilot rules.

create or replace view public.giallozafferano_autopilot_replay_audit as
with ingredient_rows as (
  select
    r.id::text as recipe_id,
    r.title as recipe_title,
    i.ordinality::integer as ingredient_index,
    i.ingredient as ingredient_json,
    nullif(trim(i.ingredient ->> 'name'), '') as ingredient_name,
    public.normalize_recipe_ingredient_text_for_matching(i.ingredient ->> 'name') as normalized_text,
    nullif(trim(i.ingredient ->> 'ingredient_id'), '')::uuid as ingredient_id
  from public.recipes r
  cross join lateral jsonb_array_elements(coalesce(r.ingredients::jsonb, '[]'::jsonb)) with ordinality as i(ingredient, ordinality)
  where r.source_name = 'ricette.giallozafferano.it'
),
golden as (
  select
    ir.*,
    coalesce(redirects.canonical_ingredient_id, ir.ingredient_id) as golden_canonical_ingredient_id,
    golden_i.slug as golden_ingredient_slug,
    direct_i.slug as direct_ingredient_slug,
    redirects.canonical_ingredient_id is not null as direct_ingredient_is_redirected
  from ingredient_rows ir
  left join public.ingredient_canonical_redirects redirects
    on redirects.ingredient_id = ir.ingredient_id
  left join public.ingredients golden_i
    on golden_i.id = coalesce(redirects.canonical_ingredient_id, ir.ingredient_id)
  left join public.ingredients direct_i
    on direct_i.id = ir.ingredient_id
),
alias_matches as (
  select
    g.recipe_id,
    g.ingredient_index,
    count(distinct a.ingredient_id)::integer as alias_target_count,
    (array_agg(distinct a.ingredient_id::text order by a.ingredient_id::text))[1]::uuid as alias_target_id,
    (array_agg(distinct a.ingredient_slug order by a.ingredient_slug))[1] as alias_target_slug
  from golden g
  left join public.ingredient_alias_app_summary a
    on a.normalized_alias_text = g.normalized_text
  group by g.recipe_id, g.ingredient_index
),
localization_matches as (
  select
    g.recipe_id,
    g.ingredient_index,
    count(distinct c.ingredient_id)::integer as localization_target_count,
    (array_agg(distinct c.ingredient_id::text order by c.ingredient_id::text))[1]::uuid as localization_target_id,
    (array_agg(distinct c.slug order by c.slug))[1] as localization_target_slug
  from golden g
  left join public.ingredient_catalog_app_summary c
    on lower(trim(c.it_name)) = g.normalized_text
    or lower(trim(c.en_name)) = g.normalized_text
  group by g.recipe_id, g.ingredient_index
),
classified as (
  select
    g.*,
    am.alias_target_count,
    am.alias_target_id,
    am.alias_target_slug,
    lm.localization_target_count,
    lm.localization_target_id,
    lm.localization_target_slug,
    case
      when am.alias_target_count = 1 then am.alias_target_id
      when am.alias_target_count = 0 and lm.localization_target_count = 1 then lm.localization_target_id
      else null
    end as replay_target_id,
    case
      when am.alias_target_count = 1 then am.alias_target_slug
      when am.alias_target_count = 0 and lm.localization_target_count = 1 then lm.localization_target_slug
      else null
    end as replay_target_slug,
    case
      when am.alias_target_count = 1 then 'approved_alias_exact_match'
      when am.alias_target_count > 1 then 'ambiguous_alias_match'
      when lm.localization_target_count = 1 then 'canonical_localization_exact_match'
      when lm.localization_target_count > 1 then 'ambiguous_localization_match'
      else 'no_exact_catalog_match'
    end as replay_resolution_source
  from golden g
  join alias_matches am
    on am.recipe_id = g.recipe_id
   and am.ingredient_index = g.ingredient_index
  join localization_matches lm
    on lm.recipe_id = g.recipe_id
   and lm.ingredient_index = g.ingredient_index
),
outcome as (
  select
    c.*,
    case
      when c.replay_target_id = c.golden_canonical_ingredient_id then 'autopilot_would_resolve_correctly'
      when c.replay_target_id is null then 'autopilot_would_fallback_to_custom_or_pending'
      else 'autopilot_would_resolve_different_target'
    end as replay_status,
    case
      when c.replay_target_id = c.golden_canonical_ingredient_id then 'none'
      when c.replay_target_id is null and c.normalized_text in ('farina', 'uova medie') then 'normalization_lost_specificity'
      when c.replay_target_id is null then 'missing_exact_alias_or_localization'
      when c.replay_target_id <> c.golden_canonical_ingredient_id
        and c.normalized_text in ('burro', 'parmigiano reggiano dop', 'grana padano dop', 'tuorli', 'albumi', 'mascarpone', 'patate') then 'qualifier_variant_collapses_to_base'
      when c.replay_target_id <> c.golden_canonical_ingredient_id then 'conflicting_exact_match_target'
      else 'unknown'
    end as gap_category,
    case
      when c.replay_target_id = c.golden_canonical_ingredient_id then 'No action needed.'
      when c.replay_target_id is null and c.normalized_text = 'farina' and c.golden_ingredient_slug = 'farina_00'
        then 'Teach normalization/import to preserve flour type tokens like 00 before exact matching.'
      when c.replay_target_id is null and c.normalized_text = 'uova medie'
        then 'Add safe alias uova medie -> eggs or normalize size adjectives for eggs.'
      when c.replay_target_id is null
        then 'Add approved alias/localization or enrichment rule for this exact normalized text.'
      when c.replay_target_id <> c.golden_canonical_ingredient_id
        then 'Decide whether qualifiers should map to base ingredient or canonical variant, then add explicit alias/routing rule.'
      else 'Review.'
    end as recommended_autopilot_fix
  from classified c
)
select
  recipe_id,
  recipe_title,
  ingredient_index,
  ingredient_name,
  normalized_text,
  ingredient_id,
  direct_ingredient_slug,
  direct_ingredient_is_redirected,
  golden_canonical_ingredient_id,
  golden_ingredient_slug,
  replay_resolution_source,
  replay_target_id,
  replay_target_slug,
  alias_target_count,
  localization_target_count,
  replay_status,
  gap_category,
  recommended_autopilot_fix,
  ingredient_json
from outcome;

create or replace view public.giallozafferano_autopilot_replay_summary as
select
  count(*)::bigint as ingredient_row_count,
  count(*) filter (where replay_status = 'autopilot_would_resolve_correctly')::bigint as would_resolve_correctly_count,
  count(*) filter (where replay_status = 'autopilot_would_fallback_to_custom_or_pending')::bigint as would_fallback_to_custom_or_pending_count,
  count(*) filter (where replay_status = 'autopilot_would_resolve_different_target')::bigint as would_resolve_different_target_count,
  count(*) filter (where replay_resolution_source = 'approved_alias_exact_match')::bigint as exact_alias_count,
  count(*) filter (where replay_resolution_source = 'canonical_localization_exact_match')::bigint as exact_localization_count,
  count(*) filter (where replay_resolution_source = 'no_exact_catalog_match')::bigint as no_exact_catalog_match_count,
  round(
    (
      count(*) filter (where replay_status = 'autopilot_would_resolve_correctly')::numeric
      / nullif(count(*)::numeric, 0)
    ) * 100.0,
    2
  ) as would_resolve_correctly_pct
from public.giallozafferano_autopilot_replay_audit;

create or replace view public.giallozafferano_autopilot_replay_gap_summary as
select
  gap_category,
  replay_status,
  count(*)::bigint as ingredient_row_count,
  count(distinct normalized_text)::bigint as distinct_normalized_text_count,
  array_agg(distinct normalized_text order by normalized_text) as normalized_texts
from public.giallozafferano_autopilot_replay_audit
where replay_status <> 'autopilot_would_resolve_correctly'
group by gap_category, replay_status;

grant select on public.giallozafferano_autopilot_replay_audit to authenticated;
grant select on public.giallozafferano_autopilot_replay_audit to service_role;
grant select on public.giallozafferano_autopilot_replay_summary to authenticated;
grant select on public.giallozafferano_autopilot_replay_summary to service_role;
grant select on public.giallozafferano_autopilot_replay_gap_summary to authenticated;
grant select on public.giallozafferano_autopilot_replay_gap_summary to service_role;
