-- JIKZO Chat public channels (MVP)
-- Run once in Supabase SQL Editor. Safe to rerun.

create table if not exists public.jikzo_channels (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  description text not null default '' check (char_length(description) <= 300),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create unique index if not exists jikzo_channels_name_lower_uidx
  on public.jikzo_channels (lower(name));

create table if not exists public.jikzo_channel_members (
  channel_id uuid not null references public.jikzo_channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  joined_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create table if not exists public.jikzo_channel_posts (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.jikzo_channels(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists jikzo_channel_posts_channel_created_idx
  on public.jikzo_channel_posts(channel_id, created_at);

alter table public.jikzo_channels enable row level security;
alter table public.jikzo_channel_members enable row level security;
alter table public.jikzo_channel_posts enable row level security;

create or replace function public.jikzo_is_channel_member(target_channel uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.jikzo_channel_members
    where channel_id = target_channel and user_id = auth.uid()
  );
$$;

create or replace function public.jikzo_is_channel_admin(target_channel uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.jikzo_channel_members
    where channel_id = target_channel and user_id = auth.uid()
      and role in ('owner','admin')
  );
$$;

drop policy if exists "Authenticated users can discover channels" on public.jikzo_channels;
create policy "Authenticated users can discover channels"
  on public.jikzo_channels for select to authenticated using (true);

drop policy if exists "Members can read own channel memberships" on public.jikzo_channel_members;
create policy "Members can read own channel memberships"
  on public.jikzo_channel_members for select to authenticated using (user_id = auth.uid());

drop policy if exists "Members can read channel posts" on public.jikzo_channel_posts;
create policy "Members can read channel posts"
  on public.jikzo_channel_posts for select to authenticated
  using (public.jikzo_is_channel_member(channel_id));

drop policy if exists "Only channel admins can publish posts" on public.jikzo_channel_posts;
create policy "Only channel admins can publish posts"
  on public.jikzo_channel_posts for insert to authenticated
  with check (sender_id = auth.uid() and public.jikzo_is_channel_admin(channel_id));

create or replace function public.jikzo_create_channel(channel_name text, channel_description text default '')
returns uuid language plpgsql security definer set search_path=public
as $$
declare new_channel uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if channel_name is null or char_length(trim(channel_name)) not between 1 and 60 then
    raise exception 'Channel name must be between 1 and 60 characters';
  end if;
  if char_length(coalesce(channel_description,'')) > 300 then
    raise exception 'Channel description must be 300 characters or fewer';
  end if;
  insert into public.jikzo_channels(name, description, created_by)
  values (trim(channel_name), coalesce(trim(channel_description),''), auth.uid())
  returning id into new_channel;
  insert into public.jikzo_channel_members(channel_id,user_id,role)
  values (new_channel, auth.uid(), 'owner');
  return new_channel;
exception when unique_violation then
  raise exception 'A channel with that name already exists';
end;
$$;

create or replace function public.jikzo_join_channel(target_channel uuid)
returns void language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from public.jikzo_channels where id = target_channel) then
    raise exception 'Channel not found';
  end if;
  insert into public.jikzo_channel_members(channel_id,user_id,role)
  values(target_channel,auth.uid(),'member')
  on conflict(channel_id,user_id) do nothing;
end;
$$;

revoke all on function public.jikzo_is_channel_member(uuid) from public;
revoke all on function public.jikzo_is_channel_admin(uuid) from public;
revoke all on function public.jikzo_create_channel(text,text) from public;
revoke all on function public.jikzo_join_channel(uuid) from public;
grant execute on function public.jikzo_is_channel_member(uuid) to authenticated;
grant execute on function public.jikzo_is_channel_admin(uuid) to authenticated;
grant execute on function public.jikzo_create_channel(text,text) to authenticated;
grant execute on function public.jikzo_join_channel(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'jikzo_channel_posts'
  ) then
    alter publication supabase_realtime add table public.jikzo_channel_posts;
  end if;
end $$;
