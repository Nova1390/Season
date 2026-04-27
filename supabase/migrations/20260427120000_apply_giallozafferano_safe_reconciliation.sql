-- Apply only already-safe Giallo Zafferano reconciliation rows.
--
-- The previous migrations improved the preview and approved explicit aliases.
-- This migration delegates the actual mutation to the audited modern safe apply
-- RPC, constrained to Giallo Zafferano curated imports.

do $$
declare
  v_recipe_ids text[];
begin
  perform set_config('request.jwt.claim.role', 'service_role', true);

  select coalesce(array_agg(r.id::text order by r.id::text), array[]::text[])
  into v_recipe_ids
  from public.recipes r
  where r.source_name = 'ricette.giallozafferano.it'
    and r.source_type = 'curated_import';

  if cardinality(v_recipe_ids) > 0 then
    perform *
    from public.apply_recipe_ingredient_reconciliation_modern(
      p_limit => 250,
      p_recipe_ids => v_recipe_ids
    );
  end if;
end $$;
