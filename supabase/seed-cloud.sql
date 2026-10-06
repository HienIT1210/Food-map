-- Dọn dẹp dữ liệu mẫu cũ
delete from public.restaurant_dishes where restaurant_id in (select id from public.restaurants where source = 'seed');
delete from public.restaurants where source = 'seed';
delete from public.dishes;
delete from public.dish_categories;

insert into public.dish_categories (id, name, region) values
  ('c1111111-1111-1111-1111-111111111111', 'Phở', 'Bắc'),
  ('c2222222-2222-2222-2222-222222222222', 'Cơm', 'Nam'),
  ('c3333333-3333-3333-3333-333333333333', 'Bún/Phở', 'Trung');

insert into public.dishes (id, name, normalized_name, category_id, aliases) values
  ('d1111111-1111-1111-1111-111111111111', 'Phở Bò', 'pho bo', 'c1111111-1111-1111-1111-111111111111', '{phở bò tái nạm}'),
  ('d2222222-2222-2222-2222-222222222222', 'Cơm Tấm', 'com tam', 'c2222222-2222-2222-2222-222222222222', '{cơm sườn}'),
  ('d3333333-3333-3333-3333-333333333333', 'Bún Bò Huế', 'bun bo hue', 'c3333333-3333-3333-3333-333333333333', '{bún bò}');

insert into public.restaurants (id, name, address, province, location, source, status, avg_rating, review_count) values
  (gen_random_uuid(), 'Cơm Tấm 1', '1 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.68507, 10.76426), 4326), 'seed', 'active', 3.5, 52),
  (gen_random_uuid(), 'Bún Bò 2', '2 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.61450, 10.75027), 4326), 'seed', 'active', 3.7, 120),
  (gen_random_uuid(), 'Quán Phở 3', '3 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.67827, 10.80564), 4326), 'seed', 'active', 4.1, 53),
  (gen_random_uuid(), 'Cơm Tấm 4', '4 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.74217, 10.79448), 4326), 'seed', 'active', 4.7, 90),
  (gen_random_uuid(), 'Bún Bò 5', '5 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.66696, 10.81961), 4326), 'seed', 'active', 4.7, 11),
  (gen_random_uuid(), 'Quán Phở 6', '6 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.73785, 10.77388), 4326), 'seed', 'active', 4.7, 169),
  (gen_random_uuid(), 'Cơm Tấm 7', '7 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.67800, 10.84954), 4326), 'seed', 'active', 3.5, 180),
  (gen_random_uuid(), 'Bún Bò 8', '8 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.69400, 10.77809), 4326), 'seed', 'active', 4.8, 35),
  (gen_random_uuid(), 'Quán Phở 9', '9 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.62647, 10.81548), 4326), 'seed', 'active', 3.9, 83),
  (gen_random_uuid(), 'Cơm Tấm 10', '10 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.63043, 10.82637), 4326), 'seed', 'active', 4.6, 127),
  (gen_random_uuid(), 'Bún Bò 11', '11 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.64253, 10.84929), 4326), 'seed', 'active', 4.5, 93),
  (gen_random_uuid(), 'Quán Phở 12', '12 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.61685, 10.75179), 4326), 'seed', 'active', 4.8, 13),
  (gen_random_uuid(), 'Cơm Tấm 13', '13 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.64579, 10.77978), 4326), 'seed', 'active', 3.9, 116),
  (gen_random_uuid(), 'Bún Bò 14', '14 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.71972, 10.77420), 4326), 'seed', 'active', 3.9, 186),
  (gen_random_uuid(), 'Quán Phở 15', '15 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.63376, 10.75777), 4326), 'seed', 'active', 4.3, 73),
  (gen_random_uuid(), 'Cơm Tấm 16', '16 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.61681, 10.83679), 4326), 'seed', 'active', 4.9, 126),
  (gen_random_uuid(), 'Bún Bò 17', '17 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.70514, 10.77179), 4326), 'seed', 'active', 4.9, 113),
  (gen_random_uuid(), 'Quán Phở 18', '18 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.71650, 10.75716), 4326), 'seed', 'active', 4.0, 187),
  (gen_random_uuid(), 'Cơm Tấm 19', '19 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.65263, 10.83479), 4326), 'seed', 'active', 4.2, 103),
  (gen_random_uuid(), 'Bún Bò 20', '20 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.66080, 10.78673), 4326), 'seed', 'active', 4.4, 94),
  (gen_random_uuid(), 'Quán Phở 21', '21 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.71678, 10.84552), 4326), 'seed', 'active', 4.8, 61),
  (gen_random_uuid(), 'Cơm Tấm 22', '22 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.69956, 10.77050), 4326), 'seed', 'active', 4.1, 126),
  (gen_random_uuid(), 'Bún Bò 23', '23 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.69350, 10.84162), 4326), 'seed', 'active', 4.7, 171),
  (gen_random_uuid(), 'Quán Phở 24', '24 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.71974, 10.79723), 4326), 'seed', 'active', 5.0, 45),
  (gen_random_uuid(), 'Cơm Tấm 25', '25 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.74486, 10.76640), 4326), 'seed', 'active', 3.5, 56),
  (gen_random_uuid(), 'Bún Bò 26', '26 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.72269, 10.78939), 4326), 'seed', 'active', 3.8, 19),
  (gen_random_uuid(), 'Quán Phở 27', '27 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.70108, 10.77155), 4326), 'seed', 'active', 3.9, 13),
  (gen_random_uuid(), 'Cơm Tấm 28', '28 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.72344, 10.75168), 4326), 'seed', 'active', 4.3, 60),
  (gen_random_uuid(), 'Bún Bò 29', '29 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.69912, 10.78070), 4326), 'seed', 'active', 4.2, 82),
  (gen_random_uuid(), 'Quán Phở 30', '30 Đường XYZ, Quận 1', 'Hồ Chí Minh', extensions.ST_SetSRID(extensions.ST_MakePoint(106.62722, 10.82068), 4326), 'seed', 'active', 3.8, 74);

insert into public.restaurant_dishes (restaurant_id, dish_id, price_vnd)
select id, (case when name like '%Phở%' then 'd1111111-1111-1111-1111-111111111111'::uuid when name like '%Cơm%' then 'd2222222-2222-2222-2222-222222222222'::uuid else 'd3333333-3333-3333-3333-333333333333'::uuid end), 50000
from public.restaurants where source = 'seed';
