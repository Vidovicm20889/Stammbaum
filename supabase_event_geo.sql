-- =====================================================
-- EVENTS: GEOKOORDINATEN + BEZUGSPERSON (für Karte / Migrationspfad)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent. SETZT supabase_events.sql + supabase_events_medien_organisator.sql VORAUS.
--
-- Warum:
--  * latitude/longitude (double precision, nullable) am Event -> Karten-Marker
--    (Leaflet/OpenStreetMap), gesetzt per Nominatim-Geocoding ODER manuellem Klick.
--  * bezugsperson_id -> optionale Verknüpfung eines Events zu EINER Baum-Person.
--    Damit lässt sich der "Migrationspfad EINER Person" bauen (ihre verorteten
--    Events chronologisch, mit Polyline verbunden). ON DELETE SET NULL = wird die
--    Person gelöscht, bleibt das Event erhalten (nur die Verknüpfung fällt weg).
--
-- events_fuer_stammbaum / events_fuer_mich liefern SETOF public.events -> die neuen
-- Spalten erscheinen dort AUTOMATISCH (kein Funktions-Rewrite nötig). Nur
-- event_speichern wird um die drei Parameter erweitert.
-- =====================================================

-- 1) Neue Spalten ------------------------------------------------------------
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS latitude        double precision;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS longitude       double precision;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS bezugsperson_id uuid
  REFERENCES public.personen(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS events_bezugsperson_idx ON public.events(bezugsperson_id);

-- 2) event_speichern um p_latitude, p_longitude, p_bezugsperson erweitern -----
--    Alte 9-Parameter-Signatur entfernen, neue 12-Parameter-Variante anlegen.
DROP FUNCTION IF EXISTS public.event_speichern(uuid, uuid, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.event_speichern(
  p_id uuid, p_tree uuid, p_titel text, p_beschreibung text,
  p_datum text, p_ort text, p_typ text, p_sprache text, p_organisator text,
  p_latitude double precision, p_longitude double precision, p_bezugsperson uuid)
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
       AND (public.ist_super_admin() OR public.sieht_familie(pe.familie_id))
     LIMIT 1;
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.events (stammbaum_id, familie_id, titel, beschreibung, datum, ort, typ,
                               sprache, organisator, latitude, longitude, bezugsperson_id)
    VALUES (p_tree, v_fam, trim(p_titel), p_beschreibung, p_datum, p_ort, p_typ,
            coalesce(nullif(p_sprache,''),'de'), p_organisator, p_latitude, p_longitude, v_bp)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.events
       SET titel = trim(p_titel), beschreibung = p_beschreibung,
           datum = p_datum, ort = p_ort, typ = p_typ, organisator = p_organisator,
           latitude = p_latitude, longitude = p_longitude, bezugsperson_id = v_bp
     WHERE id = p_id AND stammbaum_id = p_tree;
    v_id := p_id;
  END IF;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.event_speichern(
  uuid, uuid, text, text, text, text, text, text, text, double precision, double precision, uuid)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'events.latitude/longitude/bezugsperson_id + event_speichern(12 Args) aktualisiert' AS status;
