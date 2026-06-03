-- =====================================================
-- EVENTS PRO STAMMBAUM — Tabelle + RPCs
-- Ausführen in: Supabase -> SQL Editor.
-- Mehrere Events je Stammbaum; Originalsprache wird gespeichert (für spätere
-- KI-Übersetzung). Zugriff über SECURITY-DEFINER-RPCs (RLS ohne Policies =
-- direkter Zugriff gesperrt, nur die RPCs greifen).
-- Voraussetzung: ist_super_admin(), sieht_familie(), kann_familie_bearbeiten().
-- =====================================================

CREATE TABLE IF NOT EXISTS public.events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stammbaum_id uuid NOT NULL REFERENCES public.stammbaeume(id) ON DELETE CASCADE,
  familie_id   uuid NOT NULL,           -- für Rechte-/Sichtbarkeitsprüfung
  titel        text NOT NULL,
  beschreibung text,
  datum        text,                    -- Freitext-Datum (wie geburtsdatum -> NICHT date)
  ort          text,
  typ          text,
  sprache      text DEFAULT 'de',       -- Originalsprache des Inhalts
  created_at   timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS events_stammbaum_idx ON public.events(stammbaum_id);

-- RLS an, KEINE Policies -> direkter Tabellenzugriff gesperrt; nur die
-- SECURITY-DEFINER-RPCs unten dürfen lesen/schreiben.
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

-- 1) Events eines Stammbaums lesen (super_admin oder verbund-sichtbar)
CREATE OR REPLACE FUNCTION public.events_fuer_stammbaum(p_tree uuid)
RETURNS SETOF public.events
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT e.* FROM public.events e
  WHERE e.stammbaum_id = p_tree
    AND (public.ist_super_admin() OR public.sieht_familie(e.familie_id))
  ORDER BY e.created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.events_fuer_stammbaum(uuid) TO authenticated;

-- 2) Event anlegen ODER aktualisieren (alle Felder inkl. Titel). p_id NULL = neu.
CREATE OR REPLACE FUNCTION public.event_speichern(
  p_id uuid, p_tree uuid, p_titel text, p_beschreibung text,
  p_datum text, p_ort text, p_typ text, p_sprache text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_id uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  IF coalesce(trim(p_titel),'') = '' THEN RAISE EXCEPTION 'Titel ist erforderlich.'; END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.events (stammbaum_id, familie_id, titel, beschreibung, datum, ort, typ, sprache)
    VALUES (p_tree, v_fam, trim(p_titel), p_beschreibung, p_datum, p_ort, p_typ, coalesce(nullif(p_sprache,''),'de'))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.events
       SET titel = trim(p_titel), beschreibung = p_beschreibung,
           datum = p_datum, ort = p_ort, typ = p_typ
     WHERE id = p_id AND stammbaum_id = p_tree;
    v_id := p_id;
  END IF;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.event_speichern(uuid, uuid, text, text, text, text, text, text) TO authenticated;

-- 3) Event löschen
CREATE OR REPLACE FUNCTION public.event_loeschen(p_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_id;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  DELETE FROM public.events WHERE id = p_id;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.event_loeschen(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'events-Tabelle (pro Stammbaum) + RPCs angelegt' AS status;
