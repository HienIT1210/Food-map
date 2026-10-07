begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select extensions.plan(5);

select is(
  (select count(*)::int from public.restaurants_in_bounds(10.70, 106.5, 10.90, 106.8, '{"max_price":40000}'::jsonb, 500)),
  0,
  'M3 max-price filter excludes seed dishes over the selected budget'
);

select extensions.ok(
  (select count(*) > 0 and count(*) < 30 from public.restaurants_in_bounds(10.70, 106.5, 10.90, 106.8, '{"min_rating":4.5}'::jsonb, 500)),
  'M3 minimum-rating filter changes the result set'
);

select extensions.ok(
  (select count(*) > 0 and count(*) < 30 from public.restaurants_in_bounds(10.70, 106.5, 10.90, 106.8, '{"dish_type":"Phở"}'::jsonb, 500)),
  'M3 dish-type filter changes the result set'
);

select is(
  (select count(*)::int from public.restaurants_in_bounds(10.70, 106.5, 10.90, 106.8, '{"province":"Hồ Chí Minh"}'::jsonb, 500)),
  30,
  'M3 province filter returns matching restaurants'
);

select extensions.ok(
  (select bool_or('Phở' = any(dish_types)) from public.restaurants_in_bounds(10.70, 106.5, 10.90, 106.8, '{}'::jsonb, 500)),
  'M3 bounds RPC includes dish types for list mode'
);

select * from extensions.finish();
rollback;
