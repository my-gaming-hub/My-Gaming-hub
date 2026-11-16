-- JIKZO Chat MVP database
-- Run this in Supabase Dashboard > SQL Editor.
-- Row Level Security is enabled on every user-data table.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  display_name text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_created_idx
  on public.messages(conversation_id, created_at);

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create policy "Profiles are visible to signed-in users"
on public.profiles for select to authenticated using (true);

create policy "Users create their own profile"
on public.profiles for insert to authenticated with check (id = auth.uid());

create policy "Users update their own profile"
on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

create policy "Members can view their conversations"
on public.conversations for select to authenticated
using (exists (
  select 1 from public.conversation_members m
  where m.conversation_id = id and m.user_id = auth.uid()
));

create policy "Users can view memberships in their conversations"
on public.conversation_members for select to authenticated
using (exists (
  select 1 from public.conversation_members mine
  where mine.conversation_id = conversation_id and mine.user_id = auth.uid()
));

create policy "Users can create a conversation"
on public.conversations for insert to authenticated
with check (true);

create policy "Users can add themselves to a conversation"
on public.conversation_members for insert to authenticated
with check (user_id = auth.uid());

create policy "Members can read messages"
on public.messages for select to authenticated
using (exists (
  select 1 from public.conversation_members m
  where m.conversation_id = conversation_id and m.user_id = auth.uid()
));

create policy "Members can send messages as themselves"
on public.messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.conversation_members m
    where m.conversation_id = conversation_id and m.user_id = auth.uid()
  )
);

-- Enable realtime delivery for messages.
alter publication supabase_realtime add table public.messages;
