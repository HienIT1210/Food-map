begin;
create extension if not exists pgtap with schema extensions;

-- Khung test dùng search_path gồm public và extensions để các hàm của pgTAP luôn được phân giải chính xác
set search_path = public, extensions;

-- 16 existing checks plus 22 security regression checks.
select extensions.plan(38);

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
select extensions.is((select author_id from public.public_reviews where id = 'ffff6666-6666-6666-6666-666666666666'), null::uuid, 'T1 (a): Review ẩn danh không lộ author_id');
select extensions.isnt((select author_id from public.public_reviews where id = 'eeee5555-5555-5555-5555-555555555555'), null::uuid, 'T2 (a): Review công khai lộ author_id');

-- Chuyển sang context User A (authenticated)
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';

-- Yêu cầu (c): Người bị chặn bị lọc
select extensions.is_empty(
  'select 1 from public.public_reviews where id = ''00007777-7777-7777-7777-777777777777''',
  'T3 (c): User A không thấy review từ C trên public_reviews (bị chặn)'
);

-- Chuyển sang context User B (authenticated)
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';

-- Chứng minh Test 4 chạy đúng vai
select extensions.diag('>>> CURRENT_USER: ' || current_user::text);
select extensions.is(current_user::text, 'authenticated', 'T4.1: current_user là authenticated');

select extensions.diag('>>> AUTH.UID(): ' || coalesce(auth.uid()::text, 'NULL'));
select extensions.is(auth.uid(), 'bbbb2222-2222-2222-2222-222222222222'::uuid, 'T4.2: auth.uid() là User B');

-- Yêu cầu (b): B đọc được review của chính mình (chứng minh có quyền SELECT trên bảng, không bị permission denied) nhưng không đọc được của A (do RLS chặn)
select extensions.is(
  (select array_agg(id order by id) from public.reviews where id in ('eeee5555-5555-5555-5555-555555555555', 'ffff6666-6666-6666-6666-666666666666')),
  array['ffff6666-6666-6666-6666-666666666666'::uuid],
  'T4.3 (b): User B đọc được review của mình nhưng không thấy review của A (chứng minh thứ chặn là RLS chứ không phải permission denied)'
);

set local role postgres;
alter policy "Users can view own reviews" on public.reviews using (true);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';

-- UPDATE/DELETE bị RLS chặn sẽ không throw exception, mà trả về 0 rows affected.
update public.reviews set content = 'Hack' where id = 'eeee5555-5555-5555-5555-555555555556';
delete from public.reviews where id = 'eeee5555-5555-5555-5555-555555555556';

-- Reset về superuser để kiểm tra nội dung gốc.
set local role postgres;
select extensions.is(
  (select content from public.reviews where id = 'eeee5555-5555-5555-5555-555555555556'),
  'T5 original',
  'T5 (b): User B không thể update hoặc delete review của A (nội dung gốc nguyên vẹn)'
);
alter policy "Users can view own reviews" on public.reviews using (auth.uid() = user_id);
set local role postgres;
set search_path = public, extensions;

-- Yêu cầu (f): Tìm kiếm trigram
select extensions.diag(
  'T6 diagnostic: ' || jsonb_build_object(
    'fixture_name', restaurant.name,
    'normalized_name', public.f_unaccent(lower(restaurant.name)),
    'normalized_query', public.f_unaccent(lower('pho bo')),
    'pho_token_position', position('pho' in public.f_unaccent(lower(restaurant.name))),
    'name_token_match', exists (
      select 1
      from unnest(string_to_array(public.f_unaccent(lower('pho bo')), ' ')) as query_token(value)
      where length(query_token.value) >= 3
        and position(query_token.value in public.f_unaccent(lower(restaurant.name))) > 0
    ),
    'function_search_path', (
      select proconfig
      from pg_proc
      where oid = 'public.search_restaurants(text,integer)'::regprocedure
    ),
    'candidate_rewrite_installed', position(
      'all_matches' in (
        select prosrc
        from pg_proc
        where oid = 'public.search_restaurants(text,integer)'::regprocedure
      )
    ) > 0,
    'direct_name_candidate_count', (
      select count(*)::int
      from public.restaurants as candidate
      where candidate.id = restaurant.id
        and candidate.status = 'active'
        and (
          extensions.similarity(
            public.f_unaccent(lower(candidate.name)),
            public.f_unaccent(lower('pho bo'))
          ) >= 0.25
          or exists (
            select 1
            from unnest(string_to_array(public.f_unaccent(lower('pho bo')), ' ')) as query_token(value)
            where length(query_token.value) >= 3
              and position(query_token.value in public.f_unaccent(lower(candidate.name))) > 0
          )
        )
    ),
    'full_query_similarity', extensions.similarity(
      public.f_unaccent(lower(restaurant.name)),
      public.f_unaccent(lower('pho bo'))
    ),
    'status', restaurant.status,
    'rpc_rows', (
      select count(*)::int
      from public.search_restaurants('pho bo', 10) as result
      where result.id = restaurant.id
    )
  )::text
)
from public.restaurants as restaurant
where restaurant.id = 'dddd4444-4444-4444-4444-444444444444';

select extensions.is(
  (select count(*)::int from public.search_restaurants('pho bo', 10) where id = 'dddd4444-4444-4444-4444-444444444444'),
  1,
  'T6 (f): search_restaurants tìm không dấu'
);

-- Yêu cầu (e): Bounding box
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

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"dddd7777-7777-7777-7777-777777777777", "role":"authenticated"}';

select extensions.throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''dddd7777-7777-7777-7777-777777777777'', ''dddd4444-4444-4444-4444-444444444445'', 5, ''Over limit'')',
  'Đã vượt quá giới hạn 10 review mỗi ngày.',
  'T8 (d): Chặn insert review thứ 11 trong ngày'
);

-- Test limit nhà hàng: 5 nhà hàng mỗi ngày
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"dddd7777-7777-7777-7777-777777777777", "role":"authenticated"}';
do $$
begin
  for i in 1..5 loop
    insert into public.restaurants (name, location, created_by) values ('Quán D ' || i, extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'dddd7777-7777-7777-7777-777777777777');
  end loop;
end;
$$;

select extensions.throws_ok(
  'insert into public.restaurants (name, location, created_by) values (''Quán D 6'', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), ''dddd7777-7777-7777-7777-777777777777'')',
  'Đã vượt quá giới hạn tạo 5 địa điểm mỗi ngày.',
  'T9 (d): Chặn insert nhà hàng thứ 6 trong ngày'
);

-- ==============================================================================
-- KIỂM CHỨNG TÍNH ĐỘC LẬP SEARCH_PATH (MÔ PHỎNG SUPABASE CLOUD PHIÊN GỌI CHỈ CÓ PUBLIC)
-- Chứng minh các hàm trong public chạy đúng ngay cả khi search_path của phiên là chỉ 'public'
-- 1. Chạy hàm cần kiểm tra khi search_path = public, lưu kết quả vào temp table
-- 2. Đặt lại search_path = public, extensions
-- 3. Gọi extensions.is(...) để kiểm chứng kết quả mà không làm ảnh hưởng pgTAP
-- ==============================================================================
set local role postgres;

-- 1. f_unaccent độc lập search_path
set local search_path = public;
create temp table _t10 on commit drop as select public.f_unaccent('Phở Bò Hà Nội') as val;
set local search_path = public, extensions;
select extensions.is(
  (select val from _t10),
  'Pho Bo Ha Noi',
  'T10 (Cloud search_path): f_unaccent chạy thành công khi search_path = public'
);

-- 2. search_restaurants độc lập search_path (dùng trigram / unaccent trong extensions)
set local search_path = public;
create temp table _t11 on commit drop as
  select count(*)::int as cnt from public.search_restaurants('pho bo', 10) where id = 'dddd4444-4444-4444-4444-444444444444';
set local search_path = public, extensions;
select extensions.is(
  (select cnt from _t11),
  1,
  'T11 (Cloud search_path): search_restaurants chạy thành công khi search_path = public'
);

-- 3. restaurants_in_bounds độc lập search_path (dùng PostGIS st_* trong extensions)
set local search_path = public;
create temp table _t12 on commit drop as
  select count(*)::int as cnt from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9) where id = 'dddd4444-4444-4444-4444-444444444444';
set local search_path = public, extensions;
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
select extensions.is(
  (select cnt from _t14),
  1,
  'T14 (Cloud search_path): view public_reviews truy vấn thành công khi search_path = public'
);

-- Each destructive security check uses a dedicated fixture so unexpected writes cannot affect later assertions.
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"eeee7777-7777-7777-7777-777777777777", "role":"authenticated"}';
select extensions.throws_ok(
  'update public.profiles set role = ''admin'' where id = ''eeee7777-7777-7777-7777-777777777777''',
  '42501', null,
  'T15 (a): User E cannot promote their own profile'
);
select extensions.throws_ok(
  'update public.profiles set is_banned = true where id = ''eeee7777-7777-7777-7777-777777777777''',
  '42501', null,
  'T16 (a): User E cannot change their own ban status'
);
set local role postgres;
select extensions.is(
  (select role from public.profiles where id = 'eeee7777-7777-7777-7777-777777777777'),
  'user',
  'T17 (a): User E role remains user after rejected promotion'
);
select extensions.is(
  (select is_banned from public.profiles where id = 'eeee7777-7777-7777-7777-777777777777'),
  false,
  'T18 (a): User E remains unbanned after rejected self-ban'
);
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"eeee7777-7777-7777-7777-777777777777", "role":"authenticated"}';
select extensions.lives_ok(
  'update public.profiles set display_name = ''User E updated'' where id = ''eeee7777-7777-7777-7777-777777777777''',
  'T19 (a): User E can still update an editable profile field'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';
select extensions.throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''aaaa1111-1111-1111-1111-111111111111'', ''dddd4444-4444-4444-4444-444444444447'', 5, ''Spoofed owner'')',
  '42501', null,
  'T20 (b): User B cannot insert a review as User A'
);

set local role anon;
set local "request.jwt.claims" to '{"role":"anon"}';
select extensions.is(
  (select count(*)::int from public.reviews),
  0,
  'T21 (c): anon cannot read rows directly from reviews'
);
select extensions.throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''bbbb2222-2222-2222-2222-222222222222'', ''dddd4444-4444-4444-4444-444444444447'', 5, ''Anonymous insert'')',
  '42501', null,
  'T22 (c): anon cannot insert a review'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';
select extensions.throws_ok(
  'update public.restaurants set avg_rating = 1, review_count = 99, status = ''closed'' where id = ''dddd4444-4444-4444-4444-444444444444''',
  '42501', null,
  'T23 (d): User B is denied UPDATE on system-managed restaurant fields'
);
set local role postgres;
select extensions.ok(
  (select avg_rating = 0 and review_count = 0 from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'),
  'T24 (d): avg_rating and review_count remain unchanged after denied UPDATE'
);
select extensions.is(
  (select status from public.restaurants where id = 'dddd4444-4444-4444-4444-444444444444'),
  'active',
  'T25 (d): status remains unchanged after denied UPDATE'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';
select extensions.is((select count(*)::int from public.reports), 1, 'T26 (e): User A sees their own report');
select extensions.is((select count(*)::int from public.blocks), 1, 'T27 (e): User A sees their own block');
select extensions.is((select count(*)::int from public.saved_items), 1, 'T28 (e): User A sees their own saved item');

set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';
select extensions.is((select count(*)::int from public.reports), 0, 'T29 (e): User B cannot see User A reports');
select extensions.is((select count(*)::int from public.blocks), 0, 'T30 (e): User B cannot see User A blocks');
select extensions.is((select count(*)::int from public.saved_items), 0, 'T31 (e): User B cannot see User A saved items');
select extensions.is((select count(*)::int from public.admin_audit_log), 0, 'T32 (e): regular users cannot read admin audit log');

set local role postgres;
update public.profiles set is_banned = true where id = 'cccc3333-3333-3333-3333-333333333333';
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"cccc3333-3333-3333-3333-333333333333", "role":"authenticated"}';
select extensions.throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''cccc3333-3333-3333-3333-333333333333'', ''dddd4444-4444-4444-4444-444444444446'', 5, ''Banned review'')',
  '42501', null,
  'T33 (f): a banned user cannot insert a review'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';
select extensions.lives_ok(
  'insert into public.review_photos (review_id, storage_path) values (''ffff6666-6666-6666-6666-666666666666'', ''anonymous/77777777-7777-7777-7777-777777777777/photo.webp'')',
  'T34 (g): anonymous review accepts a non-identifying photo path'
);
select extensions.throws_ok(
  'insert into public.review_photos (review_id, storage_path) values (''ffff6666-6666-6666-6666-666666666666'', ''reviews/bbbb2222-2222-2222-2222-222222222222/photo.webp'')',
  '23514', null,
  'T35 (g): anonymous review rejects a photo path containing user_id'
);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';
select extensions.throws_ok(
  'update public.reviews set is_anonymous = true where id = ''eeee5555-5555-5555-5555-555555555555''',
  '23514', null,
  'T36 (g): a review with an identifying photo path cannot be made anonymous'
);

select * from extensions.finish(true);
rollback;
