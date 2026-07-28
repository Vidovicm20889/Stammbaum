-- =====================================================
-- EVENTS #2: Feld "Organizovano od" (organisator) + Medien
-- Ausführen in: Supabase -> SQL Editor.
-- Idempotent. Medien selbst liegen im Storage-Bucket "events"
-- (bereits vorhanden; Referenzen werden per Storage-Listing abgeleitet,
--  daher KEINE Medien-Spalte/Tabelle nötig).
-- Voraussetzung: events-Tabelle + Rechtefunktionen aus supabase_events.sql.
-- =====================================================

-- 1) Neue Spalte für den Organisator (Freitext, mehrsprachig vom Frontend)
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS organisator text;

-- 2) event_speichern um p_organisator erweitern.
--    Alte 8-Parameter-Signatur entfernen, neue 9-Parameter-Variante anlegen.
DROP FUNCTION IF EXISTS public.event_speichern(uuid, uuid, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.event_speichern(
  p_id uuid, p_tree uuid, p_titel text, p_beschreibung text,
  p_datum text, p_ort text, p_typ text, p_sprache text, p_organisator text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_id uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  IF coalesce(trim(p_titel),'') = '' THEN RAISE EXCEPTION 'Titel ist erforderlich.'; END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.events (stammbaum_id, familie_id, titel, beschreibung, datum, ort, typ, sprache, organisator)
    VALUES (p_tree, v_fam, trim(p_titel), p_beschreibung, p_datum, p_ort, p_typ,
            coalesce(nullif(p_sprache,''),'de'), p_organisator)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.events
       SET titel = trim(p_titel), beschreibung = p_beschreibung,
           datum = p_datum, ort = p_ort, typ = p_typ, organisator = p_organisator
     WHERE id = p_id AND stammbaum_id = p_tree;
    v_id := p_id;
  END IF;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.event_speichern(uuid, uuid, text, text, text, text, text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'events.organisator + event_speichern(9 Args) aktualisiert' AS status;

-- =====================================================
-- HINWEIS Storage-Bucket "events":
-- Existiert bereits (altes Medien-System). Falls Medien-Upload Fehler
-- "bucket not found"/"row-level security" wirft, im Dashboard prüfen:
--   Storage -> bucket "events" vorhanden, und Policies erlauben
--   authenticated: SELECT (list/download), INSERT (upload), DELETE.
-- Optionaler strengerer Schutz (Familien-Isolation auf Storage-Ebene)
-- ist ein separater Folgeschritt und hier bewusst NICHT erzwungen.
-- =====================================================
