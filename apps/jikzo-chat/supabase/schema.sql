-- JIKZO Chat MVP database. Run once in Supabase SQL Editor.
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,username text unique not null check(char_length(username) between 3 and 24),display_name text not null default '',created_at timestamptz not null default now());
create table if not exists public.conversations(id uuid primary key default gen_random_uuid(),created_at timestamptz not null default now());
create table if not exists public.conversation_members(conversation_id uuid not null references public.conversations(id) on delete cascade,user_id uuid not null references auth.users(id) on delete cascade,joined_at timestamptz not null default now(),primary key(conversation_id,user_id));
create table if not exists public.messages(id uuid primary key default gen_random_uuid(),conversation_id uuid not null references public.conversations(id) on delete cascade,sender_id uuid not null references auth.users(id) on delete cascade,body text not null check(char_length(body) between 1 and 4000),created_at timestamptz not null default now());
create index if not exists messages_conversation_created_idx on public.messages(conversation_id,created_at);
alter table public.profiles enable row level security;alter table public.conversations enable row level security;alter table public.conversation_members enable row level security;alter table public.messages enable row level security;
create or replace function public.is_conversation_member(cid uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.conversation_members where conversation_id=cid and user_id=auth.uid()); $$;
drop policy if exists "profiles_read" on public.profiles;create policy "profiles_read" on public.profiles for select to authenticated using(true);
drop policy if exists "profiles_insert_self" on public.profiles;create policy "profiles_insert_self" on public.profiles for insert to authenticated with check(id=auth.uid());
drop policy if exists "profiles_update_self" on public.profiles;create policy "profiles_update_self" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
drop policy if exists "conversations_read_member" on public.conversations;create policy "conversations_read_member" on public.conversations for select to authenticated using(public.is_conversation_member(id));
drop policy if exists "members_read_member" on public.conversation_members;create policy "members_read_member" on public.conversation_members for select to authenticated using(public.is_conversation_member(conversation_id));
drop policy if exists "messages_read_member" on public.messages;create policy "messages_read_member" on public.messages for select to authenticated using(public.is_conversation_member(conversation_id));
drop policy if exists "messages_insert_member" on public.messages;create policy "messages_insert_member" on public.messages for insert to authenticated with check(sender_id=auth.uid() and public.is_conversation_member(conversation_id));
create or replace function public.start_conversation(other_user uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); cid uuid;
begin
 if me is null then raise exception 'Sign in required';end if;
 if other_user is null or other_user=me then raise exception 'Choose another user';end if;
 if not exists(select 1 from public.profiles where id=other_user) then raise exception 'User profile not found';end if;
 select c.id into cid from public.conversations c
 where (select count(*) from public.conversation_members m where m.conversation_id=c.id)=2
 and exists(select 1 from public.conversation_members m where m.conversation_id=c.id and m.user_id=me)
 and exists(select 1 from public.conversation_members m where m.conversation_id=c.id and m.user_id=other_user) limit 1;
 if cid is null then insert into public.conversations default values returning id into cid;insert into public.conversation_members(conversation_id,user_id) values(cid,me),(cid,other_user);end if;
 return cid;
end; $$;
grant execute on function public.start_conversation(uuid) to authenticated;
do $$ begin if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then alter publication supabase_realtime add table public.messages;end if;end $$;
