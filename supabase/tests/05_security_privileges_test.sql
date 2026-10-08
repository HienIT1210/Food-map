begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select extensions.plan(24);

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
) as fixture(user_id);

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
select extensions.ok(
  has_column_privilege('authenticated', 'public.restaurants', 'name', 'INSERT')
  and has_column_privilege('authenticated', 'public.restaurants', 'created_by', 'INSERT')
  and not has_table_privilege('authenticated', 'public.restaurants', 'INSERT'),
  'R7: restaurant insert is restricted to granted columns'
);

-- A normal user insert must get canonical system values from the trigger.
set local "request.jwt.claims" to '{"sub":"50555555-5555-5555-5555-555555555555","role":"authenticated"}';
select extensions.lives_ok(
  $$insert into public.restaurants (name, location, created_by) values ('Canonical restaurant', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), auth.uid())$$,
  'R8: authenticated can create a restaurant using only user-editable fields'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.ok(
  (select source = 'user' and status = 'active' and avg_rating = 0 and review_count = 0 and created_at > now() - interval '1 minute'
   from public.restaurants where name = 'Canonical restaurant'),
  'R9: restaurant trigger sets source, status, counters and created_at'
);

-- Ten user-backdated reviews expose the old created_at-based limit bypass.
set local "request.jwt.claims" to '{}';
do $$
declare
  restaurant_id uuid;
begin
  for i in 1..13 loop
    insert into public.restaurants (name, location)
    values ('Review limit fixture ' || i, extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326))
    returning id into restaurant_id;
    if i <= 10 then
      insert into public.reviews (user_id, restaurant_id, rating, created_at)
      values ('40444444-4444-4444-4444-444444444444', restaurant_id, 5, now() - interval '30 days');
    end if;
  end loop;
end;
$$;
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"40444444-4444-4444-4444-444444444444","role":"authenticated"}';
select extensions.throws_ok(
  $$insert into public.reviews (user_id, restaurant_id, rating, created_at) values (auth.uid(), (select id from public.restaurants where name = 'Review limit fixture 11'), 5, now() - interval '30 days')$$,
  '42501', null, 'R10: authenticated cannot backdate a review to evade the daily limit'
);
select extensions.throws_ok(
  $$insert into public.reviews (user_id, restaurant_id, rating, helpful_count) values (auth.uid(), (select id from public.restaurants where name = 'Review limit fixture 12'), 5, 100)$$,
  '42501', null, 'R11: authenticated cannot set review helpful_count'
);
select extensions.throws_ok(
  $$insert into public.reviews (user_id, restaurant_id, rating, status) values (auth.uid(), (select id from public.restaurants where name = 'Review limit fixture 13'), 5, 'removed')$$,
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
select extensions.throws_ok(
  $$insert into public.saved_items (user_id, restaurant_id, list_type, created_at) values (auth.uid(), (select id from public.restaurants where name = 'Canonical restaurant'), 'want_to_try', now() - interval '30 days')$$,
  '42501', null, 'R18: authenticated cannot set saved_items created_at'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.blocks', 'UPDATE')
  and has_column_privilege('authenticated', 'public.blocks', 'blocker_id', 'INSERT')
  and has_column_privilege('authenticated', 'public.blocks', 'blocked_id', 'INSERT'),
  'R19: blocks permit only key-column inserts and no table-level update'
);
select extensions.ok(
  has_column_privilege('authenticated', 'public.review_photos', 'review_id', 'INSERT')
  and has_column_privilege('authenticated', 'public.review_photos', 'storage_path', 'INSERT')
  and not has_table_privilege('authenticated', 'public.review_photos', 'INSERT'),
  'R20: review photo insert is restricted to user-editable columns'
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
  has_column_privilege('authenticated', 'public.reviews', 'content', 'INSERT')
  and not has_column_privilege('authenticated', 'public.reviews', 'created_at', 'INSERT')
  and not has_table_privilege('authenticated', 'public.reviews', 'INSERT'),
  'R23: review insert excludes system-managed fields'
);
select extensions.throws_ok(
  $$update public.reports set status = 'resolved' where reporter_id = auth.uid()$$,
  '42501', null, 'R24: authenticated cannot update report status'
);

select * from extensions.finish();
rollback;
