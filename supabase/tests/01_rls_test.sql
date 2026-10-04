begin;
create extension if not exists pgtap;

-- Mô phỏng môi trường Cloud: đặt search_path của session chỉ còn public
-- để bắt buộc mọi đối tượng hoặc lệnh gọi extension phải có schema tường minh hoặc qua hàm có search_path cấu hình đúng.
set search_path = public;

-- Đặt kế hoạch (tổng số tests)
select plan(11);

-- Bật RLS và các triggers (nếu có)
-- Tạo data nền, cần đảm bảo user tồn tại trong cả auth.users và public.profiles
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values 
  ('00000000-0000-0000-0000-000000000000', 'aaaa1111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'a@ex.com', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbb2222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'b@ex.com', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'cccc3333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'c@ex.com', '', now(), now(), now());

insert into public.profiles (id, display_name) values 
  ('aaaa1111-1111-1111-1111-111111111111', 'User A'),
  ('bbbb2222-2222-2222-2222-222222222222', 'User B'),
  ('cccc3333-3333-3333-3333-333333333333', 'User C (Blocked)')
on conflict (id) do update 
  set display_name = excluded.display_name;

-- Tạo quán (sử dụng extensions.st_* tường minh)
insert into public.restaurants (id, name, location, status) values
  ('dddd4444-4444-4444-4444-444444444444', 'Test Phở', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'active'),
  ('dddd4444-4444-4444-4444-444444444445', 'Test Bún', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'active');

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

-- Yêu cầu (a): Không lấy được user_id review ẩn danh qua public_reviews
select is((select author_id from public.public_reviews where id = 'ffff6666-6666-6666-6666-666666666666'), null::uuid, 'T1 (a): Review ẩn danh không lộ author_id');
select isnt((select author_id from public.public_reviews where id = 'eeee5555-5555-5555-5555-555555555555'), null::uuid, 'T2 (a): Review công khai lộ author_id');

-- Chuyển sang context User A (authenticated)
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';

-- Yêu cầu (c): Người bị chặn bị lọc
select is_empty(
  'select 1 from public.public_reviews where id = ''00007777-7777-7777-7777-777777777777''',
  'T3 (c): User A không thấy review từ C trên public_reviews (bị chặn)'
);

-- Chuyển sang context User B (authenticated)
set local "request.jwt.claims" to '{"sub":"bbbb2222-2222-2222-2222-222222222222", "role":"authenticated"}';

-- Chứng minh Test 4 chạy đúng vai
select diag('>>> CURRENT_USER: ' || current_user::text);
select is(current_user::text, 'authenticated', 'T4.1: current_user là authenticated');

select diag('>>> AUTH.UID(): ' || coalesce(auth.uid()::text, 'NULL'));
select is(auth.uid(), 'bbbb2222-2222-2222-2222-222222222222'::uuid, 'T4.2: auth.uid() là User B');

-- Yêu cầu (b): B không được đọc/sửa/xóa của A
select is_empty(
  'select 1 from public.reviews where id = ''eeee5555-5555-5555-5555-555555555555''',
  'T4.3 (b): User B không thể SELECT trực tiếp bảng reviews của A (RLS chặn)'
);

-- UPDATE/DELETE bị RLS chặn sẽ không throw exception, mà trả về 0 rows affected.
update public.reviews set content = 'Hack' where id = 'eeee5555-5555-5555-5555-555555555555';
delete from public.reviews where id = 'eeee5555-5555-5555-5555-555555555555';

-- Reset về superuser để kiểm tra nội dung gốc
set local role postgres;
set search_path = public;
select is(
  (select content from public.reviews where id = 'eeee5555-5555-5555-5555-555555555555'),
  'Good',
  'T5 (b): User B không thể update hoặc delete review của A (nội dung gốc nguyên vẹn)'
);

-- Yêu cầu (f): Tìm kiếm trigram
select is(
  (select count(*)::int from public.search_restaurants('pho bo', 10) where id = 'dddd4444-4444-4444-4444-444444444444'),
  1,
  'T6 (f): search_restaurants tìm không dấu'
);

-- Yêu cầu (e): Bounding box
select is(
  (select count(*)::int from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9) where id = 'dddd4444-4444-4444-4444-444444444444'),
  1,
  'T7 (e): restaurants_in_bounds cô lập đếm đúng quán test trong khung'
);

-- Yêu cầu (d): Giới hạn lạm dụng (phía server)
-- Tạo thêm data bằng quyền postgres trước khi thử
do $$
declare
  new_rest_id uuid;
begin
  -- Thêm 9 quán khác nhau để A review không bị lỗi unique (user_id, restaurant_id)
  for i in 1..9 loop
    new_rest_id := gen_random_uuid();
    insert into public.restaurants (id, name, location, status) values (new_rest_id, 'Quán ' || i, extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'active');
    insert into public.reviews (user_id, restaurant_id, rating, content)
    values ('aaaa1111-1111-1111-1111-111111111111', new_rest_id, 5, 'Review ' || i);
  end loop;
end;
$$;

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"aaaa1111-1111-1111-1111-111111111111", "role":"authenticated"}';

select throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''aaaa1111-1111-1111-1111-111111111111'', ''dddd4444-4444-4444-4444-444444444445'', 5, ''Over limit'')',
  'Đã vượt quá giới hạn 10 review mỗi ngày.',
  'T8 (d): Chặn insert review thứ 11 trong ngày'
);

-- Test limit nhà hàng: 5 nhà hàng mỗi ngày
do $$
begin
  for i in 1..5 loop
    insert into public.restaurants (name, location, created_by) values ('Quán A ' || i, extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), 'aaaa1111-1111-1111-1111-111111111111');
  end loop;
end;
$$;

select throws_ok(
  'insert into public.restaurants (name, location, created_by) values (''Quán A 6'', extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326), ''aaaa1111-1111-1111-1111-111111111111'')',
  'Đã vượt quá giới hạn tạo 5 địa điểm mỗi ngày.',
  'T9 (d): Chặn insert nhà hàng thứ 6 trong ngày'
);

select * from finish();
rollback;
