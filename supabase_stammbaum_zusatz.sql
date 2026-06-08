-- =====================================================
-- STAMMBAUM-NAME = NUR NACHNAME  +  separates Feld „zusatz"
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Hintergrund (Nutzerwunsch): Der Stammbaum-Name soll NUR der Nachname sein (Buchstaben,
-- Bindestrich, Leerzeichen, Apostroph). Eine Unterscheidung gleichnamiger Familien (bisher
-- als Klammer-Zusatz IM Namen, z. B. „Pisarević (Desa)", oder als „Stephen - Vidović")
-- gehört in ein EIGENES Feld `zusatz`, das nur in Liste/Suche in Klammern angezeigt wird.
-- Damit braucht der Blutlinien-Vergleich (istBlutName/zielBaumFuer) keine Heuristik mehr —
-- der reine `name` IST der Nachname.
--
-- Schritte:
--   1) Spalte stammbaeume.zusatz
--   2) EINMALIGE Migration: Bestandsnamen aufsplitten (Klammer-/„ - "-Zusatz -> zusatz,
--      name = reiner Nachname). Wirkt nur, wo zusatz noch leer ist (idempotent).
--   3) stammbaum_anlegen        -> nimmt p_zusatz
--   4) stammbaum_einstellungen_holen     -> liefert zusatz
--   5) stammbaum_einstellungen_speichern -> nimmt/schreibt p_zusatz
--   6) verwaltbare_familien.baum_namen   -> zeigt „Name (Zusatz)" (Suche im Mitglieder-Dialog)
-- =====================================================

-- 1) Spalte ----------------------------------------------------------------
ALTER TABLE public.stammbaeume ADD COLUMN IF NOT EXISTS zusatz text;

-- 2) Migration der Bestandsdaten ------------------------------------------
-- a) Klammer-Zusatz:  „Pisarević (Desa)"  ->  name „Pisarević" + zusatz „Desa"
UPDATE public.stammbaeume
   SET zusatz = btrim(substring(name from '\(([^)]*)\)')),
       name   = btrim(regexp_replace(name, '\s*\([^)]*\)\s*', ' ', 'g'))
 WHERE coalesce(btrim(zusatz), '') = ''
   AND name ~ '\([^)]*\)';

-- b) Vorangestellter Zusatz mit Leerzeichen-Bindestrich:
--    „Stephen - Vidović"  ->  name „Vidović" (Teil nach „ - ") + zusatz „Stephen" (Teil davor).
--    Echte Doppelnamen OHNE Leerzeichen um den Bindestrich (z. B. „Mujkić-Vidović") bleiben
--    unberührt, weil das Muster „\s+-\s+" Leerzeichen verlangt.
UPDATE public.stammbaeume
   SET zusatz = btrim(substring(name from '^(.*?)\s+-\s+')),
       name   = btrim(substring(name from '\s+-\s+(.*)$'))
 WHERE coalesce(btrim(zusatz), '') = ''
   AND name ~ '\S\s+-\s+\S';

-- c) Familiennamen analog bereinigen (familien.name wird vom Einstellungen-RPC mit dem
--    Baum-Namen synchron gehalten -> trug denselben Zusatz). Die Unterscheidung lebt nun
--    ausschließlich in stammbaeume.zusatz. (Familien haben kein eigenes zusatz-Feld nötig.)
UPDATE public.familien
   SET name = btrim(regexp_replace(name, '\s*\([^)]*\)\s*', ' ', 'g'))
 WHERE name ~ '\([^)]*\)';
UPDATE public.familien
   SET name = btrim(substring(name from '\s+-\s+(.*)$'))
 WHERE name ~ '\S\s+-\s+\S';

-- 3) stammbaum_anlegen: zusätzlicher optionaler Parameter p_zusatz -------------
DROP FUNCTION IF EXISTS public.stammbaum_anlegen(text, text, text);
CREATE OR REPLACE FUNCTION public.stammbaum_anlegen(
  p_name text, p_vorname text, p_nachname text, p_zusatz text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid; v_fam uuid; v_tree uuid; v_ext text; v_vor text; v_nach text;
        v_zus text := nullif(btrim(coalesce(p_zusatz,'')), '');
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet.'; END IF;
  IF coalesce(trim(p_name),'') = '' THEN RAISE EXCEPTION 'Name des Stammbaums erforderlich.'; END IF;

  -- DUBLETTE: gleicher Name UND gleicher Zusatz beim selben Owner -> Abbruch.
  -- (Gleicher Name mit ABWEICHENDEM Zusatz ist erlaubt = genau der Sinn des Zusatzes.)
  IF EXISTS (
    SELECT 1 FROM public.stammbaeume s
    JOIN public.mitgliedschaften m ON m.familie_id = s.familie_id
    WHERE m.user_id = v_uid AND m.rolle = 'familien_owner' AND m.aktiv
      AND lower(trim(s.name)) = lower(trim(p_name))
      AND lower(coalesce(btrim(s.zusatz),'')) = lower(coalesce(v_zus,''))
  ) THEN
    RAISE EXCEPTION 'stammbaum_name_existiert';
  END IF;

  v_vor  := coalesce(nullif(trim(p_vorname),''), trim(p_name));
  v_nach := coalesce(nullif(trim(p_nachname),''), trim(p_name));

  INSERT INTO public.familien (name) VALUES (trim(p_name)) RETURNING id INTO v_fam;
  INSERT INTO public.stammbaeume (familie_id, name, zusatz, ersteller_id, owner_id, aktiv)
  VALUES (v_fam, trim(p_name), v_zus, v_uid, v_uid, true) RETURNING id INTO v_tree;

  v_ext := 'I' || (extract(epoch from now())*1000)::bigint;
  INSERT INTO public.personen (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum, stammbaum_daten)
  VALUES (v_fam, v_tree, v_ext, v_vor, v_nach, NULL,
    jsonb_build_object('id', v_ext, 'given', v_vor, 'surname', v_nach,
                       'name', trim(v_vor || ' ' || v_nach), 'sex', '',
                       'angelegt_aus', 'stammbaum-anlegen'));

  UPDATE public.stammbaeume SET wurzel_person_id =
    (SELECT id FROM public.personen WHERE stammbaum_id = v_tree LIMIT 1)
  WHERE id = v_tree;

  INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv)
  VALUES (v_uid, v_fam, 'familien_owner', true)
  ON CONFLICT (user_id, familie_id) DO UPDATE SET rolle = 'familien_owner', aktiv = true;

  RETURN v_tree;
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_anlegen(text, text, text, text) TO authenticated;

-- 4) stammbaum_einstellungen_holen: zusatz mitliefern -------------------------
DROP FUNCTION IF EXISTS public.stammbaum_einstellungen_holen(uuid);
CREATE OR REPLACE FUNCTION public.stammbaum_einstellungen_holen(p_stammbaum_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_rec record;
BEGIN
  IF p_stammbaum_id IS NULL THEN RAISE EXCEPTION 'fe_keine_familie'; END IF;
  SELECT s.familie_id, s.name, s.zusatz, s.einstellungen, f.land, f.stadt, f.gemeinde, f.opis
    INTO v_rec
    FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
   WHERE s.id = p_stammbaum_id;
  IF v_rec.familie_id IS NULL THEN RAISE EXCEPTION 'fe_keine_familie'; END IF;
  v_fam := v_rec.familie_id;
  IF NOT (public.ist_super_admin() OR public.sieht_familie(v_fam)) THEN
    RAISE EXCEPTION 'fe_keine_berechtigung';
  END IF;
  RETURN jsonb_build_object(
    'name', v_rec.name, 'zusatz', v_rec.zusatz, 'opis', v_rec.opis,
    'land', v_rec.land, 'stadt', v_rec.stadt, 'gemeinde', v_rec.gemeinde,
    'einstellungen', coalesce(v_rec.einstellungen, '{}'::jsonb),
    'can_edit', (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam))
  );
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_einstellungen_holen(uuid) TO authenticated;

-- 5) stammbaum_einstellungen_speichern: zusätzlicher Parameter p_zusatz --------
DROP FUNCTION IF EXISTS public.stammbaum_einstellungen_speichern(uuid, text, text, text, text, text, jsonb);
CREATE OR REPLACE FUNCTION public.stammbaum_einstellungen_speichern(
  p_stammbaum_id uuid,
  p_name         text,
  p_opis         text,
  p_land         text,
  p_stadt        text,
  p_gemeinde     text,
  p_einstellungen jsonb DEFAULT '{}'::jsonb,
  p_zusatz       text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam   uuid;
  v_old   record;
  v_name  text := trim(coalesce(p_name,''));
  v_zus   text := nullif(btrim(coalesce(p_zusatz,'')), '');
  v_land  text := trim(coalesce(p_land,''));
  v_stadt text := trim(coalesce(p_stadt,''));
  v_gem   text := trim(coalesce(p_gemeinde,''));
  v_opis  text := nullif(trim(coalesce(p_opis,'')), '');
  v_einst jsonb := coalesce(p_einstellungen, '{}'::jsonb);
  v_mail  text := nullif(trim(coalesce(v_einst->>'kontakt_email','')), '');
BEGIN
  IF p_stammbaum_id IS NULL THEN RAISE EXCEPTION 'fe_keine_familie'; END IF;

  SELECT s.familie_id, s.name AS s_name, s.zusatz AS s_zusatz, f.name AS f_name,
         f.land, f.stadt, f.gemeinde, f.opis
    INTO v_old
    FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
   WHERE s.id = p_stammbaum_id;
  IF v_old.familie_id IS NULL THEN RAISE EXCEPTION 'fe_keine_familie'; END IF;
  v_fam := v_old.familie_id;

  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'fe_keine_berechtigung';
  END IF;

  IF v_name = '' OR v_land = '' OR v_stadt = '' OR v_gem = '' THEN
    RAISE EXCEPTION 'fe_pflicht';
  END IF;

  IF v_mail IS NOT NULL AND NOT public.ist_gueltige_email(v_mail) THEN
    RAISE EXCEPTION 'fe_email_ungueltig';
  END IF;

  -- Duplikatcheck der FAMILIE (Name/Ort) unverändert
  IF public.merge_norm(v_name)  IS DISTINCT FROM public.merge_norm(v_old.f_name)
     OR public.merge_norm(v_land)  IS DISTINCT FROM public.merge_norm(v_old.land)
     OR public.merge_norm(v_stadt) IS DISTINCT FROM public.merge_norm(v_old.stadt)
     OR public.merge_norm(v_gem)   IS DISTINCT FROM public.merge_norm(v_old.gemeinde)
  THEN
    IF EXISTS (
      SELECT 1 FROM public.familien f
      WHERE f.id <> v_fam
        AND public.merge_norm(f.name)     = public.merge_norm(v_name)
        AND public.merge_norm(f.land)     = public.merge_norm(v_land)
        AND public.merge_norm(f.stadt)    = public.merge_norm(v_stadt)
        AND public.merge_norm(f.gemeinde) = public.merge_norm(v_gem)
    ) THEN
      RAISE EXCEPTION 'fe_duplikat';
    END IF;
  END IF;

  UPDATE public.familien
     SET name = v_name, land = v_land, stadt = v_stadt, gemeinde = v_gem, opis = v_opis
   WHERE id = v_fam;

  -- Name + Zusatz + Reichdaten am Stammbaum
  UPDATE public.stammbaeume
     SET einstellungen = v_einst, name = v_name, zusatz = v_zus
   WHERE id = p_stammbaum_id;

  -- Weitere Bäume derselben Familie, die noch den ALTEN Familiennamen trugen, mit umbenennen
  IF v_name IS DISTINCT FROM v_old.f_name THEN
    UPDATE public.stammbaeume
       SET name = v_name
     WHERE familie_id = v_fam
       AND id <> p_stammbaum_id
       AND lower(trim(name)) = lower(trim(coalesce(v_old.f_name,'')));
  END IF;

  INSERT INTO public.familien_audit (familie_id, stammbaum_id, geaendert_von, alte_werte, neue_werte)
  VALUES (
    v_fam, p_stammbaum_id, auth.uid(),
    jsonb_build_object('name', v_old.f_name, 'zusatz', v_old.s_zusatz, 'land', v_old.land,
                       'stadt', v_old.stadt, 'gemeinde', v_old.gemeinde, 'opis', v_old.opis),
    jsonb_build_object('name', v_name, 'zusatz', v_zus, 'land', v_land, 'stadt', v_stadt,
                       'gemeinde', v_gem, 'opis', v_opis, 'einstellungen', v_einst)
  );

  RETURN jsonb_build_object('ok', true, 'name', v_name, 'zusatz', v_zus);
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_einstellungen_speichern(uuid, text, text, text, text, text, jsonb, text) TO authenticated;

-- 6) verwaltbare_familien: baum_namen zeigt „Name (Zusatz)" -> Suche im Mitglieder-Dialog
DROP FUNCTION IF EXISTS public.verwaltbare_familien();
CREATE OR REPLACE FUNCTION public.verwaltbare_familien()
RETURNS TABLE(familie_id uuid, familie_name text, baum_namen text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT f.id, f.name,
    (SELECT string_agg(DISTINCT s.name || coalesce(' (' || nullif(btrim(s.zusatz),'') || ')',''), ', ' ORDER BY (s.name || coalesce(' (' || nullif(btrim(s.zusatz),'') || ')','')))
       FROM public.stammbaeume s WHERE s.familie_id = f.id) AS baum_namen
  FROM public.familien f
  WHERE public.ist_super_admin()
     OR EXISTS (SELECT 1 FROM public.mitgliedschaften m
                 WHERE m.familie_id = f.id AND m.user_id = auth.uid() AND m.aktiv
                   AND m.rolle IN ('familien_owner','familien_admin'))
  ORDER BY f.name;
$$;
GRANT EXECUTE ON FUNCTION public.verwaltbare_familien() TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'stammbaeume.zusatz: Spalte + Migration + RPCs (anlegen/holen/speichern/verwaltbare_familien)' AS status;

-- Kontroll-Ausgabe: aktuelle Namen + Zusatz (sollten keine „(...)"/„ - " mehr im Namen haben)
SELECT id, name, zusatz FROM public.stammbaeume ORDER BY name, zusatz NULLS FIRST;
