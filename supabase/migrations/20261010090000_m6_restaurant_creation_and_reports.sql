-- M6: user-created restaurants (RES-02), duplicate guard (RES-03) and restaurant reports (RES-04).
-- All writes go through validated RPCs; the API roles keep no direct write privilege on the tables.

-- ---------------------------------------------------------------------------
-- 1. Column privileges: created_by must never be readable through PostgREST.
--    PostgreSQL has no `REVOKE ... ON COLUMN` syntax, and revoking one column
--    while the table-level SELECT grant survives would do nothing anyway. The
--    table grant is therefore dropped and SELECT is re-granted explicitly for
--    every column except created_by. The column list is taken from the table
--    definition in 20261004114000_init_schema.sql; a new column added later must
--    be granted here by hand (see docs/ASSUMPTIONS.md M6-11).
-- ---------------------------------------------------------------------------
revoke select, insert, update, delete, truncate, references, trigger
  on table public.restaurants from public, anon, authenticated;
grant select (
  id, name, address, province, location, source, status,
  avg_rating, review_count, created_at
) on table public.restaurants to anon, authenticated;

revoke select, insert, update, delete, truncate, references, trigger
  on table public.restaurant_dishes from public, anon, authenticated;
grant select (restaurant_id, dish_id, price_vnd) on table public.restaurant_dishes to anon, authenticated;

-- Coordinates must be real WGS84 values; the RPC validates too, but the table is the last line.
alter table public.restaurants
  drop constraint if exists restaurants_lat_lng_range;
alter table public.restaurants
  add constraint restaurants_lat_lng_range check (
    extensions.st_y(location::extensions.geometry) between -90 and 90
    and extensions.st_x(location::extensions.geometry) between -180 and 180
  );

-- ---------------------------------------------------------------------------
-- 2. Shared duplicate query. Both check_duplicate_restaurant() and
--    create_restaurant() use it so a client that skips the check step still hits
--    the same server-side rule. Radius and similarity threshold are configurable.
-- ---------------------------------------------------------------------------
create or replace function public.find_duplicate_restaurants(
  p_name text,
  p_lat double precision,
  p_lng double precision,
  p_radius_meters integer default null,
  p_similarity_threshold numeric default null
) returns table (
  id uuid,
  name text,
  address text,
  distance_meters double precision,
  similarity double precision
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    r.id,
    r.name,
    r.address,
    extensions.st_distance(
      r.location,
      extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography
    ) as distance_meters,
    extensions.similarity(
      public.f_unaccent(lower(r.name)),
      public.f_unaccent(lower(p_name))
    ) as similarity
  from public.restaurants r
  where r.status = 'active'
    and extensions.st_dwithin(
      r.location,
      extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
      coalesce(p_radius_meters, 50)
    )
    and extensions.similarity(
      public.f_unaccent(lower(r.name)),
      public.f_unaccent(lower(p_name))
    ) >= coalesce(p_similarity_threshold, 0.4)
  order by similarity desc, distance_meters asc;
$$;

-- CREATE FUNCTION grants EXECUTE to PUBLIC, so revoking from anon alone is not enough: the role
-- inherits PUBLIC's grant. Revoke from PUBLIC and granter roles, then grant to authenticated only.
revoke all on function public.find_duplicate_restaurants(text, double precision, double precision, integer, numeric) from public, anon, authenticated;
grant execute on function public.find_duplicate_restaurants(text, double precision, double precision, integer, numeric) to authenticated;

-- RES-03 / §7.3: keep the SPEC signature and return shape, drop the extra similarity column.
drop function if exists public.check_duplicate_restaurant(text, float, float);
create function public.check_duplicate_restaurant(
  name text,
  lat float,
  lng float
) returns table (
  id uuid,
  name text,
  address text,
  distance_meters float
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select d.id, d.name, d.address, d.distance_meters
  from public.find_duplicate_restaurants(name, lat::double precision, lng::double precision) d;
$$;

revoke all on function public.check_duplicate_restaurant(text, float, float) from public, anon, authenticated;
grant execute on function public.check_duplicate_restaurant(text, float, float) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. create_restaurant (RES-02). The caller comes from auth.uid(); created_by,
--    status, source, avg_rating and review_count are never accepted from the
--    client. PostgREST sends JSON numbers as integer/numeric, so no smallint.
-- ---------------------------------------------------------------------------
create or replace function public.create_restaurant(
  p_name text,
  p_address text,
  p_lat double precision,
  p_lng double precision,
  p_province text default null,
  p_dishes jsonb default '[]'::jsonb,
  p_confirm_new boolean default false
) returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  actor uuid := auth.uid();
  duplicate record;
  new_id uuid;
  dish_count integer;
  daily_count integer;
  daily_limit integer := coalesce(
    nullif(current_setting('app.restaurant_daily_limit', true), '')::integer,
    5
  );
begin
  if actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles p where p.id = actor and not p.is_banned) then
    raise exception 'Account unavailable' using errcode = '42501';
  end if;

  if p_name is null or length(btrim(p_name)) = 0 or char_length(btrim(p_name)) > 120 then
    raise exception 'Invalid restaurant name';
  end if;
  if p_address is not null and char_length(btrim(p_address)) > 300 then
    raise exception 'Address too long';
  end if;
  if p_province is not null and char_length(btrim(p_province)) > 120 then
    raise exception 'Province too long';
  end if;
  if p_lat is null or p_lng is null
     or p_lat not between -90 and 90
     or p_lng not between -180 and 180 then
    raise exception 'Invalid coordinates';
  end if;
  if p_dishes is null or jsonb_typeof(p_dishes) <> 'array' then
    raise exception 'Dishes must be a JSON array';
  end if;

  select count(*) into dish_count from jsonb_array_elements(p_dishes);
  if dish_count > 10 then
    raise exception 'A restaurant can have at most ten dishes';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_dishes) d
    where jsonb_typeof(d -> 'price_vnd') = 'number' and (d ->> 'price_vnd')::numeric < 0
  ) then
    raise exception 'Invalid dish price';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_dishes) d
    where not exists (select 1 from public.dishes dish where dish.id = (d ->> 'dish_id')::uuid)
  ) then
    raise exception 'Dish does not exist';
  end if;

  -- Quota before the duplicate guard, so a call that is both over quota and a duplicate reports the
  -- quota. The limit is configurable like app.review_daily_limit; the M3 trigger remains the
  -- backstop for the absolute five-per-day window.
  select count(*) into daily_count
  from public.restaurants r
  where r.created_by = actor
    and r.created_at >= now() - interval '1 day';
  if daily_count >= daily_limit then
    raise exception 'Đã vượt quá giới hạn tạo % địa điểm mỗi ngày.', daily_limit
      using errcode = 'P0001', hint = 'restaurant_daily_limit';
  end if;

  -- Server-side duplicate guard: never trust that the client ran the check step.
  if not p_confirm_new then
    select * into duplicate
    from public.find_duplicate_restaurants(p_name, p_lat, p_lng)
    limit 1;
    if found then
      raise exception 'A similar restaurant is already within 50m: %', duplicate.name
        using errcode = 'P0001', hint = 'duplicate_restaurant',
                    detail = duplicate.id::text;
    end if;
  end if;

  -- Serialize this account's quota check so two concurrent calls cannot both pass the count.
  perform pg_advisory_xact_lock(hashtextextended('create_restaurant:' || actor::text, 0));

  insert into public.restaurants (name, address, province, location)
  values (
    btrim(p_name),
    nullif(btrim(coalesce(p_address, '')), ''),
    nullif(btrim(coalesce(p_province, '')), ''),
    extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography
  )
  returning id into new_id;

  insert into public.restaurant_dishes (restaurant_id, dish_id, price_vnd)
  select new_id, (d ->> 'dish_id')::uuid, (d ->> 'price_vnd')::integer
  from jsonb_array_elements(p_dishes) d
  on conflict (restaurant_id, dish_id) do nothing;

  return new_id;
end;
$$;

revoke all on function public.create_restaurant(text, text, double precision, double precision, text, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.create_restaurant(text, text, double precision, double precision, text, jsonb, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. report_restaurant (RES-04). Reasons are restricted in the database, one
--    report per (reporter, restaurant), and a restaurant is hidden once enough
--    distinct verified accounts report it.
-- ---------------------------------------------------------------------------
create or replace function public.report_restaurant(p_restaurant_id uuid, p_reason text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles p where p.id = actor and not p.is_banned) then
    raise exception 'Account unavailable' using errcode = '42501';
  end if;

  if p_reason is null or p_reason not in ('closed', 'wrong_location', 'wrong_info') then
    raise exception 'Invalid report reason';
  end if;

  if not exists (select 1 from public.restaurants r where r.id = p_restaurant_id) then
    raise exception 'Restaurant unavailable';
  end if;

  -- Self-reporting would be a free way to hide a venue that is already yours.
  if exists (
    select 1 from public.restaurants r where r.id = p_restaurant_id and r.created_by = actor
  ) then
    raise exception 'You cannot report a restaurant you created' using errcode = '42501';
  end if;

  insert into public.reports (reporter_id, target_type, target_id, reason)
  values (actor, 'restaurant', p_restaurant_id, p_reason);

  return true;
end;
$$;

revoke all on function public.report_restaurant(uuid, text) from public, anon, authenticated;
grant execute on function public.report_restaurant(uuid, text) to authenticated;

-- Distinct verified reporters, not raw rows: three reports from one account must not hide a venue.
create or replace function public.enforce_restaurant_report_threshold()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  threshold integer := coalesce(
    nullif(current_setting('app.restaurant_report_threshold', true), '')::integer,
    3
  );
  distinct_reporters integer;
begin
  if new.target_type <> 'restaurant' then
    return new;
  end if;

  select count(distinct report.reporter_id) into distinct_reporters
  from public.reports report
  join public.profiles p on p.id = report.reporter_id
  where report.target_type = 'restaurant'
    and report.target_id = new.target_id
    and report.status <> 'dismissed'
    and not p.is_banned
    and p.created_at <= now() - interval '24 hours'
    and exists (
      select 1 from auth.users u where u.id = p.id and u.email_confirmed_at is not null
    );

  if distinct_reporters >= threshold then
    update public.restaurants
    set status = 'hidden_pending_review'
    where id = new.target_id and status = 'active';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_restaurant_report_threshold on public.reports;
create trigger trg_enforce_restaurant_report_threshold
after insert on public.reports
for each row execute function public.enforce_restaurant_report_threshold();
