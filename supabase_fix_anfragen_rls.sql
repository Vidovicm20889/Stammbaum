-- =====================================================
-- FIX: Zugangsanfrage (registrierungs_anfragen) lässt sich nicht einfügen
-- Fehler 42501 "new row violates row-level security policy".
-- Ursache: die INSERT-Policy fehlt -> ausgeloggte (anon) Nutzer dürfen keine
-- Anfrage stellen. Hier wird sie (idempotent) wiederhergestellt.
-- Ausführen in: Supabase -> SQL Editor.
-- =====================================================

ALTER TABLE public.registrierungs_anfragen ENABLE ROW LEVEL SECURITY;

-- INSERT: jeder (auch nicht eingeloggt) darf eine Anfrage mit status='offen' stellen.
-- (Niemand kann sich selbst direkt 'bestaetigt' setzen -> WITH CHECK auf status.)
DROP POLICY IF EXISTS "reg_insert_jeder" ON public.registrierungs_anfragen;
CREATE POLICY "reg_insert_jeder" ON public.registrierungs_anfragen
FOR INSERT TO anon, authenticated
WITH CHECK ( status = 'offen' );

-- Tabellen-Grant sicherstellen (RLS-Policy wirkt nur zusätzlich zum Grant)
GRANT INSERT ON public.registrierungs_anfragen TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- Kontrolle: sollte u. a. die INSERT-Policy für {anon,authenticated} zeigen
SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'registrierungs_anfragen'
ORDER BY cmd;
