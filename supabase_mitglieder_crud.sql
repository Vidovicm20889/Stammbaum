-- =====================================================
-- MITGLIEDER-VERWALTUNG — Schreiboperationen als SECURITY DEFINER RPCs
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Grund: Direkte UPDATE/DELETE auf mitgliedschaften liefen still ins Leere
-- (RLS filterte 0 Zeilen, ohne Fehler -> GUI zeigte Änderung, die nie gespeichert
-- wurde). Diese RPCs prüfen die Berechtigung explizit und schreiben verlässlich.
--
-- Berechtigung: super_admin (alles) ODER familien_admin der Ziel-Familie.
-- Schutz: ein familien_admin kann super_admin-Zeilen NICHT verändern/löschen.
-- Voraussetzung: ist_super_admin() + get_meine_rolle() existieren (mitglieder_komplett).
-- =====================================================

-- Aktiv-Status setzen (Deaktivieren / Aktivieren)
CREATE OR REPLACE FUNCTION public.mitglied_aktiv_setzen(p_mid uuid, p_aktiv boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_rolle text;
BEGIN
  SELECT familie_id, rolle INTO v_fam, v_rolle FROM public.mitgliedschaften WHERE id = p_mid;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Mitglied nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.get_meine_rolle(v_fam) = 'familien_admin') THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  IF v_rolle = 'super_admin' AND NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  UPDATE public.mitgliedschaften SET aktiv = p_aktiv WHERE id = p_mid;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.mitglied_aktiv_setzen(uuid, boolean) TO authenticated;

-- Rolle ändern (nur familien_mitglied / familien_admin; super_admin nicht über die GUI)
CREATE OR REPLACE FUNCTION public.mitglied_rolle_setzen(p_mid uuid, p_rolle text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_rolle text;
BEGIN
  IF p_rolle NOT IN ('familien_mitglied', 'familien_admin') THEN
    RAISE EXCEPTION 'Unzulässige Rolle.';
  END IF;
  SELECT familie_id, rolle INTO v_fam, v_rolle FROM public.mitgliedschaften WHERE id = p_mid;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Mitglied nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.get_meine_rolle(v_fam) = 'familien_admin') THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  IF v_rolle = 'super_admin' AND NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  UPDATE public.mitgliedschaften SET rolle = p_rolle WHERE id = p_mid;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.mitglied_rolle_setzen(uuid, text) TO authenticated;

-- Mitglied entfernen — vollständig:
--   * Super-Admin: löscht ALLE Mitgliedschaften des Users.
--   * Familien-Admin: löscht nur die Mitgliedschaft in seiner Familie.
-- Hat der User danach NIRGENDS mehr eine Mitgliedschaft, wird auch der
-- Auth-Account (auth.users) + offene Zugangsanfragen gelöscht -> verschwindet
-- aus der Supabase-Users-Liste. (Stammbaum-PERSONEN bleiben erhalten, sie
-- gehören zur Familie, nicht zum Login-Konto.)
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

  -- Wenn der User keinerlei Zugang mehr hat: Konto + Anfragen restlos entfernen
  IF NOT EXISTS (SELECT 1 FROM public.mitgliedschaften WHERE user_id = v_user) THEN
    SELECT email INTO v_email FROM auth.users WHERE id = v_user;
    IF v_email IS NOT NULL THEN
      DELETE FROM public.registrierungs_anfragen WHERE lower(email) = lower(v_email);
    END IF;
    DELETE FROM auth.users WHERE id = v_user;   -- entfernt auch identities/sessions (FK CASCADE)
  END IF;

  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.mitglied_entfernen(uuid) TO authenticated;

-- PostgREST-Schema-Cache neu laden (sonst evtl. PGRST202)
NOTIFY pgrst, 'reload schema';

SELECT 'Mitglieder-CRUD-RPCs angelegt' AS status;
