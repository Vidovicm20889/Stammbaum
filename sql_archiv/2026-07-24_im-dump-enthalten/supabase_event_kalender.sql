-- =====================================================
-- EVENTS: UHRZEIT + ENDE + ZEITZONE  (für Kalender-Einladung .ics)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent. SETZT supabase_events.sql + supabase_events_medien_organisator.sql
--             + supabase_event_geo.sql VORAUS.
-- MUSS VOR dem Frontend-Deploy laufen: speichereEvent() ruft event_speichern mit
-- 15 Argumenten; fehlt die neue Signatur, schlägt das Speichern fehl.
--
-- Warum:
--  * uhrzeit / ende_uhrzeit (text, HH:MM, nullable) -> echte Termin-Zeit für die
--    .ics (DTSTART/DTEND). Leer = Ganztags-Termin (VALUE=DATE).
--  * zeitzone (text, Default 'Europe/Belgrade') -> TZID/VTIMEZONE in der .ics, damit
--    Outlook/Apple/Google die Uhrzeit korrekt einordnen (Diaspora).
--
-- events_fuer_stammbaum / events_fuer_mich liefern SETOF public.events -> die neuen
-- Spalten erscheinen dort AUTOMATISCH (kein Funktions-Rewrite nötig). Nur
-- event_speichern wird um die drei Parameter erweitert.
-- =====================================================

-- 1) Neue Spalten ------------------------------------------------------------
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS uhrzeit       text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS ende_uhrzeit  text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS zeitzone      text DEFAULT 'Europe/Belgrade';

-- 2) event_speichern um p_uhrzeit, p_ende_uhrzeit, p_zeitzone erweitern ------
--    Alte 12-Parameter-Signatur entfernen, neue 15-Parameter-Variante anlegen.
DROP FUNCTION IF EXISTS public.event_speichern(
  uuid, uuid, text, text, text, text, text, text, text, double precision, double precision, uuid);

CREATE OR REPLACE FUNCTION public.event_speichern(
  p_id uuid, p_tree uuid, p_titel text, p_beschreibung text,
  p_datum text, p_ort text, p_typ text, p_sprache text, p_organisator text,
  p_latitude double precision, p_longitude double precision, p_bezugsperson uuid,
  p_uhrzeit text, p_ende_uhrzeit text, p_zeitzone text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_id uuid; v_bp uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  IF coalesce(trim(p_titel),'') = '' THEN RAISE EXCEPTION 'Titel ist erforderlich.'; END IF;

  -- Bezugsperson nur übernehmen, wenn sie in einem für mich sichtbaren Baum liegt
  -- (Isolation; sonst NULL). Verbund-Sichtbarkeit über sieht_familie der Person.
  v_bp := NULL;
  IF p_bezugsperson IS NOT NULL THEN
    SELECT pe.id INTO v_bp
      FROM public.personen pe
     WHERE pe.id = p_bezugsperson
       AND pe.geloescht_am IS NULL
       AND (public.ist_super_admin() OR public.sieht_familie(pe.familie_id))
     LIMIT 1;
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.events (stammbaum_id, familie_id, titel, beschreibung, datum, ort, typ,
                               sprache, organisator, latitude, longitude, bezugsperson_id,
                               uhrzeit, ende_uhrzeit, zeitzone)
    VALUES (p_tree, v_fam, trim(p_titel), p_beschreibung, p_datum, p_ort, p_typ,
            coalesce(nullif(p_sprache,''),'de'), p_organisator, p_latitude, p_longitude, v_bp,
            nullif(trim(p_uhrzeit),''), nullif(trim(p_ende_uhrzeit),''),
            coalesce(nullif(trim(p_zeitzone),''),'Europe/Belgrade'))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.events
       SET titel = trim(p_titel), beschreibung = p_beschreibung,
           datum = p_datum, ort = p_ort, typ = p_typ, organisator = p_organisator,
           latitude = p_latitude, longitude = p_longitude, bezugsperson_id = v_bp,
           uhrzeit = nullif(trim(p_uhrzeit),''), ende_uhrzeit = nullif(trim(p_ende_uhrzeit),''),
           zeitzone = coalesce(nullif(trim(p_zeitzone),''),'Europe/Belgrade')
     WHERE id = p_id AND stammbaum_id = p_tree;
    v_id := p_id;
  END IF;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.event_speichern(
  uuid, uuid, text, text, text, text, text, text, text, double precision, double precision, uuid,
  text, text, text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'events.uhrzeit/ende_uhrzeit/zeitzone + event_speichern(15 Args) aktualisiert' AS status;
