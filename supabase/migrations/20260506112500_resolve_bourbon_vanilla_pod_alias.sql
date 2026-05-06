-- Close the last exact-match Giallo Zafferano replay fallback by approving the
-- normalized import text against the already-created canonical catalog item.

do $$
declare
  v_target_id uuid;
  v_existing_alias_ingredient_id uuid;
  v_existing_alias_slug text;
begin
  perform set_config('request.jwt.claim.role', 'service_role', true);

  select i.id into v_target_id
  from public.ingredients i
  where i.slug = 'baccello_di_vaniglia_bourbon'
  limit 1;

  if v_target_id is null then
    raise exception 'bourbon vanilla pod alias failed: missing canonical slug baccello_di_vaniglia_bourbon';
  end if;

  select a.ingredient_id, i.slug
  into v_existing_alias_ingredient_id, v_existing_alias_slug
  from public.ingredient_aliases_v2 a
  join public.ingredients i on i.id = a.ingredient_id
  where a.normalized_alias_text = 'baccello di vaniglia di bourbon'
    and coalesce(a.is_active, true)
  order by a.id desc
  limit 1;

  if v_existing_alias_ingredient_id is null then
    perform *
    from public.approve_reconciliation_alias(
      p_normalized_text => 'baccello di vaniglia di bourbon',
      p_ingredient_id => v_target_id,
      p_alias_text => 'baccello di vaniglia di Bourbon',
      p_language_code => 'it',
      p_reviewer_note => 'Autopilot replay fix: exact Giallo Zafferano Bourbon vanilla pod text maps to its canonical catalog item.',
      p_confidence_score => 0.99
    );
  elsif v_existing_alias_ingredient_id = v_target_id then
    raise notice 'skipping alias baccello di vaniglia di bourbon: active alias already points to baccello_di_vaniglia_bourbon';
  else
    raise notice 'skipping alias baccello di vaniglia di bourbon: active alias points to %, requested baccello_di_vaniglia_bourbon',
      v_existing_alias_slug;
  end if;
end $$;
