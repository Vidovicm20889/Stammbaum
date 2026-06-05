-- =====================================================
-- EVENT-SICHTBARKEIT — UMSTELLUNG AUF BENUTZERKONTEN (statt Personen)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent. SETZT supabase_event_eingeladene.sql + supabase_benachrichtigungen.sql VORAUS
-- (diese Datei ersetzt deren person-basierte Teile durch ein user-basiertes Modell).
--
-- Warum: Sichtbarkeit/Einladung ergibt nur für ECHTE Konten Sinn (Login + Benachrichtigung).
-- Die Auswahl erfolgt jetzt über REGISTRIERTE BENUTZER des Verbunds (Owner/Admin/Mitglied,
-- super_admin ausgeblendet) — aus dem aktuellen Baum UND allen verknüpften Bäumen (Verbund).
--
-- Modellwechsel: event_eingeladene speichert user_id (statt person_id). Da das Feature frisch
-- ist (keine produktiven Einladungs-Daten), wird die Tabelle neu aufgebaut.
-- =====================================================


-- 1) Tabelle neu: eingeladene KONTEN je Event ---------------------------------
DROP TABLE IF EXISTS public.event_eingeladene CASCADE;
CREATE TABLE public.event_eingeladene (
  event_id   uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id)    ON DELETE CASCADE,
  familie_id uuid NOT NULL,                 -- Event-Familie (Rechteprüfung / Konsistenz)
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, user_id)
);
CREATE INDEX IF NOT EXISTS event_eingeladene_event_idx ON public.event_eingeladene(event_id);
CREATE INDEX IF NOT EXISTS event_eingeladene_user_idx  ON public.event_eingeladene(user_id);
ALTER TABLE public.event_eingeladene ENABLE ROW LEVEL SECURITY;   -- KEINE Policies; nur RPCs


-- 2) darf_event_sehen: "eingeladen" = das eigene Konto ist eingeladen ----------
CREATE OR REPLACE FUNCTION public.darf_event_sehen(p_event_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.events e
    WHERE e.id = p_event_id
      AND (
        public.ist_super_admin()
        OR (
          public.sieht_familie(e.familie_id)
          AND (
            NOT e.sichtbar_eingeschraenkt
            OR public.kann_familie_bearbeiten(e.familie_id)
            OR EXISTS (
              SELECT 1 FROM public.event_eingeladene ee
               WHERE ee.event_id = e.id AND ee.user_id = auth.uid()
            )
          )
        )
      )
  );
$$;
GRANT EXECUTE ON FUNCTION public.darf_event_sehen(uuid) TO authenticated;


-- 3) Kandidaten: registrierte KONTEN des Verbunds (Owner/Admin/Mitglied) -------
--    super_admin ausgeblendet. Nur Admin/Owner der Event-Familie bzw. Super-Admin
--    bekommen überhaupt eine Liste (sonst leer). Rolle = höchste im Verbund.
DROP FUNCTION IF EXISTS public.event_teilnehmer_kandidaten(uuid);
CREATE FUNCTION public.event_teilnehmer_kandidaten(p_event uuid)
RETURNS TABLE(
  user_id uuid, email text, vorname text, nachname text, rolle text, eingeladen boolean
)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  WITH ev AS (
    SELECT e.familie_id, f.verbund_id
      FROM public.events e
      JOIN public.familien f ON f.id = e.familie_id
     WHERE e.id = p_event
  ),
  konten AS (
    SELECT m.user_id,
           max(CASE m.rolle
                 WHEN 'familien_owner'    THEN 3
                 WHEN 'familien_admin'    THEN 2
                 WHEN 'familien_mitglied' THEN 1
                 ELSE 0 END) AS rang
      FROM public.mitgliedschaften m
      JOIN public.familien f ON f.id = m.familie_id
     WHERE f.verbund_id = (SELECT verbund_id FROM ev)
       AND m.rolle <> 'super_admin'
     GROUP BY m.user_id
  )
  SELECT k.user_id,
         u.email,
         pr.vorname, pr.nachname,
         CASE k.rang WHEN 3 THEN 'familien_owner'
                     WHEN 2 THEN 'familien_admin'
                     ELSE 'familien_mitglied' END AS rolle,
         EXISTS (SELECT 1 FROM public.event_eingeladene ee
                  WHERE ee.event_id = p_event AND ee.user_id = k.user_id) AS eingeladen
    FROM konten k
    JOIN auth.users u ON u.id = k.user_id
    LEFT JOIN public.profile pr ON pr.user_id = k.user_id
   WHERE (public.ist_super_admin()
          OR public.kann_familie_bearbeiten((SELECT familie_id FROM ev)))
   ORDER BY coalesce(pr.nachname,''), coalesce(pr.vorname,''), u.email;
$$;
GRANT EXECUTE ON FUNCTION public.event_teilnehmer_kandidaten(uuid) TO authenticated;


-- 4) Aktuellen Einlade-Stand lesen (Overlay) — jetzt user_ids -----------------
CREATE OR REPLACE FUNCTION public.event_eingeladene_daten(p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_fam uuid; v_ein boolean; v_ids jsonb;
BEGIN
  SELECT familie_id, sichtbar_eingeschraenkt INTO v_fam, v_ein FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  SELECT coalesce(jsonb_agg(user_id), '[]'::jsonb) INTO v_ids
    FROM public.event_eingeladene WHERE event_id = p_event;
  RETURN jsonb_build_object('eingeschraenkt', coalesce(v_ein,false), 'user_ids', v_ids);
END $$;
GRANT EXECUTE ON FUNCTION public.event_eingeladene_daten(uuid) TO authenticated;


-- 5) Einlade-Set setzen — jetzt user_ids --------------------------------------
--    false -> Einschränkung AUS (Set leeren). true -> nur die übergebenen Konten.
--    Nur Konten aus dem VERBUND der Event-Familie (Isolation). Rückgabe: NEU = neue user_ids.
DROP FUNCTION IF EXISTS public.event_eingeladene_setzen(uuid, boolean, uuid[]);
CREATE FUNCTION public.event_eingeladene_setzen(
  p_event uuid, p_eingeschraenkt boolean, p_user_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_verbund uuid; v_neu jsonb; v_n int;
BEGIN
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  SELECT verbund_id INTO v_verbund FROM public.familien WHERE id = v_fam;

  -- "nicht eingeschränkt" -> Set leeren (jeder im Verbund sieht).
  IF coalesce(p_eingeschraenkt,false) = false THEN
    DELETE FROM public.event_eingeladene WHERE event_id = p_event;
    UPDATE public.events SET sichtbar_eingeschraenkt = false WHERE id = p_event;
    RETURN jsonb_build_object('ok', true, 'eingeschraenkt', false, 'anzahl', 0, 'neu', '[]'::jsonb);
  END IF;

  -- gültige Ziel-Konten = übergebene IDs, die im Verbund Mitglied sind (Isolation, dedupe)
  CREATE TEMP TABLE _gueltig ON COMMIT DROP AS
    SELECT DISTINCT m.user_id
      FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) AS inp(uid)
      JOIN public.mitgliedschaften m ON m.user_id = inp.uid
      JOIN public.familien f ON f.id = m.familie_id
     WHERE f.verbund_id = v_verbund;

  -- NEU hinzugekommene (vor dem Insert ermitteln -> Benachrichtigung)
  SELECT coalesce(jsonb_agg(g.user_id), '[]'::jsonb) INTO v_neu
    FROM _gueltig g
   WHERE NOT EXISTS (SELECT 1 FROM public.event_eingeladene ee
                      WHERE ee.event_id = p_event AND ee.user_id = g.user_id);

  -- nicht mehr gewählte entfernen
  DELETE FROM public.event_eingeladene ee
   WHERE ee.event_id = p_event
     AND NOT EXISTS (SELECT 1 FROM _gueltig g WHERE g.user_id = ee.user_id);

  -- neue ergänzen
  INSERT INTO public.event_eingeladene (event_id, user_id, familie_id)
  SELECT p_event, g.user_id, v_fam FROM _gueltig g
  ON CONFLICT (event_id, user_id) DO NOTHING;

  UPDATE public.events SET sichtbar_eingeschraenkt = true WHERE id = p_event;
  SELECT count(*) INTO v_n FROM public.event_eingeladene WHERE event_id = p_event;
  RETURN jsonb_build_object('ok', true, 'eingeschraenkt', true, 'anzahl', v_n, 'neu', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.event_eingeladene_setzen(uuid, boolean, uuid[]) TO authenticated;


-- 6) Benachrichtigung — jetzt direkt user_ids (kein Person->Konto-Mapping) -----
--    Legt je Ziel-Konto (≠ aufrufender Nutzer) eine In-App-Benachrichtigung an und
--    liefert die E-Mail-Empfänger (Adresse + Anzeigename + Sprache) für die Edge Function.
DROP FUNCTION IF EXISTS public.event_einladung_benachrichtige(uuid, uuid[]);
CREATE FUNCTION public.event_einladung_benachrichtige(
  p_event uuid, p_user_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_titel text; v_empf jsonb;
BEGIN
  IF p_user_ids IS NULL OR array_length(p_user_ids,1) IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'empfaenger', '[]'::jsonb);
  END IF;
  SELECT familie_id, titel INTO v_fam, v_titel FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  CREATE TEMP TABLE _ziel ON COMMIT DROP AS
    SELECT DISTINCT inp.uid AS user_id
      FROM unnest(p_user_ids) AS inp(uid)
     WHERE inp.uid <> auth.uid();

  INSERT INTO public.benachrichtigungen (user_id, typ, titel, text, event_id)
  SELECT z.user_id, 'event_einladung', v_titel, NULL, p_event FROM _ziel z;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'user_id', z.user_id,
           'email',   u.email,
           'name',    trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')),
           'sprache', coalesce(pr.sprache, 'de')
         )), '[]'::jsonb)
    INTO v_empf
    FROM _ziel z
    JOIN auth.users u ON u.id = z.user_id
    LEFT JOIN public.profile pr ON pr.user_id = z.user_id
   WHERE u.email IS NOT NULL;

  RETURN jsonb_build_object('ok', true, 'titel', v_titel, 'empfaenger', v_empf);
END $$;
GRANT EXECUTE ON FUNCTION public.event_einladung_benachrichtige(uuid, uuid[]) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'OK: event_eingeladene auf BENUTZERKONTEN umgestellt (Kandidaten/Setzen/Sehen/Benachrichtigung)' AS status;
