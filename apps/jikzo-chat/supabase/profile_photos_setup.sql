-- JIKZO Chat profile pictures
-- Run once in the Supabase SQL Editor.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS avatar_url text;

-- Public read is intentional so profile pictures can appear in People and Chats.
-- Upload, replacement and deletion are restricted to the signed-in user's own folder.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'jikzo-avatars',
  'jikzo-avatars',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "JIKZO avatar uploads own folder" ON storage.objects;
CREATE POLICY "JIKZO avatar uploads own folder"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'jikzo-avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "JIKZO avatar updates own folder" ON storage.objects;
CREATE POLICY "JIKZO avatar updates own folder"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'jikzo-avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'jikzo-avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "JIKZO avatar deletes own folder" ON storage.objects;
CREATE POLICY "JIKZO avatar deletes own folder"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'jikzo-avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "JIKZO avatar public read" ON storage.objects;
CREATE POLICY "JIKZO avatar public read"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'jikzo-avatars');

DROP POLICY IF EXISTS "JIKZO users update own profile" ON public.profiles;
CREATE POLICY "JIKZO users update own profile"
ON public.profiles FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());
