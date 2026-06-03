-- =====================================================
-- #4 OBAVJEŠTENJA / Benachrichtigungen
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- 1) RPC: offene Anfragen, die der angemeldete Admin verwalten darf.
-- 2) Protokoll-Tabelle für Entscheidungen (Akzeptieren/Ablehnen).
-- Voraussetzung: registrierungs_anfragen, ist_super_admin(),
--                kann_familie_bearbeiten(p_familie_id) (vorhanden).
-- =====================================================

-- 1) Offene Anfragen für den Admin (Super-Admin sieht alle; sonst nur
--    Familien, die er bearbeiten darf). geburtsdatum ist bereits text.
CREATE OR REPLACE FUNCTION public.offene_anfragen()
RETURNS TABLE(
  id uuid, vorname text, nachname text, geburtsdatum text, email text,
  created_at timestamptz, familie_id uuid, familie_name text, rolle text, sprache text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT a.id, a.vorname, a.nachname, a.geburtsdatum, a.email,
         a.created_at, a.familie_id, f.name, a.rolle, a.sprache
  FROM public.registrierungs_anfragen a
  LEFT JOIN public.familien f ON f.id = a.familie_id
  WHERE a.status = 'offen'
    AND (public.ist_super_admin() OR public.kann_familie_bearbeiten(a.familie_id))
  ORDER BY a.created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.offene_anfragen() TO authenticated;

-- 2) Protokoll der Entscheidungen (wer hat wann was entschieden).
--    Schreibzugriff nur über die Edge Function (service_role); RLS an, keine
--    Policies -> kein direkter Zugriff für normale Nutzer.
CREATE TABLE IF NOT EXISTS public.anfrage_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anfrage_id      uuid,
  email           text,
  familie_id      uuid,
  aktion          text NOT NULL,        -- 'bestaetigt' | 'abgelehnt'
  entschieden_von uuid,                 -- auth.users.id des Admins
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS anfrage_log_anfrage_idx ON public.anfrage_log(anfrage_id);
ALTER TABLE public.anfrage_log ENABLE ROW LEVEL SECURITY;

NOTIFY pgrst, 'reload schema';
SELECT 'offene_anfragen() + anfrage_log angelegt' AS status;
