-- =====================================================
-- ANLÄSSE-ERINNERUNGEN — STUFE B (Backend: tägliche In-App-Benachrichtigungen)
-- Geburtstags- & Gedenktag-Erinnerungen. Ausführen in: Supabase -> SQL Editor
-- (Editor leeren, NUR das hier einfügen, Run). Idempotent.
--
-- WAS DAS MACHT:
--   * Tabelle benachrichtigungs_einstellungen (familie_id, user_id, email_*-Schalter)
--     mit RLS analog mitgliedschaften (eigene Zeile bearbeitbar; Admin/Verbund lesen).
--   * Funktion anlaesse_taeglich_erzeugen(): ermittelt anstehende Geburtstage/Gedenktage
--     und schreibt je Mitglied mit aktivierter Einstellung eine Zeile in benachrichtigungen.
--     IDEMPOTENT über (user_id, typ, ref_person, ref_jahr) -> kein Doppel-Eintrag.
--   * pg_cron-Snippet (unten, auskommentiert) zum täglichen Aufruf.
--
-- E-MAIL-VERSAND: bewusst NOCH NICHT. Diese Stufe erzeugt nur die In-App-Zeilen
--   (die der Nutzer im Obavještenja-Modal sieht). Der Versand folgt später über eine
--   Edge Function (Skizze am Dateiende), die dieselbe Funktion nutzt und die Empfänger
--   per Resend benachrichtigt. Stufe A (Live-Widget) bleibt davon unberührt.
--
-- Voraussetzungen (vorhanden):
--   supabase_benachrichtigungen.sql (Tabelle benachrichtigungen + RLS „eigene Zeilen"),
--   supabase_verbund.sql (familien.verbund_id, ist_super_admin/kann_familie_bearbeiten),
--   supabase_gleiche_person*.sql (personen.identitaet_id),
--   personen.stammbaum_daten (birth_date/death_date/deceased als ISO YYYY-MM-DD bzw. bool).
-- Für den Cron-Teil: Extension pg_cron (Dashboard -> Database -> Extensions) — siehe unten.
-- =====================================================


-- 1) Idempotenz-Spalten an benachrichtigungen ---------------------------------
--    ref_person = welche Person der Anlass betrifft (FK, CASCADE -> bei Personen-
--    Löschung verschwindet die Benachrichtigung mit); ref_jahr = Jahr des Anlasses.
--    Partieller UNIQUE-Index verhindert Doppel-Einträge bei mehrfachem Lauf,
--    OHNE die bestehenden event_einladung-Zeilen (ref_person IS NULL) zu betreffen.
ALTER TABLE public.benachrichtigungen
  ADD COLUMN IF NOT EXISTS ref_person uuid REFERENCES public.personen(id) ON DELETE CASCADE;
ALTER TABLE public.benachrichtigungen
  ADD COLUMN IF NOT EXISTS ref_jahr int;
CREATE UNIQUE INDEX IF NOT EXISTS benachr_anlass_uniq
  ON public.benachrichtigungen (user_id, typ, ref_person, ref_jahr)
  WHERE ref_person IS NOT NULL;


-- 2) Einstellungen je Mitglied (E-Mail-Erinnerungen an/aus) --------------------
--    1 Zeile je (familie_id, user_id). RLS analog mitgliedschaften:
--    Super-Admin alle; Nutzer die EIGENE Zeile; Familien-Admin/Verbund die seiner Familie.
--    Steuert (bis der Versand kommt) das Erzeugen der In-App-Anlässe.
CREATE TABLE IF NOT EXISTS public.benachrichtigungs_einstellungen (
  familie_id        uuid NOT NULL REFERENCES public.familien(id) ON DELETE CASCADE,
  user_id           uuid NOT NULL REFERENCES auth.users(id)      ON DELETE CASCADE,
  email_geburtstage boolean  NOT NULL DEFAULT true,
  email_gedenktage  boolean  NOT NULL DEFAULT true,
  vorlauf_tage      smallint NOT NULL DEFAULT 3,   -- wie viele Tage vorher erinnert wird (1..30)
  updated_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (familie_id, user_id),
  CONSTRAINT bne_vorlauf_chk CHECK (vorlauf_tage BETWEEN 0 AND 30)
);

ALTER TABLE public.benachrichtigungs_einstellungen ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bne_select" ON public.benachrichtigungs_einstellungen;
DROP POLICY IF EXISTS "bne_insert" ON public.benachrichtigungs_einstellungen;
DROP POLICY IF EXISTS "bne_update" ON public.benachrichtigungs_einstellungen;
DROP POLICY IF EXISTS "bne_delete" ON public.benachrichtigungs_einstellungen;

-- Lesen: Super-Admin alle; eigene Zeile; Familien-Admin/Verbund die der Familie.
CREATE POLICY "bne_select" ON public.benachrichtigungs_einstellungen
  FOR SELECT TO authenticated USING (
    public.ist_super_admin() OR user_id = auth.uid() OR public.kann_familie_bearbeiten(familie_id)
  );
-- Anlegen/Ändern/Löschen: NUR die EIGENE Zeile (jeder steuert seine eigenen Erinnerungen);
-- zusätzlich darf ein Familien-Admin/Verbund nur für SICHTBARE Familien anlegen.
CREATE POLICY "bne_insert" ON public.benachrichtigungs_einstellungen
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND public.sieht_familie(familie_id));
CREATE POLICY "bne_update" ON public.benachrichtigungs_einstellungen
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "bne_delete" ON public.benachrichtigungs_einstellungen
  FOR DELETE TO authenticated USING (user_id = auth.uid() OR public.ist_super_admin());

-- updated_at automatisch pflegen
CREATE OR REPLACE FUNCTION public.bne_touch() RETURNS trigger
  LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at := now(); RETURN NEW; END $$;
DROP TRIGGER IF EXISTS bne_touch_trg ON public.benachrichtigungs_einstellungen;
CREATE TRIGGER bne_touch_trg BEFORE UPDATE ON public.benachrichtigungs_einstellungen
  FOR EACH ROW EXECUTE FUNCTION public.bne_touch();


-- 3) Tägliche Ermittlung -> In-App-Benachrichtigungen -------------------------
--    SECURITY DEFINER (läuft im Cron-/Service-Kontext OHNE auth.uid()). Bestimmt die
--    sichtbaren Personen je Mitglied über den VERBUND der Einstellungs-Familie
--    (entspricht sieht_familie für dieses Mitglied) und schreibt je anstehendem Anlass
--    (Monat+Tag = heute + vorlauf_tage) eine benachrichtigungen-Zeile.
--    Lebende -> Geburtstag, Verstorbene -> Gedenktag (Todestag). Über identitaet_id
--    entdoppelt; Platzhalter-Eltern und nicht-ISO-Datumswerte werden übersprungen.
CREATE OR REPLACE FUNCTION public.anlaesse_taeglich_erzeugen()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_geb int := 0; v_ged int := 0;
BEGIN
  -- Geburtstage (nur lebende Personen)
  WITH ins AS (
    INSERT INTO public.benachrichtigungen (user_id, typ, titel, ref_person, ref_jahr)
    SELECT DISTINCT ON (e.user_id, coalesce(pe.identitaet_id, pe.id))
           e.user_id, 'anlass_geburtstag',
           trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')),
           pe.id,
           extract(year from (current_date + e.vorlauf_tage))::int
      FROM public.benachrichtigungs_einstellungen e
      JOIN public.familien fz ON fz.id = e.familie_id
      JOIN public.familien fv ON fv.verbund_id = fz.verbund_id
      JOIN public.personen  pe ON pe.familie_id = fv.id
     WHERE e.email_geburtstage
       AND coalesce((pe.stammbaum_daten->>'platzhalter')::boolean, false) = false
       AND coalesce((pe.stammbaum_daten->>'deceased')::boolean, false) = false
       AND coalesce(pe.stammbaum_daten->>'death_date','') = ''
       AND pe.stammbaum_daten->>'birth_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
       AND substr(pe.stammbaum_daten->>'birth_date', 6, 5) = to_char(current_date + e.vorlauf_tage, 'MM-DD')
     ORDER BY e.user_id, coalesce(pe.identitaet_id, pe.id), pe.id
    ON CONFLICT (user_id, typ, ref_person, ref_jahr) WHERE ref_person IS NOT NULL DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_geb FROM ins;

  -- Gedenktage (nur verstorbene Personen, über Todestag)
  WITH ins AS (
    INSERT INTO public.benachrichtigungen (user_id, typ, titel, ref_person, ref_jahr)
    SELECT DISTINCT ON (e.user_id, coalesce(pe.identitaet_id, pe.id))
           e.user_id, 'anlass_gedenktag',
           trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')),
           pe.id,
           extract(year from (current_date + e.vorlauf_tage))::int
      FROM public.benachrichtigungs_einstellungen e
      JOIN public.familien fz ON fz.id = e.familie_id
      JOIN public.familien fv ON fv.verbund_id = fz.verbund_id
      JOIN public.personen  pe ON pe.familie_id = fv.id
     WHERE e.email_gedenktage
       AND coalesce((pe.stammbaum_daten->>'platzhalter')::boolean, false) = false
       AND pe.stammbaum_daten->>'death_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
       AND substr(pe.stammbaum_daten->>'death_date', 6, 5) = to_char(current_date + e.vorlauf_tage, 'MM-DD')
     ORDER BY e.user_id, coalesce(pe.identitaet_id, pe.id), pe.id
    ON CONFLICT (user_id, typ, ref_person, ref_jahr) WHERE ref_person IS NOT NULL DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_ged FROM ins;

  RETURN jsonb_build_object('ok', true, 'datum', current_date,
                            'geburtstage', v_geb, 'gedenktage', v_ged);
END $$;

-- Nur Service-/Cron-Kontext darf das auslösen (kein authenticated -> keine Massen-
-- erzeugung durch normale Nutzer).
REVOKE ALL ON FUNCTION public.anlaesse_taeglich_erzeugen() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.anlaesse_taeglich_erzeugen() TO service_role;


-- 4) Täglicher Trigger via pg_cron — EINMALIG NACH REVIEW AUSFÜHREN -----------
--    Voraussetzung: Extension pg_cron aktivieren (Dashboard -> Database -> Extensions).
--    Danach EINMAL das Folgende ausführen (kein HTTP/Edge nötig — pg_cron ruft die
--    Funktion direkt auf). 06:00 UTC täglich:
--
--   -- CREATE EXTENSION IF NOT EXISTS pg_cron;
--   -- SELECT cron.schedule(
--   --   'anlaesse-taeglich', '0 6 * * *',
--   --   $cron$ SELECT public.anlaesse_taeglich_erzeugen(); $cron$
--   -- );
--   -- Aushängen: SELECT cron.unschedule('anlaesse-taeglich');
--
--    Manueller Testlauf jederzeit:  SELECT public.anlaesse_taeglich_erzeugen();


-- 5) (SPÄTER) E-Mail-Versand via Edge Function — Skizze ------------------------
--    Wenn der Versand kommt: Edge Function `anlaesse-erinnerung` (Deploy via Dashboard,
--    CLI ist durch die Firewall blockiert) per pg_cron + pg_net (HTTP) statt des
--    direkten Aufrufs oben triggern. Die Function ruft anlaesse_taeglich_erzeugen()
--    und versendet zusätzlich Resend-Mails (Sprache aus profile.sprache; Texte
--    DE/SR/HR/BA/EN analog i18n). Erst NACH separater Abstimmung umsetzen.


NOTIFY pgrst, 'reload schema';
SELECT 'Stufe B aktiv: benachrichtigungs_einstellungen + anlaesse_taeglich_erzeugen (In-App; Cron-Snippet siehe Datei, E-Mail folgt)' AS status;
