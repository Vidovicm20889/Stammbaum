-- =====================================================
-- BLUTLINIEN-RECHTE (Phase 2: Genehmigung + manueller Schutz)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Voraussetzung: supabase_blutlinie_rechte.sql (Phase 1) ist ausgeführt.
-- =====================================================

-- 1) Manuelle Rollenänderung schützt die Zeile vor dem Auto-Recompute (auto=false).
--    So überschreibt die Blutlinien-Logik eine bewusst gesetzte Rolle NIE wieder.
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
  UPDATE public.mitgliedschaften SET rolle = p_rolle, auto = false WHERE id = p_mid;  -- auto=false -> manuell, geschützt
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.mitglied_rolle_setzen(uuid, text) TO authenticated;

-- 2) Personen einer Familie für das Verknüpfungs-Dropdown bei der Genehmigung.
--    Nur Admin/Owner der Familie (oder Super-Admin) darf die Liste sehen.
CREATE OR REPLACE FUNCTION public.personen_fuer_verknuepfung(p_familie uuid)
RETURNS TABLE(id uuid, name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT pe.id,
         trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,''))
           || coalesce(' (* ' || (pe.stammbaum_daten->>'birth_date') || ')', '') AS name
  FROM public.personen pe
  WHERE pe.familie_id = p_familie
    AND (public.ist_super_admin() OR public.kann_familie_bearbeiten(p_familie))
  ORDER BY pe.nachname, pe.vorname;
$$;
GRANT EXECUTE ON FUNCTION public.personen_fuer_verknuepfung(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Blutlinie Phase 2: mitglied_rolle_setzen(auto=false) + personen_fuer_verknuepfung' AS status;
