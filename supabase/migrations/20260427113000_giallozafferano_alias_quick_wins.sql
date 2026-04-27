-- Giallo Zafferano reconciliation quick wins.
--
-- Scope:
-- - make the text normalizer less brittle for common prep notes;
-- - approve a small set of low-risk aliases against existing canonical items.
--
-- This still does not mutate recipe ingredients directly. The safe apply
-- workflow/autopilot decides what can be applied from the preview.

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
  -- such as "farina 00".
  if v_text !~* '\bfarina\s+00\b' then
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
  v_alias_spec jsonb;
  v_target_id uuid;
  v_existing_alias_ingredient_id uuid;
  v_existing_alias_slug text;
begin
  perform set_config('request.jwt.claim.role', 'service_role', true);

  for v_alias_spec in
    select *
    from jsonb_array_elements(
      '[
        {
          "normalized_text": "uova",
          "alias_text": "uova",
          "slug": "eggs",
          "note": "Giallo Zafferano quick win: Italian plural eggs maps to the bridged eggs canonical, disambiguating duplicate localizations."
        },
        {
          "normalized_text": "burro",
          "alias_text": "burro",
          "slug": "butter",
          "note": "Giallo Zafferano quick win: Italian butter maps to bridged butter canonical, disambiguating duplicate localizations."
        },
        {
          "normalized_text": "prezzemolo",
          "alias_text": "prezzemolo",
          "slug": "parsley",
          "note": "Giallo Zafferano quick win: Italian parsley maps to bridged parsley canonical, disambiguating duplicate localizations."
        },
        {
          "normalized_text": "melanzane",
          "alias_text": "melanzane",
          "slug": "eggplant",
          "note": "Giallo Zafferano quick win: Italian plural eggplants maps to eggplant canonical."
        },
        {
          "normalized_text": "funghi champignon",
          "alias_text": "funghi champignon",
          "slug": "mushroom",
          "note": "Giallo Zafferano quick win: champignon mushrooms map to mushroom canonical for recipe matching."
        },
        {
          "normalized_text": "doppio concentrato di pomodoro",
          "alias_text": "doppio concentrato di pomodoro",
          "slug": "tomato_paste",
          "note": "Giallo Zafferano quick win: double tomato concentrate maps to tomato paste canonical."
        },
        {
          "normalized_text": "pomodori costoluti",
          "alias_text": "pomodori costoluti",
          "slug": "tomato",
          "note": "Giallo Zafferano quick win: ribbed tomato variety maps to tomato canonical."
        },
        {
          "normalized_text": "pomodori ramati",
          "alias_text": "pomodori ramati",
          "slug": "tomato",
          "note": "Giallo Zafferano quick win: cluster tomato variety maps to tomato canonical."
        },
        {
          "normalized_text": "pomodorini ciliegino",
          "alias_text": "pomodorini ciliegino",
          "slug": "tomato",
          "note": "Giallo Zafferano quick win: cherry tomatoes map to tomato canonical until a specific child variant is introduced."
        },
        {
          "normalized_text": "nocciole intere spellate di giffoni",
          "alias_text": "nocciole intere spellate di giffoni",
          "slug": "hazelnuts",
          "note": "Giallo Zafferano quick win: peeled whole Giffoni hazelnuts map to hazelnuts canonical."
        }
      ]'::jsonb
    )
  loop
    v_target_id := null;
    v_existing_alias_ingredient_id := null;
    v_existing_alias_slug := null;

    select i.id into v_target_id
    from public.ingredients i
    where i.slug = v_alias_spec->>'slug'
    limit 1;

    if v_target_id is null then
      raise exception 'giallozafferano alias quick wins failed: missing canonical slug %', v_alias_spec->>'slug';
    end if;

    select a.ingredient_id, i.slug
    into v_existing_alias_ingredient_id, v_existing_alias_slug
    from public.ingredient_aliases_v2 a
    join public.ingredients i on i.id = a.ingredient_id
    where a.normalized_alias_text = v_alias_spec->>'normalized_text'
      and coalesce(a.is_active, true)
    order by a.id desc
    limit 1;

    if v_existing_alias_ingredient_id is null then
      perform *
      from public.approve_reconciliation_alias(
        p_normalized_text => v_alias_spec->>'normalized_text',
        p_ingredient_id => v_target_id,
        p_alias_text => v_alias_spec->>'alias_text',
        p_language_code => 'it',
        p_reviewer_note => v_alias_spec->>'note',
        p_confidence_score => 0.99
      );
    elsif v_existing_alias_ingredient_id = v_target_id then
      raise notice 'skipping alias %: active alias already points to %',
        v_alias_spec->>'normalized_text',
        v_alias_spec->>'slug';
    else
      raise notice 'skipping alias %: active alias points to %, requested %',
        v_alias_spec->>'normalized_text',
        v_existing_alias_slug,
        v_alias_spec->>'slug';
    end if;
  end loop;
end $$;
