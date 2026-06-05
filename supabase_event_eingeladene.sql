-- =====================================================
-- EVENT-TEILNEHMER / SICHTBARKEIT (Phase 1)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent (mehrfach ausführbar).
--
-- Ziel (Feature "Teilnehmerverwaltung für Events"):
--  - Ein Admin/Owner kann je Event festlegen, WELCHE Personen aus dem Stammbaum
--    (inkl. verknüpfter Bäume = ganzer Verbund) das Event sehen dürfen.
--  - Standard = KEINE Einschränkung: jeder im Verbund sieht das Event (wie bisher).
--  - Wird eingeschränkt, sehen nur die eingeladenen Personen (über ihr verknüpftes
--    Konto) PLUS Admins/Owner der Familie (und Super-Admin). Prüfung SERVERSEITIG.
--
-- WICHTIG — Abgrenzung zur bestehenden Tabelle `event_teilnehmer`:
--  `event_teilnehmer` (supabase_event_kosten.sql) sind die KOSTEN-Teilnehmer
--  (Kostenaufteilung). Das ist ein ANDERES Konzept. Diese Datei legt eine EIGENE
--  Tabelle `event_eingeladene` an (Sichtbarkeit/Einladung) und fasst `event_teilnehmer`
--  NICHT an.
--
-- "Person" ≠ "Konto": Stammbaum-Personen haben meist KEIN Benutzerkonto. Echten
--  Zugriff/Benachrichtigung gibt es nur für Personen, die mit einem Konto verknüpft
--  sind (personen.user_id). Personen ohne Konto sind wählbar, bleiben aber ohne
--  Wirkung (sie können sich ohnehin nicht einloggen). Benachrichtigungen = Phase 2.
--
-- Voraussetzungen: supabase_events.sql (events + ist_super_admin/sieht_familie/
--   kann_familie_bearbeiten), supabase_verbund.sql (familien.verbund_id),
--   supabase_gleiche_person.sql (personen.identitaet_id).
-- =====================================================


-- 1) Flag am Event: ist die Sichtbarkeit eingeschränkt? -----------------------
--    false (Default) = jeder im Verbund sieht es (Rückwärtskompatibel).
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS sichtbar_eingeschraenkt boolean NOT NULL DEFAULT false;


-- 2) Tabelle: eingeladene Personen je Event -----------------------------------
CREATE TABLE IF NOT EXISTS public.event_eingeladene (
  event_id   uuid NOT NULL REFERENCES public.events(id)   ON DELETE CASCADE,
  person_id  uuid NOT NULL REFERENCES public.personen(id) ON DELETE CASCADE,
  familie_id uuid NOT NULL,                 -- für Rechteprüfung / Konsistenz
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, person_id)
);
CREATE INDEX IF NOT EXISTS event_eingeladene_event_idx  ON public.event_eingeladene(event_id);
CREATE INDEX IF NOT EXISTS event_eingeladene_person_idx ON public.event_eingeladene(person_id);

-- RLS an, KEINE Policies -> direkter Zugriff gesperrt; nur die RPCs unten greifen.
ALTER TABLE public.event_eingeladene ENABLE ROW LEVEL SECURITY;


-- 3) Helper: darf der EINGELOGGTE Nutzer dieses Event sehen? -------------------
--    super_admin: immer. Sonst: Familie sichtbar UND (nicht eingeschränkt ODER
--    Admin/Owner der Familie ODER über ein verknüpftes Konto eingeladen).
--    Die Konto-Zuordnung berücksichtigt Identitätsgruppen (Spiegelkarten via
--    identitaet_id), damit ein eingeladenes Spiegel-Pendant ebenfalls zählt.
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
              SELECT 1
                FROM public.event_eingeladene ee
                JOIN public.personen pi ON pi.id = ee.person_id
                JOIN public.personen pu
                  ON (pu.id = pi.id
                      OR (pi.identitaet_id IS NOT NULL AND pu.identitaet_id = pi.identitaet_id))
               WHERE ee.event_id = e.id
                 AND pu.user_id = auth.uid()
            )
          )
        )
      )
  );
$$;
GRANT EXECUTE ON FUNCTION public.darf_event_sehen(uuid) TO authenticated;


-- 4) Bestehende Lese-RPCs serverseitig auf die Sichtbarkeit umstellen ----------

-- 4a) Events eines Stammbaums: zusätzlich darf_event_sehen je Zeile.
CREATE OR REPLACE FUNCTION public.events_fuer_stammbaum(p_tree uuid)
RETURNS SETOF public.events
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT e.* FROM public.events e
  WHERE e.stammbaum_id = p_tree
    AND public.darf_event_sehen(e.id)
  ORDER BY e.created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.events_fuer_stammbaum(uuid) TO authenticated;

-- 4b) Kosten-/Teilnehmerdaten eines Events: nur, wenn man das Event sehen darf.
CREATE OR REPLACE FUNCTION public.event_kosten_daten(p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_res jsonb;
BEGIN
  IF (SELECT familie_id FROM public.events WHERE id = p_event) IS NULL THEN
    RAISE EXCEPTION 'Event nicht gefunden.';
  END IF;
  IF NOT public.darf_event_sehen(p_event) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  SELECT jsonb_build_object(
    'teilnehmer', coalesce((SELECT jsonb_agg(jsonb_build_object(
                              'id', t.id, 'person_id', t.person_id, 'name', t.name) ORDER BY t.created_at)
                            FROM public.event_teilnehmer t WHERE t.event_id = p_event), '[]'::jsonb),
    'kosten',     coalesce((SELECT jsonb_agg(jsonb_build_object(
                              'id', k.id, 'bezeichnung', k.bezeichnung, 'beschreibung', k.beschreibung,
                              'betrag', k.betrag, 'waehrung', k.waehrung, 'datum', k.datum,
                              'payer_id', k.payer_id) ORDER BY k.created_at)
                            FROM public.event_kosten k WHERE k.event_id = p_event), '[]'::jsonb)
  ) INTO v_res;
  RETURN v_res;
END $$;
GRANT EXECUTE ON FUNCTION public.event_kosten_daten(uuid) TO authenticated;


-- 5) Kandidaten für das Teilnehmer-Overlay (Verbund des Events) ----------------
--    Liefert alle Personen aus dem aktuellen Baum + allen verknüpften Bäumen
--    (= Verbund der Event-Familie). Nur für Admin/Owner der Event-Familie bzw.
--    Super-Admin (sonst leere Liste). hat_konto = mit Benutzerkonto verknüpft.
CREATE OR REPLACE FUNCTION public.event_teilnehmer_kandidaten(p_event uuid)
RETURNS TABLE(
  person_id uuid, vorname text, nachname text, geburt text,
  stammbaum_id uuid, baum_name text, hat_konto boolean, eingeladen boolean
)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT pe.id, pe.vorname, pe.nachname,
         pe.stammbaum_daten->>'birth_date' AS geburt,
         pe.stammbaum_id, s.name AS baum_name,
         (pe.user_id IS NOT NULL) AS hat_konto,
         EXISTS (SELECT 1 FROM public.event_eingeladene ee
                  WHERE ee.event_id = p_event AND ee.person_id = pe.id) AS eingeladen
    FROM public.personen pe
    JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
    JOIN public.familien   f ON f.id = pe.familie_id
   WHERE f.verbund_id = (
           SELECT f2.verbund_id FROM public.familien f2
            WHERE f2.id = (SELECT familie_id FROM public.events WHERE id = p_event))
     AND (
       public.ist_super_admin()
       OR public.kann_familie_bearbeiten((SELECT familie_id FROM public.events WHERE id = p_event))
     )
   ORDER BY pe.nachname, pe.vorname;
$$;
GRANT EXECUTE ON FUNCTION public.event_teilnehmer_kandidaten(uuid) TO authenticated;


-- 6) Aktuellen Einlade-Stand lesen (für das Overlay) --------------------------
CREATE OR REPLACE FUNCTION public.event_eingeladene_daten(p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_fam uuid; v_ein boolean; v_ids jsonb;
BEGIN
  SELECT familie_id, sichtbar_eingeschraenkt INTO v_fam, v_ein FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  SELECT coalesce(jsonb_agg(person_id), '[]'::jsonb) INTO v_ids
    FROM public.event_eingeladene WHERE event_id = p_event;
  RETURN jsonb_build_object('eingeschraenkt', coalesce(v_ein,false), 'person_ids', v_ids);
END $$;
GRANT EXECUTE ON FUNCTION public.event_eingeladene_daten(uuid) TO authenticated;


-- 7) Einlade-Set setzen (Overlay "Speichern") ---------------------------------
--    p_eingeschraenkt = false -> Einschränkung AUS (Set wird geleert, jeder sieht).
--    p_eingeschraenkt = true  -> nur die übergebenen Personen (aus dem Verbund).
--    Idempotentes "Replace": nicht mehr gewählte werden entfernt, neue ergänzt.
--    Rückgabe enthält die NEU hinzugefügten person_ids (für Phase-2-Benachrichtigung).
CREATE OR REPLACE FUNCTION public.event_eingeladene_setzen(
  p_event uuid, p_eingeschraenkt boolean, p_person_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_verbund uuid; v_neu jsonb; v_n int;
BEGIN
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  SELECT verbund_id INTO v_verbund FROM public.familien WHERE id = v_fam;

  -- Bei "nicht eingeschränkt" das Set leeren (unbeschränkt = jeder sieht).
  IF coalesce(p_eingeschraenkt,false) = false THEN
    DELETE FROM public.event_eingeladene WHERE event_id = p_event;
    UPDATE public.events SET sichtbar_eingeschraenkt = false WHERE id = p_event;
    RETURN jsonb_build_object('ok', true, 'eingeschraenkt', false, 'anzahl', 0, 'neu', '[]'::jsonb);
  END IF;

  -- NEU hinzugekommene (vor dem Insert ermitteln -> Phase-2-Benachrichtigung)
  SELECT coalesce(jsonb_agg(x), '[]'::jsonb) INTO v_neu FROM (
    SELECT unnest(p_person_ids) AS x
    EXCEPT
    SELECT person_id FROM public.event_eingeladene WHERE event_id = p_event
  ) q;

  -- Nicht mehr gewählte entfernen
  DELETE FROM public.event_eingeladene ee
   WHERE ee.event_id = p_event
     AND (p_person_ids IS NULL OR NOT (ee.person_id = ANY(p_person_ids)));

  -- Neue ergänzen — nur Personen aus dem Verbund der Event-Familie (Isolation).
  IF p_person_ids IS NOT NULL THEN
    INSERT INTO public.event_eingeladene (event_id, person_id, familie_id)
    SELECT p_event, pe.id, v_fam
      FROM public.personen pe
      JOIN public.familien f ON f.id = pe.familie_id
     WHERE pe.id = ANY(p_person_ids)
       AND f.verbund_id = v_verbund
    ON CONFLICT (event_id, person_id) DO NOTHING;
  END IF;

  UPDATE public.events SET sichtbar_eingeschraenkt = true WHERE id = p_event;
  SELECT count(*) INTO v_n FROM public.event_eingeladene WHERE event_id = p_event;
  RETURN jsonb_build_object('ok', true, 'eingeschraenkt', true, 'anzahl', v_n, 'neu', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.event_eingeladene_setzen(uuid, boolean, uuid[]) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'Phase 1 OK: event_eingeladene + Sichtbarkeits-RPCs (darf_event_sehen, Kandidaten, setzen/lesen)' AS status;
