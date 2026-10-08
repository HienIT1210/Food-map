-- Remove API-wide write grants and grant only columns users are allowed to control.
revoke insert, update on table public.restaurants from public, anon, authenticated;
grant insert (name, address, province, location, created_by)
  on table public.restaurants to authenticated;
grant update (name, address, province, location, created_by)
  on table public.restaurants to authenticated;

revoke insert, update on table public.reviews from public, anon, authenticated;
grant insert (user_id, restaurant_id, dish_id, rating, content, is_anonymous)
  on table public.reviews to authenticated;
grant update (dish_id, rating, content, is_anonymous)
  on table public.reviews to authenticated;

revoke insert, update on table public.reports from public, anon, authenticated;
grant insert (reporter_id, target_type, target_id, reason)
  on table public.reports to authenticated;
grant update (reason) on table public.reports to authenticated;

revoke insert, update on table public.review_photos from public, anon, authenticated;
grant insert (review_id, storage_path, position)
  on table public.review_photos to authenticated;
grant update (storage_path, position)
  on table public.review_photos to authenticated;

revoke insert, update on table public.saved_items from public, anon, authenticated;
grant insert (user_id, restaurant_id, list_type)
  on table public.saved_items to authenticated;
grant update (list_type) on table public.saved_items to authenticated;

revoke insert, update on table public.blocks from public, anon, authenticated;
grant insert (blocker_id, blocked_id) on table public.blocks to authenticated;

-- Canonicalize review metadata before insert and preserve it on updates, including writes
-- made through privileged paths. The review limit counts the authenticated actor's rows.
create or replace function public.check_review_limits()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  daily_count int;
begin
  if auth.uid() is null then
    return new;
  end if;

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

create or replace function public.enforce_review_system_fields()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'visible';
    new.helpful_count := 0;
    new.created_at := now();
  else
    new.status := old.status;
    new.helpful_count := old.helpful_count;
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_enforce_review_system_fields
before insert or update on public.reviews
for each row execute function public.enforce_review_system_fields();

create or replace function public.enforce_report_system_fields()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'open';
    new.created_at := now();
  else
    new.status := old.status;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_report_system_fields
before insert or update on public.reports
for each row execute function public.enforce_report_system_fields();

create or replace function public.enforce_saved_item_system_fields()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
  else
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_saved_item_system_fields
before insert or update on public.saved_items
for each row execute function public.enforce_saved_item_system_fields();

-- Bound the public map RPC regardless of its caller-provided limit and define stable ordering.
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
  status text,
  province text,
  dish_types text[]
)
language sql
stable
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
    r.status,
    r.province,
    array(
      select distinct category.name
      from public.restaurant_dishes restaurant_dish
      join public.dishes dish on dish.id = restaurant_dish.dish_id
      join public.dish_categories category on category.id = dish.category_id
      where restaurant_dish.restaurant_id = r.id
      order by category.name
    ) as dish_types
  from public.restaurants r
  where r.status = 'active'
    and r.location && extensions.st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)
    and (
      filters ->> 'min_rating' is null
      or r.avg_rating >= (filters ->> 'min_rating')::numeric
    )
    and (
      filters ->> 'province' is null
      or r.province = filters ->> 'province'
    )
    and (
      filters ->> 'max_price' is null
      or exists (
        select 1
        from public.restaurant_dishes restaurant_dish
        where restaurant_dish.restaurant_id = r.id
          and restaurant_dish.price_vnd < (filters ->> 'max_price')::integer
      )
    )
    and (
      filters ->> 'dish_type' is null
      or exists (
        select 1
        from public.restaurant_dishes restaurant_dish
        join public.dishes dish on dish.id = restaurant_dish.dish_id
        join public.dish_categories category on category.id = dish.category_id
        where restaurant_dish.restaurant_id = r.id
          and category.name = filters ->> 'dish_type'
      )
    )
  order by r.id
  limit least(greatest(coalesce(lim, 500), 0), 500);
$$;

-- The source value is derived from the trusted JWT context, never from client input.
-- A null auth.uid() is reserved for trusted seed/administrative writes; anon has no INSERT grant.
create or replace function public.check_restaurant_limits()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  daily_count int;
begin
  new.created_at := now();
  new.status := 'active';
  new.avg_rating := 0;
  new.review_count := 0;

  if auth.uid() is null then
    new.source := 'seed';
    return new;
  end if;

  new.created_by := auth.uid();
  new.source := 'user';

  select count(*) into daily_count
  from public.restaurants
  where created_by = auth.uid()
    and created_at >= now() - interval '1 day';

  if daily_count >= 5 then
    raise exception 'Đã vượt quá giới hạn tạo 5 địa điểm mỗi ngày.';
  end if;
  return new;
end;
$$;
