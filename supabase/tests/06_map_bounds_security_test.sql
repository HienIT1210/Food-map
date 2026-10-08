begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select extensions.plan(4);

set local role postgres;
set local "request.jwt.claims" to '{}';
insert into public.restaurants (name, location)
select
  'Bounds limit fixture ' || fixture_number,
  extensions.st_setsrid(extensions.st_makepoint(-100 + fixture_number::float / 1000, 0), 4326)
from generate_series(1, 501) as fixture(fixture_number);

set local role anon;
select extensions.is(
  (select count(*)::int from public.restaurants_in_bounds(-10, -101, 10, -99, '{}'::jsonb, 10000)),
  500,
  'B1: anon cannot raise restaurants_in_bounds above 500 rows'
);

select extensions.ok(
  (
    select bool_and(previous_id is null or previous_id <= id)
    from (
      select id, lag(id) over (order by ordinality) as previous_id
      from public.restaurants_in_bounds(-10, -101, 10, -99, '{}'::jsonb, 500)
        with ordinality as bounds(id, name, lat, lng, avg_rating, review_count, status, province, dish_types, ordinality)
    ) as ordered_bounds
  ),
  'B2: anon receives restaurants_in_bounds in stable id order'
);

select extensions.is(
  (select count(*)::int from public.restaurants_in_bounds(-10, -101, 10, -99, '{}'::jsonb, -1)),
  0,
  'B3: negative lim is clamped to zero rows'
);

select extensions.ok(
  has_function_privilege(
    'anon',
    'public.restaurants_in_bounds(double precision, double precision, double precision, double precision, jsonb, integer)',
    'EXECUTE'
  ),
  'B4: anon can execute the protected map RPC'
);

select * from extensions.finish();
rollback;
