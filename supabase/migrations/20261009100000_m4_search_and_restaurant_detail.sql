-- M4 search covers restaurant names/addresses and dish names/aliases.
create index if not exists restaurants_address_trgm
  on public.restaurants using gin (public.f_unaccent(lower(coalesce(address, ''))) extensions.gin_trgm_ops);
create index if not exists dishes_name_trgm
  on public.dishes using gin (public.f_unaccent(lower(name)) extensions.gin_trgm_ops);
create index if not exists reviews_public_newest_cursor
  on public.reviews (restaurant_id, created_at desc, id desc) where status = 'visible';
create index if not exists reviews_public_helpful_cursor
  on public.reviews (restaurant_id, helpful_count desc, created_at desc, id desc) where status = 'visible';
create index if not exists reviews_public_rating_high_cursor
  on public.reviews (restaurant_id, rating desc, created_at desc, id desc) where status = 'visible';
create index if not exists reviews_public_rating_low_cursor
  on public.reviews (restaurant_id, rating asc, created_at desc, id desc) where status = 'visible';

drop function public.search_restaurants(text, integer);

create function public.search_restaurants(
  q text,
  lim integer default 20
) returns table (
  id uuid,
  name text,
  address text,
  avg_rating numeric(3,2),
  review_count integer,
  lat double precision,
  lng double precision
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with search_input as (
    select nullif(public.f_unaccent(lower(btrim(q))), '') as term
  ), matched_restaurants as (
    select
      r.id,
      greatest(
        extensions.similarity(restaurant_text.name, search_input.term),
        extensions.similarity(restaurant_text.address, search_input.term),
        extensions.similarity(restaurant_text.province, search_input.term),
        coalesce(dish_matches.score, 0)
      ) as relevance
    from public.restaurants r
    cross join search_input
    cross join lateral (
      select
        public.f_unaccent(lower(r.name)) as name,
        public.f_unaccent(lower(coalesce(r.address, ''))) as address,
        public.f_unaccent(lower(coalesce(r.province, ''))) as province
    ) restaurant_text
    left join lateral (
      select max(dish_match.score) as score
      from (
        select greatest(
          extensions.similarity(public.f_unaccent(lower(d.name)), search_input.term),
          coalesce((
            select max(extensions.similarity(public.f_unaccent(lower(alias.value)), search_input.term))
            from unnest(d.aliases) as alias(value)
          ), 0)
        ) as score
        from public.restaurant_dishes rd
        join public.dishes d on d.id = rd.dish_id
        where rd.restaurant_id = r.id
          and (
            public.f_unaccent(lower(d.name)) % search_input.term
            or position(search_input.term in public.f_unaccent(lower(d.name))) > 0
            or exists (
              select 1
              from unnest(d.aliases) as alias(value)
              where public.f_unaccent(lower(alias.value)) % search_input.term
                or position(search_input.term in public.f_unaccent(lower(alias.value))) > 0
            )
          )
      ) dish_match
    ) dish_matches on true
    where r.status = 'active'
      and search_input.term is not null
      and (
        restaurant_text.name % search_input.term
        or position(search_input.term in restaurant_text.name) > 0
        or restaurant_text.address % search_input.term
        or position(search_input.term in restaurant_text.address) > 0
        or restaurant_text.province % search_input.term
        or position(search_input.term in restaurant_text.province) > 0
        or coalesce(dish_matches.score, 0) >= 0.25
      )
  )
  select
    r.id,
    r.name,
    r.address,
    r.avg_rating,
    r.review_count,
    extensions.st_y(r.location::extensions.geometry),
    extensions.st_x(r.location::extensions.geometry)
  from matched_restaurants matches
  join public.restaurants r on r.id = matches.id
  order by matches.relevance desc, r.id
  limit least(greatest(coalesce(lim, 20), 1), 50);
$$;

revoke all on function public.search_restaurants(text, integer) from public;
grant execute on function public.search_restaurants(text, integer) to anon, authenticated;

create or replace function public.restaurant_detail(p_restaurant_id uuid)
returns table (
  id uuid,
  name text,
  address text,
  province text,
  avg_rating numeric(3,2),
  review_count integer,
  lat double precision,
  lng double precision
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    r.id,
    r.name,
    r.address,
    r.province,
    r.avg_rating,
    r.review_count,
    extensions.st_y(r.location::extensions.geometry),
    extensions.st_x(r.location::extensions.geometry)
  from public.restaurants r
  where r.id = p_restaurant_id
    and r.status = 'active';
$$;

revoke all on function public.restaurant_detail(uuid) from public;
grant execute on function public.restaurant_detail(uuid) to anon, authenticated;
