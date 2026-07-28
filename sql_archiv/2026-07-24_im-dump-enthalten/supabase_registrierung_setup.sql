-- =====================================================
-- ZUGANGSANFRAGEN ("Account anlegen")
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Phase 1 (jetzt): Tabelle + Policies + öffentliche Familienliste.
--   Das Frontend speichert die Anfrage hier hinein.
-- Phase 2 (folgt):  Edge Function liest diese Tabelle, verschickt E-Mails (Resend)
--   an Familien-/Super-Admin mit Bestätigen-/Ablehnen-Link und legt bei
--   Bestätigung den User (Einladungs-Link) + Mitgliedschaft + Person an.
--
-- Annahme: Tabelle public.familien hat die Spalten "id" (uuid) und "name" (text).
--   Falls die Namensspalte anders heißt, in oeffentliche_familien() anpassen.
-- =====================================================


-- 1) Öffentliche Familienliste (nur id + name) für das Registrierungs-Dropdown.
--    SECURITY DEFINER -> auch nicht eingeloggte (anon) User dürfen sie lesen,
--    ohne dass die familien-Tabelle selbst für anon geöffnet werden muss.
CREATE OR REPLACE FUNCTION public.oeffentliche_familien()
RETURNS TABLE (id uuid, name text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT id, name FROM public.familien ORDER BY name;
$$;

GRANT EXECUTE ON FUNCTION public.oeffentliche_familien() TO anon, authenticated;


-- 2) Tabelle für die Anfragen
CREATE TABLE IF NOT EXISTS public.registrierungs_anfragen (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email           text NOT NULL,
  familie_id      uuid REFERENCES public.familien(id),
  rolle           text NOT NULL CHECK (rolle IN ('familien_admin', 'familien_mitglied')),

  -- optionale Personendaten
  vorname         text,
  nachname        text,
  geburtsdatum    text,
  geburtsort      text,
  geburtsland     text,
  getauft_am      text,
  verheiratet_am  text,

  -- optionale Kontaktdaten
  telefon         text,
  kontakt_email   text,
  facebook        text,
  instagram       text,

  -- Workflow
  sprache         text NOT NULL DEFAULT 'de',
  status          text NOT NULL DEFAULT 'offen'
                    CHECK (status IN ('offen', 'bestaetigt', 'abgelehnt')),
  token           uuid NOT NULL DEFAULT gen_random_uuid(),  -- für Bestätigen/Ablehnen-Link
  created_at      timestamptz NOT NULL DEFAULT now()
);


-- 3) RLS aktivieren
ALTER TABLE public.registrierungs_anfragen ENABLE ROW LEVEL SECURITY;


-- 4) Policies (idempotent)
DROP POLICY IF EXISTS "reg_insert_jeder"   ON public.registrierungs_anfragen;
DROP POLICY IF EXISTS "reg_select_admin"   ON public.registrierungs_anfragen;
DROP POLICY IF EXISTS "reg_update_admin"   ON public.registrierungs_anfragen;
DROP POLICY IF EXISTS "reg_delete_admin"   ON public.registrierungs_anfragen;

-- INSERT: jeder (auch nicht eingeloggt) darf eine Anfrage stellen.
--   status muss 'offen' sein -> niemand kann sich selbst direkt 'bestaetigt' setzen.
CREATE POLICY "reg_insert_jeder" ON public.registrierungs_anfragen
FOR INSERT TO anon, authenticated
WITH CHECK ( status = 'offen' );

-- SELECT: nur Super-Admin oder Familien-Admin der betroffenen Familie.
--   (Die Edge Function nutzt den Service-Role-Key und umgeht RLS ohnehin.)
CREATE POLICY "reg_select_admin" ON public.registrierungs_anfragen
FOR SELECT TO authenticated
USING (
  public.ist_super_admin()
  OR public.get_meine_rolle(familie_id) = 'familien_admin'
);

-- UPDATE: nur Admins (z. B. manuelles Bearbeiten im Notfall)
CREATE POLICY "reg_update_admin" ON public.registrierungs_anfragen
FOR UPDATE TO authenticated
USING (
  public.ist_super_admin()
  OR public.get_meine_rolle(familie_id) = 'familien_admin'
);

-- DELETE: nur Super-Admin
CREATE POLICY "reg_delete_admin" ON public.registrierungs_anfragen
FOR DELETE TO authenticated
USING ( public.ist_super_admin() );


-- 5) Kontrolle
SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'registrierungs_anfragen'
ORDER BY cmd;
