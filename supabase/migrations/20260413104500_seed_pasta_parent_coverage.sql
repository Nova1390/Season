-- Minimal pasta parent coverage to improve safe auto-promotion for pasta-shape variants.
-- Conservative scope: ensure root `pasta` exists, then link a small set of obvious pasta-shape children if they exist.
-- No workflow logic changes.

do $$
declare
  v_pasta_id uuid;
  v_has_canonical_root boolean;
begin
  -- Ensure canonical parent root exists.
  insert into public.ingredients (
    slug,
    ingredient_type,
    default_unit,
    supported_units,
    specificity_rank,
    variant_kind,
    parent_ingredient_id,
    quality_status
  )
  values (
    'pasta',
    'basic',
    'g',
    array['g']::text[],
    0,
    'base',
    null,
    'active'
  )
  on conflict (slug) do nothing;

  select i.id
  into v_pasta_id
  from public.ingredients i
  where i.slug = 'pasta'
  limit 1;

  if v_pasta_id is null then
    raise notice 'pasta root missing after insert attempt; skipping parent coverage assignment';
    return;
  end if;

  -- Keep root metadata stable.
  update public.ingredients i
  set
    parent_ingredient_id = null,
    specificity_rank = 0,
    variant_kind = 'base'
  where i.id = v_pasta_id;

  -- Minimal localization for root if missing.
  insert into public.ingredient_localizations (ingredient_id, language_code, display_name)
  values
    (v_pasta_id, 'it', 'Pasta'),
    (v_pasta_id, 'en', 'Pasta')
  on conflict (ingredient_id, language_code) do nothing;

  -- Conservative child assignment: only if child slug already exists.
  update public.ingredients c
  set
    parent_ingredient_id = v_pasta_id,
    specificity_rank = 1,
    variant_kind = 'shape'
  where c.slug in (
    'fusilli',
    'penne_rigate',
    'sedanini_rigati',
    'trofie',
    'pappardelle_all_uovo',
    'rigatoni',
    'conchiglioni',
    'orecchiette',
    'paccheri',
    'tagliatelle',
    'spaghetti'
  )
    and c.id <> v_pasta_id;

  -- Optional canonical_root_id support (only if column exists).
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ingredients'
      and column_name = 'canonical_root_id'
  )
  into v_has_canonical_root;

  if v_has_canonical_root then
    execute $sql$
      update public.ingredients i
      set canonical_root_id = i.id
      where i.slug = 'pasta'
    $sql$;

    execute $sql$
      update public.ingredients c
      set canonical_root_id = p.id
      from public.ingredients p
      where p.slug = 'pasta'
        and c.slug in (
          'fusilli',
          'penne_rigate',
          'sedanini_rigati',
          'trofie',
          'pappardelle_all_uovo',
          'rigatoni',
          'conchiglioni',
          'orecchiette',
          'paccheri',
          'tagliatelle',
          'spaghetti'
        )
    $sql$;
  end if;
end
$$;

-- Verification helpers:
-- select slug, ingredient_type, parent_ingredient_id, specificity_rank, variant_kind
-- from public.ingredients
-- where slug in (
--   'pasta',
--   'fusilli','penne_rigate','sedanini_rigati','trofie','pappardelle_all_uovo',
--   'rigatoni','conchiglioni','orecchiette','paccheri','tagliatelle','spaghetti'
-- )
-- order by slug;
--
-- select child.slug as child_slug, parent.slug as parent_slug
-- from public.ingredients child
-- left join public.ingredients parent on parent.id = child.parent_ingredient_id
-- where child.slug in ('fusilli','penne_rigate','sedanini_rigati','trofie','pappardelle_all_uovo')
-- order by child.slug;
