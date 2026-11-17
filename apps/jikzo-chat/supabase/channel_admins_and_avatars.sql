-- JIKZO Chat channel pictures and multiple admins
-- Run this once in Supabase SQL Editor. Safe to rerun.

alter table public.jikzo_channels
  add column if not exists avatar_url text;

create or replace function public.jikzo_is_channel_owner(target_channel uuid)
returns boolean
language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.jikzo_channel_members
    where channel_id = target_channel
      and user_id = auth.uid()
      and role = 'owner'
  );
$$;

create or replace function public.jikzo_add_channel_admin(
  target_channel uuid,
  target_username text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare target_user uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in required';
  end if;

  if not public.jikzo_is_channel_owner(target_channel) then
    raise exception 'Only the channel owner can appoint administrators';
  end if;

  if target_username is null or char_length(trim(target_username)) < 3 then
    raise exception 'Enter a valid username';
  end if;

  select id into target_user
  from public.profiles
  where lower(username) = lower(trim(target_username))
  limit 1;

  if target_user is null then
    raise exception 'No JIKZO user found with that username';
  end if;

  insert into public.jikzo_channel_members(channel_id, user_id, role)
  values (target_channel, target_user, 'admin')
  on conflict (channel_id, user_id) do update
    set role = case
      when public.jikzo_channel_members.role = 'owner' then 'owner'
      else 'admin'
    end;

  return target_user;
end;
$$;

drop policy if exists "Channel owners can update channel details" on public.jikzo_channels;
create policy "Channel owners can update channel details"
  on public.jikzo_channels
  for update to authenticated
  using (public.jikzo_is_channel_owner(id))
  with check (public.jikzo_is_channel_owner(id));

revoke all on function public.jikzo_is_channel_owner(uuid) from public;
revoke all on function public.jikzo_add_channel_admin(uuid,text) from public;
grant execute on function public.jikzo_is_channel_owner(uuid) to authenticated;
grant execute on function public.jikzo_add_channel_admin(uuid,text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'jikzo-channel-avatars',
  'jikzo-channel-avatars',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public = true,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Anyone can view JIKZO channel pictures" on storage.objects;
create policy "Anyone can view JIKZO channel pictures"
  on storage.objects for select
  using (bucket_id = 'jikzo-channel-avatars');

drop policy if exists "Channel owners can upload channel pictures" on storage.objects;
create policy "Channel owners can upload channel pictures"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'jikzo-channel-avatars'
    and public.jikzo_is_channel_owner(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "Channel owners can update channel pictures" on storage.objects;
create policy "Channel owners can update channel pictures"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'jikzo-channel-avatars'
    and public.jikzo_is_channel_owner(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = 'jikzo-channel-avatars'
    and public.jikzo_is_channel_owner(((storage.foldername(name))[1])::uuid)
  );
