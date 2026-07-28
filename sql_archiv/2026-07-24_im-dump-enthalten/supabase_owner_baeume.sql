-- =====================================================
-- OWNER: eigene Bäume auflisten + neuen Stammbaum anlegen
-- Ausführen in: Supabase -> SQL Editor.
-- Voraussetzung: ist_super_admin() existiert; Rolle familien_owner eingerichtet.
-- =====================================================

-- 1) Bäume, die der eingeloggte User als Eigentümer löschen darf.
--    Super-Admin (Betrieb) bekommt alle Bäume.
CREATE OR REPLACE FUNCTION public.meine_owner_baeume()
RETURNS TABLE (stammbaum_id uuid, stammbaum_name text, familie_id uuid, personen bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT s.id, s.name, s.familie_id,
         (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id)
  FROM public.stammbaeume s
  WHERE public.ist_super_admin()
     OR EXISTS (
       SELECT 1 FROM public.mitgliedschaften m
       WHERE m.familie_id = s.familie_id AND m.user_id = auth.uid()
         AND m.rolle = 'familien_owner' AND m.aktiv
     )
  ORDER BY s.name;
$$;
GRANT EXECUTE ON FUNCTION public.meine_owner_baeume() TO authenticated;

-- 2) Neuen, eigenständigen Stammbaum anlegen. Der Aufrufer wird dessen
--    familien_owner. Es wird eine erste Person als Startpunkt angelegt,
--    damit der Baum sichtbar/erweiterbar ist.
CREATE OR REPLACE FUNCTION public.stammbaum_anlegen(p_name text, p_vorname text, p_nachname text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid; v_fam uuid; v_tree uuid; v_ext text; v_vor text; v_nach text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet.'; END IF;
  IF coalesce(trim(p_name),'') = '' THEN RAISE EXCEPTION 'Name des Stammbaums erforderlich.'; END IF;

  v_vor  := coalesce(nullif(trim(p_vorname),''), trim(p_name));
  v_nach := coalesce(nullif(trim(p_nachname),''), trim(p_name));

  INSERT INTO public.familien (name) VALUES (trim(p_name)) RETURNING id INTO v_fam;
  INSERT INTO public.stammbaeume (familie_id, name) VALUES (v_fam, trim(p_name)) RETURNING id INTO v_tree;

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
GRANT EXECUTE ON FUNCTION public.stammbaum_anlegen(text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Owner-Baum-RPCs angelegt' AS status;
