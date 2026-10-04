-- Migration: Trigger tự động tạo hồ sơ profile khi có user mới trong auth.users
-- File: 20261004141000_handle_new_user.sql

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  raw_name text;
begin
  -- Ưu tiên full_name hoặc name từ user_metadata, nếu không có lấy phần username của email, hoặc mặc định 'Thực khách'
  raw_name := coalesce(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    split_part(new.email, '@', 1),
    'Thực khách'
  );

  insert into public.profiles (id, display_name, avatar_url, role)
  values (
    new.id,
    coalesce(raw_name, 'Thực khách'),
    new.raw_user_meta_data->>'avatar_url',
    'user'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- Tạo trigger trên auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
