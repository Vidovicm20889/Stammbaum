-- =====================================================
-- VERKNÜPFUNG ACCOUNT <-> NAMENSKARTE: Verwaltung & Korrektur
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Voraussetzung: supabase_blutlinie_rechte.sql (personen.user_id, rechte_neu_berechnen),
--   ist_super_admin(), kann_familie_bearbeiten(), mitglieder-CRUD.
-- =====================================================

-- 1) Welche Person ist mit einem Konto verknüpft? (für die GUI-Vorauswahl)
CREATE OR REPLACE FUNCTION public.verknuepfte_person(p_user uuid)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT id FROM public.personen WHERE user_id = p_user LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.verknuepfte_person(uuid) TO authenticated;

-- 2) Verknüpfung eines Kontos LÖSEN (Karte bleibt, wird "unassigned") + Rechte neu rechnen.
CREATE OR REPLACE FUNCTION public.person_user_loesen(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT pe.familie_id INTO v_fam FROM public.personen pe WHERE pe.user_id = p_user LIMIT 1;
  IF v_fam IS NOT NULL AND NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  UPDATE public.personen SET user_id = NULL WHERE user_id = p_user;   -- Karte bleibt erhalten
  PERFORM public.rechte_neu_berechnen(p_user);                        -- entzieht auto-Admin-Rollen
END $$;
GRANT EXECUTE ON FUNCTION public.person_user_loesen(uuid) TO authenticated;

-- 3) Neue Namenskarte anlegen (für "Neue Karte erstellen" bei der Anfrage-Genehmigung).
--    Person ohne erzwungene Position; Beziehungen kann der Admin später setzen.
CREATE OR REPLACE FUNCTION public.namenskarte_anlegen(
  p_stammbaum uuid, p_vorname text, p_nachname text, p_geburtsdatum text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_id uuid; v_ext text; v_vor text; v_nach text;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_stammbaum;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  v_vor := trim(coalesce(p_vorname,'')); v_nach := trim(coalesce(p_nachname,''));
  IF v_vor = '' AND v_nach = '' THEN RAISE EXCEPTION 'Name erforderlich.'; END IF;

  v_ext := 'I' || (extract(epoch from now())*1000)::bigint;
  INSERT INTO public.personen (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum, stammbaum_daten)
  VALUES (v_fam, p_stammbaum, v_ext, v_vor, v_nach, NULL,   -- date-Spalte bleibt NULL (Regel)
    jsonb_build_object('id', v_ext, 'given', v_vor, 'surname', v_nach,
      'name', trim(v_vor || ' ' || v_nach), 'sex', '',
      'birth_date', nullif(trim(coalesce(p_geburtsdatum,'')),''),   -- Freitext/ISO in stammbaum_daten
      'angelegt_aus', 'namenskarte-genehmigung'))
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.namenskarte_anlegen(uuid, text, text, text) TO authenticated;

-- 4) Stammbäume einer Familie (für das Stammbaum-Dropdown beim Anlegen einer neuen Karte)
CREATE OR REPLACE FUNCTION public.stammbaeume_der_familie(p_familie uuid)
RETURNS TABLE(id uuid, name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT s.id, s.name FROM public.stammbaeume s
  WHERE s.familie_id = p_familie
    AND (public.ist_super_admin() OR public.kann_familie_bearbeiten(p_familie) OR public.sieht_familie(p_familie))
  ORDER BY s.name;
$$;
GRANT EXECUTE ON FUNCTION public.stammbaeume_der_familie(uuid) TO authenticated;

-- 5) User-Delete (mitglied_entfernen) erweitern: wird das KONTO komplett entfernt,
--    auch die Namenskarte FREIGEBEN (user_id = NULL). Karte + Beziehungen bleiben erhalten.
CREATE OR REPLACE FUNCTION public.mitglied_entfernen(p_mid uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_rolle text; v_user uuid; v_email text;
BEGIN
  SELECT familie_id, rolle, user_id INTO v_fam, v_rolle, v_user
    FROM public.mitgliedschaften WHERE id = p_mid;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Mitglied nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.get_meine_rolle(v_fam) = 'familien_admin') THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  IF v_rolle = 'super_admin' AND NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  IF public.ist_super_admin() THEN
    DELETE FROM public.mitgliedschaften WHERE user_id = v_user;   -- alle Familien
  ELSE
    DELETE FROM public.mitgliedschaften WHERE id = p_mid;          -- nur diese
  END IF;

  -- Konto restlos entfernen, wenn keinerlei Zugang mehr besteht
  IF NOT EXISTS (SELECT 1 FROM public.mitgliedschaften WHERE user_id = v_user) THEN
    UPDATE public.personen SET user_id = NULL WHERE user_id = v_user;   -- Namenskarte freigeben (bleibt im Baum)
    SELECT email INTO v_email FROM auth.users WHERE id = v_user;
    IF v_email IS NOT NULL THEN
      DELETE FROM public.registrierungs_anfragen WHERE lower(email) = lower(v_email);
    END IF;
    DELETE FROM auth.users WHERE id = v_user;   -- entfernt identities/sessions (FK CASCADE)
  END IF;

  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.mitglied_entfernen(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Verknüpfungs-Verwaltung: loesen/anlegen/stammbaeume + mitglied_entfernen (Karte freigeben)' AS status;
