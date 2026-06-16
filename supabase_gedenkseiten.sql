-- =====================================================
-- GEDENKSEITEN mit KONDOLENZ-/ERINNERUNGSBUCH (Social-Schicht, Prompt B)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_reaktionen_kommentare.sql ausführen (nutzt die dortigen
-- rekursionsfreien Helfer ist_in_verbund / darf_verbund_moderieren / _ziel_verbund).
--
-- KONZEPT: Für verstorbene Personen gibt es eine würdevolle Gedenkseite mit einem
-- Kondolenz-/Erinnerungsbuch. Verbund-Mitglieder hinterlassen eine Erinnerung/Kondolenz
-- (Text + optional EIN Foto) oder zünden eine Kerze an (dezente Geste statt bunter Emojis).
--
-- STRIKT VERBUND-GEBUNDEN (CLAUDE.md Social-/Kinderschutz-Regel): Einträge sind NIE
-- verbundübergreifend sichtbar (KEIN baum_freigaben-Pfad). Der verbund_id wird denormalisiert
-- mitgeführt -> einfache, rekursionsfreie RLS (kein polymorpher Join in der Policy).
--
-- SICHERHEIT:
--   * SELECT: nur Mitglieder des verbund_id (Helfer ist_in_verbund).
--   * Schreiben ausschließlich über SECURITY-DEFINER-RPCs (kein direktes INSERT/UPDATE/DELETE):
--     verbund_id wird serverseitig aus der Person abgeleitet (_ziel_verbund) -> nicht fälschbar.
--   * Eintrag bearbeiten: nur Autor. Löschen (soft, geloescht=true): Autor ODER Moderator
--     (familien_owner/familien_admin im Verbund + super_admin via darf_verbund_moderieren).
--   * Kerze: 1 je Nutzer je Person (Toggle = hartes Insert/Delete, kein Inhalt zu bewahren).
--
-- TRANSPORT: bewusst KEIN Realtime (wie Galerie/Dokumente/Geschichten) — die Gedenkseite
--   lädt frisch beim Öffnen. Würdevoll-ruhig, kein Live-Ticker.
--
-- Voraussetzungen: supabase_verbund.sql (mitgliedschaften/familien/verbund_id, ist_super_admin),
--   supabase_profile.sql (profile), supabase_multitree_phase5.sql (personen),
--   supabase_reaktionen_kommentare.sql (ist_in_verbund, darf_verbund_moderieren, _ziel_verbund).
-- =====================================================


-- =====================================================
-- 1) TABELLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.gedenk_eintraege (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id    uuid NOT NULL,
  person_id     uuid NOT NULL REFERENCES public.personen(id) ON DELETE CASCADE,
  autor_id      uuid REFERENCES auth.users(id) ON DELETE SET NULL,   -- Eintrag bleibt erhalten
  typ           text NOT NULL DEFAULT 'kondolenz' CHECK (typ IN ('kondolenz','kerze')),
  text          text,
  storage_pfad  text,                                   -- optionales Foto im Bucket 'gedenkseiten'
  erstellt_am   timestamptz NOT NULL DEFAULT now(),
  bearbeitet_am timestamptz,
  geloescht     boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS gedenk_person_zeit_idx ON public.gedenk_eintraege (person_id, erstellt_am);
CREATE INDEX IF NOT EXISTS gedenk_verbund_idx     ON public.gedenk_eintraege (verbund_id);

-- Genau EINE Kerze je Nutzer je Person (Toggle hält das aufrecht; harter Delete bei Aus).
CREATE UNIQUE INDEX IF NOT EXISTS gedenk_eine_kerze
  ON public.gedenk_eintraege (person_id, autor_id) WHERE typ = 'kerze';

ALTER TABLE public.gedenk_eintraege ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "gedenk_select" ON public.gedenk_eintraege;
CREATE POLICY "gedenk_select" ON public.gedenk_eintraege FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );
-- (KEINE INSERT/UPDATE/DELETE-Policies -> ausschließlich die SECURITY-DEFINER-RPCs schreiben.)


-- =====================================================
-- 2) RPCs
-- =====================================================

-- 2a) Kondolenz/Erinnerung schreiben (Text und/oder Foto). Verbund aus der Person abgeleitet.
CREATE OR REPLACE FUNCTION public.gedenk_eintrag_schreiben(
  p_person uuid, p_text text, p_storage_pfad text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_neu  uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  IF (p_text IS NULL OR btrim(p_text) = '') AND (p_storage_pfad IS NULL OR btrim(p_storage_pfad) = '') THEN
    RAISE EXCEPTION 'leer';
  END IF;
  v_verb := public._ziel_verbund('person', p_person);
  IF v_verb IS NULL THEN RAISE EXCEPTION 'ziel_unbekannt'; END IF;
  IF NOT public.ist_in_verbund(v_verb) THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;

  INSERT INTO public.gedenk_eintraege (verbund_id, person_id, autor_id, typ, text, storage_pfad)
  VALUES (v_verb, p_person, v_me, 'kondolenz',
          nullif(btrim(coalesce(p_text,'')), ''), nullif(btrim(coalesce(p_storage_pfad,'')), ''))
  RETURNING id INTO v_neu;

  RETURN jsonb_build_object('ok', true, 'id', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.gedenk_eintrag_schreiben(uuid, text, text) TO authenticated;


-- 2b) Eigenen Eintrag bearbeiten (nur Text; nur Autor).
CREATE OR REPLACE FUNCTION public.gedenk_eintrag_bearbeiten(p_id uuid, p_text text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  IF p_text IS NULL OR btrim(p_text) = '' THEN RAISE EXCEPTION 'leer'; END IF;
  SELECT autor_id INTO v_owner FROM public.gedenk_eintraege
   WHERE id = p_id AND typ = 'kondolenz' AND geloescht = false;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF v_owner IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;
  UPDATE public.gedenk_eintraege SET text = btrim(p_text), bearbeitet_am = now() WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.gedenk_eintrag_bearbeiten(uuid, text) TO authenticated;


-- 2c) Eintrag löschen (soft): Autor ODER Moderator. Gibt storage_pfad zurück, damit das
--     Frontend ein evtl. Foto aus dem Bucket räumen kann (kein Storage-Delete aus Postgres).
CREATE OR REPLACE FUNCTION public.gedenk_eintrag_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid; v_verb uuid; v_pfad text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  SELECT autor_id, verbund_id, storage_pfad INTO v_owner, v_verb, v_pfad
    FROM public.gedenk_eintraege WHERE id = p_id AND typ = 'kondolenz';
  IF v_verb IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF v_owner IS DISTINCT FROM auth.uid() AND NOT public.darf_verbund_moderieren(v_verb) THEN
    RAISE EXCEPTION 'keine_berechtigung';
  END IF;
  UPDATE public.gedenk_eintraege SET geloescht = true, text = NULL, storage_pfad = NULL WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'storage_pfad', v_pfad);
END $$;
GRANT EXECUTE ON FUNCTION public.gedenk_eintrag_loeschen(uuid) TO authenticated;


-- 2d) Kerze umschalten (an/aus). Toggle = hartes Insert/Delete (1 Kerze je Nutzer je Person).
CREATE OR REPLACE FUNCTION public.gedenk_kerze_umschalten(p_person uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_da   boolean;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  v_verb := public._ziel_verbund('person', p_person);
  IF v_verb IS NULL THEN RAISE EXCEPTION 'ziel_unbekannt'; END IF;
  IF NOT public.ist_in_verbund(v_verb) THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;

  SELECT EXISTS (SELECT 1 FROM public.gedenk_eintraege
                  WHERE person_id = p_person AND autor_id = v_me AND typ = 'kerze') INTO v_da;
  IF v_da THEN
    DELETE FROM public.gedenk_eintraege
     WHERE person_id = p_person AND autor_id = v_me AND typ = 'kerze';
    RETURN jsonb_build_object('ok', true, 'an', false);
  ELSE
    INSERT INTO public.gedenk_eintraege (verbund_id, person_id, autor_id, typ)
    VALUES (v_verb, p_person, v_me, 'kerze');
    RETURN jsonb_build_object('ok', true, 'an', true);
  END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.gedenk_kerze_umschalten(uuid) TO authenticated;


-- 2e) Gedenkseite EINER Person holen (EIN Roundtrip): Kerzen-Zähler + eigene Kerze +
--     Kerzen-Namen + Erinnerungs-/Kondolenz-Einträge (Name/Avatar + darf_*).
CREATE OR REPLACE FUNCTION public.gedenkseite_holen(p_person uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_mod  boolean;
  v_kerzen_anz int;
  v_meine_kerze boolean;
  v_kerzen jsonb;
  v_eintr  jsonb;
BEGIN
  v_verb := public._ziel_verbund('person', p_person);
  IF v_verb IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'ziel_unbekannt'); END IF;
  IF NOT public.ist_in_verbund(v_verb) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  v_mod := public.darf_verbund_moderieren(v_verb);

  SELECT count(*) INTO v_kerzen_anz FROM public.gedenk_eintraege
   WHERE person_id = p_person AND typ = 'kerze';
  SELECT EXISTS (SELECT 1 FROM public.gedenk_eintraege
                  WHERE person_id = p_person AND typ = 'kerze' AND autor_id = v_me) INTO v_meine_kerze;

  -- Namen der Kerzen-Anzünder (neueste zuerst, begrenzt auf 50 für die Anzeige)
  SELECT coalesce(jsonb_agg(nm ORDER BY ts DESC), '[]'::jsonb) INTO v_kerzen FROM (
    SELECT g.erstellt_am AS ts,
           COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''),
                    initcap(replace(replace(replace(split_part(u.email,'@',1),'.',' '),'_',' '),'-',' ')),
                    u.email, '—') AS nm
      FROM public.gedenk_eintraege g
      LEFT JOIN auth.users u    ON u.id = g.autor_id
      LEFT JOIN public.profile pr ON pr.user_id = g.autor_id
     WHERE g.person_id = p_person AND g.typ = 'kerze'
     ORDER BY g.erstellt_am DESC
     LIMIT 50
  ) s;

  -- Kondolenz-/Erinnerungseinträge (älteste zuerst) inkl. Name/Avatar + Rechte
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', g.id,
           'autor_id', g.autor_id,
           'text', CASE WHEN g.geloescht THEN NULL ELSE g.text END,
           'storage_pfad', CASE WHEN g.geloescht THEN NULL ELSE g.storage_pfad END,
           'geloescht', g.geloescht,
           'erstellt_am', g.erstellt_am,
           'bearbeitet_am', g.bearbeitet_am,
           'name', COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''),
                            initcap(replace(replace(replace(split_part(u.email,'@',1),'.',' '),'_',' '),'-',' ')),
                            u.email),
           'avatar', CASE WHEN COALESCE(pr.avatar_sichtbarkeit,'verbund') <> 'privat'
                          THEN COALESCE(pr.avatar_thumb_url, pr.avatar_url) END,
           'darf_bearbeiten', (g.autor_id = v_me AND NOT g.geloescht),
           'darf_loeschen', ((g.autor_id = v_me OR v_mod) AND NOT g.geloescht)
         ) ORDER BY g.erstellt_am), '[]'::jsonb) INTO v_eintr
    FROM public.gedenk_eintraege g
    LEFT JOIN auth.users u     ON u.id = g.autor_id
    LEFT JOIN public.profile pr ON pr.user_id = g.autor_id
   WHERE g.person_id = p_person AND g.typ = 'kondolenz';

  RETURN jsonb_build_object(
    'ok', true,
    'kerzen_anzahl', v_kerzen_anz,
    'meine_kerze', v_meine_kerze,
    'kerzen', v_kerzen,
    'kann_moderieren', v_mod,
    'eintraege', v_eintr
  );
END $$;
GRANT EXECUTE ON FUNCTION public.gedenkseite_holen(uuid) TO authenticated;


-- =====================================================
-- 3) STORAGE-BUCKET 'gedenkseiten' (public-read wie beitraege/avatars/personen-fotos)
--    Pfadschema: <user_id>/<uuid>  -> Schreiben nur im eigenen Ordner. Die Lese-Grenze
--    der Einträge selbst sichert die Tabellen-RLS (verbund-gebunden) ab.
-- =====================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('gedenkseiten', 'gedenkseiten', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "gedenk_obj_select" ON storage.objects;
DROP POLICY IF EXISTS "gedenk_obj_insert" ON storage.objects;
DROP POLICY IF EXISTS "gedenk_obj_update" ON storage.objects;
DROP POLICY IF EXISTS "gedenk_obj_delete" ON storage.objects;

CREATE POLICY "gedenk_obj_select" ON storage.objects FOR SELECT TO authenticated
  USING ( bucket_id = 'gedenkseiten' );
CREATE POLICY "gedenk_obj_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK ( bucket_id = 'gedenkseiten' AND (storage.foldername(name))[1] = auth.uid()::text );
CREATE POLICY "gedenk_obj_update" ON storage.objects FOR UPDATE TO authenticated
  USING ( bucket_id = 'gedenkseiten' AND (storage.foldername(name))[1] = auth.uid()::text )
  WITH CHECK ( bucket_id = 'gedenkseiten' AND (storage.foldername(name))[1] = auth.uid()::text );
CREATE POLICY "gedenk_obj_delete" ON storage.objects FOR DELETE TO authenticated
  USING ( bucket_id = 'gedenkseiten' AND (storage.foldername(name))[1] = auth.uid()::text );


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_gedenkseiten.sql ausgeführt — gedenk_eintraege (verbund-RLS) + RPCs (schreiben/bearbeiten/loeschen/kerze/holen) + Bucket gedenkseiten' AS status;
