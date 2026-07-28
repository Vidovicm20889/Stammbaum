-- =====================================================
-- FAMILIEN-FEED / BEITRÄGE — verbund-gebundene Pinnwand (Social-Schicht, Prompt 2)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_reaktionen_kommentare.sql ausführen (ergänzt _ziel_verbund um
-- den 'beitrag'-Zweig -> Beiträge tragen sofort Reaktionen/Kommentare).
--
-- KONZEPT: Mitglieder eines Verbunds posten Text (+ optionales Foto, + optionale Personen-
-- Markierung) in den Familien-Feed. STRIKT VERBUND-GEBUNDEN (CLAUDE.md Social-Regel): ein
-- Beitrag gehört zu genau EINEM verbund_id; sichtbar nur für dessen Mitglieder (KEIN
-- baum_freigaben-Pfad). Reaktionen/Kommentare laufen über das bestehende Engagement-System
-- (ziel_typ='beitrag').
--
-- SICHERHEIT:
--   * SELECT: nur ist_in_verbund(verbund_id) (echte RLS-Policy -> Realtime liefert aus).
--   * Schreiben ausschließlich über SECURITY-DEFINER-RPCs (verbund_id serverseitig aus der
--     Mitgliedschaft abgeleitet -> nicht fälschbar). Bearbeiten/Löschen nur Autor;
--     Moderation (löschen, soft) zusätzlich owner/admin im Verbund + super_admin.
--
-- Voraussetzungen: supabase_verbund.sql, supabase_reaktionen_kommentare.sql (ist_in_verbund,
--   darf_verbund_moderieren, _ziel_verbund), supabase_profile.sql, supabase_multitree_phase5.sql.
-- =====================================================


-- =====================================================
-- 1) TABELLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.beitraege (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id    uuid NOT NULL,
  autor         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  text          text,
  bild_pfad     text,                                   -- Storage-Pfad im Bucket 'beitraege'
  bild_url      text,                                   -- öffentliche URL (public Bucket)
  ref_person    uuid REFERENCES public.personen(id) ON DELETE SET NULL,   -- optionale Markierung
  erstellt_am   timestamptz NOT NULL DEFAULT now(),
  bearbeitet_am timestamptz,
  geloescht     boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS beitraege_verbund_zeit_idx ON public.beitraege (verbund_id, erstellt_am DESC);

ALTER TABLE public.beitraege ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "beitraege_select" ON public.beitraege;
CREATE POLICY "beitraege_select" ON public.beitraege FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );
-- (KEINE INSERT/UPDATE/DELETE-Policies -> nur die RPCs unten schreiben.)


-- =====================================================
-- 2) _ziel_verbund um 'beitrag' erweitern (überschreibt die Version aus dem Engagement-File;
--    alle bisherigen Zweige bleiben erhalten) -> Reaktionen/Kommentare an Beiträgen möglich.
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
  ELSE
    v := NULL;
  END IF;
  RETURN v;
END $$;


-- =====================================================
-- 3) HELFER: einen Verbund des Aufrufers bestimmen (für neue Beiträge).
--    v1-Grenze: bei mehreren Verbünden wird der kleinste deterministisch gewählt
--    (Verbünde verschmelzen ohnehin bei Heirat -> i. d. R. genau einer je Nutzer).
-- =====================================================
CREATE OR REPLACE FUNCTION public.mein_verbund()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT f.verbund_id
    FROM public.mitgliedschaften m
    JOIN public.familien f ON f.id = m.familie_id
   WHERE m.user_id = auth.uid()
   ORDER BY f.verbund_id
   LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.mein_verbund() TO authenticated;


-- =====================================================
-- 4) RPCs
-- =====================================================

-- 4a) Beitrag erstellen (Text und/oder Bild; optionale Personen-Markierung).
CREATE OR REPLACE FUNCTION public.beitrag_erstellen(
  p_text text, p_bild_pfad text DEFAULT NULL, p_bild_url text DEFAULT NULL,
  p_ref_person uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_ref  uuid := NULL;
  v_neu  uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  IF (p_text IS NULL OR btrim(p_text) = '') AND (p_bild_url IS NULL OR btrim(p_bild_url) = '') THEN
    RAISE EXCEPTION 'leer';
  END IF;
  v_verb := public.mein_verbund();
  IF v_verb IS NULL THEN RAISE EXCEPTION 'kein_verbund'; END IF;

  -- Markierung nur übernehmen, wenn die Person im EIGENEN Verbund sichtbar ist.
  IF p_ref_person IS NOT NULL AND public.ist_in_verbund(public._ziel_verbund('person', p_ref_person)) THEN
    v_ref := p_ref_person;
  END IF;

  INSERT INTO public.beitraege (verbund_id, autor, text, bild_pfad, bild_url, ref_person)
  VALUES (v_verb, v_me, nullif(btrim(coalesce(p_text,'')), ''), p_bild_pfad, p_bild_url, v_ref)
  RETURNING id INTO v_neu;

  RETURN jsonb_build_object('ok', true, 'id', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.beitrag_erstellen(text, text, text, uuid) TO authenticated;


-- 4b) Eigenen Beitrag bearbeiten (nur Text).
CREATE OR REPLACE FUNCTION public.beitrag_bearbeiten(p_id uuid, p_text text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  SELECT autor INTO v_owner FROM public.beitraege WHERE id = p_id AND geloescht = false;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF v_owner <> auth.uid() THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;
  UPDATE public.beitraege SET text = nullif(btrim(coalesce(p_text,'')), ''), bearbeitet_am = now()
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.beitrag_bearbeiten(uuid, text) TO authenticated;


-- 4c) Beitrag löschen (soft): Autor ODER Moderator. Gibt den Storage-Pfad zurück, damit das
--     Frontend das Bild aus dem Bucket räumen kann (kein Storage-Delete aus Postgres).
CREATE OR REPLACE FUNCTION public.beitrag_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid; v_verb uuid; v_pfad text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  SELECT autor, verbund_id, bild_pfad INTO v_owner, v_verb, v_pfad FROM public.beitraege WHERE id = p_id;
  IF v_verb IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF v_owner IS DISTINCT FROM auth.uid() AND NOT public.darf_verbund_moderieren(v_verb) THEN
    RAISE EXCEPTION 'keine_berechtigung';
  END IF;
  UPDATE public.beitraege SET geloescht = true, text = NULL, bild_pfad = NULL, bild_url = NULL WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'bild_pfad', v_pfad);
END $$;
GRANT EXECUTE ON FUNCTION public.beitrag_loeschen(uuid) TO authenticated;


-- 4d) (ERSETZT) Das frühere einfache feed_holen (nur Beiträge) ist durch den ALLGEMEINEN
--     Aktivitäten-Stream ersetzt: supabase_aktivitaeten.sql -> aktivitaeten_holen(p_limit, p_vor)
--     liefert ALLE Feed-Typen (beitrag_neu/foto_neu/geschichte_neu/event_neu/person_neu); der
--     beitrag_neu-Eintrag trägt die vollen Beitragsfelder, die das Frontend für die Beitragskarte
--     braucht. Das Frontend (feedLaden) ruft NUR noch aktivitaeten_holen auf. Die alte Funktion
--     wird daher entfernt, damit sie nicht versehentlich weiterverwendet wird.
DROP FUNCTION IF EXISTS public.feed_holen(int, timestamptz);


-- =====================================================
-- 5) STORAGE-BUCKET 'beitraege' (public-read wie avatars/personen-fotos)
--    Pfadschema: <user_id>/<uuid>  -> Schreiben nur im eigenen Ordner.
-- =====================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('beitraege', 'beitraege', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "beitraege_obj_select" ON storage.objects;
DROP POLICY IF EXISTS "beitraege_obj_insert" ON storage.objects;
DROP POLICY IF EXISTS "beitraege_obj_update" ON storage.objects;
DROP POLICY IF EXISTS "beitraege_obj_delete" ON storage.objects;

CREATE POLICY "beitraege_obj_select" ON storage.objects FOR SELECT TO authenticated
  USING ( bucket_id = 'beitraege' );
CREATE POLICY "beitraege_obj_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK ( bucket_id = 'beitraege' AND (storage.foldername(name))[1] = auth.uid()::text );
CREATE POLICY "beitraege_obj_update" ON storage.objects FOR UPDATE TO authenticated
  USING ( bucket_id = 'beitraege' AND (storage.foldername(name))[1] = auth.uid()::text )
  WITH CHECK ( bucket_id = 'beitraege' AND (storage.foldername(name))[1] = auth.uid()::text );
CREATE POLICY "beitraege_obj_delete" ON storage.objects FOR DELETE TO authenticated
  USING ( bucket_id = 'beitraege' AND (storage.foldername(name))[1] = auth.uid()::text );


-- =====================================================
-- 6) REALTIME-PUBLICATION (neue Beiträge live)
-- =====================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'beitraege'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.beitraege;
  END IF;
END $$;
ALTER TABLE public.beitraege REPLICA IDENTITY FULL;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_beitraege.sql ausgeführt — beitraege (verbund-RLS) + RPCs + _ziel_verbund(beitrag) + Bucket + Realtime; feed_holen entfernt (-> aktivitaeten_holen)' AS status;
