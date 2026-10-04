-- Bật các extensions trong schema "extensions" (chuẩn của Supabase Cloud và local)
create schema if not exists extensions;
create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

-- Hàm bọc unaccent, trỏ đến hàm trong schema extensions để dùng trong INDEX (phải IMMUTABLE)
create or replace function public.f_unaccent(text)
returns text language sql immutable parallel safe as
$$ select extensions.unaccent('extensions.unaccent', $1) $$;

-- 1. Bảng Profiles
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_url text,
  role text not null default 'user' check (role in ('user','admin')),
  is_banned boolean not null default false,
  created_at timestamptz not null default now()
);

-- 2. Bảng Dish Categories & Dishes
create table public.dish_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  region text
);

create table public.dishes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text not null,
  category_id uuid references public.dish_categories(id),
  aliases text[] not null default '{}',
  unique (normalized_name)
);

-- 3. Bảng Restaurants
-- Lưu ý: Sử dụng tường minh kiểu extensions.geography để tương thích tuyệt đối trên Supabase Cloud
create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  province text,
  location extensions.geography(Point,4326) not null,
  created_by uuid references public.profiles(id) on delete set null,
  source text not null default 'user' check (source in ('user','seed')),
  status text not null default 'active' check (status in ('active','hidden_pending_review','closed','removed')),
  avg_rating numeric(3,2) not null default 0,
  review_count integer not null default 0,
  created_at timestamptz not null default now()
);
create index restaurants_location_gix on public.restaurants using gist (location);
create index restaurants_name_trgm on public.restaurants using gin (public.f_unaccent(lower(name)) extensions.gin_trgm_ops);

-- Bảng phụ liên kết Quán và Món
create table public.restaurant_dishes (
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  dish_id uuid references public.dishes(id) on delete cascade,
  price_vnd integer check (price_vnd is null or price_vnd >= 0),
  primary key (restaurant_id, dish_id)
);

-- 4. Bảng Reviews
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  dish_id uuid references public.dishes(id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  content text check (char_length(content) <= 2000),
  is_anonymous boolean not null default false,
  status text not null default 'visible' check (status in ('visible','hidden_pending_review','removed')),
  helpful_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index reviews_one_per_target on public.reviews
  (user_id, restaurant_id, coalesce(dish_id, '00000000-0000-0000-0000-000000000000'::uuid));

create table public.review_photos (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  storage_path text not null,
  position smallint not null default 0
);

create table public.review_helpful (
  review_id uuid references public.reviews(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  primary key (review_id, user_id)
);

-- 5. Bảng Saved Items, Reports, Blocks, Audit Log
create table public.saved_items (
  user_id uuid references public.profiles(id) on delete cascade,
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  list_type text not null check (list_type in ('want_to_try','visited')),
  created_at timestamptz not null default now(),
  primary key (user_id, restaurant_id, list_type)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('review','restaurant','user')),
  target_id uuid not null,
  reason text not null,
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  created_at timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)
);

create table public.blocks (
  blocker_id uuid references public.profiles(id) on delete cascade,
  blocked_id uuid references public.profiles(id) on delete cascade,
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  action text not null,
  target_type text,
  target_id uuid,
  created_at timestamptz not null default now()
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- ==========================================

alter table public.profiles enable row level security;
alter table public.dish_categories enable row level security;
alter table public.dishes enable row level security;
alter table public.restaurants enable row level security;
alter table public.restaurant_dishes enable row level security;
alter table public.reviews enable row level security;
alter table public.review_photos enable row level security;
alter table public.review_helpful enable row level security;
alter table public.saved_items enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.admin_audit_log enable row level security;

-- Profiles
create policy "Public profiles are viewable by everyone" on public.profiles for select using (true);
create policy "Users can insert their own profile" on public.profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id)
  with check (auth.uid() = id);

-- Categories & Dishes
create policy "Categories viewable by everyone" on public.dish_categories for select using (true);
create policy "Dishes viewable by everyone" on public.dishes for select using (true);

-- Restaurants
create policy "Active restaurants viewable by everyone" on public.restaurants for select 
  using (status = 'active');
create policy "Users can insert restaurants" on public.restaurants for insert 
  with check (auth.uid() = created_by);

create policy "Restaurant dishes viewable by everyone" on public.restaurant_dishes for select using (true);

-- Reviews: Client KHÔNG THỂ select trực tiếp review của người khác (dùng view public_reviews)
create policy "Users can view own reviews" on public.reviews for select using (auth.uid() = user_id);
create policy "Users can insert own reviews" on public.reviews for insert with check (auth.uid() = user_id);
create policy "Users can update own reviews" on public.reviews for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "Users can delete own reviews" on public.reviews for delete using (auth.uid() = user_id);

-- Review Photos
create policy "Users can view own review photos" on public.review_photos for select 
  using (exists (select 1 from public.reviews r where r.id = review_id and r.user_id = auth.uid()));
create policy "Users can insert own review photos" on public.review_photos for insert 
  with check (exists (select 1 from public.reviews r where r.id = review_id and r.user_id = auth.uid()));
create policy "Users can delete own review photos" on public.review_photos for delete 
  using (exists (select 1 from public.reviews r where r.id = review_id and r.user_id = auth.uid()));

-- Review Helpful
create policy "Users can view helpful interactions" on public.review_helpful for select using (true);
create policy "Users can insert helpful" on public.review_helpful for insert with check (auth.uid() = user_id);
create policy "Users can delete helpful" on public.review_helpful for delete using (auth.uid() = user_id);

-- Saved Items
create policy "Users can manage own saved items" on public.saved_items for all using (auth.uid() = user_id);

-- Reports
create policy "Users can manage own reports" on public.reports for all using (auth.uid() = reporter_id);

-- Blocks
create policy "Users can manage own blocks" on public.blocks for all using (auth.uid() = blocker_id);


-- ==========================================
-- VIEWS
-- ==========================================

create view public.public_reviews 
with (security_invoker = off) as
select
  r.id,
  r.restaurant_id,
  r.dish_id,
  r.rating,
  r.content,
  r.is_anonymous,
  r.helpful_count,
  r.created_at,
  case when r.is_anonymous then null else r.user_id end as author_id,
  case when r.is_anonymous then null else p.display_name end as author_name,
  case when r.is_anonymous then null else p.avatar_url end as author_avatar
from public.reviews r
join public.profiles p on p.id = r.user_id
where r.status = 'visible'
  and not exists (
    select 1 from public.blocks b
    where b.blocker_id = auth.uid() and b.blocked_id = r.user_id
  );


-- ==========================================
-- FUNCTIONS (RPCs)
-- ==========================================

-- Lấy nhà hàng trong khung hiển thị bản đồ
create or replace function public.restaurants_in_bounds(
  min_lat float,
  min_lng float,
  max_lat float,
  max_lng float,
  filters jsonb default '{}'::jsonb,
  lim int default 500
) returns table (
  id uuid,
  name text,
  lat float,
  lng float,
  avg_rating numeric(3,2),
  review_count integer,
  status text
) 
language sql
security invoker
set search_path = public, extensions
as $$
  select 
    r.id, 
    r.name, 
    extensions.st_y(r.location::extensions.geometry) as lat, 
    extensions.st_x(r.location::extensions.geometry) as lng, 
    r.avg_rating, 
    r.review_count,
    r.status
  from public.restaurants r
  where r.status = 'active'
    and r.location && extensions.st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)
  limit lim;
$$;

-- Tìm kiếm với trigram
create or replace function public.search_restaurants(
  q text,
  lim int default 20
) returns table (
  id uuid,
  name text,
  address text,
  avg_rating numeric(3,2)
) 
language sql
security invoker
set search_path = public, extensions
as $$
  select 
    id, name, address, avg_rating
  from public.restaurants
  where status = 'active'
    and public.f_unaccent(lower(name)) % public.f_unaccent(lower(q))
  order by public.f_unaccent(lower(name)) <-> public.f_unaccent(lower(q))
  limit lim;
$$;

-- Kiểm tra trùng quán: tìm quán gần trong bán kính ~50m và có độ tương đồng tên
create or replace function public.check_duplicate_restaurant(
  name text,
  lat float,
  lng float
) returns table (
  id uuid,
  name text,
  address text,
  distance_meters float,
  similarity float
)
language sql
security invoker
set search_path = public, extensions
as $$
  select 
    r.id,
    r.name,
    r.address,
    extensions.st_distance(r.location, extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography) as distance_meters,
    extensions.similarity(public.f_unaccent(lower(r.name)), public.f_unaccent(lower(name))) as similarity
  from public.restaurants r
  where r.status = 'active'
    and extensions.st_dwithin(r.location, extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography, 50)
  order by similarity desc;
$$;


-- ==========================================
-- GIỚI HẠN CHỐNG LẠM DỤNG (Abuse Limits)
-- ==========================================

-- Hàm trigger kiểm tra giới hạn thêm review
create or replace function public.check_review_limits()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  daily_count int;
begin
  select count(*) into daily_count
  from public.reviews
  where user_id = new.user_id
    and created_at >= now() - interval '1 day';
    
  if daily_count >= 10 then
    raise exception 'Đã vượt quá giới hạn 10 review mỗi ngày.';
  end if;
  return new;
end;
$$;

create trigger trg_check_review_limits
before insert on public.reviews
for each row execute function public.check_review_limits();

-- Hàm trigger kiểm tra giới hạn thêm nhà hàng
create or replace function public.check_restaurant_limits()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  daily_count int;
begin
  -- Bỏ qua nếu là seed
  if new.source = 'seed' then
    return new;
  end if;

  select count(*) into daily_count
  from public.restaurants
  where created_by = new.created_by
    and created_at >= now() - interval '1 day';
    
  if daily_count >= 5 then
    raise exception 'Đã vượt quá giới hạn tạo 5 địa điểm mỗi ngày.';
  end if;
  return new;
end;
$$;

create trigger trg_check_restaurant_limits
before insert on public.restaurants
for each row execute function public.check_restaurant_limits();
