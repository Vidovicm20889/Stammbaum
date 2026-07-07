-- ============================================================================
-- FAMILIEN-ALBEN (standalone) — Fotos & Videos in benannten Alben
-- ----------------------------------------------------------------------------
-- Neuer „Albums"-Bereich im Events-Tab (zwischen Liste und Zeitstrahl). Anders als das
-- bestehende PER-EVENT-Album (event_album_fotos) sind dies EIGENSTÄNDIGE, verbundweite Alben:
-- jedes Verbund-Mitglied legt Alben an und lädt Fotos/Videos rein (kollaborativ).
--
-- Entscheidungen (mit dem Betreiber abgestimmt):
--   * Geltung   = VERBUND-weit (nicht baum-gebunden) -> überall im Verbund dieselben Alben.
--   * Rechte    = ALLE Verbund-Mitglieder dürfen anlegen + hochladen; Löschen = eigener Upload
--                 ODER Moderator (darf_verbund_moderieren). Album löschen = Ersteller ODER Moderator.
--   * Speicher  = eigener, NICHT-öffentlicher Bucket 'alben' (signierte URLs, wie event-album) —
--                 Videos lebender Personen bleiben verbund-intern.
-- Muster gespiegelt von supabase_event_album.sql (RLS AN ohne Tabellen-Policies -> Zugriff nur
-- über SECURITY-DEFINER-RPCs; Storage-Policies über das erste Pfad-Segment = verbund_id).
-- Pfadschema im Bucket:  {verbund_id}/{album_id}/{uuid}.{ext}
--
-- PREMIUM-/LIMIT-KANDIDAT: Videos sind egress-intensiv (Supabase-Egress). v1 begrenzt clientseitig
-- 50 MB je Datei; ein hartes Server-Quota folgt mit der abo_status-Kopplung.
-- Idempotent -> im Supabase SQL-Editor ausführbar. Voraussetzungen: ist_in_verbund/mein_verbund/
-- darf_verbund_moderieren, familien/verbund, profile.
-- ============================================================================

-- ------------------------------------------------------------------ 1) Tabellen
CREATE TABLE IF NOT EXISTS public.alben (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id   uuid NOT NULL,
  titel        text NOT NULL,
  beschreibung text,
  cover_pfad   text,                       -- optionales Titelbild (Pfad im Bucket 'alben')
  erstellt_von uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  erstellt_am  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS alben_verbund_idx ON public.alben (verbund_id, erstellt_am DESC);

CREATE TABLE IF NOT EXISTS public.album_medien (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id        uuid NOT NULL REFERENCES public.alben(id) ON DELETE CASCADE,
  verbund_id      uuid NOT NULL,           -- denormalisiert -> einfache, rekursionsfreie Prüfungen
  storage_pfad    text NOT NULL,
  mime            text,                    -- image/* oder video/* -> Frontend rendert typgerecht
  beschriftung    text,
  sortierung      int NOT NULL DEFAULT 0,
  hochgeladen_von uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  erstellt_am     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS album_medien_album_idx ON public.album_medien (album_id, sortierung, erstellt_am);

-- RLS AN, KEINE Tabellen-Policies -> direkter Zugriff gesperrt; nur die DEFINER-RPCs unten.
ALTER TABLE public.alben        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.album_medien ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------ 2) Storage-Bucket + Policies
INSERT INTO storage.buckets (id, name, public)
VALUES ('alben', 'alben', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Erstes Pfad-Segment (verbund_id als Text) -> „gehört der Aufrufer zu diesem Verbund?"
CREATE OR REPLACE FUNCTION public.darf_albenordner(p_verbund_text text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v uuid;
BEGIN
  BEGIN v := p_verbund_text::uuid; EXCEPTION WHEN others THEN RETURN false; END;
  RETURN public.ist_in_verbund(v);
END $$;

CREATE OR REPLACE FUNCTION public.darf_albenordner_moderieren(p_verbund_text text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v uuid;
BEGIN
  BEGIN v := p_verbund_text::uuid; EXCEPTION WHEN others THEN RETURN false; END;
  RETURN public.darf_verbund_moderieren(v);
END $$;

DROP POLICY IF EXISTS "alben_select" ON storage.objects;
DROP POLICY IF EXISTS "alben_insert" ON storage.objects;
DROP POLICY IF EXISTS "alben_delete" ON storage.objects;

-- SELECT/list/signieren: Verbund-Mitglieder (erstes Pfad-Segment = verbund_id)
CREATE POLICY "alben_select" ON storage.objects
  FOR SELECT TO authenticated
  USING ( bucket_id = 'alben'
          AND public.darf_albenordner((storage.foldername(name))[1]) );

-- INSERT: jedes Verbund-Mitglied darf beisteuern (die RPC album_medium_anlegen prüft zusätzlich).
CREATE POLICY "alben_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK ( bucket_id = 'alben'
               AND public.darf_albenordner((storage.foldername(name))[1]) );

-- DELETE: jedes Verbund-Mitglied (erstes Pfad-Segment = verbund_id). BEWUSST mitgliedschafts-
-- basiert (wie INSERT/SELECT), NICHT nur owner+Moderator: Album-weites Löschen erlaubt die RPC
-- album_loeschen dem ALBUM-ERSTELLER (ggf. einfaches Mitglied, kein Moderator); dessen Frontend-
-- Storage-Sweep muss auch FREMDE Uploads im Album abräumen können, sonst verwaiste Bucket-Dateien
-- (CLAUDE.md: keine verwaisten Nicht-DB-Stores). Alben sind ohnehin voll kollaborativ (jedes Mitglied
-- darf hochladen/lesen), daher konsistent. Per-Datei-UI-Recht (Uploader/Moderator) bleibt in der RPC
-- album_medium_loeschen erhalten; die Storage-Policy ist die verbund-interne Vertrauensgrenze.
CREATE POLICY "alben_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING ( bucket_id = 'alben'
          AND public.darf_albenordner((storage.foldername(name))[1]) );

-- ------------------------------------------------------------------ 3) RPCs
-- 3a) Album anlegen (jedes Verbund-Mitglied). Verbund aus mein_verbund().
CREATE OR REPLACE FUNCTION public.album_erstellen(p_titel text, p_beschreibung text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_verb uuid; v_id uuid; v_t text := btrim(coalesce(p_titel,''));
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF v_t = '' THEN RETURN jsonb_build_object('ok', false, 'grund', 'titel_leer'); END IF;
  v_verb := public.mein_verbund();
  IF v_verb IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'kein_verbund'); END IF;
  INSERT INTO public.alben (verbund_id, titel, beschreibung, erstellt_von)
  VALUES (v_verb, v_t, nullif(btrim(coalesce(p_beschreibung,'')), ''), v_me)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'verbund_id', v_verb);
END $$;
GRANT EXECUTE ON FUNCTION public.album_erstellen(text, text) TO authenticated;

-- 3b) Album bearbeiten (Ersteller ODER Moderator).
CREATE OR REPLACE FUNCTION public.album_bearbeiten(p_id uuid, p_titel text, p_beschreibung text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_verb uuid; v_von uuid; v_t text := btrim(coalesce(p_titel,''));
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  SELECT verbund_id, erstellt_von INTO v_verb, v_von FROM public.alben WHERE id = p_id;
  IF v_verb IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF v_von IS DISTINCT FROM v_me AND NOT public.darf_verbund_moderieren(v_verb) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  IF v_t = '' THEN RETURN jsonb_build_object('ok', false, 'grund', 'titel_leer'); END IF;
  UPDATE public.alben SET titel = v_t, beschreibung = nullif(btrim(coalesce(p_beschreibung,'')), '')
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.album_bearbeiten(uuid, text, text) TO authenticated;

-- 3c) Album löschen (Ersteller ODER Moderator). Gibt alle Storage-Pfade zurück -> Frontend räumt Bucket.
CREATE OR REPLACE FUNCTION public.album_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_verb uuid; v_von uuid; v_pfade jsonb;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  SELECT verbund_id, erstellt_von INTO v_verb, v_von FROM public.alben WHERE id = p_id;
  IF v_verb IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF v_von IS DISTINCT FROM v_me AND NOT public.darf_verbund_moderieren(v_verb) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  SELECT coalesce(jsonb_agg(storage_pfad), '[]'::jsonb) INTO v_pfade
    FROM public.album_medien WHERE album_id = p_id;
  DELETE FROM public.alben WHERE id = p_id;   -- album_medien per CASCADE
  RETURN jsonb_build_object('ok', true, 'pfade', v_pfade);
END $$;
GRANT EXECUTE ON FUNCTION public.album_loeschen(uuid) TO authenticated;

-- 3d) Alben des Verbunds holen (Liste + Cover + Medienzahl).
CREATE OR REPLACE FUNCTION public.alben_holen()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_list jsonb;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', al.id,
           'verbund_id', al.verbund_id,
           'titel', al.titel,
           'beschreibung', al.beschreibung,
           'erstellt_am', al.erstellt_am,
           'erstellt_von', al.erstellt_von,
           'ersteller', COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''),
                                 initcap(replace(replace(replace(split_part(u.email,'@',1),'.',' '),'_',' '),'-',' ')),
                                 u.email),
           'anzahl', (SELECT count(*) FROM public.album_medien m WHERE m.album_id = al.id),
           'cover_pfad', COALESCE(al.cover_pfad,
                          (SELECT m.storage_pfad FROM public.album_medien m
                            WHERE m.album_id = al.id
                            ORDER BY (m.mime LIKE 'image/%') DESC, m.erstellt_am DESC LIMIT 1)),
           'darf_aendern', (al.erstellt_von = v_me OR public.darf_verbund_moderieren(al.verbund_id))
         ) ORDER BY al.erstellt_am DESC), '[]'::jsonb)
    INTO v_list
    FROM public.alben al
    LEFT JOIN auth.users u      ON u.id = al.erstellt_von
    LEFT JOIN public.profile pr ON pr.user_id = al.erstellt_von
   WHERE public.ist_in_verbund(al.verbund_id);
  RETURN jsonb_build_object('ok', true, 'alben', v_list);
END $$;
GRANT EXECUTE ON FUNCTION public.alben_holen() TO authenticated;

-- 3e) Medien eines Albums holen (Verbund-Mitglieder). Pfade signiert das Frontend.
CREATE OR REPLACE FUNCTION public.album_medien_holen(p_album uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_verb uuid; v_list jsonb;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  SELECT verbund_id INTO v_verb FROM public.alben WHERE id = p_album;
  IF v_verb IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF NOT public.ist_in_verbund(v_verb) THEN RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung'); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', m.id,
           'pfad', m.storage_pfad,
           'mime', m.mime,
           'beschriftung', m.beschriftung,
           'erstellt_am', m.erstellt_am,
           'hochgeladen_von', m.hochgeladen_von,
           'uploader', COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''),
                                initcap(replace(replace(replace(split_part(u.email,'@',1),'.',' '),'_',' '),'-',' ')),
                                u.email),
           'darf_loeschen', (m.hochgeladen_von = v_me OR public.darf_verbund_moderieren(m.verbund_id))
         ) ORDER BY m.sortierung, m.erstellt_am), '[]'::jsonb)
    INTO v_list
    FROM public.album_medien m
    LEFT JOIN auth.users u      ON u.id = m.hochgeladen_von
    LEFT JOIN public.profile pr ON pr.user_id = m.hochgeladen_von
   WHERE m.album_id = p_album;
  RETURN jsonb_build_object('ok', true, 'medien', v_list, 'verbund_id', v_verb, 'darf_hochladen', true);
END $$;
GRANT EXECUTE ON FUNCTION public.album_medien_holen(uuid) TO authenticated;

-- 3f) Medium eintragen (nach Storage-Upload). Prüft Verbund-Mitgliedschaft + dass der Pfad zum
--     Album/Verbund gehört (erstes Segment = verbund_id, zweites = album_id).
CREATE OR REPLACE FUNCTION public.album_medium_anlegen(
  p_album uuid, p_pfad text, p_mime text DEFAULT NULL, p_beschriftung text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_verb uuid; v_neu uuid;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF p_pfad IS NULL OR btrim(p_pfad) = '' THEN RETURN jsonb_build_object('ok', false, 'grund', 'leer'); END IF;
  SELECT verbund_id INTO v_verb FROM public.alben WHERE id = p_album;
  IF v_verb IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF NOT public.ist_in_verbund(v_verb) THEN RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung'); END IF;
  IF p_pfad NOT LIKE v_verb::text || '/' || p_album::text || '/%' THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'pfad_ungueltig');
  END IF;
  INSERT INTO public.album_medien (album_id, verbund_id, storage_pfad, mime, beschriftung, hochgeladen_von)
  VALUES (p_album, v_verb, p_pfad, nullif(btrim(coalesce(p_mime,'')), ''),
          nullif(btrim(coalesce(p_beschriftung,'')), ''), v_me)
  RETURNING id INTO v_neu;
  RETURN jsonb_build_object('ok', true, 'id', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.album_medium_anlegen(uuid, text, text, text) TO authenticated;

-- 3g) Medium löschen (Uploader ODER Moderator). Gibt storage_pfad zurück -> Frontend räumt Bucket.
CREATE OR REPLACE FUNCTION public.album_medium_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_verb uuid; v_von uuid; v_pfad text;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  SELECT verbund_id, hochgeladen_von, storage_pfad INTO v_verb, v_von, v_pfad
    FROM public.album_medien WHERE id = p_id;
  IF v_pfad IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF v_von IS DISTINCT FROM v_me AND NOT public.darf_verbund_moderieren(v_verb) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  DELETE FROM public.album_medien WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'pfad', v_pfad);
END $$;
GRANT EXECUTE ON FUNCTION public.album_medium_loeschen(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_alben.sql ausgeführt — alben + album_medien (verbund-RLS via RPCs) + Bucket alben (privat) + Storage-Policies + RPCs (erstellen/bearbeiten/loeschen/holen/medien_holen/medium_anlegen/medium_loeschen)' AS status;
