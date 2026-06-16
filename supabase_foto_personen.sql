-- =====================================================
-- FOTO-TAGGING — Personen in Fotos markieren (Feature 4)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_personen_fotos.sql UND supabase_reaktionen_kommentare.sql ausführen.
--
-- Markiert Personen (Personenkarten) in einem Galerie-Foto (personen_fotos). Markierte Fotos
-- erscheinen auf der Personenkarte der markierten Person ("Markiert in Fotos"). STRIKT VERBUND-
-- GEBUNDEN (CLAUDE.md Social-Regel): eine Markierung gehört zu genau EINEM verbund_id (dem des
-- Fotos) und ist nur für dessen Mitglieder sichtbar -> KEINE verbundübergreifende Exposition
-- (Minderjährige werden außerhalb des Verbunds nicht über Markierungen sichtbar).
--
-- SICHERHEIT:
--   * SELECT: nur ist_in_verbund(verbund_id).
--   * Markieren: nur Bearbeiter der Foto-Familie (kann_familie_bearbeiten). Die markierte Person
--     muss im SELBEN Verbund liegen. Schreiben ausschließlich über SECURITY-DEFINER-RPCs
--     (verbund_id serverseitig aus dem Foto abgeleitet -> nicht fälschbar).
--   * Entfernen: Bearbeiter der Foto-Familie ODER wer die Markierung gesetzt hat.
--
-- Voraussetzungen: supabase_verbund.sql, supabase_reaktionen_kommentare.sql (ist_in_verbund,
--   _ziel_verbund), supabase_personen_fotos.sql (personen_fotos), supabase_multitree_phase5.sql.
-- =====================================================


-- =====================================================
-- 1) TABELLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.foto_personen (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id   uuid NOT NULL,
  foto_id      uuid NOT NULL REFERENCES public.personen_fotos(id) ON DELETE CASCADE,
  person_id    uuid NOT NULL REFERENCES public.personen(id)       ON DELETE CASCADE,
  x            real,                       -- optionale Markierungs-Position (0..1), nullable
  y            real,
  markiert_von uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  erstellt_am  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (foto_id, person_id)              -- eine Person je Foto nur einmal markiert
);
CREATE INDEX IF NOT EXISTS foto_personen_foto_idx    ON public.foto_personen (foto_id);
CREATE INDEX IF NOT EXISTS foto_personen_person_idx  ON public.foto_personen (person_id);
CREATE INDEX IF NOT EXISTS foto_personen_verbund_idx ON public.foto_personen (verbund_id);

ALTER TABLE public.foto_personen ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "foto_personen_select" ON public.foto_personen;
CREATE POLICY "foto_personen_select" ON public.foto_personen FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );
-- (Schreiben nur über die SECURITY-DEFINER-RPCs unten.)


-- =====================================================
-- 2) HELFER: Familie eines Fotos (für Bearbeitungsrecht). Verbund über _ziel_verbund('foto',…).
-- =====================================================
CREATE OR REPLACE FUNCTION public._foto_familie(p_foto uuid)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT familie_id FROM public.personen_fotos WHERE id = p_foto;
$$;


-- =====================================================
-- 3) RPCs
-- =====================================================

-- 3a) Person in einem Foto markieren (oder Position aktualisieren). Nur Foto-Bearbeiter;
--     markierte Person muss im selben Verbund liegen.
CREATE OR REPLACE FUNCTION public.foto_person_markieren(
  p_foto uuid, p_person uuid, p_x real DEFAULT NULL, p_y real DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid; v_fam uuid; v_pverb uuid; v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  v_verb := public._ziel_verbund('foto', p_foto);
  IF v_verb IS NULL THEN RAISE EXCEPTION 'foto_unbekannt'; END IF;
  v_fam := public._foto_familie(p_foto);
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;
  v_pverb := public._ziel_verbund('person', p_person);
  IF v_pverb IS DISTINCT FROM v_verb THEN RAISE EXCEPTION 'person_fremd'; END IF;

  INSERT INTO public.foto_personen (verbund_id, foto_id, person_id, x, y, markiert_von)
  VALUES (v_verb, p_foto, p_person, p_x, p_y, auth.uid())
  ON CONFLICT (foto_id, person_id) DO UPDATE SET x = EXCLUDED.x, y = EXCLUDED.y
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END $$;
GRANT EXECUTE ON FUNCTION public.foto_person_markieren(uuid, uuid, real, real) TO authenticated;

-- 3b) Markierung entfernen: Foto-Bearbeiter ODER wer sie gesetzt hat.
CREATE OR REPLACE FUNCTION public.foto_person_entfernen(p_foto uuid, p_person uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_von uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  SELECT markiert_von INTO v_von FROM public.foto_personen WHERE foto_id = p_foto AND person_id = p_person;
  IF v_von IS NULL AND NOT EXISTS (SELECT 1 FROM public.foto_personen WHERE foto_id = p_foto AND person_id = p_person) THEN
    RAISE EXCEPTION 'nicht_gefunden';
  END IF;
  v_fam := public._foto_familie(p_foto);
  IF NOT public.kann_familie_bearbeiten(v_fam) AND v_von IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'keine_berechtigung';
  END IF;
  DELETE FROM public.foto_personen WHERE foto_id = p_foto AND person_id = p_person;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.foto_person_entfernen(uuid, uuid) TO authenticated;

-- 3c) Markierungen EINES Fotos holen (Name + externe_id für Navigation + Position + Recht).
CREATE OR REPLACE FUNCTION public.foto_tags_holen(p_foto uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid; v_fam uuid; v_darf boolean; v_rows jsonb;
BEGIN
  v_verb := public._ziel_verbund('foto', p_foto);
  IF v_verb IS NULL OR NOT public.ist_in_verbund(v_verb) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  v_fam := public._foto_familie(p_foto);
  v_darf := public.kann_familie_bearbeiten(v_fam);
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'person_id', fp.person_id,
           'person_ext', pe.externe_id,
           'name', nullif(btrim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')), ''),
           'x', fp.x, 'y', fp.y
         ) ORDER BY pe.vorname, pe.nachname), '[]'::jsonb) INTO v_rows
    FROM public.foto_personen fp
    JOIN public.personen pe ON pe.id = fp.person_id
   WHERE fp.foto_id = p_foto;
  RETURN jsonb_build_object('ok', true, 'darf_markieren', v_darf, 'tags', v_rows);
END $$;
GRANT EXECUTE ON FUNCTION public.foto_tags_holen(uuid) TO authenticated;

-- 3d) Alle Fotos, in denen eine Person markiert ist (Thumbnail-Pfad + Galerie-Besitzer für Navigation).
CREATE OR REPLACE FUNCTION public.person_markierte_fotos(p_person uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'foto_id', fp.foto_id,
           'storage_pfad', pfoto.storage_pfad,
           'besitzer_ext', bes.externe_id,
           'besitzer_name', nullif(btrim(coalesce(bes.vorname,'') || ' ' || coalesce(bes.nachname,'')), '')
         ) ORDER BY fp.erstellt_am DESC), '[]'::jsonb)
    FROM public.foto_personen fp
    JOIN public.personen_fotos pfoto ON pfoto.id = fp.foto_id
    JOIN public.personen bes         ON bes.id = pfoto.person_id
   WHERE fp.person_id = p_person
     AND public.ist_in_verbund(fp.verbund_id);
$$;
GRANT EXECUTE ON FUNCTION public.person_markierte_fotos(uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_foto_personen.sql ausgeführt — foto_personen (verbund-RLS) + markieren/entfernen/tags_holen/markierte_fotos' AS status;
