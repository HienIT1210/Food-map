begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(2);

-- Ð?c và th?c thi file seed
-- Wait, pgTAP can't easily include a file unless we use \i which is a psql command.
-- Instead, we can just check if there are 30 restaurants from seed.

select is(
  (select count(*)::int from public.restaurants where source = 'seed'),
  30,
  'T1 (M3): 30 restaurants inserted from seed'
);

select is(
  (select count(*)::int from public.restaurant_dishes where restaurant_id in (select id from public.restaurants where source = 'seed')),
  30,
  'T2 (M3): 30 restaurant_dishes inserted from seed'
);

select * from finish();
rollback;
