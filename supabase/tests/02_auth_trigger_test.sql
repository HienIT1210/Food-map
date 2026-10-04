begin;
create extension if not exists pgtap;

select plan(3);

-- Mô phỏng môi trường Cloud: đặt search_path = public
set search_path = public;

-- Test trigger handle_new_user: khi insert vào auth.users, profile tự động được tạo
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '99999999-9999-9999-9999-999999999999',
  'authenticated',
  'authenticated',
  'test_trigger@example.com',
  '',
  now(),
  '{"full_name": "Nguyen Van Test", "avatar_url": "https://example.com/avatar.png"}'::jsonb,
  now(),
  now()
);

-- Kiểm tra xem bảng public.profiles đã có dòng tương ứng chưa
select is(
  (select count(*)::int from public.profiles where id = '99999999-9999-9999-9999-999999999999'),
  1,
  'T1 (M2): Profile tự động được tạo khi có user mới trong auth.users'
);

select is(
  (select display_name from public.profiles where id = '99999999-9999-9999-9999-999999999999'),
  'Nguyen Van Test',
  'T2 (M2): display_name lấy đúng từ raw_user_meta_data'
);

select is(
  (select avatar_url from public.profiles where id = '99999999-9999-9999-9999-999999999999'),
  'https://example.com/avatar.png',
  'T3 (M2): avatar_url lấy đúng từ raw_user_meta_data'
);

select * from finish();
rollback;
