-- =====================================================
-- ANLÄSSE-ERINNERUNGEN — E-MAIL-LAYER (Stufe B, Versand via Resend-Edge-Function)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent. Voraussetzung: supabase_benachrichtigungen_anlaesse.sql (Stufe B In-App).
--
-- WAS DAS MACHT:
--   * Spalte benachrichtigungen.email_gesendet -> verhindert Doppel-Mails.
--   * anlaesse_email_offen()  -> liefert der Edge Function die NOCH NICHT gemailten
--     Anlass-Benachrichtigungen der letzten Tage inkl. Empfänger-E-Mail/Name/Sprache.
--   * anlaesse_email_erledigt(uuid[]) -> markiert erfolgreich versendete als gesendet.
--   * pg_net-Cron-Snippet (unten, auskommentiert) -> ruft täglich die Edge Function
--     `anlaesse-erinnerung` auf (die ihrerseits anlaesse_taeglich_erzeugen() ausführt,
--     die offenen Mails versendet und sie als gesendet markiert).
--
-- Sicherheit: beide Funktionen sind SECURITY DEFINER und NUR für service_role (die
--   Edge Function nutzt den Service-Key). Kein Zugriff für normale Nutzer.
-- =====================================================


-- 1) "Gesendet"-Flag an benachrichtigungen -------------------------------------
ALTER TABLE public.benachrichtigungen
  ADD COLUMN IF NOT EXISTS email_gesendet boolean NOT NULL DEFAULT false;


-- 2) Offene Anlass-Mails liefern (für die Edge Function) -----------------------
--    Nur Anlass-Typen, noch nicht gemailt, aus den letzten 2 Tagen (kein Versand von
--    Altbestand bei Erst-Einführung/Re-Run; das gesendet-Flag schützt zusätzlich gegen
--    Doppel-Mails). E-Mail aus auth.users, Name/Sprache aus profile.
CREATE OR REPLACE FUNCTION public.anlaesse_email_offen()
RETURNS TABLE(id uuid, user_id uuid, email text, name text, sprache text,
              typ text, person_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT b.id, b.user_id, u.email,
         nullif(trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')), '') AS name,
         coalesce(pr.sprache, 'de') AS sprache,
         b.typ, b.titel AS person_name
    FROM public.benachrichtigungen b
    JOIN auth.users u ON u.id = b.user_id
    LEFT JOIN public.profile pr ON pr.user_id = b.user_id
   WHERE b.typ IN ('anlass_geburtstag','anlass_gedenktag')
     AND b.email_gesendet = false
     AND b.created_at >= (current_date - 2)
     AND u.email IS NOT NULL
   ORDER BY b.user_id;
$$;
REVOKE ALL ON FUNCTION public.anlaesse_email_offen() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.anlaesse_email_offen() TO service_role;


-- 3) Versendete als gesendet markieren ----------------------------------------
CREATE OR REPLACE FUNCTION public.anlaesse_email_erledigt(p_ids uuid[])
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n int;
BEGIN
  IF p_ids IS NULL OR array_length(p_ids,1) IS NULL THEN RETURN 0; END IF;
  UPDATE public.benachrichtigungen
     SET email_gesendet = true
   WHERE id = ANY(p_ids)
     AND typ IN ('anlass_geburtstag','anlass_gedenktag');
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;
REVOKE ALL ON FUNCTION public.anlaesse_email_erledigt(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.anlaesse_email_erledigt(uuid[]) TO service_role;


-- 4) Täglicher E-Mail-Trigger via pg_cron + pg_net — NACH REVIEW EINMAL AUSFÜHREN
--    Ersetzt den reinen In-App-Cron aus supabase_benachrichtigungen_anlaesse.sql
--    (die Edge Function ruft anlaesse_taeglich_erzeugen() selbst auf -> In-App + Mail
--    in einem Lauf). Voraussetzungen:
--      a) Extensions pg_cron UND pg_net aktivieren (Dashboard -> Database -> Extensions).
--      b) Edge Function `anlaesse-erinnerung` deployen (Dashboard -> Edge Functions,
--         Code: supabase/functions/anlaesse-erinnerung/index.ts) inkl. Secrets
--         (RESEND_API_KEY etc.) UND einem selbst vergebenen Secret CRON_SECRET.
--      c) Für diese Function die JWT-Prüfung abschalten (Dashboard -> Function ->
--         "Verify JWT" AUS) -> dann zählt NUR der Header x-cron-secret. (Alternativ
--         JWT-Prüfung AN lassen und im http_post zusätzlich einen 'Authorization: Bearer
--         <ANON_KEY>'-Header mitgeben; der x-cron-secret bleibt die eigentliche Prüfung.)
--      d) <PROJECT_REF> + <CRON_SECRET> einsetzen (CRON_SECRET = derselbe Wert wie das Secret).
--
--   -- Alten reinen In-App-Cron entfernen (falls gesetzt):
--   -- SELECT cron.unschedule('anlaesse-taeglich');
--
--   -- SELECT cron.schedule(
--   --   'anlaesse-erinnerung', '0 6 * * *',
--   --   $cron$
--   --     SELECT net.http_post(
--   --       url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/anlaesse-erinnerung',
--   --       headers := jsonb_build_object(
--   --                    'Content-Type','application/json',
--   --                    'x-cron-secret','<CRON_SECRET>'),
--   --       body    := '{}'::jsonb
--   --     );
--   --   $cron$
--   -- );
--
--    Hinweis: CRON_SECRET ist nur ein selbst gewähltes Passwort (kein Supabase-Key);
--    es schützt die Function vor fremden Aufrufen, ohne vom Key-Format abzuhängen.


NOTIFY pgrst, 'reload schema';
SELECT 'E-Mail-Layer bereit: email_gesendet + anlaesse_email_offen/erledigt (Edge Function + pg_net-Cron separat aktivieren)' AS status;
