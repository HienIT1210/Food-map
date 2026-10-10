-- M6: restaurant creation (RES-02), duplicate guard (RES-03), restaurant reports (RES-04).
-- Fixtures live in the a606... UUID range so they never collide with 01/02/05/08/09.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select extensions.plan(62);

-- ---------------------------------------------------------------------------
-- Shared helper: throws_ok's third argument is a MESSAGE pattern, so a test that needs the HINT
-- (or the detail) cannot use it. This runs the statement in its own subtransaction, captures
-- sqlstate/message/hint/detail and returns them, so callers assert sqlstate and hint separately.
-- ---------------------------------------------------------------------------
create function pg_temp.capture_error(p_sql text)
returns table (sqlstate text, message text, hint text, detail text)
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics
      sqlstate = returned_sqlstate,
      message = message_text,
      hint = pg_exception_hint,
      detail = pg_exception_detail;
    return next;
  end;
  -- No exception: return one row with NULLs so a caller assertion fails instead of erroring out.
  sqlstate := null; message := null; hint := null; detail := null;
  return next;
end;
$$;
grant execute on function pg_temp.capture_error(text) to public;

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

-- The quota user (a606...004) starts with NO restaurants on purpose: the quota block below creates
-- exactly app.restaurant_daily_limit places through the RPC, so the count it asserts is exact and
-- the refused call is the (N+1)-th. The three restaurants above belong to other users.
select extensions.diag('>>> fixtures ready: quota user existing restaurants = '
  || (select count(*)::text from public.restaurants where created_by = 'a6060000-0000-4000-8000-000000000004')
  || ' (must be 0), report-threshold targets = 2');

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
-- M6-20..M6-35: duplicate refusal, quota limit and the configurable limit, confirmation flag and the daily quota.
-- The quota user starts with no restaurants, so the N places created below are exactly the
-- configured limit and the N+1 call is the only one that can be refused.
-- ---------------------------------------------------------------------------
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000004","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.create_restaurant('M6 Bún', 'near duplicate', 21.0101, 105.8101)$$,
  'A similar restaurant is already within 50m%', null,
  'M6-20: an unconfirmed duplicate is refused'
);
-- The hint is a separate column of the error, so it must be captured and asserted separately:
-- throws_ok's third argument is a message pattern and cannot match a hint.
select extensions.is((select hint from pg_temp.capture_error(
  $$select public.create_restaurant('M6 Bún', 'near duplicate', 21.0101, 105.8101)$$)),
  'duplicate_restaurant',
  'M6-21: the duplicate refusal carries the duplicate_restaurant hint'
);
select extensions.diag('>>> duplicate refusal captured: sqlstate='
  || coalesce((select sqlstate from pg_temp.capture_error(
       $$select public.create_restaurant('M6 Bún', 'near duplicate', 21.0101, 105.8101)$$)), 'NULL')
  || ' hint=' || coalesce((select hint from pg_temp.capture_error(
       $$select public.create_restaurant('M6 Bún', 'near duplicate', 21.0101, 105.8101)$$)), 'NULL')
  || ' detail=' || coalesce((select detail from pg_temp.capture_error(
       $$select public.create_restaurant('M6 Bún', 'near duplicate', 21.0101, 105.8101)$$)), 'NULL'));
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Bún', 'confirmed as a different place', 21.0101, 105.8101, null, '[]'::jsonb, true)$$,
  'M6-22: confirming "this is a different place" creates the restaurant next to a similar name'
);

-- Fill the quota with N = app.restaurant_daily_limit places (default 5). Names differ and the
-- coordinates are more than 50m apart, and p_confirm_new stays false, so no call here can be a
-- duplicate and the refusal below can only be the quota.
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Quota Một', '15 M6 Street', 21.09, 105.89)$$,
  'M6-23: the second place of the day is allowed'
);
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Quota Hai', '16 M6 Street', 21.10, 105.90)$$,
  'M6-24: the third place of the day is allowed'
);
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Quota Ba', '17 M6 Street', 21.11, 105.91)$$,
  'M6-25: the fourth place of the day is allowed'
);
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Quota Bốn', '18 M6 Street', 21.12, 105.92)$$,
  'M6-26: the fifth place of the day is allowed, reaching the default limit'
);
-- The count assertion and the diagnostic must sit BEFORE the refused call, using exactly the
-- predicate the RPC uses, so the next run proves the limit really was reached.
select extensions.is(
  (select count(*)::int from public.restaurants
   where created_by = 'a6060000-0000-4000-8000-000000000004'
     and created_at >= now() - interval '1 day'),
  coalesce(nullif(current_setting('app.restaurant_daily_limit', true), '')::integer, 5),
  'M6-27: the caller holds exactly app.restaurant_daily_limit places in the last day'
);
select extensions.diag('>>> before the N+1 call: app.restaurant_daily_limit='
  || coalesce(current_setting('app.restaurant_daily_limit', true), '(unset -> default 5)')
  || ' count by the RPC predicate (created_by + last 24h)='
  || (select count(*)::text from public.restaurants
      where created_by = 'a6060000-0000-4000-8000-000000000004'
        and created_at >= now() - interval '1 day')
  || ' trigger reads the same setting since M6');
select extensions.is((select sqlstate from pg_temp.capture_error(
  $$select public.create_restaurant('M6 Quota Sáu', '19 M6 Street', 21.13, 105.93)$$)),
  'P0001',
  'M6-28: the N+1 call fails with the P0001 quota error'
);
select extensions.is((select hint from pg_temp.capture_error(
  $$select public.create_restaurant('M6 Quota Sáu', '19 M6 Street', 21.13, 105.93)$$)),
  'restaurant_daily_limit',
  'M6-29: the N+1 refusal carries the restaurant_daily_limit hint'
);
-- Quota is checked before the duplicate guard (ASSUMPTIONS M6-12): a call that is both over quota
-- and a duplicate must report the quota.
select extensions.is((select hint from pg_temp.capture_error(
  $$select public.create_restaurant('M6 Bún', 'near duplicate', 21.0101, 105.8101)$$)),
  'restaurant_daily_limit',
  'M6-30: an over-quota duplicate reports the quota hint, not the duplicate hint'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is(
  (select count(*)::int from public.restaurants
   where created_by = 'a6060000-0000-4000-8000-000000000004'
     and created_at >= now() - interval '1 day'),
  5,
  'M6-31: the refused calls created no additional restaurant (snapshot is still N)'
);
select extensions.diag('>>> after the refused calls: app.restaurant_daily_limit='
  || coalesce(current_setting('app.restaurant_daily_limit', true), '(unset -> default 5)')
  || ' count used by the RPC (created_by + last 24h)='
  || (select count(*)::text from public.restaurants
      where created_by = 'a6060000-0000-4000-8000-000000000004'
        and created_at >= now() - interval '1 day')
  || ' trigger reads the same setting since M6');
select extensions.diag('>>> quota user rows: '
  || coalesce((
       select string_agg(r.name || ' | created_by=' || coalesce(r.created_by::text, 'NULL')
              || ' | created_at=' || r.created_at::text || ' | status=' || r.status
              || ' | source=' || r.source, ' ;; ' order by r.created_at)
       from public.restaurants r
       where r.created_by = 'a6060000-0000-4000-8000-000000000004'
     ), '(none)'));

-- The limit must be configurable, not hard-coded in one layer: with the setting at 2 the RPC and
-- the M3 trigger both refuse the third place. User ...003 is banned, so use the young account
-- ...005 with the ban flag temporarily irrelevant (it is not banned, only young) and a raised
-- setting for anonymity checks, which do not apply to create_restaurant.
select set_config('app.restaurant_daily_limit', '2', true);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000005","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Limit Hai 1', '20 M6 Street', 21.20, 105.70)$$,
  'M6-32: with app.restaurant_daily_limit=2 the first place is allowed'
);
select extensions.lives_ok(
  $$select public.create_restaurant('M6 Limit Hai 2', '21 M6 Street', 21.21, 105.71)$$,
  'M6-33: with app.restaurant_daily_limit=2 the second place is allowed'
);
select extensions.is((select hint from pg_temp.capture_error(
  $$select public.create_restaurant('M6 Limit Hai 3', '22 M6 Street', 21.22, 105.72)$$)),
  'restaurant_daily_limit',
  'M6-34: the third place is refused by the configured limit, not a hard-coded five'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select set_config('app.restaurant_daily_limit', '5', true);
select extensions.is(
  (select count(*)::int from public.restaurants
   where created_by = 'a6060000-0000-4000-8000-000000000005'
     and created_at >= now() - interval '1 day'),
  2,
  'M6-35: the configured limit stopped the third call (still two rows)'
);

-- ---------------------------------------------------------------------------
-- M6-36..M6-39: report_restaurant guards.
-- ---------------------------------------------------------------------------
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000012', 'closed')$$,
  '42501', null, 'M6-36: a user cannot report a restaurant they created'
);
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000012', 'not a reason')$$,
  'P0001', null, 'M6-37: an unsupported report reason is refused'
);
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000003","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.create_restaurant('M6 Banned Quán', 'banned', 21.3, 105.3)$$,
  '42501', null, 'M6-38: a banned account cannot create a restaurant'
);
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000012', 'closed')$$,
  '42501', null, 'M6-39: a banned account cannot report a restaurant'
);

-- ---------------------------------------------------------------------------
-- M6-29..M6-44: threshold behaviour, snapshot before/after, one-person repeat.
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
  'M6-40: one account can report a restaurant it did not create'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is(
  (select count(distinct reporter_id)::integer from public.reports
   where target_type = 'restaurant' and target_id = 'a6060000-0000-4000-8000-000000000013'),
  1,
  'M6-41: the report is stored as one distinct reporter'
);
select set_config('app.restaurant_report_threshold', '3', true);
select extensions.is(
  (select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000013'),
  (select status from _m6_status_before),
  'M6-42: below the threshold the status is unchanged from the snapshot'
);

-- The same person reporting the same restaurant again must not count twice.
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000013', 'wrong_location')$$,
  '23505', null, 'M6-43: one account cannot report the same restaurant twice'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.is(
  (select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000013'),
  'active',
  'M6-44: a repeated report from the same account leaves the restaurant active'
);

-- ---------------------------------------------------------------------------
-- M6-45..M6-47: reaching the threshold hides the restaurant everywhere.
-- ---------------------------------------------------------------------------
create temp table _m6_status_before_hide on commit drop as
  select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000014';
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000014', 'closed')$$,
  'M6-45: the first report on the three-reporter target is accepted'
);
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000006","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000014', 'wrong_info')$$,
  'M6-46: the second distinct report is accepted'
);
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000007","role":"authenticated"}';
select extensions.lives_ok(
  $$select public.report_restaurant('a6060000-0000-4000-8000-000000000014', 'wrong_location')$$,
  'M6-47: the third distinct report is accepted and reaches the threshold'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.diag('>>> AFTER threshold reports: restaurant ...014 status = '
  || coalesce((select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000014'), 'NULL')
  || ' (threshold=3, three distinct reporters, expected hidden_pending_review)');
select extensions.is(
  (select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000014'),
  'hidden_pending_review',
  'M6-48: reaching three distinct reporters hides the restaurant'
);
select extensions.ok(
  (select status from _m6_status_before_hide) = 'active'
  and (select status from public.restaurants where id = 'a6060000-0000-4000-8000-000000000014') = 'hidden_pending_review',
  'M6-49: the status changed from the pre-report snapshot, not by assumption'
);
select extensions.is(
  (select count(*)::int from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9)
   where id = 'a6060000-0000-4000-8000-000000000013'),
  1,
  'M6-50: an active restaurant in the same box is still visible, so the next assertion can fail'
);
select extensions.is(
  (select count(*)::int from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9)
   where id = 'a6060000-0000-4000-8000-000000000014'),
  0,
  'M6-51: a hidden restaurant disappears from restaurants_in_bounds'
);
select extensions.is(
  (select count(*)::int from public.search_restaurants('M6 Bị Báo Ba Người', 50)
   where id = 'a6060000-0000-4000-8000-000000000014'),
  0,
  'M6-52: a hidden restaurant disappears from search'
);

-- ---------------------------------------------------------------------------
-- M6-53..M6-54: privacy of reports and of created_by through the API.
-- ---------------------------------------------------------------------------
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000005","role":"authenticated"}';
select extensions.is(
  (select count(*)::int from public.reports),
  0,
  'M6-53: a user with no reports cannot read anyone else reports'
);
set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
select extensions.ok(
  not has_column_privilege('anon', 'public.restaurants', 'created_by', 'SELECT')
  and has_column_privilege('anon', 'public.restaurants', 'name', 'SELECT'),
  'M6-54: anon keeps the safe restaurant columns but not created_by'
);

-- ---------------------------------------------------------------------------
-- M6-56..M6-61: the column-level SELECT contract. Everything here runs as postgres:
-- information_schema.column_privileges only shows rows the CURRENT role can see, which is why an
-- earlier diagnostic printed "(none)" while the grant was in fact missing. The sweep uses
-- pg_attribute plus has_column_privilege(), which answer for any requested role.
-- ---------------------------------------------------------------------------
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.diag('>>> created_by visible to postgres itself? '
  || has_column_privilege('postgres', 'public.restaurants', 'created_by', 'SELECT')::text
  || ' | table-level SELECT for anon='
  || has_table_privilege('anon', 'public.restaurants', 'SELECT')::text
  || ' authenticated='
  || has_table_privilege('authenticated', 'public.restaurants', 'SELECT')::text);
select extensions.diag('>>> SELECT privilege per column (postgres-verified): '
  || coalesce((
       select string_agg(
         a.attname || ': anon=' || has_column_privilege('anon', 'public.restaurants', a.attname, 'SELECT')::text
         || ' authenticated=' || has_column_privilege('authenticated', 'public.restaurants', a.attname, 'SELECT')::text,
         ' ;; ' order by a.attnum)
       from pg_attribute a
       where a.attrelid = 'public.restaurants'::regclass
         and a.attnum > 0
         and not a.attisdropped
     ), '(none)'));

select extensions.ok(
  not has_table_privilege('anon', 'public.restaurants', 'SELECT')
  and not has_table_privilege('authenticated', 'public.restaurants', 'SELECT'),
  'M6-55: neither API role holds table-level SELECT on restaurants'
);
select extensions.ok(
  has_column_privilege('anon', 'public.restaurants', 'id', 'SELECT')
  and has_column_privilege('anon', 'public.restaurants', 'status', 'SELECT')
  and has_column_privilege('authenticated', 'public.restaurants', 'review_count', 'SELECT')
  and has_column_privilege('authenticated', 'public.restaurants', 'created_at', 'SELECT'),
  'M6-56: the public columns stay readable for both roles'
);
select extensions.ok(
  (
    select count(*)::integer
    from pg_attribute a
    where a.attrelid = 'public.restaurants'::regclass
      and a.attnum > 0
      and not a.attisdropped
      and a.attname <> 'created_by'
      and not has_column_privilege('anon', 'public.restaurants', a.attname, 'SELECT')
  ) = 0,
  'M6-57: every non-created_by column is granted to anon'
);
select extensions.ok(
  (
    select count(*)::integer
    from pg_attribute a
    where a.attrelid = 'public.restaurants'::regclass
      and a.attnum > 0
      and not a.attisdropped
      and a.attname <> 'created_by'
      and not has_column_privilege('authenticated', 'public.restaurants', a.attname, 'SELECT')
  ) = 0,
  'M6-58: every non-created_by column is granted to authenticated'
);

set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
select extensions.throws_ok(
  'select created_by from public.restaurants',
  '42501', null, 'M6-59: anon reading created_by gets a privilege error, not rows'
);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"a6060000-0000-4000-8000-000000000001","role":"authenticated"}';
select extensions.throws_ok(
  'select created_by from public.restaurants',
  '42501', null, 'M6-60: authenticated reading created_by gets a privilege error, not rows'
);

-- M6-62/M6-63: the shared duplicate helper must not be callable by anon. CREATE FUNCTION grants
-- EXECUTE to PUBLIC, so the revoke has to name PUBLIC as well.
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.diag('>>> find_duplicate_restaurants execute: anon='
  || has_function_privilege('anon', 'public.find_duplicate_restaurants(text, double precision, double precision, integer, numeric)', 'EXECUTE')::text
  || ' authenticated='
  || has_function_privilege('authenticated', 'public.find_duplicate_restaurants(text, double precision, double precision, integer, numeric)', 'EXECUTE')::text
  || ' public='
  || has_function_privilege('public', 'public.find_duplicate_restaurants(text, double precision, double precision, integer, numeric)', 'EXECUTE')::text);
select extensions.ok(
  not has_function_privilege('anon', 'public.find_duplicate_restaurants(text, double precision, double precision, integer, numeric)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.find_duplicate_restaurants(text, double precision, double precision, integer, numeric)', 'EXECUTE'),
  'M6-61: the duplicate helper is callable by authenticated but not by anon'
);
set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
select extensions.throws_ok(
  $$select public.find_duplicate_restaurants('M6 Bún', 21.01, 105.81)$$,
  '42501', null, 'M6-62: anon calling the duplicate helper directly is refused'
);

select * from extensions.finish(true);
rollback;
