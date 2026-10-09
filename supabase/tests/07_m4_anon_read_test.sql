begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select extensions.plan(8);

set local role postgres;
set local "request.jwt.claims" to '{}';
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a4040000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'm4-search@example.test', '', now(), now(), now());
insert into public.dish_categories (id, name) values ('a4040000-0000-4000-8000-000000000002', 'M4 test category');
insert into public.dishes (id, name, normalized_name, category_id, aliases)
values ('a4040000-0000-4000-8000-000000000003', 'Phở bò M4', 'pho bo m4', 'a4040000-0000-4000-8000-000000000002', array['phở bò sốt vang']);
insert into public.restaurants (id, name, address, province, location)
values (
  'a4040000-0000-4000-8000-000000000004',
  'Quán M4 Search Fixture',
  '82 Nguyễn Huệ',
  'Hồ Chí Minh',
  extensions.st_setsrid(extensions.st_makepoint(106.7, 10.8), 4326)
);
insert into public.restaurant_dishes (restaurant_id, dish_id, price_vnd)
values ('a4040000-0000-4000-8000-000000000004', 'a4040000-0000-4000-8000-000000000003', 45000);
insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous)
values (
  'a4040000-0000-4000-8000-000000000005',
  'a4040000-0000-4000-8000-000000000001',
  'a4040000-0000-4000-8000-000000000004',
  5,
  'M4 anonymous review fixture',
  true
);

set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
set local search_path = public;
select extensions.ok(
  has_function_privilege('anon', 'public.search_restaurants(text,integer)', 'EXECUTE'),
  'anon can execute search_restaurants'
);
select extensions.is(
  (select id from public.search_restaurants('pho bo', 20) where id = 'a4040000-0000-4000-8000-000000000004'),
  'a4040000-0000-4000-8000-000000000004'::uuid,
  'anon search finds Phở bò when query omits Vietnamese accents'
);
select extensions.is(
  (select id from public.search_restaurants('quan m4 search', 20) where id = 'a4040000-0000-4000-8000-000000000004'),
  'a4040000-0000-4000-8000-000000000004'::uuid,
  'anon search matches restaurant names without accents'
);
select extensions.is(
  (select id from public.search_restaurants('pho bee', 20) where id = 'a4040000-0000-4000-8000-000000000004'),
  'a4040000-0000-4000-8000-000000000004'::uuid,
  'anon search tolerates a small dish-name typo'
);
select extensions.is(
  (select id from public.search_restaurants('nguyen hue', 20) where id = 'a4040000-0000-4000-8000-000000000004'),
  'a4040000-0000-4000-8000-000000000004'::uuid,
  'anon search matches restaurant addresses without accents'
);
select extensions.is(
  (select id from public.restaurant_detail('a4040000-0000-4000-8000-000000000004')),
  'a4040000-0000-4000-8000-000000000004'::uuid,
  'anon can read public restaurant details through the detail RPC'
);
select extensions.is(
  (select author_id from public.public_reviews where id = 'a4040000-0000-4000-8000-000000000005'),
  null::uuid,
  'anon sees no author id for an anonymous review'
);
select extensions.ok(
  not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'public_reviews' and column_name = 'user_id'
  ),
  'public_reviews has no user_id column'
);

select * from extensions.finish();
rollback;
