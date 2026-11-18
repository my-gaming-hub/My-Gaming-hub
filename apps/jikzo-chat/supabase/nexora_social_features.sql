-- Nexora social features foundation
-- Run once in Supabase SQL Editor. Safe to rerun.
-- Keeps existing profiles, conversations, messages and channels unchanged.

-- 1) Online presence / last seen
create table if not exists public.nexora_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_online boolean not null default false,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.nexora_presence enable row level security;
drop policy if exists "Presence is visible to authenticated users" on public.nexora_presence;
create policy "Presence is visible to authenticated users"
  on public.nexora_presence for select to authenticated using (true);
drop policy if exists "Users can create their own presence" on public.nexora_presence;
create policy "Users can create their own presence"
  on public.nexora_presence for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "Users can update their own presence" on public.nexora_presence;
create policy "Users can update their own presence"
  on public.nexora_presence for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create index if not exists nexora_presence_online_idx
  on public.nexora_presence(is_online, updated_at desc);

-- 2) Followers / following
create table if not exists public.nexora_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint nexora_no_self_follow check (follower_id <> following_id)
);

create index if not exists nexora_follows_following_idx
  on public.nexora_follows(following_id);
create index if not exists nexora_follows_follower_idx
  on public.nexora_follows(follower_id);

alter table public.nexora_follows enable row level security;
drop policy if exists "Follow relationships are visible to authenticated users" on public.nexora_follows;
create policy "Follow relationships are visible to authenticated users"
  on public.nexora_follows for select to authenticated using (true);
drop policy if exists "Users can follow from their own account" on public.nexora_follows;
create policy "Users can follow from their own account"
  on public.nexora_follows for insert to authenticated
  with check (follower_id = auth.uid() and follower_id <> following_id);
drop policy if exists "Users can unfollow from their own account" on public.nexora_follows;
create policy "Users can unfollow from their own account"
  on public.nexora_follows for delete to authenticated
  using (follower_id = auth.uid());

-- 3) Groups and group membership
create table if not exists public.nexora_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 60),
  description text not null default '' check (char_length(description) <= 300),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.nexora_group_members (
  group_id uuid not null references public.nexora_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index if not exists nexora_group_members_user_idx
  on public.nexora_group_members(user_id);

alter table public.nexora_groups enable row level security;
alter table public.nexora_group_members enable row level security;

create or replace function public.nexora_is_group_member(target_group uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.nexora_group_members
    where group_id = target_group and user_id = auth.uid()
  );
$$;

drop policy if exists "Authenticated users can discover groups" on public.nexora_groups;
create policy "Authenticated users can discover groups"
  on public.nexora_groups for select to authenticated using (true);

drop policy if exists "Group members can view their membership lists" on public.nexora_group_members;
create policy "Group members can view their membership lists"
  on public.nexora_group_members for select to authenticated
  using (public.nexora_is_group_member(group_id));

create or replace function public.nexora_create_group(group_name text, group_description text default '')
returns uuid
language plpgsql security definer set search_path = public
as $$
declare new_group uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if group_name is null or char_length(trim(group_name)) not between 1 and 60 then
    raise exception 'Group name must be between 1 and 60 characters';
  end if;
  if char_length(coalesce(group_description, '')) > 300 then
    raise exception 'Group description must be 300 characters or fewer';
  end if;

  insert into public.nexora_groups(name, description, created_by)
  values (trim(group_name), coalesce(trim(group_description), ''), auth.uid())
  returning id into new_group;

  insert into public.nexora_group_members(group_id, user_id, role)
  values (new_group, auth.uid(), 'owner');
  return new_group;
end;
$$;

create or replace function public.nexora_join_group(target_group uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if not exists (select 1 from public.nexora_groups where id = target_group) then
    raise exception 'Group not found';
  end if;
  insert into public.nexora_group_members(group_id, user_id, role)
  values (target_group, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;
end;
$$;

revoke all on function public.nexora_is_group_member(uuid) from public;
revoke all on function public.nexora_create_group(text,text) from public;
revoke all on function public.nexora_join_group(uuid) from public;
grant execute on function public.nexora_is_group_member(uuid) to authenticated;
grant execute on function public.nexora_create_group(text,text) to authenticated;
grant execute on function public.nexora_join_group(uuid) to authenticated;

-- Enable realtime updates for presence and group membership.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'nexora_presence'
  ) then
    alter publication supabase_realtime add table public.nexora_presence;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'nexora_group_members'
  ) then
    alter publication supabase_realtime add table public.nexora_group_members;
  end if;
end $$;
