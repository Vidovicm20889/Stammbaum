-- =====================================================
-- GEMEINSAME EVENT-ALBEN (Feature E) — Fotos je Event, von allen Teilnehmern beigesteuert
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run). IDEMPOTENT.
-- NACH supabase_events.sql, supabase_event_eingeladene(_user).sql (darf_event_sehen),
--   supabase_reaktionen_kommentare.sql (Engagement-CHECK/_ziel_verbund/ist_in_verbund),
--   supabase_familien_fragen.sql (letzte _ziel_verbund-Fassung + 'frage' im CHECK) ausführen.
--
-- KONZEPT: EIN Album je Event. Jede Zeile = EIN Foto (Metadaten in der Tabelle, Binärdaten im
-- eigenen Storage-Bucket 'event-album', Pfad {stammbaum_id}/{event_id}/{uuid}). Baut bewusst auf
-- dem vorhandenen Event-/Foto-/Storage-Muster auf (kein zweites Medien-System):
--   * Tabelle wie personen_fotos (verbund-RLS), aber an EVENT statt Person gehängt.
--   * Storage-Policies wie personen-fotos (erstes Pfad-Segment = stammbaum_id steuert Schreibrecht).
--
-- RECHTE (CLAUDE.md / Prompt):
--   * Ansehen: Verbund-Mitglieder, die das EVENT sehen dürfen (darf_event_sehen) — respektiert
--     eingeschränkt sichtbare Events.
--   * Hochladen: wer das Event sehen darf (= „Teilnehmer" im Sinne des Zugriffs; für offene Events
--     alle Verbund-Mitglieder, für eingeschränkte nur Eingeladene + Admins). Bewusste Auslegung,
--     da es für offene Events keine separate harte „Teilnehmer"-Liste gibt.
--   * Löschen: nur der Uploader ODER kann_familie_bearbeiten (Owner/Admin/Super-Admin).
--
-- DATENKONSISTENZ: Tabellenzeilen hängen per ON DELETE CASCADE am Event (Event weg -> Zeilen weg).
--   Die STORAGE-Dateien fallen NICHT per CASCADE -> das Frontend räumt sie beim Event-Löschen
--   (loescheAlbumMedien) bzw. über die verwaiste_event_medien-Queue (raeumeVerwaisteMedien) mit ab.
--
-- OPTIONAL (umgesetzt): Reaktionen/Kommentare je Album-Foto über das bestehende Engagement-System
--   (neuer ziel_typ 'album_foto').
-- =====================================================


-- =====================================================
-- 0) ziel_typ 'album_foto' freischalten (Engagement-CHECKs + _ziel_verbund erweitern)
--    Vollständige Liste (alle bisherigen Typen bleiben erhalten).
-- =====================================================
ALTER TABLE public.reaktionen DROP CONSTRAINT IF EXISTS reaktionen_ziel_typ_check;
ALTER TABLE public.reaktionen ADD  CONSTRAINT reaktionen_ziel_typ_check
  CHECK (ziel_typ IN ('foto','geschichte','beitrag','person','event','frage','album_foto'));

ALTER TABLE public.kommentare DROP CONSTRAINT IF EXISTS kommentare_ziel_typ_check;
ALTER TABLE public.kommentare ADD  CONSTRAINT kommentare_ziel_typ_check
  CHECK (ziel_typ IN ('foto','geschichte','beitrag','person','event','frage','album_foto'));


-- =====================================================
-- 1) TABELLE (eine Zeile je Album-Foto)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.event_album_fotos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id        uuid NOT NULL REFERENCES public.events(id)       ON DELETE CASCADE,
  stammbaum_id    uuid NOT NULL REFERENCES public.stammbaeume(id)  ON DELETE CASCADE,
  familie_id      uuid NOT NULL REFERENCES public.familien(id),
  verbund_id      uuid NOT NULL,                       -- denormalisiert -> einfache, rekursionsfreie RLS
  storage_pfad    text NOT NULL,                       -- Pfad im Bucket 'event-album'
  beschriftung    text,
  hochgeladen_von uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  erstellt_am     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS event_album_fotos_event_idx   ON public.event_album_fotos (event_id, erstellt_am);
CREATE INDEX IF NOT EXISTS event_album_fotos_verbund_idx ON public.event_album_fotos (verbund_id);

-- Erweiterung (Übernahme des alten „Medien"-Abschnitts ins Album, ab v14.x):
--   bucket  = Storage-Bucket der Datei ('event-album' für neue, 'events' für übernommene Altmedien)
--   mime    = MIME-Typ (Bild/Video/PDF) -> Frontend rendert typgerecht
--   quelle  = ursprünglicher Pfad im 'events'-Bucket (Idempotenz: keine doppelte Übernahme)
-- Übernahme erfolgt PER REFERENZ (kein Byte-Kopieren/Löschen) -> Altmedien können nicht verloren gehen.
ALTER TABLE public.event_album_fotos ADD COLUMN IF NOT EXISTS bucket text NOT NULL DEFAULT 'event-album';
ALTER TABLE public.event_album_fotos ADD COLUMN IF NOT EXISTS mime   text;
ALTER TABLE public.event_album_fotos ADD COLUMN IF NOT EXISTS quelle text;
CREATE UNIQUE INDEX IF NOT EXISTS event_album_fotos_quelle_uidx
  ON public.event_album_fotos (event_id, quelle) WHERE quelle IS NOT NULL;

ALTER TABLE public.event_album_fotos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "event_album_select" ON public.event_album_fotos;
CREATE POLICY "event_album_select" ON public.event_album_fotos FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );
-- (KEINE INSERT/UPDATE/DELETE-Policies -> nur die SECURITY-DEFINER-RPCs unten schreiben.
--  Die feinere „darf das Event sehen?"-Prüfung leistet die Lese-RPC event_album_holen.)


-- =====================================================
-- 2) _ziel_verbund um 'album_foto' erweitern (alle bisherigen Zweige bleiben)
-- =====================================================
CREATE OR REPLACE FUNCTION public._ziel_verbund(p_typ text, p_ziel uuid)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v uuid;
BEGIN
  IF p_ziel IS NULL THEN RETURN NULL; END IF;
  IF p_typ = 'person' THEN
    SELECT f.verbund_id INTO v FROM public.personen p
      JOIN public.familien f ON f.id = p.familie_id WHERE p.id = p_ziel AND p.geloescht_am IS NULL;
  ELSIF p_typ = 'foto' THEN
    SELECT f.verbund_id INTO v FROM public.personen_fotos x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSIF p_typ = 'geschichte' THEN
    SELECT f.verbund_id INTO v FROM public.personen_geschichten x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSIF p_typ = 'event' THEN
    SELECT f.verbund_id INTO v FROM public.events x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSIF p_typ = 'beitrag' THEN
    SELECT b.verbund_id INTO v FROM public.beitraege b WHERE b.id = p_ziel;
  ELSIF p_typ = 'frage' THEN
    SELECT fr.verbund_id INTO v FROM public.familien_fragen fr WHERE fr.id = p_ziel;
  ELSIF p_typ = 'album_foto' THEN
    SELECT a.verbund_id INTO v FROM public.event_album_fotos a WHERE a.id = p_ziel;
  ELSE
    v := NULL;
  END IF;
  RETURN v;
END $$;


-- =====================================================
-- 3) STORAGE-BUCKET 'event-album' (PRIVAT — signierte URLs, wie 'events'/'personen-dokumente';
--    Event-Fotos können lebende Personen/Minderjährige zeigen -> bleiben verbund-intern)
-- =====================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('event-album', 'event-album', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Helfer: erstes Pfad-Segment (stammbaum_id als Text) -> Verbund-Sicht / Bearbeitungsrecht.
CREATE OR REPLACE FUNCTION public.darf_albumordner_sehen(p_stammbaum_text text)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.stammbaeume s
    WHERE s.id::text = p_stammbaum_text AND public.sieht_familie(s.familie_id)
  );
$$;
CREATE OR REPLACE FUNCTION public.darf_albumordner_bearbeiten(p_stammbaum_text text)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.stammbaeume s
    WHERE s.id::text = p_stammbaum_text AND public.kann_familie_bearbeiten(s.familie_id)
  );
$$;

DROP POLICY IF EXISTS "ealbum_select" ON storage.objects;
DROP POLICY IF EXISTS "ealbum_insert" ON storage.objects;
DROP POLICY IF EXISTS "ealbum_delete" ON storage.objects;

-- SELECT/list/signieren: Verbund-Mitglieder, die den Baum sehen (erstes Pfad-Segment).
CREATE POLICY "ealbum_select" ON storage.objects
  FOR SELECT TO authenticated
  USING ( bucket_id = 'event-album'
          AND public.darf_albumordner_sehen((storage.foldername(name))[1]) );

-- INSERT: jedes Verbund-Mitglied, das den Baum sehen darf, kann ein Foto beisteuern.
-- (Die exakte „darf dieses Event sehen?"-Prüfung leistet zusätzlich die RPC event_album_foto_anlegen,
--  bevor die Tabellenzeile entsteht; eine Datei ohne Zeile ist eine räumbare Waise.)
CREATE POLICY "ealbum_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK ( bucket_id = 'event-album'
               AND public.darf_albumordner_sehen((storage.foldername(name))[1]) );

-- DELETE: der Uploader (storage.objects.owner = auth.uid()) ODER ein Bearbeiter der Familie.
CREATE POLICY "ealbum_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING ( bucket_id = 'event-album'
          AND ( owner = auth.uid()
                OR public.darf_albumordner_bearbeiten((storage.foldername(name))[1]) ) );


-- =====================================================
-- 4) RPCs (SECURITY DEFINER, geben nur erlaubte Daten zurück)
-- =====================================================

-- 4a) Album eines Events laden (nur wer das Event sehen darf). Liefert je Foto Uploader-Name/Avatar
--     + darf_loeschen-Flag. Pfade signiert das Frontend (createSignedUrls).
CREATE OR REPLACE FUNCTION public.event_album_holen(p_event uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_fam  uuid;
  v_list jsonb;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF NOT public.darf_event_sehen(p_event) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', a.id,
           'pfad', a.storage_pfad,
           'bucket', a.bucket,
           'mime', a.mime,
           'quelle', a.quelle,
           'beschriftung', a.beschriftung,
           'erstellt_am', a.erstellt_am,
           'hochgeladen_von', a.hochgeladen_von,
           'uploader', COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''),
                                initcap(replace(replace(replace(split_part(u.email,'@',1),'.',' '),'_',' '),'-',' ')),
                                u.email),
           'uploader_avatar', CASE WHEN COALESCE(pr.avatar_sichtbarkeit,'verbund') <> 'privat'
                                   THEN COALESCE(pr.avatar_thumb_url, pr.avatar_url) END,
           'darf_loeschen', (a.hochgeladen_von = v_me OR public.kann_familie_bearbeiten(a.familie_id))
         ) ORDER BY a.erstellt_am), '[]'::jsonb)
    INTO v_list
    FROM public.event_album_fotos a
    LEFT JOIN auth.users u      ON u.id = a.hochgeladen_von
    LEFT JOIN public.profile pr ON pr.user_id = a.hochgeladen_von
   WHERE a.event_id = p_event;

  RETURN jsonb_build_object('ok', true, 'fotos', v_list,
                            'darf_hochladen', true);   -- darf_event_sehen bereits bestanden
END $$;
GRANT EXECUTE ON FUNCTION public.event_album_holen(uuid) TO authenticated;

-- 4b) Album-Foto eintragen (nach erfolgreichem Storage-Upload). Prüft darf_event_sehen + dass der
--     Pfad zum Event/Baum gehört; leitet verbund/familie/stammbaum aus dem Event ab.
CREATE OR REPLACE FUNCTION public.event_album_foto_anlegen(
  p_event uuid, p_pfad text, p_beschriftung text DEFAULT NULL, p_mime text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_tree uuid; v_fam uuid; v_verb uuid;
  v_neu  uuid;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF p_pfad IS NULL OR btrim(p_pfad) = '' THEN RETURN jsonb_build_object('ok', false, 'grund', 'leer'); END IF;
  IF NOT public.darf_event_sehen(p_event) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  SELECT e.stammbaum_id, e.familie_id, f.verbund_id
    INTO v_tree, v_fam, v_verb
    FROM public.events e JOIN public.familien f ON f.id = e.familie_id
   WHERE e.id = p_event;
  IF v_tree IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;

  -- Pfad muss zum Baum+Event gehören (verhindert Einschleusen in fremde Ordner).
  IF p_pfad NOT LIKE v_tree::text || '/' || p_event::text || '/%' THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'pfad_ungueltig');
  END IF;

  INSERT INTO public.event_album_fotos
    (event_id, stammbaum_id, familie_id, verbund_id, storage_pfad, bucket, mime, beschriftung, hochgeladen_von)
  VALUES (p_event, v_tree, v_fam, v_verb, p_pfad, 'event-album',
          nullif(btrim(coalesce(p_mime,'')), ''), nullif(btrim(coalesce(p_beschriftung,'')), ''), v_me)
  RETURNING id INTO v_neu;

  RETURN jsonb_build_object('ok', true, 'id', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.event_album_foto_anlegen(uuid, text, text, text) TO authenticated;

-- 4b2) Bestehende „Medien" (events-Bucket) PER REFERENZ ins Album übernehmen (idempotent).
--      Legt je Altdatei eine Album-Zeile an, die auf die VORHANDENE Datei im 'events'-Bucket zeigt
--      (bucket='events', quelle=Originalpfad). KEIN Kopieren/Löschen -> kein Datenverlust.
--      p_dateien = jsonb-Array [{ "pfad": "<event_id>/<datei>", "mime": "image/..." }, ...].
CREATE OR REPLACE FUNCTION public.event_album_legacy_uebernehmen(p_event uuid, p_dateien jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_tree uuid; v_fam uuid; v_verb uuid;
  v_d    jsonb;
  v_pfad text;
  v_anz  int := 0;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF NOT public.darf_event_sehen(p_event) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  SELECT e.stammbaum_id, e.familie_id, f.verbund_id INTO v_tree, v_fam, v_verb
    FROM public.events e JOIN public.familien f ON f.id = e.familie_id WHERE e.id = p_event;
  IF v_tree IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;

  FOR v_d IN SELECT value FROM jsonb_array_elements(coalesce(p_dateien, '[]'::jsonb)) LOOP
    v_pfad := btrim(coalesce(v_d->>'pfad',''));
    CONTINUE WHEN v_pfad = '';
    -- Pfad muss zum Event gehören (erstes Segment = event_id).
    CONTINUE WHEN v_pfad NOT LIKE p_event::text || '/%';
    INSERT INTO public.event_album_fotos
      (event_id, stammbaum_id, familie_id, verbund_id, storage_pfad, bucket, mime, quelle, hochgeladen_von)
    VALUES (p_event, v_tree, v_fam, v_verb, v_pfad, 'events',
            nullif(btrim(coalesce(v_d->>'mime','')), ''), v_pfad, NULL)
    ON CONFLICT (event_id, quelle) WHERE quelle IS NOT NULL DO NOTHING;
    IF FOUND THEN v_anz := v_anz + 1; END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'uebernommen', v_anz);
END $$;
GRANT EXECUTE ON FUNCTION public.event_album_legacy_uebernehmen(uuid, jsonb) TO authenticated;

-- 4c) Album-Foto löschen (Uploader ODER Bearbeiter). Gibt storage_pfad zurück -> Frontend räumt Storage.
CREATE OR REPLACE FUNCTION public.event_album_foto_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_owner uuid; v_fam uuid; v_pfad text; v_bucket text;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  SELECT hochgeladen_von, familie_id, storage_pfad, bucket INTO v_owner, v_fam, v_pfad, v_bucket
    FROM public.event_album_fotos WHERE id = p_id;
  IF v_pfad IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF v_owner IS DISTINCT FROM v_me AND NOT public.kann_familie_bearbeiten(v_fam) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  DELETE FROM public.event_album_fotos WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'pfad', v_pfad, 'bucket', coalesce(v_bucket, 'event-album'));
END $$;
GRANT EXECUTE ON FUNCTION public.event_album_foto_loeschen(uuid) TO authenticated;

-- 4d) Übersicht (Cover + Anzahl) für die Event-Liste/-Karten. Nur Events, die der Aufrufer sehen darf.
--     Cover = neuestes Foto je Event.
CREATE OR REPLACE FUNCTION public.event_album_uebersicht(p_event_ids uuid[])
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'event_id', s.e, 'anzahl', s.n, 'cover_pfad', s.cover, 'cover_bucket', s.cover_bucket)), '[]'::jsonb)
  FROM (
    SELECT a.event_id AS e, count(*) AS n,
           -- Cover = neuestes BILD (sonst neuestes beliebiges Medium).
           (array_agg(a.storage_pfad ORDER BY (a.mime LIKE 'image/%') DESC, a.erstellt_am DESC))[1] AS cover,
           (array_agg(a.bucket       ORDER BY (a.mime LIKE 'image/%') DESC, a.erstellt_am DESC))[1] AS cover_bucket
    FROM public.event_album_fotos a
    WHERE a.event_id = ANY(p_event_ids) AND public.darf_event_sehen(a.event_id)
    GROUP BY a.event_id
  ) s;
$$;
GRANT EXECUTE ON FUNCTION public.event_album_uebersicht(uuid[]) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_event_album.sql ausgeführt — event_album_fotos (verbund-RLS) + Bucket event-album + Storage-Policies + RPCs (holen/anlegen/loeschen/uebersicht) + ziel_typ album_foto' AS status;
