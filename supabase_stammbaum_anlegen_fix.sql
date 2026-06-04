-- =====================================================
-- BUG 2: stammbaum_anlegen — Dublettencheck + Pflicht-Metadaten
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Die Funktion ist eine einzelne plpgsql-Transaktion -> bei jedem RAISE wird
-- ALLES zurückgerollt (keine halb angelegten Bäume / verwaisten Zeilen).
-- =====================================================

-- 1) Metadaten-Spalten (Erstellungsdatum existiert bereits als created_at)
ALTER TABLE public.stammbaeume ADD COLUMN IF NOT EXISTS ersteller_id uuid;
ALTER TABLE public.stammbaeume ADD COLUMN IF NOT EXISTS owner_id     uuid;
ALTER TABLE public.stammbaeume ADD COLUMN IF NOT EXISTS aktiv        boolean NOT NULL DEFAULT true;

-- 2) RPC neu: Dublettencheck (eigener Besitz) + Metadaten setzen
CREATE OR REPLACE FUNCTION public.stammbaum_anlegen(p_name text, p_vorname text, p_nachname text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid; v_fam uuid; v_tree uuid; v_ext text; v_vor text; v_nach text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet.'; END IF;
  IF coalesce(trim(p_name),'') = '' THEN RAISE EXCEPTION 'Name des Stammbaums erforderlich.'; END IF;

  -- DUBLETTE: besitzt der Aufrufer bereits einen Baum gleichen Namens? -> Abbruch
  -- (owner-bezogen; verschiedene Mandanten dürfen denselben Nachnamen haben).
  IF EXISTS (
    SELECT 1 FROM public.stammbaeume s
    JOIN public.mitgliedschaften m ON m.familie_id = s.familie_id
    WHERE m.user_id = v_uid AND m.rolle = 'familien_owner' AND m.aktiv
      AND lower(trim(s.name)) = lower(trim(p_name))
  ) THEN
    RAISE EXCEPTION 'stammbaum_name_existiert';
  END IF;

  v_vor  := coalesce(nullif(trim(p_vorname),''), trim(p_name));
  v_nach := coalesce(nullif(trim(p_nachname),''), trim(p_name));

  -- Familie + Stammbaum + Metadaten
  INSERT INTO public.familien (name) VALUES (trim(p_name)) RETURNING id INTO v_fam;
  INSERT INTO public.stammbaeume (familie_id, name, ersteller_id, owner_id, aktiv)
  VALUES (v_fam, trim(p_name), v_uid, v_uid, true) RETURNING id INTO v_tree;

  -- Erste Person als Startpunkt (sonst hätte der Baum 0 Personen)
  v_ext := 'I' || (extract(epoch from now())*1000)::bigint;
  INSERT INTO public.personen (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum, stammbaum_daten)
  VALUES (v_fam, v_tree, v_ext, v_vor, v_nach, NULL,
    jsonb_build_object('id', v_ext, 'given', v_vor, 'surname', v_nach,
                       'name', trim(v_vor || ' ' || v_nach), 'sex', '',
                       'angelegt_aus', 'stammbaum-anlegen'));

  UPDATE public.stammbaeume SET wurzel_person_id =
    (SELECT id FROM public.personen WHERE stammbaum_id = v_tree LIMIT 1)
  WHERE id = v_tree;

  -- Ersteller wird Owner der neuen Familie
  INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv)
  VALUES (v_uid, v_fam, 'familien_owner', true)
  ON CONFLICT (user_id, familie_id) DO UPDATE SET rolle = 'familien_owner', aktiv = true;

  RETURN v_tree;
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_anlegen(text, text, text) TO authenticated;

-- 3) Optional: bestehende Bäume mit owner_id/ersteller_id nachfüllen (aus der Owner-Mitgliedschaft)
UPDATE public.stammbaeume s
   SET owner_id = COALESCE(s.owner_id, m.user_id),
       ersteller_id = COALESCE(s.ersteller_id, m.user_id)
  FROM public.mitgliedschaften m
 WHERE m.familie_id = s.familie_id AND m.rolle = 'familien_owner' AND m.aktiv
   AND (s.owner_id IS NULL OR s.ersteller_id IS NULL);

NOTIFY pgrst, 'reload schema';
SELECT 'stammbaum_anlegen: Dublettencheck + ersteller_id/owner_id/aktiv aktiv' AS status;
