-- Fix two replayed Giallo Zafferano autopilot gaps:
-- - preserve flour type tokens such as "00" during recipe text normalization;
-- - approve the safe Italian alias "uova medie" against the canonical eggs item.

create or replace function public.normalize_recipe_ingredient_text_for_matching(p_text text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_text text := lower(trim(coalesce(p_text, '')));
begin
  if v_text = '' then
    return '';
  end if;

  v_text := replace(v_text, '&nbsp;', ' ');
  v_text := replace(v_text, '&amp;', '&');
  v_text := regexp_replace(v_text, '&frac(?:12|14|34);?', ' ', 'gi');
  v_text := translate(v_text, '½¼¾', '   ');

  -- Giallo Zafferano often keeps prep notes in the ingredient name.
  v_text := regexp_replace(v_text, '\s*\([^)]*\)', ' ', 'g');
  v_text := regexp_replace(
    v_text,
    '\s*,?\s*(?:da\s+(?:pulire|grattugiare|ridurre\s+in\s+polvere|tritare|tagliare|sbucciare|mondare)|a\s+temperatura\s+ambiente|ammorbidit[oaie]|fredd[oaie]\s+di\s+frigo|per\s+(?:decorare|guarnire|friggere)).*$',
    '',
    'gi'
  );
  v_text := regexp_replace(v_text, '\s+possibilmente\s+biologic[oaie].*$', '', 'gi');
  v_text := regexp_replace(v_text, '\s+sgocciolat[oaie]\s*$', '', 'gi');

  -- Remove trailing quantity contamination while preserving canonical variants
  -- such as "farina 00". PostgreSQL regex word-boundary "\b" is not reliable
  -- here, so use explicit start/space and end/space boundaries.
  if v_text !~* '(^|[[:space:]])farina[[:space:]]+00($|[[:space:]])' then
    v_text := regexp_replace(
      v_text,
      '\s+[0-9]+(?:[,.][0-9]+)?\s*(?:g|gr|grammi|kg|mg|ml|cl|l|lt|litri|cucchiaio|cucchiai|cucchiaino|cucchiaini|bicchiere|bicchieri|pizzico|pizzichi|spicchio|spicchi|foglia|foglie|pezzo|pezzi|ciuffo|ciuffi|mazzetto|mazzetti|fetta|fette)\.?\s*$',
      '',
      'gi'
    );
    v_text := regexp_replace(v_text, '\s+[0-9]+(?:[,.][0-9]+)?\s*$', '', 'gi');
  end if;

  -- If a fraction left only a unit word at the end, drop that serving measure.
  v_text := regexp_replace(
    v_text,
    '\s+(?:bicchiere|bicchieri|cucchiaio|cucchiai|cucchiaino|cucchiaini|pizzico|pizzichi|ciuffo|ciuffi|mazzetto|mazzetti|fetta|fette)\s*$',
    '',
    'gi'
  );

  v_text := regexp_replace(v_text, '\s+', ' ', 'g');
  v_text := trim(both ' ,;:-' from v_text);

  return v_text;
end;
$$;

do $$
declare
  v_target_id uuid;
  v_existing_alias_ingredient_id uuid;
  v_existing_alias_slug text;
begin
  perform set_config('request.jwt.claim.role', 'service_role', true);

  select i.id into v_target_id
  from public.ingredients i
  where i.slug = 'eggs'
  limit 1;

  if v_target_id is null then
    raise exception 'medium eggs alias failed: missing canonical slug eggs';
  end if;

  select a.ingredient_id, i.slug
  into v_existing_alias_ingredient_id, v_existing_alias_slug
  from public.ingredient_aliases_v2 a
  join public.ingredients i on i.id = a.ingredient_id
  where a.normalized_alias_text = 'uova medie'
    and coalesce(a.is_active, true)
  order by a.id desc
  limit 1;

  if v_existing_alias_ingredient_id is null then
    perform *
    from public.approve_reconciliation_alias(
      p_normalized_text => 'uova medie',
      p_ingredient_id => v_target_id,
      p_alias_text => 'uova medie',
      p_language_code => 'it',
      p_reviewer_note => 'Autopilot replay fix: medium egg size adjective should resolve to canonical eggs.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id = v_target_id then
    raise notice 'skipping alias uova medie: active alias already points to eggs';
  else
    raise notice 'skipping alias uova medie: active alias points to %, requested eggs',
      v_existing_alias_slug;
  end if;
end $$;

grant execute on function public.normalize_recipe_ingredient_text_for_matching(text) to authenticated;
grant execute on function public.normalize_recipe_ingredient_text_for_matching(text) to service_role;
