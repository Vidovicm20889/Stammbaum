-- =====================================================
-- STORAGE-POLICIES für den Bucket "events"
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Ziel:
--  - Alle EINGELOGGTEN User dürfen Event-Medien sehen/auflisten (Punkt 3)
--  - Nur Admins (super_admin / familien_admin) dürfen hochladen und löschen
--
-- Hinweis: Storage-RLS läuft auf der Tabelle storage.objects.
-- =====================================================


-- 0) Helper: ist der eingeloggte User Admin (Super- ODER Familien-Admin in irgendeiner Familie)?
--    SECURITY DEFINER -> umgeht RLS, keine Rekursion.
CREATE OR REPLACE FUNCTION public.ist_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid()
      AND rolle IN ('super_admin', 'familien_admin')
  );
$$;


-- 1) Alte Policies mit diesen Namen sicher entfernen (idempotent)
DROP POLICY IF EXISTS "events_select" ON storage.objects;
DROP POLICY IF EXISTS "events_insert" ON storage.objects;
DROP POLICY IF EXISTS "events_delete" ON storage.objects;


-- 2) SELECT: jeder eingeloggte User darf Dateien im Bucket "events" sehen/auflisten
--    (nötig für list() und createSignedUrls())
CREATE POLICY "events_select" ON storage.objects
FOR SELECT TO authenticated
USING ( bucket_id = 'events' );


-- 3) INSERT: nur Admins dürfen hochladen
CREATE POLICY "events_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK ( bucket_id = 'events' AND public.ist_admin() );


-- 4) DELETE: nur Admins dürfen löschen
CREATE POLICY "events_delete" ON storage.objects
FOR DELETE TO authenticated
USING ( bucket_id = 'events' AND public.ist_admin() );


-- 5) Kontrolle: zeigt die 3 Policies auf storage.objects für den Bucket "events"
SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname IN ('events_select', 'events_insert', 'events_delete')
ORDER BY cmd;
