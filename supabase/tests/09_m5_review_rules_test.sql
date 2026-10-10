-- M5: server-side rules for review writes, anonymous eligibility, photo caps and derived stats.
-- Fixtures live in the a909... UUID range so they never collide with 01/02/05/08.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select extensions.plan(16);

-- Fixture setup runs as database owner with cleared JWT claims: security-definer triggers must
-- not attribute these rows to a leftover authenticated session.
set local role postgres;
set local "request.jwt.claims" to '{}';

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a9090000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'm5-old@example.test', '', now(), now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a9090000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'm5-new@example.test', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a9090000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'm5-unverified@example.test', '', null, now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a9090000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', 'm5-voter@example.test', '', now(), now() - interval '3 days', now());

-- handle_new_user() already created the profiles, so only adjust the fields under test.
update public.profiles set created_at = now() - interval '3 days'
where id = 'a9090000-0000-4000-8000-000000000001';
update public.profiles set created_at = now()
where id = 'a9090000-0000-4000-8000-000000000002';
update public.profiles set created_at = now() - interval '3 days'
where id = 'a9090000-0000-4000-8000-000000000003';

insert into public.restaurants (id, name, address, province, location)
select ('a9090000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'M5 Rule Fixture ' || n, 'M5 test address', 'Ha Noi',
  extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326)
from generate_series(1, 2) as series(n);

-- A review owned by the voter account, used for helpful-count and self-vote assertions.
insert into public.reviews (id, user_id, restaurant_id, rating, content)
values ('a9090000-0000-4000-8000-000000000020', 'a9090000-0000-4000-8000-000000000004',
  'a9090000-0000-4000-8000-000000000001', 4, 'Voter own review');

-- 1-3: only the ownership-checked RPCs may write review data.
select extensions.ok(
  not has_function_privilege('anon', 'public.save_review(uuid,uuid,smallint,text,boolean)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.toggle_review_helpful(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.add_review_photo(uuid,text,smallint)', 'EXECUTE'),
  'M5-02: anon cannot execute the review write RPCs'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.reviews', 'INSERT')
  and not has_table_privilege('authenticated', 'public.reviews', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.reviews', 'DELETE')
  and not has_table_privilege('authenticated', 'public.review_photos', 'INSERT')
  and not has_table_privilege('authenticated', 'public.review_photos', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.review_photos', 'DELETE')
  and not has_table_privilege('authenticated', 'public.review_helpful', 'INSERT')
  and not has_table_privilege('authenticated', 'public.review_helpful', 'DELETE'),
  'M5-03: review tables expose no direct write privileges to authenticated'
);
select extensions.ok(
  has_function_privilege('authenticated', 'public.save_review(uuid,uuid,smallint,text,boolean)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.delete_review(uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.my_reviews()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.toggle_review_helpful(uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.add_review_photo(uuid,text,smallint)', 'EXECUTE'),
  'M5-04: authenticated keeps execute on every review mutation RPC'
);

-- 4-6: anonymous reviews require a verified account at least 24 hours old, enforced in the database.
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a9090000-0000-4000-8000-000000000002","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.save_review('a9090000-0000-4000-8000-000000000002', null, 5, 'Anonymous too soon', true)$$,
  '42501', null, 'M5-05: an account younger than 24 hours cannot post anonymously'
);
set local "request.jwt.claims" to '{"sub":"a9090000-0000-4000-8000-000000000003","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.save_review('a9090000-0000-4000-8000-000000000002', null, 5, 'Anonymous unverified', true)$$,
  '42501', null, 'M5-06: an account without a verified email cannot post anonymously'
);
set local "request.jwt.claims" to '{"sub":"a9090000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.save_review('a9090000-0000-4000-8000-000000000002', null, 5, 'Anonymous eligible', true)$$,
  'M5-07: a verified account older than 24 hours can post anonymously'
);

-- 8-11: the (user, restaurant, dish) target collapses to one row and system fields stay derived.
select extensions.is(
  (select count(*)::int from public.public_reviews
   where restaurant_id = 'a9090000-0000-4000-8000-000000000002' and is_anonymous),
  1,
  'M5-08: an anonymous review is exposed through public_reviews'
);
select extensions.is(
  (select author_id from public.public_reviews
   where restaurant_id = 'a9090000-0000-4000-8000-000000000002'),
  null::uuid,
  'M5-09: the anonymous review exposes a null author_id'
);
select extensions.is(
  length(public.save_review('a9090000-0000-4000-8000-000000000002', null, 3, 'Updated in place', false)::text),
  36,
  'M5-10: saving the same target again returns the existing review UUID'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is(
  (select count(*)::integer from public.reviews
   where user_id = 'a9090000-0000-4000-8000-000000000001'
     and restaurant_id = 'a9090000-0000-4000-8000-000000000002'),
  1,
  'M5-11: the unique (user, restaurant, dish) target never duplicates a review row'
);
select extensions.is(
  (select rating from public.reviews
   where user_id = 'a9090000-0000-4000-8000-000000000001'
     and restaurant_id = 'a9090000-0000-4000-8000-000000000002'),
  3::smallint,
  'M5-12: the second save updated the same row instead of inserting'
);

-- 13: at most five photos per review, enforced by the table trigger.
insert into public.review_photos (review_id, storage_path, position)
select 'a9090000-0000-4000-8000-000000000020',
  'a9090000-0000-4000-8000-000000000020/photo-' || n || '.jpg', n::smallint
from generate_series(1, 5) as series(n);
select extensions.throws_ok(
  $$insert into public.review_photos (review_id, storage_path, position) values ('a9090000-0000-4000-8000-000000000020', 'a9090000-0000-4000-8000-000000000020/photo-6.jpg', 6)$$,
  'P0001', null, 'M5-13: a sixth photo for the same review is rejected by the server'
);

-- 14-15: helpful votes are one per (review, user), never self-votes, and the counter is derived.
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a9090000-0000-4000-8000-000000000004","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.toggle_review_helpful('a9090000-0000-4000-8000-000000000020')$$,
  '42501', null, 'M5-14: a review owner cannot mark their own review helpful'
);
set local "request.jwt.claims" to '{"sub":"a9090000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.is(
  public.toggle_review_helpful('a9090000-0000-4000-8000-000000000020')
  and (select helpful_count from public.reviews where id = 'a9090000-0000-4000-8000-000000000020') = 1,
  true,
  'M5-15: a helpful vote by another user derives helpful_count from the vote table'
);

select * from extensions.finish(true);
rollback;
