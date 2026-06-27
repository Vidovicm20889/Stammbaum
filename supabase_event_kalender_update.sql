-- =====================================================
-- EVENTS: KALENDER-UPDATE bei Eventänderung (SEQUENCE + Empfänger aller Eingeladenen)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent. SETZT supabase_event_kalender.sql VORAUS (uhrzeit/ende_uhrzeit/zeitzone).
-- MUSS VOR dem Frontend-Deploy laufen.
--
-- Warum:
--  * kalender_seq (integer, Default 0) -> wird bei JEDER Aktualisierung eines Events
--    hochgezählt und als iCalendar-SEQUENCE in der .ics ausgegeben. Gleiche UID
--    (= event_id) + höhere SEQUENCE => Kalender-Clients ERSETZEN den vorhandenen
--    Termin, statt einen zweiten anzulegen.
--  * event_einladung_empfaenger(p_event) -> liefert (read-only, OHNE neue In-App-
--    Benachrichtigung) die E-Mail-Empfänger ALLER aktuell Eingeladenen (außer mir
--    selbst). Das Frontend ruft das nach einer Eventänderung auf und verschickt die
--    aktualisierte .ics über die Edge Function event-einladung-senden (aktualisierung=true).
-- =====================================================

-- 1) SEQUENCE-Zähler -----------------------------------------------------------
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS kalender_seq integer NOT NULL DEFAULT 0;

-- 2) event_speichern: bei UPDATE die SEQUENCE hochzählen ----------------------
--    Gleiche 15-Parameter-Signatur wie supabase_event_kalender.sql -> CREATE OR
--    REPLACE genügt (kein DROP nötig). Einzige Änderung: kalender_seq = kalender_seq + 1.
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
           zeitzone = coalesce(nullif(trim(p_zeitzone),''),'Europe/Belgrade'),
           kalender_seq = kalender_seq + 1
     WHERE id = p_id AND stammbaum_id = p_tree;
    v_id := p_id;
  END IF;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.event_speichern(
  uuid, uuid, text, text, text, text, text, text, text, double precision, double precision, uuid,
  text, text, text)
  TO authenticated;

-- 3) Empfänger ALLER aktuell Eingeladenen (read-only, keine In-App-Benachrichtigung) -
CREATE OR REPLACE FUNCTION public.event_einladung_empfaenger(p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_fam uuid; v_empf jsonb;
BEGIN
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'user_id', ee.user_id,
           'email',   u.email,
           'name',    trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')),
           'sprache', coalesce(pr.sprache, 'de')
         )), '[]'::jsonb)
    INTO v_empf
    FROM public.event_eingeladene ee
    JOIN auth.users u ON u.id = ee.user_id
    LEFT JOIN public.profile pr ON pr.user_id = ee.user_id
   WHERE ee.event_id = p_event
     AND ee.user_id <> auth.uid()
     AND u.email IS NOT NULL;

  RETURN jsonb_build_object('ok', true, 'empfaenger', v_empf);
END $$;
GRANT EXECUTE ON FUNCTION public.event_einladung_empfaenger(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'events.kalender_seq + event_speichern(SEQUENCE++) + event_einladung_empfaenger angelegt' AS status;
