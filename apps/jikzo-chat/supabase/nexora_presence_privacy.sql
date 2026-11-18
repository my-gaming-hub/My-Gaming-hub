-- Nexora presence privacy RPC
-- Run after nexora_social_features.sql in the Supabase SQL Editor.
-- "Contacts" means users who follow each other.

create or replace function public.nexora_get_presence(target_users uuid[])
returns table (
  user_id uuid,
  is_online boolean,
  last_seen_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.user_id,
    case
      when coalesce(s.online_status_visibility, 'everyone') = 'everyone'
        or (
          coalesce(s.online_status_visibility, 'everyone') = 'contacts'
          and exists (
            select 1 from public.nexora_follows a
            join public.nexora_follows b
              on b.follower_id = a.following_id
             and b.following_id = a.follower_id
            where a.follower_id = auth.uid()
              and a.following_id = p.user_id
          )
        )
      then p.is_online
      else null
    end as is_online,
    case
      when coalesce(s.last_seen_visibility, 'everyone') = 'everyone'
        or (
          coalesce(s.last_seen_visibility, 'everyone') = 'contacts'
          and exists (
            select 1 from public.nexora_follows a
            join public.nexora_follows b
              on b.follower_id = a.following_id
             and b.following_id = a.follower_id
            where a.follower_id = auth.uid()
              and a.following_id = p.user_id
          )
        )
      then p.last_seen_at
      else null
    end as last_seen_at
  from public.nexora_presence p
  left join public.jikzo_user_settings s on s.user_id = p.user_id
  where p.user_id = any(target_users)
    and p.user_id <> auth.uid();
$$;

revoke all on function public.nexora_get_presence(uuid[]) from public;
grant execute on function public.nexora_get_presence(uuid[]) to authenticated;
