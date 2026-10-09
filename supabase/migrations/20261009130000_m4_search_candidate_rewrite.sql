-- Keep restaurant-field and dish-field candidates independent so a matching
-- restaurant name cannot be lost in the dish lateral aggregation path.
create or replace function public.search_restaurants(
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
  ), restaurant_matches as (
    select
      r.id,
      greatest(
        extensions.similarity(public.f_unaccent(lower(r.name)), search_input.term),
        extensions.similarity(public.f_unaccent(lower(coalesce(r.address, ''))), search_input.term),
        extensions.similarity(public.f_unaccent(lower(coalesce(r.province, ''))), search_input.term),
        case when exists (
          select 1
          from unnest(string_to_array(search_input.term, ' ')) as query_token(value)
          where length(query_token.value) >= 3
            and (
              position(query_token.value in public.f_unaccent(lower(r.name))) > 0
              or position(query_token.value in public.f_unaccent(lower(coalesce(r.address, '')))) > 0
              or position(query_token.value in public.f_unaccent(lower(coalesce(r.province, '')))) > 0
            )
        ) then 0.5 else 0 end
      ) as relevance
    from public.restaurants as r
    cross join search_input
    where r.status = 'active'
      and search_input.term is not null
      and (
        public.f_unaccent(lower(r.name)) % search_input.term
        or extensions.similarity(public.f_unaccent(lower(r.name)), search_input.term) >= 0.25
        or position(search_input.term in public.f_unaccent(lower(r.name))) > 0
        or public.f_unaccent(lower(coalesce(r.address, ''))) % search_input.term
        or extensions.similarity(public.f_unaccent(lower(coalesce(r.address, ''))), search_input.term) >= 0.25
        or position(search_input.term in public.f_unaccent(lower(coalesce(r.address, '')))) > 0
        or public.f_unaccent(lower(coalesce(r.province, ''))) % search_input.term
        or extensions.similarity(public.f_unaccent(lower(coalesce(r.province, ''))), search_input.term) >= 0.25
        or position(search_input.term in public.f_unaccent(lower(coalesce(r.province, '')))) > 0
        or exists (
          select 1
          from unnest(string_to_array(search_input.term, ' ')) as query_token(value)
          where length(query_token.value) >= 3
            and (
              position(query_token.value in public.f_unaccent(lower(r.name))) > 0
              or position(query_token.value in public.f_unaccent(lower(coalesce(r.address, '')))) > 0
              or position(query_token.value in public.f_unaccent(lower(coalesce(r.province, '')))) > 0
            )
        )
      )
  ), dish_matches as (
    select
      r.id,
      max(greatest(
        extensions.similarity(public.f_unaccent(lower(d.name)), search_input.term),
        coalesce((
          select max(extensions.similarity(public.f_unaccent(lower(alias.value)), search_input.term))
          from unnest(d.aliases) as alias(value)
        ), 0),
        case when exists (
          select 1
          from unnest(string_to_array(search_input.term, ' ')) as query_token(value)
          where length(query_token.value) >= 3
            and (
              position(query_token.value in public.f_unaccent(lower(d.name))) > 0
              or exists (
                select 1
                from unnest(d.aliases) as alias(value)
                where position(query_token.value in public.f_unaccent(lower(alias.value))) > 0
              )
            )
        ) then 0.5 else 0 end
      )) as relevance
    from public.restaurants as r
    join public.restaurant_dishes as rd on rd.restaurant_id = r.id
    join public.dishes as d on d.id = rd.dish_id
    cross join search_input
    where r.status = 'active'
      and search_input.term is not null
      and (
        public.f_unaccent(lower(d.name)) % search_input.term
        or extensions.similarity(public.f_unaccent(lower(d.name)), search_input.term) >= 0.25
        or position(search_input.term in public.f_unaccent(lower(d.name))) > 0
        or exists (
          select 1
          from unnest(d.aliases) as alias(value)
          where public.f_unaccent(lower(alias.value)) % search_input.term
            or extensions.similarity(public.f_unaccent(lower(alias.value)), search_input.term) >= 0.25
            or position(search_input.term in public.f_unaccent(lower(alias.value))) > 0
        )
        or exists (
          select 1
          from unnest(string_to_array(search_input.term, ' ')) as query_token(value)
          where length(query_token.value) >= 3
            and (
              position(query_token.value in public.f_unaccent(lower(d.name))) > 0
              or exists (
                select 1
                from unnest(d.aliases) as alias(value)
                where position(query_token.value in public.f_unaccent(lower(alias.value))) > 0
              )
            )
        )
      )
    group by r.id
  ), all_matches as (
    select id, relevance from restaurant_matches
    union all
    select id, relevance from dish_matches
  ), matched_restaurants as (
    select id, max(relevance) as relevance
    from all_matches
    group by id
  )
  select
    r.id,
    r.name,
    r.address,
    r.avg_rating,
    r.review_count,
    extensions.st_y(r.location::extensions.geometry),
    extensions.st_x(r.location::extensions.geometry)
  from matched_restaurants as matches
  join public.restaurants as r on r.id = matches.id
  order by matches.relevance desc, r.id
  limit least(greatest(coalesce(lim, 20), 1), 50);
$$;

revoke all on function public.search_restaurants(text, integer) from public;
grant execute on function public.search_restaurants(text, integer) to anon, authenticated;
