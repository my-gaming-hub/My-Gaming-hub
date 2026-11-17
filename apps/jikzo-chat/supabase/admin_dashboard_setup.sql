-- JIKZO Chat owner dashboard: admin-only controls and announcements.
-- Run this once in Supabase SQL Editor while signed in as the project owner.

CREATE TABLE IF NOT EXISTS public.jikzo_admin_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  message text NOT NULL CHECK (char_length(message) BETWEEN 1 AND 2000),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.jikzo_admin_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can read admin announcements" ON public.jikzo_admin_announcements;
CREATE POLICY "Members can read admin announcements"
ON public.jikzo_admin_announcements FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "Only JIKZO admins can publish announcements" ON public.jikzo_admin_announcements;
CREATE POLICY "Only JIKZO admins can publish announcements"
ON public.jikzo_admin_announcements FOR INSERT TO authenticated
WITH CHECK (created_by = auth.uid() AND public.is_jikzo_admin());

DROP POLICY IF EXISTS "Only JIKZO admins can delete announcements" ON public.jikzo_admin_announcements;
CREATE POLICY "Only JIKZO admins can delete announcements"
ON public.jikzo_admin_announcements FOR DELETE TO authenticated
USING (public.is_jikzo_admin());

CREATE TABLE IF NOT EXISTS public.jikzo_user_moderation (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  reason text,
  updated_by uuid REFERENCES auth.users(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.jikzo_user_moderation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own moderation status" ON public.jikzo_user_moderation;
CREATE POLICY "Users can read their own moderation status"
ON public.jikzo_user_moderation FOR SELECT TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can read moderation records" ON public.jikzo_user_moderation;
CREATE POLICY "Admins can read moderation records"
ON public.jikzo_user_moderation FOR SELECT TO authenticated
USING (public.is_jikzo_admin());

-- Admin-only directory function: exposes profile names/usernames, never emails or message contents.
CREATE OR REPLACE FUNCTION public.jikzo_admin_list_users(search_term text DEFAULT NULL)
RETURNS TABLE(user_id uuid, username text, display_name text, account_status text, moderation_reason text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_jikzo_admin() THEN
    RAISE EXCEPTION 'Administrator access required';
  END IF;

  RETURN QUERY
  SELECT p.id, p.username, p.display_name,
         COALESCE(m.status, 'active'),
         m.reason
  FROM public.profiles p
  LEFT JOIN public.jikzo_user_moderation m ON m.user_id = p.id
  WHERE search_term IS NULL
     OR p.username ILIKE '%' || search_term || '%'
     OR p.display_name ILIKE '%' || search_term || '%'
  ORDER BY p.username
  LIMIT 100;
END;
$$;

-- Admin-only moderation function. This restricts access inside JIKZO Chat;
-- it does not disable the user's Supabase Auth account.
CREATE OR REPLACE FUNCTION public.jikzo_admin_set_user_status(
  target_user_id uuid,
  new_status text,
  moderation_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_jikzo_admin() THEN
    RAISE EXCEPTION 'Administrator access required';
  END IF;
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot suspend your own administrator account';
  END IF;
  IF new_status NOT IN ('active', 'suspended') THEN
    RAISE EXCEPTION 'Invalid account status';
  END IF;

  INSERT INTO public.jikzo_user_moderation(user_id, status, reason, updated_by, updated_at)
  VALUES (target_user_id, new_status, NULLIF(moderation_reason, ''), auth.uid(), now())
  ON CONFLICT (user_id) DO UPDATE
  SET status = EXCLUDED.status,
      reason = EXCLUDED.reason,
      updated_by = EXCLUDED.updated_by,
      updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.jikzo_admin_dashboard_stats()
RETURNS TABLE(total_users bigint, total_conversations bigint, total_messages bigint, total_shared_files bigint, suspended_users bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_jikzo_admin() THEN
    RAISE EXCEPTION 'Administrator access required';
  END IF;

  RETURN QUERY SELECT
    (SELECT count(*) FROM public.profiles),
    (SELECT count(*) FROM public.conversations),
    (SELECT count(*) FROM public.messages),
    (SELECT count(*) FROM public.jikzo_files),
    (SELECT count(*) FROM public.jikzo_user_moderation WHERE status = 'suspended');
END;
$$;

REVOKE ALL ON FUNCTION public.jikzo_admin_list_users(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.jikzo_admin_set_user_status(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.jikzo_admin_dashboard_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.jikzo_admin_list_users(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.jikzo_admin_set_user_status(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.jikzo_admin_dashboard_stats() TO authenticated;
