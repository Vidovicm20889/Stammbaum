-- =====================================================
-- GLOBALE E-MAIL-VALIDIERUNG (Backend) — Format-Check in der Datenbank
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Ergänzt die Frontend-Validierung (isValidEmail) um eine SERVERSEITIGE Prüfung:
--   * zentrale Funktion ist_gueltige_email(text)
--   * Trigger auf registrierungs_anfragen (Pflicht-E-Mail + optionale Kontakt-E-Mail)
-- (Die RPC stammbaum_einstellungen_speichern prüft die Kontakt-E-Mail bereits.)
--
-- Hinweis: Edge Functions (neue-familie-anlegen, mitglied-einladen) prüfen das
--   Format zusätzlich im TypeScript-Code (dort 400 zurückgeben) und müssen über
--   das Supabase-Dashboard neu deployt werden.
-- =====================================================

-- Zentrale Regel: genau ein @, kein Whitespace, Domain mit Punkt + TLD
CREATE OR REPLACE FUNCTION public.ist_gueltige_email(p_email text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' AND p_email !~ '\.\.';
$$;

-- Trigger: Anfragen mit ungültiger E-Mail ablehnen (Pflicht- + Kontakt-E-Mail)
CREATE OR REPLACE FUNCTION public.trg_anfrage_email_pruefen()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.email IS NULL OR NOT public.ist_gueltige_email(NEW.email) THEN
    RAISE EXCEPTION 'email_ungueltig' USING ERRCODE = '23514';
  END IF;
  IF NEW.kontakt_email IS NOT NULL AND trim(NEW.kontakt_email) <> ''
     AND NOT public.ist_gueltige_email(NEW.kontakt_email) THEN
    RAISE EXCEPTION 'email_ungueltig' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS anfrage_email_pruefen ON public.registrierungs_anfragen;
CREATE TRIGGER anfrage_email_pruefen
BEFORE INSERT OR UPDATE OF email, kontakt_email ON public.registrierungs_anfragen
FOR EACH ROW EXECUTE FUNCTION public.trg_anfrage_email_pruefen();

NOTIFY pgrst, 'reload schema';
SELECT 'E-Mail-Validierung (Backend): ist_gueltige_email + Trigger auf registrierungs_anfragen' AS status;
