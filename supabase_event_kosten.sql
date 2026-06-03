-- =====================================================
-- EVENTS #3: Kostenübersicht / Troškovi događaja
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Zwei Tabellen (Teilnehmer + Ausgaben), je ON DELETE CASCADE am Event
-- (Event löschen entfernt automatisch Teilnehmer & Kosten -> keine Waisen).
-- Zugriff nur über SECURITY-DEFINER-RPCs (RLS an, keine Policies).
-- Voraussetzung: events-Tabelle + ist_super_admin()/sieht_familie()/
--                kann_familie_bearbeiten() aus supabase_events.sql.
-- =====================================================

CREATE TABLE IF NOT EXISTS public.event_teilnehmer (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id   uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  familie_id uuid NOT NULL,
  person_id  uuid,                 -- optional: Person aus dem Stammbaum (personen.id)
  name       text NOT NULL,        -- Anzeigename (extern ODER Kopie des Personennamens)
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS event_teilnehmer_event_idx ON public.event_teilnehmer(event_id);

CREATE TABLE IF NOT EXISTS public.event_kosten (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id     uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  familie_id   uuid NOT NULL,
  bezeichnung  text NOT NULL,
  beschreibung text,
  betrag       numeric(12,2) NOT NULL DEFAULT 0,
  waehrung     text NOT NULL DEFAULT 'EUR',
  datum        text,                                                   -- Freitext/ISO wie events.datum
  payer_id     uuid REFERENCES public.event_teilnehmer(id) ON DELETE SET NULL,  -- "bezahlt von"
  created_at   timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS event_kosten_event_idx ON public.event_kosten(event_id);

ALTER TABLE public.event_teilnehmer ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_kosten     ENABLE ROW LEVEL SECURITY;

-- 1) Lesen: Teilnehmer + Ausgaben eines Events als ein JSON-Objekt
CREATE OR REPLACE FUNCTION public.event_kosten_daten(p_event uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_fam uuid; v_res jsonb;
BEGIN
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.sieht_familie(v_fam)) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
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

-- 2) Teilnehmer anlegen/aktualisieren
CREATE OR REPLACE FUNCTION public.event_teilnehmer_speichern(
  p_id uuid, p_event uuid, p_person_id uuid, p_name text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_id uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  IF coalesce(trim(p_name),'') = '' THEN RAISE EXCEPTION 'Name erforderlich.'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.event_teilnehmer (event_id, familie_id, person_id, name)
    VALUES (p_event, v_fam, p_person_id, trim(p_name)) RETURNING id INTO v_id;
  ELSE
    UPDATE public.event_teilnehmer SET person_id = p_person_id, name = trim(p_name)
    WHERE id = p_id AND event_id = p_event;
    v_id := p_id;
  END IF;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.event_teilnehmer_speichern(uuid, uuid, uuid, text) TO authenticated;

-- 3) Teilnehmer löschen (payer_id der Ausgaben wird per FK auf NULL gesetzt)
CREATE OR REPLACE FUNCTION public.event_teilnehmer_loeschen(p_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.event_teilnehmer WHERE id = p_id;
  IF v_fam IS NULL THEN RETURN false; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  DELETE FROM public.event_teilnehmer WHERE id = p_id;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.event_teilnehmer_loeschen(uuid) TO authenticated;

-- 4) Ausgabe anlegen/aktualisieren
CREATE OR REPLACE FUNCTION public.event_kosten_speichern(
  p_id uuid, p_event uuid, p_bezeichnung text, p_beschreibung text,
  p_betrag numeric, p_waehrung text, p_datum text, p_payer uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_id uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  IF coalesce(trim(p_bezeichnung),'') = '' THEN RAISE EXCEPTION 'Bezeichnung erforderlich.'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.event_kosten (event_id, familie_id, bezeichnung, beschreibung, betrag, waehrung, datum, payer_id)
    VALUES (p_event, v_fam, trim(p_bezeichnung), p_beschreibung, coalesce(p_betrag,0),
            coalesce(nullif(trim(p_waehrung),''),'EUR'), p_datum, p_payer)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.event_kosten
       SET bezeichnung = trim(p_bezeichnung), beschreibung = p_beschreibung,
           betrag = coalesce(p_betrag,0), waehrung = coalesce(nullif(trim(p_waehrung),''),'EUR'),
           datum = p_datum, payer_id = p_payer
     WHERE id = p_id AND event_id = p_event;
    v_id := p_id;
  END IF;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.event_kosten_speichern(uuid, uuid, text, text, numeric, text, text, uuid) TO authenticated;

-- 5) Ausgabe löschen
CREATE OR REPLACE FUNCTION public.event_kosten_loeschen(p_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.event_kosten WHERE id = p_id;
  IF v_fam IS NULL THEN RETURN false; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  DELETE FROM public.event_kosten WHERE id = p_id;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.event_kosten_loeschen(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'event_teilnehmer + event_kosten + RPCs angelegt' AS status;
