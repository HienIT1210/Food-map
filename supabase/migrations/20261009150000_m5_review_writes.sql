-- M5: authenticated review mutations, useful votes, and public review photo metadata.
create or replace function public.check_review_limits()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  daily_count integer;
  daily_limit integer := coalesce(nullif(current_setting('app.review_daily_limit', true), '')::integer, 10);
begin
  if auth.uid() is null then return new; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  select count(*)::integer into daily_count
  from public.reviews
  where user_id = auth.uid() and created_at >= now() - interval '1 day';
  if daily_count >= daily_limit then
    raise exception 'Đã vượt quá giới hạn % review mỗi ngày.', daily_limit;
  end if;
  return new;
end;
$$;

create or replace function public.save_review(
  p_restaurant_id uuid,
  p_dish_id uuid,
  p_rating smallint,
  p_content text,
  p_is_anonymous boolean
) returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  actor uuid := auth.uid();
  review_id uuid;
  account_created_at timestamptz;
  verified_at timestamptz;
  anonymous_min_age interval := coalesce(
    nullif(current_setting('app.anonymous_review_min_age', true), '')::interval,
    interval '24 hours'
  );
begin
  if actor is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_rating not between 1 and 5 or char_length(p_content) > 2000 then
    raise exception 'Invalid review';
  end if;

  select p.created_at, u.email_confirmed_at into account_created_at, verified_at
  from public.profiles p join auth.users u on u.id = p.id
  where p.id = actor and not p.is_banned;
  if not found then raise exception 'Account unavailable' using errcode = '42501'; end if;
  if p_is_anonymous and (verified_at is null or account_created_at > now() - anonymous_min_age) then
    raise exception 'Anonymous reviews require a verified account at least 24 hours old' using errcode = '42501';
  end if;
  if not exists (select 1 from public.restaurants r where r.id = p_restaurant_id and r.status = 'active') then
    raise exception 'Restaurant unavailable';
  end if;
  if p_dish_id is not null and not exists (
    select 1 from public.restaurant_dishes rd where rd.restaurant_id = p_restaurant_id and rd.dish_id = p_dish_id
  ) then raise exception 'Dish does not belong to restaurant'; end if;

  select id into review_id from public.reviews
  where user_id = actor and restaurant_id = p_restaurant_id and dish_id is not distinct from p_dish_id;
  if review_id is null then
    insert into public.reviews(user_id, restaurant_id, dish_id, rating, content, is_anonymous)
    values (actor, p_restaurant_id, p_dish_id, p_rating, nullif(trim(p_content), ''), p_is_anonymous)
    returning id into review_id;
  else
    update public.reviews set rating = p_rating, content = nullif(trim(p_content), ''), is_anonymous = p_is_anonymous
    where id = review_id and user_id = actor;
  end if;
  return review_id;
end;
$$;

create or replace function public.delete_review(p_review_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  delete from storage.objects o
  using public.review_photos photo, public.reviews review
  where photo.review_id = review.id and o.bucket_id = 'review-photos'
    and o.name = photo.storage_path and review.id = p_review_id and review.user_id = auth.uid();
  delete from public.reviews where id = p_review_id and user_id = auth.uid();
  return found;
end;
$$;

create or replace function public.my_review_for_target(p_restaurant_id uuid, p_dish_id uuid default null)
returns table (id uuid, rating smallint, content text, is_anonymous boolean)
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.rating, r.content, r.is_anonymous
  from public.reviews r
  where r.user_id = auth.uid() and r.restaurant_id = p_restaurant_id
    and r.dish_id is not distinct from p_dish_id
  limit 1;
$$;

create or replace function public.my_reviews()
returns table (
  id uuid, restaurant_id uuid, restaurant_name text, dish_id uuid,
  rating smallint, content text, is_anonymous boolean, created_at timestamptz
)
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.restaurant_id, restaurant.name, r.dish_id,
    r.rating, r.content, r.is_anonymous, r.created_at
  from public.reviews r
  join public.restaurants restaurant on restaurant.id = r.restaurant_id
  where r.user_id = auth.uid()
  order by r.created_at desc, r.id desc;
$$;

create or replace function public.toggle_review_helpful(p_review_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  actor uuid := auth.uid();
  currently_helpful boolean;
begin
  if actor is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if exists (select 1 from public.reviews where id = p_review_id and user_id = actor) then
    raise exception 'Cannot vote for your own review' using errcode = '42501';
  end if;
  if not exists (select 1 from public.reviews where id = p_review_id and status = 'visible') then
    raise exception 'Review unavailable';
  end if;
  delete from public.review_helpful where review_id = p_review_id and user_id = actor;
  if found then return false; end if;
  insert into public.review_helpful(review_id, user_id) values (p_review_id, actor);
  return true;
end;
$$;

create or replace function public.add_review_photo(p_review_id uuid, p_storage_path text, p_position smallint)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.reviews r where r.id = p_review_id and r.user_id = auth.uid()
  ) then raise exception 'Review unavailable' using errcode = '42501'; end if;
  if split_part(p_storage_path, '/', 1) <> p_review_id::text then raise exception 'Invalid photo path'; end if;
  insert into public.review_photos(review_id, storage_path, position)
  values (p_review_id, p_storage_path, p_position);
end;
$$;

revoke all on function public.save_review(uuid, uuid, smallint, text, boolean) from public, anon;
revoke all on function public.delete_review(uuid) from public, anon;
revoke all on function public.my_review_for_target(uuid, uuid) from public, anon;
revoke all on function public.my_reviews() from public, anon;
revoke all on function public.toggle_review_helpful(uuid) from public, anon;
revoke all on function public.add_review_photo(uuid, text, smallint) from public, anon;
grant execute on function public.save_review(uuid, uuid, smallint, text, boolean) to authenticated;
grant execute on function public.delete_review(uuid) to authenticated;
grant execute on function public.my_review_for_target(uuid, uuid) to authenticated;
grant execute on function public.my_reviews() to authenticated;
grant execute on function public.toggle_review_helpful(uuid) to authenticated;
grant execute on function public.add_review_photo(uuid, text, smallint) to authenticated;

-- All mutations go through the validated RPCs so anonymous eligibility and review limits cannot be skipped.
revoke insert, update, delete on table public.reviews from public, anon, authenticated;
revoke insert, update, delete on table public.review_photos from public, anon, authenticated;
revoke insert, update, delete on table public.review_helpful from public, anon, authenticated;

-- Storage paths are review-scoped UUIDs, never account identifiers.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('review-photos', 'review-photos', true, 5242880, array['image/jpeg', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/webp'];

drop policy if exists "Review photos are publicly readable" on storage.objects;
create policy "Review photos are publicly readable" on storage.objects for select
using (bucket_id = 'review-photos');
drop policy if exists "Owners upload review photos" on storage.objects;
create policy "Owners upload review photos" on storage.objects for insert to authenticated
with check (
  bucket_id = 'review-photos'
  and exists (select 1 from public.reviews r where r.id::text = (storage.foldername(name))[1] and r.user_id = auth.uid())
);
drop policy if exists "Owners update review photos" on storage.objects;
create policy "Owners update review photos" on storage.objects for update to authenticated
using (
  bucket_id = 'review-photos'
  and exists (select 1 from public.reviews r where r.id::text = (storage.foldername(name))[1] and r.user_id = auth.uid())
)
with check (
  bucket_id = 'review-photos'
  and exists (select 1 from public.reviews r where r.id::text = (storage.foldername(name))[1] and r.user_id = auth.uid())
);
drop policy if exists "Owners delete review photos" on storage.objects;
create policy "Owners delete review photos" on storage.objects for delete to authenticated
using (
  bucket_id = 'review-photos'
  and exists (select 1 from public.reviews r where r.id::text = (storage.foldername(name))[1] and r.user_id = auth.uid())
);

create or replace function public.enforce_review_photo_limit()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare photo_count integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(new.review_id::text, 0));
  if auth.uid() is not null and not exists (
    select 1 from public.reviews r where r.id = new.review_id and r.user_id = auth.uid()
  ) then
    raise exception 'Review unavailable' using errcode = '42501';
  end if;
  select count(*) into photo_count from public.review_photos where review_id = new.review_id;
  if photo_count >= 5 then raise exception 'A review can have at most five photos'; end if;
  return new;
end;
$$;
create trigger trg_enforce_review_photo_limit before insert on public.review_photos
for each row execute function public.enforce_review_photo_limit();

create or replace function public.recalculate_restaurant_review_stats()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare restaurant_key uuid := coalesce(new.restaurant_id, old.restaurant_id);
begin
  update public.restaurants restaurant
  set review_count = stats.review_count, avg_rating = stats.avg_rating
  from (
    select count(*)::integer as review_count, coalesce(round(avg(r.rating), 2), 0)::numeric(3,2) as avg_rating
    from public.reviews r where r.restaurant_id = restaurant_key and r.status = 'visible'
  ) stats
  where restaurant.id = restaurant_key;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
create trigger trg_recalculate_restaurant_review_stats
after insert or delete or update of rating, status on public.reviews
for each row execute function public.recalculate_restaurant_review_stats();

create or replace function public.recalculate_review_helpful_count()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare review_key uuid := coalesce(new.review_id, old.review_id);
begin
  update public.reviews r
  set helpful_count = (select count(*)::integer from public.review_helpful h where h.review_id = review_key)
  where r.id = review_key;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
create trigger trg_recalculate_review_helpful_count
after insert or delete on public.review_helpful
for each row execute function public.recalculate_review_helpful_count();

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
    new.helpful_count := (select count(*)::integer from public.review_helpful h where h.review_id = old.id);
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- Add only storage paths to the public view; ownership identifiers remain excluded.
create or replace view public.public_reviews with (security_invoker = off) as
select
  r.id, r.restaurant_id, r.dish_id, r.rating, r.content, r.is_anonymous,
  r.helpful_count, r.created_at,
  case when r.is_anonymous then null else r.user_id end as author_id,
  case when r.is_anonymous then null else p.display_name end as author_name,
  case when r.is_anonymous then null else p.avatar_url end as author_avatar,
  coalesce(array_agg(photo.storage_path order by photo.position, photo.id)
    filter (where photo.storage_path is not null), '{}') as photo_paths
from public.reviews r
join public.profiles p on p.id = r.user_id
left join public.review_photos photo on photo.review_id = r.id
where r.status = 'visible'
  and not exists (select 1 from public.blocks b where b.blocker_id = auth.uid() and b.blocked_id = r.user_id)
group by r.id, p.id;

grant select on public.public_reviews to anon, authenticated;

-- Keep existing restaurants consistent when this migration is applied to an established database.
update public.restaurants restaurant
set review_count = stats.review_count,
    avg_rating = stats.avg_rating
from (
  select restaurant_row.id,
    (count(review.id) filter (where review.status = 'visible'))::integer as review_count,
    coalesce(round(avg(review.rating) filter (where review.status = 'visible'), 2), 0)::numeric(3,2) as avg_rating
  from public.restaurants restaurant_row
  left join public.reviews review on review.restaurant_id = restaurant_row.id
  group by restaurant_row.id
) stats
where restaurant.id = stats.id;
