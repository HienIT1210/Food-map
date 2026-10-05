-- Mutation check: temporarily grant authenticated UPDATE on every profile column.
revoke update on table public.profiles from public, anon, authenticated;
grant update on table public.profiles to authenticated;
-- A banned account must not be able to create reviews through a direct API call.
drop policy "Users can insert own reviews" on public.reviews;
create policy "Users can insert own reviews" on public.reviews for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and not p.is_banned
    )
  );

create or replace function public.enforce_anonymous_review_photo_path()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  review_owner_id uuid;
  review_is_anonymous boolean;
begin
  select r.user_id, r.is_anonymous
  into review_owner_id, review_is_anonymous
  from public.reviews r
  where r.id = new.review_id;

  if review_is_anonymous
     and position(lower(review_owner_id::text) in lower(new.storage_path)) > 0 then
    raise exception 'Anonymous review photo paths must not contain the review owner ID.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger trg_enforce_anonymous_review_photo_path
before insert or update of review_id, storage_path on public.review_photos
for each row execute function public.enforce_anonymous_review_photo_path();

create or replace function public.prevent_anonymizing_review_with_identifying_photo()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if new.is_anonymous
     and exists (
       select 1
       from public.review_photos p
       where p.review_id = new.id
         and position(lower(new.user_id::text) in lower(p.storage_path)) > 0
     ) then
    raise exception 'Review cannot be made anonymous while a photo path contains the owner ID.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger trg_prevent_anonymizing_review_with_identifying_photo
before update of is_anonymous on public.reviews
for each row execute function public.prevent_anonymizing_review_with_identifying_photo();