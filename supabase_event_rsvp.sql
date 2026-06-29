-- =====================================================
-- EVENT-RSVP — Zu-/Absage je eingeladenem Konto (Komme ich? Ja/Vielleicht/Nein + Begleitpersonen)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent. SETZT supabase_event_eingeladene_user.sql + supabase_benachrichtigungen.sql VORAUS.
-- MUSS VOR dem Frontend-Deploy laufen (Frontend selektiert rsvp_*/ersteller).
--
-- Warum:
--  * Der RSVP-Status gehört an die EINGELADENEN KONTEN (event_eingeladene, user-basiert),
--    NICHT an event_teilnehmer (das ist Kostenaufteilung, namensbasiert).
--  * events.ersteller (uuid) hält das Konto fest, das das Event angelegt hat -> RSVP-
--    Rückmeldungen gehen gezielt an den Organisator. organisator ist nur Freitext und
--    taugt nicht zum Benachrichtigen. Altbestand: ersteller NULL -> Fallback auf die
--    Admins/Owner der Event-Familie.
--  * Reine SECURITY-DEFINER-RPCs (RLS auf event_eingeladene bleibt policy-frei).
-- =====================================================


-- 1) RSVP-Felder an die eingeladenen Konten -----------------------------------
ALTER TABLE public.event_eingeladene
  ADD COLUMN IF NOT EXISTS rsvp_status text NOT NULL DEFAULT 'offen'
    CHECK (rsvp_status IN ('offen','zusage','absage','vielleicht')),
  ADD COLUMN IF NOT EXISTS rsvp_anzahl int  NOT NULL DEFAULT 1,   -- inkl. Begleitpersonen (>=1)
  ADD COLUMN IF NOT EXISTS rsvp_notiz  text,
  ADD COLUMN IF NOT EXISTS rsvp_am     timestamptz;


-- 2) Ersteller am Event festhalten (für gezielte RSVP-Benachrichtigung) -------
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS ersteller uuid REFERENCES auth.users(id) ON DELETE SET NULL;


-- 3) event_speichern: beim ANLEGEN den Ersteller setzen -----------------------
--    Gleiche 15-Parameter-Signatur wie supabase_event_kalender_update.sql ->
--    CREATE OR REPLACE genügt. Einzige Änderung ggü. dort: ersteller = auth.uid()
--    im INSERT (UPDATE-Zweig unverändert, inkl. kalender_seq = kalender_seq + 1).
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
                               uhrzeit, ende_uhrzeit, zeitzone, ersteller)
    VALUES (p_tree, v_fam, trim(p_titel), p_beschreibung, p_datum, p_ort, p_typ,
            coalesce(nullif(p_sprache,''),'de'), p_organisator, p_latitude, p_longitude, v_bp,
            nullif(trim(p_uhrzeit),''), nullif(trim(p_ende_uhrzeit),''),
            coalesce(nullif(trim(p_zeitzone),''),'Europe/Belgrade'), auth.uid())
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


-- 4) RSVP setzen: der eingeloggte Nutzer beantwortet sein EIGENES Kommen -------
--    Voraussetzung: darf_event_sehen(p_event). Legt bei Bedarf die event_eingeladene-
--    Zeile an (offene, nicht eingeschränkte Events -> jeder im Verbund darf zusagen).
--    Benachrichtigt den Organisator (events.ersteller) bzw. ersatzweise die Admins/Owner
--    der Event-Familie (nie sich selbst). titel = Antwortender (Anzeigename), text = Status.
CREATE OR REPLACE FUNCTION public.event_rsvp_setzen(
  p_event uuid, p_status text, p_anzahl int, p_notiz text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam uuid; v_titel text; v_ersteller uuid; v_verbund uuid;
  v_status text; v_anzahl int; v_name text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet.'; END IF;
  IF NOT public.darf_event_sehen(p_event) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;

  v_status := lower(coalesce(p_status,''));
  IF v_status NOT IN ('zusage','absage','vielleicht') THEN
    RAISE EXCEPTION 'Ungültiger RSVP-Status.';
  END IF;
  v_anzahl := greatest(1, coalesce(p_anzahl, 1));

  SELECT familie_id, titel, ersteller INTO v_fam, v_titel, v_ersteller
    FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;

  -- UPSERT auf die eigene Eingeladene-Zeile (PK event_id,user_id)
  INSERT INTO public.event_eingeladene (event_id, user_id, familie_id,
                                        rsvp_status, rsvp_anzahl, rsvp_notiz, rsvp_am)
  VALUES (p_event, auth.uid(), v_fam, v_status, v_anzahl, nullif(trim(coalesce(p_notiz,'')),''), now())
  ON CONFLICT (event_id, user_id) DO UPDATE
     SET rsvp_status = excluded.rsvp_status,
         rsvp_anzahl = excluded.rsvp_anzahl,
         rsvp_notiz  = excluded.rsvp_notiz,
         rsvp_am     = excluded.rsvp_am;

  -- Anzeigename des Antwortenden (Profil -> sonst E-Mail-Stamm)
  SELECT nullif(trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')),'')
    INTO v_name FROM public.profile pr WHERE pr.user_id = auth.uid();
  IF v_name IS NULL THEN
    SELECT split_part(coalesce(u.email,''), '@', 1) INTO v_name
      FROM auth.users u WHERE u.id = auth.uid();
  END IF;

  -- Benachrichtigung an den Organisator -> sonst Admins/Owner der Event-Familie (nie an mich)
  IF v_ersteller IS NOT NULL AND v_ersteller <> auth.uid() THEN
    INSERT INTO public.benachrichtigungen (user_id, typ, titel, text, event_id)
    VALUES (v_ersteller, 'event_rsvp', coalesce(v_name,''), v_status, p_event);
  ELSIF v_ersteller IS NULL THEN
    INSERT INTO public.benachrichtigungen (user_id, typ, titel, text, event_id)
    SELECT DISTINCT m.user_id, 'event_rsvp', coalesce(v_name,''), v_status, p_event
      FROM public.mitgliedschaften m
     WHERE m.familie_id = v_fam
       AND m.rolle IN ('familien_owner','familien_admin')
       AND m.user_id <> auth.uid();
  END IF;

  RETURN jsonb_build_object('ok', true, 'status', v_status, 'anzahl', v_anzahl);
END $$;
GRANT EXECUTE ON FUNCTION public.event_rsvp_setzen(uuid, text, int, text) TO authenticated;


-- 5) RSVP-Übersicht: Zähler für alle, Namensliste nur für Verwalter -----------
CREATE OR REPLACE FUNCTION public.event_rsvp_uebersicht(p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE
  v_fam uuid; v_darf_namen boolean;
  v_meine jsonb; v_zaehler jsonb; v_gesamt int; v_liste jsonb;
BEGIN
  IF NOT public.darf_event_sehen(p_event) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;

  v_darf_namen := public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam);

  -- eigene Antwort
  SELECT jsonb_build_object(
           'status', coalesce(ee.rsvp_status, 'offen'),
           'anzahl', coalesce(ee.rsvp_anzahl, 1),
           'notiz',  ee.rsvp_notiz)
    INTO v_meine
    FROM public.event_eingeladene ee
   WHERE ee.event_id = p_event AND ee.user_id = auth.uid();
  IF v_meine IS NULL THEN
    v_meine := jsonb_build_object('status','offen','anzahl',1,'notiz',NULL);
  END IF;

  -- Zähler je Status
  SELECT jsonb_build_object(
           'zusage',     count(*) FILTER (WHERE rsvp_status = 'zusage'),
           'absage',     count(*) FILTER (WHERE rsvp_status = 'absage'),
           'vielleicht', count(*) FILTER (WHERE rsvp_status = 'vielleicht'),
           'offen',      count(*) FILTER (WHERE rsvp_status = 'offen')),
         coalesce(sum(rsvp_anzahl) FILTER (WHERE rsvp_status = 'zusage'), 0)
    INTO v_zaehler, v_gesamt
    FROM public.event_eingeladene WHERE event_id = p_event;

  -- Namensliste nur für Verwalter
  IF v_darf_namen THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'name', nullif(trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')),''),
             'email', u.email,
             'status', ee.rsvp_status,
             'anzahl', ee.rsvp_anzahl,
             'notiz', ee.rsvp_notiz)
             ORDER BY ee.rsvp_status, pr.nachname, pr.vorname), '[]'::jsonb)
      INTO v_liste
      FROM public.event_eingeladene ee
      JOIN auth.users u ON u.id = ee.user_id
      LEFT JOIN public.profile pr ON pr.user_id = ee.user_id
     WHERE ee.event_id = p_event
       AND ee.rsvp_status <> 'offen';
  ELSE
    v_liste := '[]'::jsonb;
  END IF;

  RETURN jsonb_build_object(
    'meine', v_meine,
    'zaehler', v_zaehler,
    'personen_gesamt', v_gesamt,
    'darf_namen', v_darf_namen,
    'liste', v_liste);
END $$;
GRANT EXECUTE ON FUNCTION public.event_rsvp_uebersicht(uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'OK: event_eingeladene.rsvp_* + events.ersteller + event_speichern(ersteller) + event_rsvp_setzen/uebersicht angelegt' AS status;
