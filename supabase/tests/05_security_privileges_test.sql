begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select extensions.plan(25);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', user_id, 'authenticated', 'authenticated', user_id::text || '@security.test', '', now(), now(), now()
from (values
  ('10111111-1111-1111-1111-111111111111'::uuid),
  ('20222222-2222-2222-2222-222222222222'::uuid),
  ('30333333-3333-3333-3333-333333333333'::uuid),
  ('40444444-4444-4444-4444-444444444444'::uuid),
  ('50555555-5555-5555-5555-555555555555'::uuid)
) as fixture(user_id);

insert into public.profiles (id, display_name)
select user_id, 'Security fixture'
from (values
  ('10111111-1111-1111-1111-111111111111'::uuid),
  ('20222222-2222-2222-2222-222222222222'::uuid),
  ('30333333-3333-3333-3333-333333333333'::uuid),
  ('40444444-4444-4444-4444-444444444444'::uuid),
  ('50555555-5555-5555-5555-555555555555'::uuid)
) as fixture(user_id)
on conflict (id) do update
set display_name = excluded.display_name;

-- Actor 1 fills today's restaurant allowance, then tries the user-controlled seed escape.
set local role postgres;
set local "request.jwt.claims" to '{}';
do $$
begin
  for i in 1..5 loop
    insert into public.restaurants (name, location, created_by)
    values ('Seed bypass fixture ' || i, extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), '10111111-1111-1111-1111-111111111111');
  end loop;
end;
$$;
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"10111111-1111-1111-1111-111111111111","role":"authenticated"}';
select extensions.throws_ok(
  $$insert into public.restaurants (name, location, created_by, source) values ('Seed bypass', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), auth.uid(), 'seed')$$,
  '42501', null, 'R1: authenticated cannot use source=seed to bypass the restaurant limit'
);

-- Actor 2 attempts to move their sixth restaurant outside the count window.
set local role postgres;
set local "request.jwt.claims" to '{}';
do $$
begin
  for i in 1..5 loop
    insert into public.restaurants (name, location, created_by, created_at)
    values ('Backdate fixture ' || i, extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), '20222222-2222-2222-2222-222222222222', now() - interval '30 days');
  end loop;
end;
$$;
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"20222222-2222-2222-2222-222222222222","role":"authenticated"}';
select extensions.throws_ok(
  $$insert into public.restaurants (name, location, created_by, created_at) values ('Backdated sixth', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), auth.uid(), now() - interval '30 days')$$,
  '42501', null, 'R2: authenticated cannot backdate a restaurant to evade the daily limit'
);

-- Actor 3 tries each system-managed restaurant field independently.
set local "request.jwt.claims" to '{"sub":"30333333-3333-3333-3333-333333333333","role":"authenticated"}';
select extensions.throws_ok(
  $$insert into public.restaurants (name, location, created_by, avg_rating) values ('Forged rating', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), auth.uid(), 5)$$,
  '42501', null, 'R3: authenticated cannot set restaurant avg_rating'
);
select extensions.throws_ok(
  $$insert into public.restaurants (name, location, created_by, review_count) values ('Forged count', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), auth.uid(), 99)$$,
  '42501', null, 'R4: authenticated cannot set restaurant review_count'
);
select extensions.throws_ok(
  $$insert into public.restaurants (name, location, created_by, status) values ('Forged status', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), auth.uid(), 'active')$$,
  '42501', null, 'R5: authenticated cannot set restaurant status'
);
select extensions.throws_ok(
  $$insert into public.restaurants (name, location, created_by, source) values ('Forged source', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), auth.uid(), 'user')$$,
  '42501', null, 'R6: authenticated cannot set restaurant source'
);
-- R7/R8/R9 keep their slots but now describe the M6 contract: no table or column write on
-- restaurants, and creation only through create_restaurant, which the trigger then canonicalizes.
select extensions.ok(
  not has_column_privilege('authenticated', 'public.restaurants', 'name', 'INSERT')
  and not has_column_privilege('authenticated', 'public.restaurants', 'created_by', 'INSERT')
  and not has_table_privilege('authenticated', 'public.restaurants', 'INSERT'),
  'R7: authenticated holds no insert privilege on restaurants at table or column level'
);
select extensions.throws_ok(
  $$insert into public.restaurants (name, location, created_by) values ('Direct write', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), auth.uid())$$,
  '42501', null, 'R7b: a direct restaurant insert is denied'
);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"50555555-5555-5555-5555-555555555555","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.create_restaurant('f05e0000-canonical', 'fixture address', 21.05, 105.85)$$,
  'R8: authenticated can create a restaurant through the RPC with user-editable fields only'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.ok(
  (select source = 'user' and status = 'active' and avg_rating = 0 and review_count = 0
     and created_at > now() - interval '1 minute'
   from public.restaurants where name = 'f05e0000-canonical'),
  'R9: the create path sets source, status, counters and created_at'
);

-- Ten user-backdated reviews expose the old created_at-based limit bypass.
-- M6 revoked every write privilege on restaurants, so the fixtures are created as postgres and get
-- fixed ids: the review assertions below must not read public.restaurants as an API role, otherwise
-- they would fail on a privilege error from the subquery instead of from the insert they test.
set local "request.jwt.claims" to '{}';
create temp table _r_review_fixtures on commit drop as
  select ('d05e0000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid as id, n
  from generate_series(1, 13) as series(n);
do $$
declare
  fixture record;
begin
  for fixture in select id, n from _r_review_fixtures order by n loop
    insert into public.restaurants (id, name, location)
    values (fixture.id, 'Review limit fixture ' || fixture.n,
      extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326));
    if fixture.n <= 10 then
      insert into public.reviews (user_id, restaurant_id, rating, created_at)
      values ('40444444-4444-4444-4444-444444444444', fixture.id, 5, now() - interval '30 days');
    end if;
  end loop;
end;
$$;
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"40444444-4444-4444-4444-444444444444","role":"authenticated"}';
select extensions.throws_ok(
  $$insert into public.reviews (user_id, restaurant_id, rating, created_at) values (auth.uid(), 'd05e0000-0000-4000-8000-000000000011', 5, now() - interval '30 days')$$,
  '42501', null, 'R10: authenticated cannot backdate a review to evade the daily limit'
);
select extensions.throws_ok(
  $$insert into public.reviews (user_id, restaurant_id, rating, helpful_count) values (auth.uid(), 'd05e0000-0000-4000-8000-000000000012', 5, 100)$$,
  '42501', null, 'R11: authenticated cannot set review helpful_count'
);
select extensions.throws_ok(
  $$insert into public.reviews (user_id, restaurant_id, rating, status) values (auth.uid(), 'd05e0000-0000-4000-8000-000000000013', 5, 'removed')$$,
  '42501', null, 'R12: authenticated cannot set review status'
);
select extensions.throws_ok(
  $$update public.reviews set helpful_count = 100 where user_id = auth.uid()$$,
  '42501', null, 'R13: authenticated cannot update review helpful_count'
);
select extensions.throws_ok(
  $$update public.reviews set status = 'removed' where user_id = auth.uid()$$,
  '42501', null, 'R14: authenticated cannot update review status'
);
select extensions.throws_ok(
  $$update public.reviews set created_at = now() - interval '30 days' where user_id = auth.uid()$$,
  '42501', null, 'R15: authenticated cannot update review created_at'
);

-- System-managed fields on the other user-write tables are unavailable as well.
select extensions.throws_ok(
  $$insert into public.reports (reporter_id, target_type, target_id, reason, status) values (auth.uid(), 'restaurant', gen_random_uuid(), 'test', 'resolved')$$,
  '42501', null, 'R16: authenticated cannot set report status'
);
select extensions.throws_ok(
  $$insert into public.reports (reporter_id, target_type, target_id, reason, created_at) values (auth.uid(), 'restaurant', gen_random_uuid(), 'test', now() - interval '30 days')$$,
  '42501', null, 'R17: authenticated cannot set report created_at'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
create temp table _r_canonical on commit drop as
  select id from public.restaurants where name = 'f05e0000-canonical';
select extensions.diag('>>> R8/R9 canonical restaurant id = '
  || coalesce((select id::text from _r_canonical), 'MISSING'));

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"40444444-4444-4444-4444-444444444444","role":"authenticated"}';
select extensions.throws_ok(
  $$insert into public.saved_items (user_id, restaurant_id, list_type, created_at) values (auth.uid(), (select id from _r_canonical), 'want_to_try', now() - interval '30 days')$$,
  '42501', null, 'R18: authenticated cannot set saved_items created_at'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.blocks', 'UPDATE')
  and has_column_privilege('authenticated', 'public.blocks', 'blocker_id', 'INSERT')
  and has_column_privilege('authenticated', 'public.blocks', 'blocked_id', 'INSERT'),
  'R19: blocks permit only key-column inserts and no table-level update'
);
-- M5 moved every review, review_photo and helpful-vote write behind the ownership-checked RPCs,
-- so the API roles must hold no INSERT/UPDATE/DELETE privilege on those tables at all. The
-- assertions stay in the same slots (R20, R23) and keep the same security property.
select extensions.ok(
  not has_table_privilege('authenticated', 'public.review_photos', 'INSERT')
  and not has_table_privilege('authenticated', 'public.review_photos', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.review_photos', 'DELETE')
  and has_function_privilege('authenticated', 'public.add_review_photo(uuid,text,integer)', 'EXECUTE'),
  'R20: review photo writes require the RPC, not table privileges'
);
select extensions.ok(
  has_column_privilege('authenticated', 'public.saved_items', 'list_type', 'INSERT')
  and not has_column_privilege('authenticated', 'public.saved_items', 'created_at', 'INSERT')
  and not has_table_privilege('authenticated', 'public.saved_items', 'INSERT'),
  'R21: saved item insert excludes system-managed created_at'
);
select extensions.ok(
  has_column_privilege('authenticated', 'public.reports', 'reason', 'INSERT')
  and not has_column_privilege('authenticated', 'public.reports', 'status', 'INSERT')
  and not has_table_privilege('authenticated', 'public.reports', 'INSERT'),
  'R22: report insert excludes system-managed status'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.reviews', 'INSERT')
  and not has_table_privilege('authenticated', 'public.reviews', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.reviews', 'DELETE')
  and has_function_privilege('authenticated', 'public.save_review(uuid,uuid,integer,text,boolean)', 'EXECUTE'),
  'R23: review writes require the RPC and expose no system-managed column grant'
);
select extensions.throws_ok(
  $$update public.reports set status = 'resolved' where reporter_id = auth.uid()$$,
  '42501', null, 'R24: authenticated cannot update report status'
);

select * from extensions.finish();
rollback;
