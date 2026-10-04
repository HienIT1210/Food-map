-- supabase/seed.sql
-- Seed dữ liệu vài chục quán mẫu (source = 'seed')

-- Tạo 2 user giả lập để viết review
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
values 
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'user1@example.com', '', now(), null, now(), '{"provider":"email","providers":["email"]}', '{"name":"User 1"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'user2@example.com', '', now(), null, now(), '{"provider":"email","providers":["email"]}', '{"name":"User 2"}', now(), now(), '', '', '', '');

insert into public.profiles (id, display_name, role)
values 
  ('11111111-1111-1111-1111-111111111111', 'Người dùng 1', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'Người dùng 2', 'user')
on conflict (id) do update 
  set display_name = excluded.display_name,
      role = excluded.role;

-- Tạo Categories
insert into public.dish_categories (id, name, region)
values 
  ('10000000-0000-0000-0000-000000000001', 'Phở', 'Bắc'),
  ('10000000-0000-0000-0000-000000000002', 'Bún', 'Đa dạng'),
  ('10000000-0000-0000-0000-000000000003', 'Cơm', 'Đa dạng');

-- Tạo Dishes
insert into public.dishes (id, name, normalized_name, category_id)
values
  ('20000000-0000-0000-0000-000000000001', 'Phở Bò', 'pho bo', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002', 'Bún Chả', 'bun cha', '10000000-0000-0000-0000-000000000002'),
  ('20000000-0000-0000-0000-000000000003', 'Cơm Tấm', 'com tam', '10000000-0000-0000-0000-000000000003');

-- Tạo Restaurants (vài chục quán, toạ độ khu vực Hồ Chí Minh / Hà Nội)
insert into public.restaurants (id, name, address, location, created_by, source, status, avg_rating, review_count)
values 
  ('30000000-0000-0000-0000-000000000001', 'Phở Hòa Pasteur', '260C Pasteur, Quận 3, TP.HCM', st_setsrid(st_makepoint(106.690850, 10.785460), 4326), '11111111-1111-1111-1111-111111111111', 'seed', 'active', 4.5, 1),
  ('30000000-0000-0000-0000-000000000002', 'Bún Chả Hương Liên', '24 Lê Văn Hưu, Hà Nội', st_setsrid(st_makepoint(105.852860, 21.017770), 4326), '11111111-1111-1111-1111-111111111111', 'seed', 'active', 4.0, 1),
  ('30000000-0000-0000-0000-000000000003', 'Cơm Tấm Ba Ghiền', '84 Đặng Văn Ngữ, Phú Nhuận, TP.HCM', st_setsrid(st_makepoint(106.674930, 10.793610), 4326), '11111111-1111-1111-1111-111111111111', 'seed', 'active', 4.2, 0);

-- Thêm món cho quán
insert into public.restaurant_dishes (restaurant_id, dish_id, price_vnd)
values 
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 90000),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 60000);

-- Tạo một vài reviews
insert into public.reviews (id, user_id, restaurant_id, dish_id, rating, content, is_anonymous)
values 
  ('40000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 5, 'Phở rất ngon', false),
  ('40000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', '30000000-0000-0000-0000-000000000002', null, 4, 'Bún chả ok, đông khách', true);
