drop function public.restaurants_in_bounds(
  double precision,
  double precision,
  double precision,
  double precision,
  jsonb,
  integer
);

create function public.restaurants_in_bounds(
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
      or r.province = (filters ->> 'province')
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
          and category.name = (filters ->> 'dish_type')
      )
    )
  limit lim;
$$;

grant execute on function public.restaurants_in_bounds(
  double precision,
  double precision,
  double precision,
  double precision,
  jsonb,
  integer
) to anon, authenticated;
