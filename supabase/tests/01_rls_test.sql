begin;
create extension if not exists pgtap with schema extensions;

-- Khung test dùng search_path gồm public và extensions để các hàm của pgTAP luôn được phân giải chính xác
set search_path = public, extensions;

-- M5 requires every denied write to be asserted as a privilege error (42501) instead of relying on
-- RLS silently matching zero rows, which removed the bare UPDATE/DELETE statements that used to run
-- unasserted. Each denial therefore needs its own throws_ok slot, so the plan grew from 38 to 50
-- while covering the same security rules. Nothing was deleted or commented out.
select extensions.plan(52);

-- Shared helper: throws_ok's third argument is a MESSAGE pattern, so a test that needs the HINT
-- must capture the error instead. It runs the statement in its own subtransaction and returns
-- exactly ONE row: the diagnostics when the statement raised, otherwise one row of NULLs so a
-- caller assertion fails instead of the file erroring out. Output columns are named err_* because
-- PL/pgSQL declares `sqlstate` and `sqlerrm` as CONSTANT special variables (an output column with
-- those names raises "variable sqlstate is declared CONSTANT"), and the exception arm ends with a
-- plain RETURN so no second row is produced (a second row would break scalar `select err_hint ...`
-- with "more than one row returned by a subquery"). It lives in public, not pg_temp, because the
-- tests switch to the authenticated role and pg_temp schema access for another role is not
-- guaranteed.
create function public.m6_capture_error(p_sql text)
returns table (err_sqlstate text, err_message text, err_hint text, err_detail text)
language plpgsql
as $$
declare
  v_sqlstate text;
  v_message text;
  v_hint text;
  v_detail text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics
      v_sqlstate = returned_sqlstate,
      v_message = message_text,
      v_hint = pg_exception_hint,
      v_detail = pg_exception_detail;
    return query select v_sqlstate, v_message, v_hint, v_detail;
    return;
  end;
  return query select null::text, null::text, null::text, null::text;
end;
$$;
revoke all on function public.m6_capture_error(text) from public, anon, authenticated;
grant execute on function public.m6_capture_error(text) to anon, authenticated;

-- CI diagnostics: print the live signatures so a test/function mismatch shows its own evidence
-- instead of a bare 42883. These diag() calls do not consume a plan slot.
select extensions.diag('>>> save_review args: '
  || coalesce((select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'save_review'), 'MISSING'));
select extensions.diag('>>> add_review_photo args: '
  || coalesce((select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'add_review_photo'), 'MISSING'));
select extensions.diag('>>> delete_review result: '
  || coalesce((select string_agg(pg_get_function_result(p.oid), ' | ')
               from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'delete_review'), 'MISSING'));

-- Bật RLS và các triggers (nếu có)
-- Tạo data nền, cần đảm bảo user tồn tại trong cả auth.users và public.profiles
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values 
  ('00000000-0000-0000-0000-000000000000', 'aaaa1111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'a@ex.com', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbb2222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'b@ex.com', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'cccc3333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'c@ex.com', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'dddd7777-7777-7777-7777-777777777777', 'authenticated', 'authenticated', 'd@ex.com', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'eeee7777-7777-7777-7777-777777777777', 'authenticated', 'authenticated', 'e@ex.com', '', now(), now(), now());

insert into public.profiles (id, display_name) values 
  ('aaaa1111-1111-1111-1111-111111111111', 'User A'),
  ('bbbb2222-2222-2222-2222-222222222222', 'User B'),
  ('cccc3333-3333-3333-3333-333333333333', 'User C (Blocked)'),
  ('dddd7777-7777-7777-7777-777777777777', 'User D (Rate Limit)'),
  ('eeee7777-7777-7777-7777-777777777777', 'User E (Profile Privilege)')
on conflict (id) do update 
  set display_name = excluded.display_name;

-- Tạo quán (sử dụng extensions.st_* tường minh)
insert into public.restaurants (id, name, location, status) values
  ('dddd4444-4444-4444-4444-444444444444', 'Test Phở', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'active'),
  ('dddd4444-4444-4444-4444-444444444445', 'Test Bún', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'active'),
  ('dddd4444-4444-4444-4444-444444444446', 'Test Cơm', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'active'),
  ('dddd4444-4444-4444-4444-444444444447', 'Test Cháo', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'active');

-- A viết review công khai
insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous) values
  ('eeee5555-5555-5555-5555-555555555555', 'aaaa1111-1111-1111-1111-111111111111', 'dddd4444-4444-4444-4444-444444444444', 5, 'Good', false);

-- B viết review ẩn danh
insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous) values
  ('ffff6666-6666-6666-6666-666666666666', 'bbbb2222-2222-2222-2222-222222222222', 'dddd4444-4444-4444-4444-444444444444', 4, 'Ok, anonymous', true);

-- A chặn C
insert into public.blocks (blocker_id, blocked_id) values ('aaaa1111-1111-1111-1111-111111111111', 'cccc3333-3333-3333-3333-333333333333');

-- C viết review (ở quán khác để tránh đụng unique user_id + restaurant_id nếu test chạy nhiều lần)
insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous) values
  ('00007777-7777-7777-7777-777777777777', 'cccc3333-3333-3333-3333-333333333333', 'dddd4444-4444-4444-4444-444444444445', 1, 'Bad', false);

insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous) values
  ('eeee5555-5555-5555-5555-555555555556', 'aaaa1111-1111-1111-1111-111111111111', 'dddd4444-4444-4444-4444-444444444446', 5, 'T5 original', false);

insert into public.review_photos (id, review_id, storage_path) values
  ('11118888-8888-8888-8888-888888888888', 'eeee5555-5555-5555-5555-555555555555', 'users/aaaa1111-1111-1111-1111-111111111111/reviews/photo.webp');

insert into public.reports (id, reporter_id, target_type, target_id, reason) values
  ('22229999-9999-9999-9999-999999999999', 'aaaa1111-1111-1111-1111-111111111111', 'review', 'eeee5555-5555-5555-5555-555555555555', 'test report');

insert into public.saved_items (user_id, restaurant_id, list_type) values
  ('aaaa1111-1111-1111-1111-111111111111', 'dddd4444-4444-4444-4444-444444444445', 'want_to_try');

insert into public.admin_audit_log (admin_id, action, target_type, target_id) values
  ('aaaa1111-1111-1111-1111-111111111111', 'test', 'review', 'eeee5555-5555-5555-5555-555555555555');

-- Yêu cầu (a): Không lấy được user_id review ẩn danh qua public_reviews
-- A01 (assertion 1 of 52)
-- A01 trace
select extensions.diag('>>> about to run A01');
select extensions.is((select author_id from public.public_reviews where id = 'ffff6666-6666-6666-6666-666666666666'), null::uuid, 'T1 (a): Review ẩn danh không lộ author_id');
-- A02 (assertion 2 of 52)
-- A02 trace
select extensions.diag('>>> about to run A02');
select extensions.isnt((select author_id from public.public_reviews where id = 'eeee5555-5555-5555-5555-555555555555'), null::uuid, 'T2 (a): Review công khai lộ author_id');

-- Chuyển sang context User A (authenticated)
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';

-- Yêu cầu (c): Người bị chặn bị lọc
-- A03 (assertion 3 of 52)
-- A03 trace
select extensions.diag('>>> about to run A03');
select extensions.is_empty(
  'select 1 from public.public_reviews where id = ''00007777-7777-7777-7777-777777777777''',
  'T3 (c): User A không thấy review từ C trên public_reviews (bị chặn)'
);

-- Chuyển sang context User B (authenticated)
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';

-- Chứng minh Test 4 chạy đúng vai
select extensions.diag('>>> CURRENT_USER: ' || current_user::text);
-- A04 (assertion 4 of 52)
-- A04 trace
select extensions.diag('>>> about to run A04');
select extensions.is(current_user::text, 'authenticated', 'T4.1: current_user là authenticated');

select extensions.diag('>>> AUTH.UID(): ' || coalesce(auth.uid()::text, 'NULL'));
-- A05 (assertion 5 of 52)
-- A05 trace
select extensions.diag('>>> about to run A05');
select extensions.is(auth.uid(), 'bbbb2222-2222-2222-2222-222222222222'::uuid, 'T4.2: auth.uid() là User B');

-- Yêu cầu (b): B đọc được review của chính mình (chứng minh có quyền SELECT trên bảng, không bị permission denied) nhưng không đọc được của A (do RLS chặn)
-- A06 (assertion 6 of 52)
-- A06 trace
select extensions.diag('>>> about to run A06');
select extensions.is(
  (select array_agg(id order by id) from public.reviews where id in ('eeee5555-5555-5555-5555-555555555555', 'ffff6666-6666-6666-6666-666666666666')),
  array['ffff6666-6666-6666-6666-666666666666'::uuid],
  'T4.3 (b): User B đọc được review của mình nhưng không thấy review của A (chứng minh thứ chặn là RLS chứ không phải permission denied)'
);

set local role postgres;
alter policy "Users can view own reviews" on public.reviews using (true);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';

-- M5 revoked the table-level INSERT/UPDATE/DELETE grants on public.reviews, so a direct write
-- raises 42501 instead of silently matching zero rows through RLS. The security property is
-- unchanged; only the layer that denies the write moved.
-- A07 (assertion 7 of 52)
-- A07 trace
select extensions.diag('>>> about to run A07');
select extensions.throws_ok(
  'update public.reviews set content = ''Hack'' where id = ''eeee5555-5555-5555-5555-555555555556''',
  '42501', null,
  'T5a (b): User B cannot even attempt a direct UPDATE on reviews'
);
-- A08 (assertion 8 of 52)
-- A08 trace
select extensions.diag('>>> about to run A08');
select extensions.throws_ok(
  'delete from public.reviews where id = ''eeee5555-5555-5555-5555-555555555556''',
  '42501', null,
  'T5b (b): User B cannot even attempt a direct DELETE on reviews'
);

-- Reset về superuser để kiểm tra nội dung gốc.
set local role postgres;
-- A09 (assertion 9 of 52)
-- A09 trace
select extensions.diag('>>> about to run A09');
select extensions.is(
  (select content from public.reviews where id = 'eeee5555-5555-5555-5555-555555555556'),
  'T5 original',
  'T5c (b): user A review content is intact and its row still exists'
);
alter policy "Users can view own reviews" on public.reviews using (auth.uid() = user_id);
set local role postgres;
set search_path = public, extensions;

-- Yêu cầu (f): Tìm kiếm trigram
-- A10 (assertion 10 of 52)
-- A10 trace
select extensions.diag('>>> about to run A10');
select extensions.is(
  (select count(*)::int from public.search_restaurants('pho bo', 50) where id = 'dddd4444-4444-4444-4444-444444444444'),
  1,
  'T6 (f): search_restaurants tìm tên quán không dấu với đủ giới hạn kết quả'
);

-- Yêu cầu (e): Bounding box
-- A11 (assertion 11 of 52)
-- A11 trace
select extensions.diag('>>> about to run A11');
select extensions.is(
  (select count(*)::int from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9) where id = 'dddd4444-4444-4444-4444-444444444444'),
  1,
  'T7 (e): restaurants_in_bounds cô lập đếm đúng quán test trong khung'
);

-- Yêu cầu (d): Giới hạn lạm dụng (phía server)
-- Tạo thêm data bằng quyền postgres trước khi thử
set local role postgres;
set local "request.jwt.claims" to '{}';
do $$
declare
  new_rest_id uuid;
begin
  -- Thêm 10 quán khác nhau cho User D để cô lập bộ đếm review.
  for i in 1..10 loop
    new_rest_id := gen_random_uuid();
    insert into public.restaurants (id, name, location, status) values (new_rest_id, 'Quán ' || i, extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'active');
    insert into public.reviews (user_id, restaurant_id, rating, content)
    values ('dddd7777-7777-7777-7777-777777777777', new_rest_id, 5, 'Review ' || i);
  end loop;
end;
$$;

-- T24 needs the value this row holds immediately before the denied UPDATE, because the invariant
-- under test is "the denied UPDATE changes nothing". The fixture holds exactly two visible reviews
-- for this restaurant (rating 5 and 4, see the inserts above), so the expected state is avg_rating
-- 4.50 / review_count 2, maintained by the M5 stats trigger.
set local role postgres;
select extensions.diag('>>> BEFORE T8/T20/T22: restaurant dddd4444-...444 avg_rating='
  || coalesce((select avg_rating::text from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' review_count='
  || coalesce((select review_count::text from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' reviews-for-444=' || (select count(*)::text from public.reviews where restaurant_id = 'dddd4444-4444-4444-4444-444444444444')
  || ' (fixture: two visible reviews rated 5 and 4)');

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"dddd7777-7777-7777-7777-777777777777", "role":"authenticated"}';

-- T8 keeps its slot: the daily cap is asserted on the RPC the app actually calls. The 10 fixture
-- rows above leave User D exactly at the limit, so the eleventh review must be refused there.
-- A12 (assertion 12 of 52)
-- A12 trace
select extensions.diag('>>> about to run A12');
select extensions.throws_ok(
  $$select public.save_review('dddd4444-4444-4444-4444-444444444445', null, 5, 'Over limit', false)$$,
  'P0001', null,
  'T8 (d): save_review chặn review thứ 11 trong ngày (giới hạn ép ở database)'
);

-- T9: the restaurant quota. M6 revoked direct inserts, so the five places are created through
-- create_restaurant. The names differ and the coordinates are hundreds of metres apart, so a
-- refusal can only come from the quota and never from the duplicate guard; p_confirm_new stays false.
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"dddd7777-7777-7777-7777-777777777777", "role":"authenticated"}';
-- A13 (assertion 13 of 52)
-- A13 trace
select extensions.diag('>>> about to run A13');
select extensions.lives_ok(
  $$select public.create_restaurant('Quán D quota 1', null, 21.0100, 105.8100)$$,
  'T9 (d): quán D thứ 1 trong ngày được tạo qua create_restaurant'
);
-- A14 (assertion 14 of 52)
-- A14 trace
select extensions.diag('>>> about to run A14');
select extensions.lives_ok(
  $$select public.create_restaurant('Quán D quota 2', null, 21.0200, 105.8200)$$,
  'T9b (d): quán D thứ 2 trong ngày được tạo qua create_restaurant'
);
-- A15 (assertion 15 of 52)
-- A15 trace
select extensions.diag('>>> about to run A15');
select extensions.lives_ok(
  $$select public.create_restaurant('Quán D quota 3', null, 21.0300, 105.8300)$$,
  'T9c (d): quán D thứ 3 trong ngày được tạo qua create_restaurant'
);
-- A16 (assertion 16 of 52)
-- A16 trace
select extensions.diag('>>> about to run A16');
select extensions.lives_ok(
  $$select public.create_restaurant('Quán D quota 4', null, 21.0400, 105.8400)$$,
  'T9d (d): quán D thứ 4 trong ngày được tạo qua create_restaurant'
);
-- A17 (assertion 17 of 52)
-- A17 trace
select extensions.diag('>>> about to run A17');
select extensions.lives_ok(
  $$select public.create_restaurant('Quán D quota 5', null, 21.0500, 105.8500)$$,
  'T9e (d): quán D thứ 5 trong ngày được tạo qua create_restaurant'
);
-- A18 (assertion 18 of 52)
-- throws_ok's second argument is an ERRCODE, not the message, so the quota message is asserted with
-- the capture helper instead (SQLSTATE and hint each get their own assertion below).
-- A18 trace
select extensions.diag('>>> about to run A18');
select extensions.is(
  (select err_sqlstate from public.m6_capture_error(
     $$select public.create_restaurant('Quán D quota 6', null, 21.0600, 105.8600)$$)),
  'P0001',
  'T9f (d): create_restaurant chặn quán thứ 6 trong ngày với P0001'
);
-- A19 (assertion 19 of 52)
-- A19 trace
select extensions.diag('>>> about to run A19');
select extensions.is(
  (select err_hint from public.m6_capture_error(
     $$select public.create_restaurant('Quán D quota 6', null, 21.0600, 105.8600)$$)),
  'restaurant_daily_limit',
  'T9f2 (d): lỗi giới hạn quán mang hint restaurant_daily_limit'
);
-- A20 (assertion 20 of 52)
-- A20 trace
select extensions.diag('>>> about to run A20');
select extensions.ok(
  (select err_message from public.m6_capture_error(
     $$select public.create_restaurant('Quán D quota 6', null, 21.0600, 105.8600)$$))
  like 'Đã vượt quá giới hạn tạo %địa điểm mỗi ngày.',
  'T9f3 (d): thông báo giới hạn quán đúng nội dung (kiểm bằng like)'
);
set local role postgres;
set local "request.jwt.claims" to '{}';
select extensions.diag('>>> restaurant quota: app.restaurant_daily_limit='
  || coalesce(current_setting('app.restaurant_daily_limit', true), '(unset -> default 5)')
  || ' rows for user D in the last day='
  || (select count(*)::text from public.restaurants
      where created_by = 'dddd7777-7777-7777-7777-777777777777'
        and created_at >= now() - interval '1 day')
  || ' (expected: 5 rows, so the sixth RPC call is refused)');
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"dddd7777-7777-7777-7777-777777777777", "role":"authenticated"}';

-- The M3 trigger stays the backstop for any path that bypasses the RPC: a direct insert is denied
-- by privileges, and a different account still hits the five-per-day trigger message.
-- A21 (assertion 21 of 52)
-- A21 trace
select extensions.diag('>>> about to run A21');
select extensions.throws_ok(
  'insert into public.restaurants (name, location, created_by) values (''Quán D 6'', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), ''dddd7777-7777-7777-7777-777777777777'')',
  '42501', null,
  'T9g (d): insert trực tiếp restaurants bị từ chối (42501), không cấp lại quyền để test qua'
);

-- Evidence for T24: does the denied RPC leave restaurant 444 alone?
set local role postgres;
select extensions.diag('>>> AFTER T8 RPC: restaurant dddd4444-...444 avg_rating='
  || coalesce((select avg_rating::text from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' review_count='
  || coalesce((select review_count::text from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' (expected: unchanged at 4.50 / 2)');
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"dddd7777-7777-7777-7777-777777777777", "role":"authenticated"}';

-- Evidence for T24: has anything touched restaurant 444 by the end of the quota block?
set local role postgres;
select extensions.diag('>>> AFTER T9: restaurant dddd4444-...444 avg_rating='
  || coalesce((select avg_rating::text from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' review_count='
  || coalesce((select review_count::text from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' reviews-for-444=' || (select count(*)::text from public.reviews where restaurant_id = 'dddd4444-4444-4444-4444-444444444444')
  || ' (expected: unchanged at 4.50 / 2 / 2)');

set local role postgres;
set local "request.jwt.claims" to '{}';
-- A22 (assertion 22 of 52)
-- A22 trace
select extensions.diag('>>> about to run A22');
select extensions.is(
  (select count(*)::integer
   from public.restaurants
   where created_by = 'dddd7777-7777-7777-7777-777777777777'
     and name = 'Quán D quota 6'),
  0,
  'T9f4 (d): lời gọi tạo quán thứ 6 bị quota từ chối và không tạo hàng'
);

-- ==============================================================================
-- KIỂM CHỨNG TÍNH ĐỘC LẬP SEARCH_PATH (MÔ PHỎNG SUPABASE CLOUD PHIÊN GỌI CHỈ CÓ PUBLIC)
-- Chứng minh các hàm trong public chạy đúng ngay cả khi search_path của phiên là chỉ 'public'
-- 1. Chạy hàm cần kiểm tra khi search_path = public, lưu kết quả vào temp table
-- 2. Đặt lại search_path = public, extensions
-- 3. Gọi extensions.is(...) để kiểm chứng kết quả mà không làm ảnh hưởng pgTAP
-- ==============================================================================
-- 1. f_unaccent độc lập search_path
set local search_path = public;
create temp table _t10 on commit drop as select public.f_unaccent('Phở Bò Hà Nội') as val;
set local search_path = public, extensions;

-- A23 (assertion 23 of 52)
-- A23 trace
select extensions.diag('>>> about to run A23');
select extensions.is(
  (select val from _t10),
  'Pho Bo Ha Noi',
  'T10 (Cloud search_path): f_unaccent chạy thành công khi search_path = public'
);

-- 2. search_restaurants độc lập search_path (dùng trigram / unaccent trong extensions)
set local search_path = public;
create temp table _t11 on commit drop as
  select count(*)::int as cnt from public.search_restaurants('pho bo', 50) where id = 'dddd4444-4444-4444-4444-444444444444';
set local search_path = public, extensions;
-- A24 (assertion 24 of 52)
-- A24 trace
select extensions.diag('>>> about to run A24');
select extensions.is(
  (select cnt from _t11),
  1,
  'T11 (Cloud search_path): search_restaurants tìm tên quán không dấu khi search_path = public'
);

-- 3. restaurants_in_bounds độc lập search_path (dùng PostGIS st_* trong extensions)
set local search_path = public;
create temp table _t12 on commit drop as
  select count(*)::int as cnt from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9) where id = 'dddd4444-4444-4444-4444-444444444444';
set local search_path = public, extensions;
-- A25 (assertion 25 of 52)
-- A25 trace
select extensions.diag('>>> about to run A25');
select extensions.is(
  (select cnt from _t12),
  1,
  'T12 (Cloud search_path): restaurants_in_bounds chạy thành công khi search_path = public'
);

-- 4. check_duplicate_restaurant độc lập search_path (dùng st_distance, st_dwithin, similarity)
set local search_path = public;
create temp table _t13 on commit drop as
  select count(*)::int as cnt from public.check_duplicate_restaurant('Test Pho', 21.0, 105.8) where id = 'dddd4444-4444-4444-4444-444444444444';
set local search_path = public, extensions;
-- A26 (assertion 26 of 52)
-- A26 trace
select extensions.diag('>>> about to run A26');
select extensions.is(
  (select cnt from _t13),
  1,
  'T13 (Cloud search_path): check_duplicate_restaurant chạy thành công khi search_path = public'
);

-- 5. View public_reviews độc lập search_path
set local search_path = public;
create temp table _t14 on commit drop as
  select count(*)::int as cnt from public.public_reviews where id = 'eeee5555-5555-5555-5555-555555555555';
set local search_path = public, extensions;
-- A27 (assertion 27 of 52)
-- A27 trace
select extensions.diag('>>> about to run A27');
select extensions.is(
  (select cnt from _t14),
  1,
  'T14 (Cloud search_path): view public_reviews truy vấn thành công khi search_path = public'
);

-- Each destructive security check uses a dedicated fixture so unexpected writes cannot affect later assertions.
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"eeee7777-7777-7777-7777-777777777777", "role":"authenticated"}';
-- A28 (assertion 28 of 52)
-- A28 trace
select extensions.diag('>>> about to run A28');
select extensions.throws_ok(
  'update public.profiles set role = ''admin'' where id = ''eeee7777-7777-7777-7777-777777777777''',
  '42501', null,
  'T15 (a): User E cannot promote their own profile'
);
-- A29 (assertion 29 of 52)
-- A29 trace
select extensions.diag('>>> about to run A29');
select extensions.throws_ok(
  'update public.profiles set is_banned = true where id = ''eeee7777-7777-7777-7777-777777777777''',
  '42501', null,
  'T16 (a): User E cannot change their own ban status'
);
set local role postgres;
-- A30 (assertion 30 of 52)
-- A30 trace
select extensions.diag('>>> about to run A30');
select extensions.is(
  (select role from public.profiles where id = 'eeee7777-7777-7777-7777-777777777777'),
  'user',
  'T17 (a): User E role remains user after rejected promotion'
);
-- A31 (assertion 31 of 52)
-- A31 trace
select extensions.diag('>>> about to run A31');
select extensions.is(
  (select is_banned from public.profiles where id = 'eeee7777-7777-7777-7777-777777777777'),
  false,
  'T18 (a): User E remains unbanned after rejected self-ban'
);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"eeee7777-7777-7777-7777-777777777777", "role":"authenticated"}';
-- A32 (assertion 32 of 52)
-- A32 trace
select extensions.diag('>>> about to run A32');
select extensions.lives_ok(
  'update public.profiles set display_name = ''User E updated'' where id = ''eeee7777-7777-7777-7777-777777777777''',
  'T19 (a): User E can still update an editable profile field'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';
-- A33 (assertion 33 of 52)
-- A33 trace
select extensions.diag('>>> about to run A33');
select extensions.throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''aaaa1111-1111-1111-1111-111111111111'', ''dddd4444-4444-4444-4444-444444444447'', 5, ''Spoofed owner'')',
  '42501', null,
  'T20 (b): User B cannot insert a review as User A (direct write denied); no row can appear'
);

set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
-- A34 (assertion 34 of 52)
-- A34 trace
select extensions.diag('>>> about to run A34');
select extensions.is(
  (select count(*)::int from public.reviews),
  0,
  'T21 (c): anon cannot read rows directly from reviews'
);
-- A35 (assertion 35 of 52)
-- A35 trace
select extensions.diag('>>> about to run A35');
select extensions.throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''bbbb2222-2222-2222-2222-222222222222'', ''dddd4444-4444-4444-4444-444444444447'', 5, ''Anonymous insert'')',
  '42501', null,
  'T22 (c): anon cannot insert a review'
);
set local role postgres;
-- One privileged read-back per denied write rule proves the row was not created.
-- A36 (assertion 36 of 52)
-- A36 trace
select extensions.diag('>>> about to run A36');
select extensions.is(
  (select count(*)::integer from public.public_reviews where restaurant_id = 'dddd4444-4444-4444-4444-444444444447'),
  0,
  'T22b (c): neither the spoofed nor the anon insert created a review row'
);

-- Snapshot the row immediately before the denied UPDATE. T24/T25 then compare this snapshot with
-- the state after the denial, so the assertion proves "nothing changed" without hard-coding a
-- value that the fixture (and the M5 stats trigger) legitimately sets.
set local role postgres;
create temp table _t24_before on commit drop as
  select avg_rating, review_count, status from public.restaurants
  where id = 'dddd4444-4444-4444-4444-444444444444';
select extensions.diag('>>> BEFORE T23 snapshot: restaurant dddd4444-...444 avg_rating='
  || coalesce((select avg_rating::text from _t24_before), 'NULL')
  || ' review_count=' || coalesce((select review_count::text from _t24_before), 'NULL')
  || ' status=' || coalesce((select status from _t24_before), 'NULL'));

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';
-- M5 removed the system-managed restaurant UPDATE grant, so the write is denied outright.
-- A37 (assertion 37 of 52)
-- A37 trace
select extensions.diag('>>> about to run A37');
select extensions.throws_ok(
  'update public.restaurants set avg_rating = 1, review_count = 99, status = ''closed'' where id = ''dddd4444-4444-4444-4444-444444444444''',
  '42501', null,
  'T23 (d): User B is denied the system-managed restaurant UPDATE'
);
set local role postgres;
-- Evidence for T24/T25: print the before/after state. The denied UPDATE tried to write 1.00 / 99 /
-- 'closed', so any of those values appearing here means the denial failed.
select extensions.diag('>>> AFTER T23: restaurant dddd4444-...444 avg_rating='
  || coalesce((select avg_rating::text from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' review_count='
  || coalesce((select review_count::text from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' status='
  || coalesce((select status from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'), 'NULL')
  || ' (denied UPDATE tried 1.00 / 99 / closed)');
-- A38 (assertion 38 of 52)
-- A38 trace
select extensions.diag('>>> about to run A38');
select extensions.is(
  (select avg_rating = (select avg_rating from _t24_before)
     and review_count = (select review_count from _t24_before)
   from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'),
  true,
  'T24 (d): avg_rating and review_count are identical to the pre-UPDATE snapshot'
);
-- A39 (assertion 39 of 52)
-- A39 trace
select extensions.diag('>>> about to run A39');
select extensions.is(
  (select status from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'),
  (select status from _t24_before),
  'T25 (d): restaurant status is identical to the pre-UPDATE snapshot'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';
-- A40 (assertion 40 of 52)
-- A40 trace
select extensions.diag('>>> about to run A40');
select extensions.is((select count(*)::int from public.reports), 1, 'T26 (e): User A sees their own report');
-- A41 (assertion 41 of 52)
-- A41 trace
select extensions.diag('>>> about to run A41');
select extensions.is((select count(*)::int from public.blocks), 1, 'T27 (e): User A sees their own block');
-- A42 (assertion 42 of 52)
-- A42 trace
select extensions.diag('>>> about to run A42');
select extensions.is((select count(*)::int from public.saved_items), 1, 'T28 (e): User A sees their own saved item');

set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';
-- A43 (assertion 43 of 52)
-- A43 trace
select extensions.diag('>>> about to run A43');
select extensions.is((select count(*)::int from public.reports), 0, 'T29 (e): User B cannot see User A reports');
-- A44 (assertion 44 of 52)
-- A44 trace
select extensions.diag('>>> about to run A44');
select extensions.is((select count(*)::int from public.blocks), 0, 'T30 (e): User B cannot see User A blocks');
-- A45 (assertion 45 of 52)
-- A45 trace
select extensions.diag('>>> about to run A45');
select extensions.is((select count(*)::int from public.saved_items), 0, 'T31 (e): User B cannot see User A saved items');
-- A46 (assertion 46 of 52)
-- A46 trace
select extensions.diag('>>> about to run A46');
select extensions.is((select count(*)::int from public.admin_audit_log), 0, 'T32 (e): regular users cannot read admin audit log');

set local role postgres;
update public.profiles set is_banned = true where id = 'cccc3333-3333-3333-3333-333333333333';
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"cccc3333-3333-3333-3333-333333333333", "role":"authenticated"}';
-- A47 (assertion 47 of 52)
-- A47 trace
select extensions.diag('>>> about to run A47');
select extensions.throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''cccc3333-3333-3333-3333-333333333333'', ''dddd4444-4444-4444-4444-444444444446'', 5, ''Banned review'')',
  '42501', null,
  'T33 (f): a banned user cannot insert a review, so no row can appear'
);

-- M5 requires every photo write to pass through add_review_photo() as the review owner, so the
-- privacy rules below are exercised through that RPC and through privileged maintenance inserts
-- (the only remaining paths that reach the BEFORE triggers).
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';
-- A48 (assertion 48 of 52)
-- A48 trace
select extensions.diag('>>> about to run A48');
select extensions.lives_ok(
  'select public.add_review_photo(''eeee5555-5555-5555-5555-555555555555'', ''eeee5555-5555-5555-5555-555555555555/9f1d2c34-0000-4000-8000-000000000001.webp'', 1)',
  'T34 (g): the review owner attaches a non-identifying photo path through the RPC'
);

set local role postgres;
set local "request.jwt.claims" to '{}';
-- A49 (assertion 49 of 52)
-- A49 trace
select extensions.diag('>>> about to run A49');
select extensions.throws_ok(
  'insert into public.review_photos (review_id, storage_path) values (''ffff6666-6666-6666-6666-666666666666'', ''reviews/bbbb2222-2222-2222-2222-222222222222/photo.webp'')',
  '23514', null,
  'T35 (g): anonymous review rejects a photo path containing user_id'
);
-- A50 (assertion 50 of 52)
-- A50 trace
select extensions.diag('>>> about to run A50');
select extensions.lives_ok(
  'insert into public.review_photos (review_id, storage_path) values (''ffff6666-6666-6666-6666-666666666666'', ''ffff6666-6666-6666-6666-666666666666/9f1d2c34-0000-4000-8000-000000000002.webp'')',
  'T36 (g): anonymous review accepts a path that only carries the review UUID'
);
-- A51 (assertion 51 of 52)
-- A51 trace
select extensions.diag('>>> about to run A51');
select extensions.throws_ok(
  'update public.reviews set is_anonymous = true where id = ''eeee5555-5555-5555-5555-555555555555''',
  '23514', null,
  'T37 (g): a review holding an identifying photo path cannot be switched to anonymous'
);

-- M5 removed the API write grants on review metadata; only the ownership-checked RPC may write.
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';
-- A52 (assertion 52 of 52)
-- A52 trace
select extensions.diag('>>> about to run A52');
select extensions.throws_ok(
  'insert into public.review_photos (id, review_id, storage_path) values (''33330000-0000-4000-8000-000000000001'', ''eeee5555-5555-5555-5555-555555555555'', ''eeee5555-5555-5555-5555-555555555555/9f1d2c34-0000-4000-8000-000000000003.webp'')',
  '42501', null,
  'T38 (g): review photo metadata writes require the ownership-checked RPC, so no row can appear'
);

select * from extensions.finish(true);
rollback;
