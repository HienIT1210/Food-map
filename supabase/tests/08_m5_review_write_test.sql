begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select extensions.plan(13);

-- CI diagnostic: a signature mismatch must show its own evidence instead of a bare 42883.
select extensions.diag('>>> save_review args: '
  || coalesce((select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'save_review'), 'MISSING'));
select extensions.diag('>>> add_review_photo args: '
  || coalesce((select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'add_review_photo'), 'MISSING'));

set local role postgres;
set local "request.jwt.claims" to '{}';
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a5050000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'm5-author@example.test', '', now(), now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a5050000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'm5-voter@example.test', '', now(), now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a5050000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'm5-new@example.test', '', null, now(), now());
update public.profiles set created_at = now() - interval '3 days'
where id in ('a5050000-0000-4000-8000-000000000001', 'a5050000-0000-4000-8000-000000000002');
insert into public.restaurants (id, name, address, province, location)
values ('a5050000-0000-4000-8000-000000000010', 'M5 Review Fixture', 'M5 test address', 'Ha Noi',
  extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326));
insert into public.restaurants (id, name, address, province, location)
select ('a5050000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'M5 Limit Fixture ' || n, 'M5 test address', 'Ha Noi',
  extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326)
from generate_series(11, 20) as series(n);
insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous)
values ('a5050000-0000-4000-8000-000000000020', 'a5050000-0000-4000-8000-000000000001',
  'a5050000-0000-4000-8000-000000000010', 4, 'Existing review', false);
insert into public.reviews (id, user_id, restaurant_id, rating, content)
select ('a5050000-0000-4000-8000-' || lpad((100 + n)::text, 12, '0'))::uuid,
  'a5050000-0000-4000-8000-000000000001',
  ('a5050000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  4, 'Daily limit fixture'
from generate_series(11, 19) as series(n);
insert into public.review_photos (review_id, storage_path, position)
select 'a5050000-0000-4000-8000-000000000020',
  'a5050000-0000-4000-8000-000000000020/' || n || '.jpg', n::smallint
from generate_series(1, 5) as series(n);

select extensions.ok(
  not has_function_privilege('anon', 'public.save_review(uuid,uuid,integer,text,boolean)', 'EXECUTE'),
  'anon cannot execute the review write RPC'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a5050000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.is(
  public.save_review('a5050000-0000-4000-8000-000000000010', null, 5, 'Updated through RPC', false),
  'a5050000-0000-4000-8000-000000000020'::uuid,
  'save_review updates the existing restaurant-level review'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is((select count(*)::integer from public.reviews where user_id = 'a5050000-0000-4000-8000-000000000001'), 10,
  'updating the same restaurant and dish does not create another review row');
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a5050000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.is(
  (select id from public.my_reviews() where restaurant_id = 'a5050000-0000-4000-8000-000000000010'),
  'a5050000-0000-4000-8000-000000000020'::uuid,
  'my_reviews lists the caller review through an explicit safe RPC result'
);
select extensions.throws_ok(
  $$select public.save_review('a5050000-0000-4000-8000-000000000020', null, 5, 'Eleventh review', false)$$,
  'P0001', null, 'the server rejects an eleventh review in the rolling day'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a5050000-0000-4000-8000-000000000003","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.save_review('a5050000-0000-4000-8000-000000000010', null, 5, 'Too soon anonymous', true)$$,
  '42501', null, 'anonymous review requires a verified email and an account at least 24 hours old'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a5050000-0000-4000-8000-000000000002","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.save_review('a5050000-0000-4000-8000-000000000020', null, 5, 'Eligible anonymous review', true)$$,
  'a verified account older than 24 hours can post anonymously'
);
select extensions.is(
  public.toggle_review_helpful('a5050000-0000-4000-8000-000000000020'), true,
  'another user can mark a review helpful'
);
set local "request.jwt.claims" to '{"sub":"a5050000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.toggle_review_helpful('a5050000-0000-4000-8000-000000000020')$$,
  '42501', null, 'a user cannot mark their own review helpful'
);
select extensions.throws_ok(
  $$select public.add_review_photo('a5050000-0000-4000-8000-000000000020', 'a5050000-0000-4000-8000-000000000020/6.jpg', 5)$$,
  'P0001', null, 'server rejects a sixth review photo'
);
select extensions.throws_ok(
  $$insert into public.review_photos (review_id, storage_path, position) values ('a5050000-0000-4000-8000-000000000020', 'a5050000-0000-4000-8000-000000000020/6.jpg', 5)$$,
  '42501', null, 'review photo metadata writes must use the ownership-checked RPC'
);
select extensions.throws_ok(
  $$insert into public.reviews (user_id, restaurant_id, rating) values (auth.uid(), 'a5050000-0000-4000-8000-000000000010', 3)$$,
  '42501', null, 'review inserts must go through the validated RPC'
);
set local "request.jwt.claims" to '{"sub":"a5050000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.delete_review('a5050000-0000-4000-8000-000000000020')$$,
  'review owner can delete their review through the RPC'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is(
  (select count(*)::integer from public.review_photos where review_id = 'a5050000-0000-4000-8000-000000000020'),
  0,
  'deleting the review cascades its photo metadata rows'
);

select * from extensions.finish();
rollback;
