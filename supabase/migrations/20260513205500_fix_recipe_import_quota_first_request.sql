-- Allow a user's first Smart Import request of the day to pass immediately.
--
-- The previous implementation inserted the daily usage row with last_request_at
-- set to now(), then immediately evaluated the cooldown against that same row.
-- For brand-new users this could return TOO_FREQUENT_REQUESTS on their first
-- import attempt. Cooldown should only apply after at least one request has
-- already been consumed.

create or replace function public.consume_recipe_import_quota(
  p_user_id uuid,
  p_day_bucket date,
  p_daily_limit integer default 20,
  p_cooldown_seconds integer default 2
)
returns table(
  allowed boolean,
  reason text,
  current_count integer,
  limit_count integer,
  retry_after_seconds integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.recipe_import_usage%rowtype;
  v_now timestamptz := now();
  v_retry integer := 0;
begin
  if p_user_id is null then
    return query select false, 'unauthenticated'::text, 0, p_daily_limit, 0;
    return;
  end if;

  insert into public.recipe_import_usage(user_id, day_bucket, count, last_request_at, created_at, updated_at)
  values (p_user_id, p_day_bucket, 0, v_now, v_now, v_now)
  on conflict (user_id, day_bucket) do nothing;

  select *
  into v_existing
  from public.recipe_import_usage
  where user_id = p_user_id
    and day_bucket = p_day_bucket
  for update;

  if v_existing.count >= p_daily_limit then
    return query select false, 'daily_limit'::text, v_existing.count, p_daily_limit, 86400;
    return;
  end if;

  if v_existing.count > 0
     and p_cooldown_seconds > 0
     and extract(epoch from (v_now - v_existing.last_request_at)) < p_cooldown_seconds
  then
    v_retry := greatest(1, p_cooldown_seconds - floor(extract(epoch from (v_now - v_existing.last_request_at)))::integer);
    return query select false, 'cooldown'::text, v_existing.count, p_daily_limit, v_retry;
    return;
  end if;

  update public.recipe_import_usage
  set count = v_existing.count + 1,
      last_request_at = v_now,
      updated_at = v_now
  where user_id = p_user_id
    and day_bucket = p_day_bucket;

  return query select true, 'ok'::text, v_existing.count + 1, p_daily_limit, 0;
end;
$$;

revoke all on function public.consume_recipe_import_quota(uuid, date, integer, integer) from public;
grant execute on function public.consume_recipe_import_quota(uuid, date, integer, integer) to service_role;
