begin;
create extension if not exists pgtap;

-- Đặt kế hoạch test (số lượng test)
select plan(7);

-- Tạo users giả để test
insert into auth.users (id, role) values 
  ('aaaa1111-1111-1111-1111-111111111111', 'authenticated'),
  ('bbbb2222-2222-2222-2222-222222222222', 'authenticated'),
  ('cccc3333-3333-3333-3333-333333333333', 'authenticated');

insert into public.profiles (id, display_name) values 
  ('aaaa1111-1111-1111-1111-111111111111', 'User A'),
  ('bbbb2222-2222-2222-2222-222222222222', 'User B'),
  ('cccc3333-3333-3333-3333-333333333333', 'User C (Blocked by A)');

-- Thêm data nhà hàng
insert into public.restaurants (id, name, location, status) values
  ('dddd4444-4444-4444-4444-444444444444', 'Test Phở', st_setsrid(st_makepoint(105.8, 21.0), 4326), 'active');

-- A viết review công khai
insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous) values
  ('eeee5555-5555-5555-5555-555555555555', 'aaaa1111-1111-1111-1111-111111111111', 'dddd4444-4444-4444-4444-444444444444', 5, 'Good', false);

-- B viết review ẩn danh
insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous) values
  ('ffff6666-6666-6666-6666-666666666666', 'bbbb2222-2222-2222-2222-222222222222', 'dddd4444-4444-4444-4444-444444444444', 4, 'Ok, anonymous', true);

-- A chặn C
insert into public.blocks (blocker_id, blocked_id) values ('aaaa1111-1111-1111-1111-111111111111', 'cccc3333-3333-3333-3333-333333333333');
-- C viết review
insert into public.reviews (id, user_id, restaurant_id, rating, content, is_anonymous) values
  ('00007777-7777-7777-7777-777777777777', 'cccc3333-3333-3333-3333-333333333333', 'dddd4444-4444-4444-4444-444444444444', 1, 'Bad', false);

-- Test 1 & 2: Không lấy được user_id của review ẩn danh qua public_reviews
select is(
  (select author_id from public.public_reviews where id = 'ffff6666-6666-6666-6666-666666666666'),
  null::uuid,
  'Review ẩn danh không được lộ author_id qua public_reviews'
);

select isnt(
  (select author_id from public.public_reviews where id = 'eeee5555-5555-5555-5555-555555555555'),
  null::uuid,
  'Review công khai vẫn hiện author_id'
);

-- Chuyển sang context User A để test RLS và View
select set_config('request.jwt.claims', '{"sub":"aaaa1111-1111-1111-1111-111111111111"}', true);

-- Test 3: Người dùng bị chặn bị lọc theo blocks (A không thấy review của C trên public_reviews)
select is_empty(
  'select 1 from public.public_reviews where id = ''00007777-7777-7777-7777-777777777777''',
  'User A không thấy review từ C (người bị chặn)'
);

-- Test 4: Khách/B không thấy review của A nếu query thẳng bảng reviews? 
-- (Policy RLS của bảng reviews quy định chỉ thấy của mình)
select set_config('request.jwt.claims', '{"sub":"bbbb2222-2222-2222-2222-222222222222"}', true);
select is_empty(
  'select 1 from public.reviews where id = ''eeee5555-5555-5555-5555-555555555555''',
  'User B không thể SELECT bảng reviews trực tiếp để xem review của A (phải qua view)'
);

-- Test 5: Người dùng A không sửa/xóa được review của B
select throws_ok(
  'update public.reviews set content = ''Hack'' where id = ''ffff6666-6666-6666-6666-666666666666''',
  'Người dùng không sửa được review của người khác'
);

-- Đổi lại quyền postgres / admin
select set_config('request.jwt.claims', '', true);

-- Test 6: search_restaurants (trigram test - f_unaccent)
-- Cần test "pho bo" tìm ra "Test Phở" (giả sử trigram match)
select is(
  (select count(*)::int from public.search_restaurants('pho bo', 10)),
  1,
  'search_restaurants có thể tìm thấy theo text không dấu'
);

-- Test 7: restaurants_in_bounds (bounding box test)
-- Tọa độ Test Phở: (105.8, 21.0). Nằm trong bounds (20.9, 105.7) tới (21.1, 105.9)
select is(
  (select count(*)::int from public.restaurants_in_bounds(20.9, 105.7, 21.1, 105.9)),
  1,
  'restaurants_in_bounds trả về đúng quán trong vùng'
);

select * from finish();
rollback;

-- Test 8: Giới hạn chống lạm dụng (Abuse limits)
select set_config('request.jwt.claims', '{"sub":"aaaa1111-1111-1111-1111-111111111111"}', true);
-- Thêm 10 review giả để đạt giới hạn. Đã có 1 (eeee5555...). Thêm 9 nữa.
do $$
begin
  for i in 1..9 loop
    insert into public.reviews (user_id, restaurant_id, rating, content)
    values ('aaaa1111-1111-1111-1111-111111111111', 'dddd4444-4444-4444-4444-444444444444', 5, 'Review ' || i);
  end loop;
end;
$$;

select throws_ok(
  'insert into public.reviews (user_id, restaurant_id, rating, content) values (''aaaa1111-1111-1111-1111-111111111111'', ''dddd4444-4444-4444-4444-444444444444'', 5, ''Over limit'')',
  'Đã vượt quá giới hạn 10 review mỗi ngày.',
  'Server chặn insert review khi vượt quá giới hạn 10/ngày'
);
