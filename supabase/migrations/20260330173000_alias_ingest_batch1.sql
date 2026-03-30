-- Batch 1 manual alias ingestion for high-value unresolved strings.
-- Maps approved IT aliases to canonical unified basic ingredient slugs.

do $$
declare
  missing_slugs text[];
begin
  with required(slug) as (
    values
      ('olive_oil'::text),
      ('tomato_sauce'::text),
      ('salt'::text)
  ),
  missing as (
    select r.slug
    from required r
    left join public.ingredients i
      on i.slug = r.slug
    where i.id is null
  )
  select array_agg(slug order by slug)
  into missing_slugs
  from missing;

  if missing_slugs is not null then
    raise exception
      'alias_ingest_batch1 failed: missing canonical ingredient slug(s): %',
      array_to_string(missing_slugs, ', ');
  end if;
end;
$$;

with alias_targets as (
  select
    i.id as ingredient_id,
    m.alias_text,
    m.normalized_alias_text,
    m.language_code,
    m.source,
    m.confidence
  from (values
    ('olio evo'::text, 'olio evo'::text, 'it'::text, 'manual'::text, 1.0::double precision, 'olive_oil'::text),
    ('salsa di pomodoro'::text, 'salsa di pomodoro'::text, 'it'::text, 'manual'::text, 1.0::double precision, 'tomato_sauce'::text),
    ('sale'::text, 'sale'::text, 'it'::text, 'manual'::text, 1.0::double precision, 'salt'::text)
  ) as m(alias_text, normalized_alias_text, language_code, source, confidence, target_slug)
  join public.ingredients i
    on i.slug = m.target_slug
)
update public.ingredient_aliases_v2 a
set
  ingredient_id = t.ingredient_id,
  alias_text = t.alias_text,
  language_code = t.language_code,
  source = t.source,
  confidence = t.confidence,
  is_active = true,
  updated_at = now()
from alias_targets t
where a.normalized_alias_text = t.normalized_alias_text
  and a.is_active = true;

with alias_targets as (
  select
    i.id as ingredient_id,
    m.alias_text,
    m.normalized_alias_text,
    m.language_code,
    m.source,
    m.confidence
  from (values
    ('olio evo'::text, 'olio evo'::text, 'it'::text, 'manual'::text, 1.0::double precision, 'olive_oil'::text),
    ('salsa di pomodoro'::text, 'salsa di pomodoro'::text, 'it'::text, 'manual'::text, 1.0::double precision, 'tomato_sauce'::text),
    ('sale'::text, 'sale'::text, 'it'::text, 'manual'::text, 1.0::double precision, 'salt'::text)
  ) as m(alias_text, normalized_alias_text, language_code, source, confidence, target_slug)
  join public.ingredients i
    on i.slug = m.target_slug
)
insert into public.ingredient_aliases_v2 (
  ingredient_id,
  alias_text,
  normalized_alias_text,
  language_code,
  source,
  confidence,
  is_active,
  created_at,
  updated_at
)
select
  t.ingredient_id,
  t.alias_text,
  t.normalized_alias_text,
  t.language_code,
  t.source,
  t.confidence,
  true,
  now(),
  now()
from alias_targets t
where not exists (
  select 1
  from public.ingredient_aliases_v2 a
  where a.normalized_alias_text = t.normalized_alias_text
    and a.is_active = true
);
