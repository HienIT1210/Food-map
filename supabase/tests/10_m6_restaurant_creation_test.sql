-- M6: restaurant creation (RES-02), duplicate guard (RES-03), restaurant reports (RES-04).
-- Fixtures live in the a606... UUID range so they never collide with 01/02/05/08/09.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select extensions.plan(49);

-- First CI run evidence: print every new signature so a mismatch is never a bare 42883.
select extensions.diag('>>> create_restaurant args: '
  || coalesce((select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'create_restaurant'), 'MISSING'));
select extensions.diag('>>> check_duplicate_restaurant args: '
  || coalesce((select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'check_duplicate_restaurant'), 'MISSING'));
select extensions.diag('>>> find_duplicate_restaurants args: '
  || coalesce((select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'find_duplicate_restaurants'), 'MISSING'));
select extensions.diag('>>> report_restaurant args: '
  || coalesce((select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'report_restaurant'), 'MISSING'));

-- ---------------------------------------------------------------------------
-- Fixtures: database owner, JWT claims cleared so triggers never blame a session.
-- ---------------------------------------------------------------------------
set local role postgres;
set local "request.jwt.claims" to '{}';

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a6060000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'm6-owner@example.test', '', now(), now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a6060000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'm6-reporter@example.test', '', now(), now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a6060000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'm6-banned@example.test', '', now(), now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a6060000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', 'm6-quota@example.test', '', now(), now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a6060000-0000-4000-8000-000000000005', 'authenticated', 'authenticated', 'm6-young@example.test', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a6060000-0000-4000-8000-000000000006', 'authenticated', 'authenticated', 'm6-reporter2@example.test', '', now(), now() - interval '3 days', now()),
  ('00000000-0000-0000-0000-000000000000', 'a6060000-0000-4000-8000-000000000007', 'authenticated', 'authenticated', 'm6-reporter3@example.test', '', now(), now() - interval '3 days', now());

-- handle_new_user() already inserted the profiles; only adjust the fields under test.
update public.profiles set created_at = now() - interval '3 days'
where id in (
  'a6060000-0000-4000-8000-000000000001', 'a6060000-0000-4000-8000-000000000002',
  'a6060000-0000-4000-8000-000000000003', 'a6060000-0000-4000-8000-000000000004',
  'a6060000-0000-4000-8000-000000000006', 'a6060000-0000-4000-8000-000000000007'
);
update public.profiles set is_banned = true where id = 'a6060000-0000-4000-8000-000000000003';

insert into public.restaurants (id, name, address, province, location, created_by)
values
  ('a6060000-0000-4000-8000-000000000010', 'M6 Bún', '10 M6 Street', 'Ha Noi',
   extensions.st_setsrid(extensions.st_makepoint(105.81, 21.01), 4326),
   'a6060000-0000-4000-8000-000000000002'),
  ('a6060000-0000-4000-8000-000000000011', 'M6 Bún', '11 M6 Street', 'Ha Noi',
   extensions.st_setsrid(extensions.st_makepoint(105.85, 21.05), 4326),
   'a6060000-0000-4000-8000-000000000002'),
  ('a6060000-0000-4000-8000-000000000012', 'M6 Báo Cáo', '12 M6 Street', 'Ha Noi',
   extensions.st_setsrid(extensions.st_makepoint(105.82, 21.02), 4326),
   'a6060000-0000-4000-8000-000000000001'),
  ('a6060000-0000-4000-8000-000000000013', 'M6 Bị Báo Hai Người', '13 M6 Street', 'Ha Noi',
   extensions.st_setsrid(extensions.st_makepoint(105.83, 21.03), 4326),
   'a6060000-0000-4000-8000-000000000002'),
  ('a6060000-0000-4000-8000-000000000014', 'M6 Bị Báo Ba Người', '14 M6 Street', 'Ha Noi',
   extensions.st_setsrid(extensions.st_makepoint(105.84, 21.04), 4326),
   'a6060000-0000-4000-8000-000000000002');

insert into public.dish_categories (id, name) values ('a6060000-0000-4000-8000-000000000030', 'M6 category');
insert into public.dishes (id, name, normalized_name, category_id)
values ('a6060000-0000-4000-8000-000000000020', 'M6 Phở', 'm6 pho', 'a6060000-0000-4000-8000-000000000030');

-- The quota fixture already holds one restaurant, so two more fit before the daily cap is 3.
update public.restaurants
set created_at = now() - interval '10 days'
where created_by = 'a6060000-0000-4000-8000-000000000004';
select extensions.diag('>>> fixtures ready: quota user existing restaurants = '
  || (select count(*)::text from public.restaurants where created_by = 'a6060000-0000-4000-8000-000000000004')
  || ', report-threshold targets = 2');

-- ---------------------------------------------------------------------------
-- M6-01..M6-07: the API roles hold no direct write privilege and anon holds no RPC.
-- ---------------------------------------------------------------------------
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  $$insert into public.restaurants (name, location) values ('Direct M6 write', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326))$$,
  '42501', null, 'M6-01: authenticated cannot insert restaurants directly'
);
select extensions.throws_ok(
  $$update public.restaurants set name = 'Renamed' where id = 'a6060000-0000-4000-8000-000000000010'$$,
  '42501', null, 'M6-02: authenticated cannot update restaurants directly'
);
select extensions.throws_ok(
  $$insert into public.restaurant_dishes (restaurant_id, dish_id) values ('a6060000-0000-4000-8000-000000000010', 'a6060000-0000-4000-8000-000000000020')$$,
  '42501', null, 'M6-03: authenticated cannot insert restaurant_dishes directly'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is(
  (select count(*)::integer from public.restaurants where name = 'Direct M6 write'),
  0,
  'M6-04: the denied direct insert created no row (privileged read-back)'
);

set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
select extensions.throws_ok(
  $$select public.create_restaurant('Anon created', 'addr', 21.01, 105.81)$$,
  '42501', null, 'M6-05: anon cannot execute create_restaurant'
);
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000012', 'closed')$$,
  '42501', null, 'M6-06: anon cannot execute report_restaurant'
);
select extensions.throws_ok(
  $$select public.check_duplicate_restaurant('M6 Bún', 21.01::float, 105.81::float)$$,
  '42501', null, 'M6-07: anon cannot execute check_duplicate_restaurant'
);

-- ---------------------------------------------------------------------------
-- M6-08..M6-13: the duplicate lookup returns safe columns only.
-- ---------------------------------------------------------------------------
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.is(
  (select count(*)::int from public.check_duplicate_restaurant('M6 Bún', 21.01::float, 105.81::float)
   where id = 'a6060000-0000-4000-8000-000000000010'),
  1,
  'M6-08: check_duplicate_restaurant finds the near identical name'
);
select extensions.ok(
  (select distance_meters >= 0 and distance_meters < 50
   from public.check_duplicate_restaurant('M6 Bún', 21.01::float, 105.81::float)
   where id = 'a6060000-0000-4000-8000-000000000010'),
  'M6-09: the reported distance is within the 50m radius'
);
select extensions.is(
  (select count(*)::int from public.check_duplicate_restaurant('M6 Bún', 21.01::float, 105.81::float)
   where id = 'a6060000-0000-4000-8000-000000000011'),
  0,
  'M6-10: a same-named restaurant more than 50m away is not a duplicate'
);
select extensions.is(
  (select count(*)::int from public.check_duplicate_restaurant('m6 bun', 21.01::float, 105.81::float)
   where id = 'a6060000-0000-4000-8000-000000000010'),
  1,
  'M6-11: the match ignores accents and letter case'
);
select extensions.is(
  (select count(*)::int from public.check_duplicate_restaurant('M6 Hoàn Toàn Khác', 21.01::float, 105.81::float)),
  0,
  'M6-12: a different name inside the radius is not a duplicate'
);
select extensions.ok(
  not has_column_privilege('authenticated', 'public.restaurants', 'created_by', 'SELECT'),
  'M6-13: authenticated cannot read the created_by column'
);

-- ---------------------------------------------------------------------------
-- M6-14..M6-19: create_restaurant rules (canonical fields, spoofing, validation).
-- ---------------------------------------------------------------------------
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Quán Mới', '12 M6 Street', 21.05, 105.85, 'Ha Noi')$$,
  'M6-14: a signed-in user can create a restaurant'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.ok(
  (select source = 'user' and status = 'active' and created_by = 'a6060000-0000-4000-8000-000000000001'
   from public.restaurants where name = 'M6 Quán Mới'),
  'M6-15: source and status are canonical and created_by is the caller'
);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Quán Khác', '13 M6 Street', 21.07, 105.87, 'Ha Noi',
    '[{"dish_id":"a6060000-0000-4000-8000-000000000020","price_vnd":25000,"created_by":"a6060000-0000-4000-8000-000000000002","status":"removed","source":"seed","avg_rating":5}]'::jsonb)$$,
  'M6-16: create_restaurant accepts the dish list'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.ok(
  (select source = 'user' and status = 'active' and avg_rating = 0 and review_count = 0
     and created_by = 'a6060000-0000-4000-8000-000000000001'
   from public.restaurants where name = 'M6 Quán Khác'),
  'M6-17: spoofed created_by/status/source/rating inside p_dishes are ignored'
);
select extensions.is(
  (select price_vnd from public.restaurant_dishes
   where restaurant_id = (select id from public.restaurants where name = 'M6 Quán Khác')
     and dish_id = 'a6060000-0000-4000-8000-000000000020'),
  25000,
  'M6-18: the accepted dish is linked with its price'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.create_restaurant('M6 Bad Coords', 'nowhere', 91, 200)$$,
  'P0001', null, 'M6-19: out-of-range coordinates are refused'
);

-- ---------------------------------------------------------------------------
-- M6-20..M6-24: duplicate refusal, confirmation flag and the daily quota.
-- A fresh user keeps the quota cases isolated from the restaurants created above.
-- ---------------------------------------------------------------------------
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000004","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.create_restaurant('M6 Bún', 'near duplicate', 21.0101, 105.8101)$$,
  'P0001', null, 'M6-20: an unconfirmed duplicate is refused'
);
select extensions.throws_ok(
  $$select public.create_restaurant('M6 Bún', 'near duplicate', 21.0101, 105.8101)$$,
  'duplicate_restaurant', null, 'M6-21: the duplicate refusal carries the duplicate_restaurant hint'
);
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Bún', 'confirmed as a different place', 21.0101, 105.8101, null, '[]'::jsonb, true)$$,
  'M6-22: confirming "this is a different place" creates the restaurant next to a similar name'
);
select extensions.throws_ok(
  $$select public.create_restaurant('M6 Quota Ba', '14 M6 Street', 21.08, 105.88)$$,
  'P0001', null, 'M6-23: the daily quota refuses the next restaurant'
);
select extensions.throws_ok(
  $$select public.create_restaurant('M6 Quota Ba', '14 M6 Street', 21.08, 105.88)$$,
  'Đã vượt quá giới hạn tạo 5 địa điểm mỗi ngày.', null,
  'M6-24: the quota refusal is the documented daily-limit error'
);

-- ---------------------------------------------------------------------------
-- M6-25..M6-28: report_restaurant guards.
-- ---------------------------------------------------------------------------
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000012', 'closed')$$,
  '42501', null, 'M6-25: a user cannot report a restaurant they created'
);
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000012', 'not a reason')$$,
  'P0001', null, 'M6-26: an unsupported report reason is refused'
);
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000003","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.create_restaurant('M6 Banned Quán', 'banned', 21.3, 105.3)$$,
  '42501', null, 'M6-27: a banned account cannot create a restaurant'
);
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000012', 'closed')$$,
  '42501', null, 'M6-28: a banned account cannot report a restaurant'
);

-- ---------------------------------------------------------------------------
-- M6-29..M6-33: threshold behaviour, snapshot before/after, one-person repeat.
-- ---------------------------------------------------------------------------
set local role postgres;
set local "request.jwt.claims" to '{}';
select set_config('app.restaurant_report_threshold', '2', true);
create temp table _m6_status_before on commit drop as
  select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000013';
select extensions.diag('>>> BEFORE threshold reports: restaurant ...013 status = '
  || coalesce((select status from _m6_status_before), 'NULL')
  || ' (threshold=2, expected active)');

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000013', 'closed')$$,
  'M6-29: one account can report a restaurant it did not create'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is(
  (select count(distinct reporter_id)::integer from public.reports
   where target_type = 'restaurant' and target_id = 'a6060000-0000-4000-8000-000000000013'),
  1,
  'M6-30: the report is stored as one distinct reporter'
);
select set_config('app.restaurant_report_threshold', '3', true);
select extensions.is(
  (select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000013'),
  (select status from _m6_status_before),
  'M6-31: below the threshold the status is unchanged from the snapshot'
);

-- The same person reporting the same restaurant again must not count twice.
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000013', 'wrong_location')$$,
  '23505', null, 'M6-32: one account cannot report the same restaurant twice'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is(
  (select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000013'),
  'active',
  'M6-33: a repeated report from the same account leaves the restaurant active'
);

-- ---------------------------------------------------------------------------
-- M6-34..M6-36: reaching the threshold hides the restaurant everywhere.
-- ---------------------------------------------------------------------------
create temp table _m6_status_before_hide on commit drop as
  select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000014';
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000014', 'closed')$$,
  'M6-34: the first report on the three-reporter target is accepted'
);
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000006","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000014', 'wrong_info')$$,
  'M6-35: the second distinct report is accepted'
);
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000007","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000014', 'wrong_location')$$,
  'M6-36: the third distinct report is accepted and reaches the threshold'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.diag('>>> AFTER threshold reports: restaurant ...014 status = '
  || coalesce((select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000014'), 'NULL')
  || ' (threshold=3, three distinct reporters, expected hidden_pending_review)');
select extensions.is(
  (select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000014'),
  'hidden_pending_review',
  'M6-37: reaching three distinct reporters hides the restaurant'
);
select extensions.ok(
  (select status from _m6_status_before_hide) = 'active'
  and (select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000014') = 'hidden_pending_review',
  'M6-38: the status changed from the pre-report snapshot, not by assumption'
);
select extensions.is(
  (select count(*)::int from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9)
   where id = 'a6060000-0000-4000-8000-000000000013'),
  1,
  'M6-39: an active restaurant in the same box is still visible, so the next assertion can fail'
);
select extensions.is(
  (select count(*)::int from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9)
   where id = 'a6060000-0000-4000-8000-000000000014'),
  0,
  'M6-40: a hidden restaurant disappears from restaurants_in_bounds'
);
select extensions.is(
  (select count(*)::int from public.search_restaurants('M6 Bị Báo Ba Người', 50)
   where id = 'a6060000-0000-4000-8000-000000000014'),
  0,
  'M6-41: a hidden restaurant disappears from search'
);

-- ---------------------------------------------------------------------------
-- M6-42..M6-43: privacy of reports and of created_by through the API.
-- ---------------------------------------------------------------------------
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000005","role":"authenticated"}';
select extensions.is(
  (select count(*)::int from public.reports),
  0,
  'M6-42: a user with no reports cannot read anyone else reports'
);
set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
select extensions.ok(
  not has_column_privilege('anon', 'public.restaurants', 'created_by', 'SELECT')
  and has_column_privilege('anon', 'public.restaurants', 'name', 'SELECT'),
  'M6-43: anon keeps the safe restaurant columns but not created_by'
);

-- ---------------------------------------------------------------------------
-- M6-44..M6-49: the column-level SELECT contract. The list is compared against the catalog so a
-- column added later without an explicit grant cannot slip through unnoticed.
-- ---------------------------------------------------------------------------
select extensions.diag('>>> restaurants columns without SELECT for anon: '
  || coalesce((
       select string_agg(c.column_name, ', ' order by c.column_name)
       from information_schema.columns c
       where c.table_schema = 'public' and c.table_name = 'restaurants'
         and not has_column_privilege('anon', 'public.restaurants', c.column_name, 'SELECT')
     ), '(none)'));
select extensions.diag('>>> restaurants columns without SELECT for authenticated: '
  || coalesce((
       select string_agg(c.column_name, ', ' order by c.column_name)
       from information_schema.columns c
       where c.table_schema = 'public' and c.table_name = 'restaurants'
         and not has_column_privilege('authenticated', 'public.restaurants', c.column_name, 'SELECT')
     ), '(none)'));
select extensions.diag('>>> column privileges actually granted on public.restaurants: '
  || coalesce((
       select string_agg(grantee || ' on ' || column_name, ', ' order by grantee, column_name)
       from information_schema.column_privileges
       where table_schema = 'public' and table_name = 'restaurants'
         and grantee in ('anon', 'authenticated')
         and privilege_type = 'SELECT'
     ), '(none)'));

select extensions.ok(
  not has_table_privilege('anon', 'public.restaurants', 'SELECT')
  and not has_table_privilege('authenticated', 'public.restaurants', 'SELECT'),
  'M6-44: neither API role holds table-level SELECT on restaurants'
);
select extensions.ok(
  has_column_privilege('anon', 'public.restaurants', 'id', 'SELECT')
  and has_column_privilege('anon', 'public.restaurants', 'status', 'SELECT')
  and has_column_privilege('authenticated', 'public.restaurants', 'review_count', 'SELECT')
  and has_column_privilege('authenticated', 'public.restaurants', 'created_at', 'SELECT'),
  'M6-45: the public columns stay readable for both roles'
);
select extensions.ok(
  (
    select count(*)::integer
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = 'restaurants'
      and c.column_name <> 'created_by'
      and not has_column_privilege('anon', 'public.restaurants', c.column_name, 'SELECT')
  ) = 0,
  'M6-46: every non-created_by column is granted to anon'
);
select extensions.ok(
  (
    select count(*)::integer
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = 'restaurants'
      and c.column_name <> 'created_by'
      and not has_column_privilege('authenticated', 'public.restaurants', c.column_name, 'SELECT')
  ) = 0,
  'M6-47: every non-created_by column is granted to authenticated'
);

set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
select extensions.throws_ok(
  'select created_by from public.restaurants',
  '42501', null, 'M6-48: anon reading created_by gets a privilege error, not rows'
);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  'select created_by from public.restaurants',
  '42501', null, 'M6-49: authenticated reading created_by gets a privilege error, not rows'
);

select * from extensions.finish(true);
rollback;
