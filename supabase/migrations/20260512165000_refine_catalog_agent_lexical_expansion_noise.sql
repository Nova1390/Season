begin;

-- Keep lexical expansion useful but quiet:
-- - preparation-state stripping can apply to phrases such as "pane raffermo";
-- - singular/plural morphology should apply only to single-token terms.

create or replace function public.catalog_agent_lexical_candidate_terms(
  p_normalized_text text
)
returns table(term text, expansion_source text)
language sql
immutable
set search_path = public
as $$
  with input as (
    select
      nullif(lower(trim(coalesce(p_normalized_text, ''))), '') as normalized_text,
      position(' ' in nullif(lower(trim(coalesce(p_normalized_text, ''))), '')) = 0 as is_single_token
  ),
  generated as (
    select normalized_text as term, 'original'::text as expansion_source
    from input
    where normalized_text is not null

    union all

    select regexp_replace(normalized_text, '\s+(rafferm[oaie]|cotto|cotta|cotti|cotte|crudo|cruda|crudi|crude|tostato|tostata|tostati|tostate|grattugiato|grattugiata|grattugiati|grattugiate|tritato|tritata|tritati|tritate|tagliato|tagliata|tagliati|tagliate|bollito|bollita|bolliti|bollite|lessato|lessata|lessati|lessate|fresco|fresca|freschi|fresche)$', '') as term,
      'preparation_state_stripped'::text as expansion_source
    from input
    where normalized_text ~ '\s+(rafferm[oaie]|cotto|cotta|cotti|cotte|crudo|cruda|crudi|crude|tostato|tostata|tostati|tostate|grattugiato|grattugiata|grattugiati|grattugiate|tritato|tritata|tritati|tritate|tagliato|tagliata|tagliati|tagliate|bollito|bollita|bolliti|bollite|lessato|lessata|lessati|lessate|fresco|fresca|freschi|fresche)$'

    union all

    select regexp_replace(normalized_text, 'i$', 'o') as term,
      'italian_plural_i_to_o'::text as expansion_source
    from input
    where is_single_token
      and normalized_text ~ '.{3,}i$'

    union all

    select regexp_replace(normalized_text, 'i$', 'e') as term,
      'italian_plural_i_to_e'::text as expansion_source
    from input
    where is_single_token
      and normalized_text ~ '.{3,}i$'

    union all

    select regexp_replace(normalized_text, 'e$', 'a') as term,
      'italian_plural_e_to_a'::text as expansion_source
    from input
    where is_single_token
      and normalized_text ~ '.{4,}e$'

    union all

    select regexp_replace(normalized_text, 'e$', 'o') as term,
      'italian_plural_e_to_o'::text as expansion_source
    from input
    where is_single_token
      and normalized_text ~ '.{4,}e$'

    union all

    select regexp_replace(normalized_text, 'o$', 'i') as term,
      'italian_singular_o_to_i'::text as expansion_source
    from input
    where is_single_token
      and normalized_text ~ '.{3,}o$'

    union all

    select regexp_replace(normalized_text, 'o$', 'a') as term,
      'italian_singular_o_to_a'::text as expansion_source
    from input
    where is_single_token
      and normalized_text ~ '.{3,}o$'

    union all

    select regexp_replace(normalized_text, 'a$', 'e') as term,
      'italian_singular_a_to_e'::text as expansion_source
    from input
    where is_single_token
      and normalized_text ~ '.{3,}a$'
  )
  select distinct
    nullif(trim(generated.term), '') as term,
    generated.expansion_source
  from generated
  where nullif(trim(generated.term), '') is not null
    and length(trim(generated.term)) >= 2;
$$;

comment on function public.catalog_agent_lexical_candidate_terms(text) is
  'Read-only deterministic term expansion for Catalog Agent candidate lookup. Generates conservative localized singular/plural hints for single-token terms and preparation-state stripped phrase variants; it does not approve or mutate catalog data.';

commit;
