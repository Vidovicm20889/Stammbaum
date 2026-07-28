-- =====================================================
-- FIX: stammbaum_loeschen räumt jetzt auch familien + mitgliedschaften ab
-- + Bereinigung bereits verwaister Familien (z. B. Testeric-Rest).
-- Ausführen in: Supabase -> SQL Editor.
-- =====================================================

-- ---------------------------------------------------------------
-- TEIL 1 — BEREINIGEN: verwaiste Familien (kein Baum, keine Personen)
-- entfernen. Familien mit super_admin-Mitgliedschaft bleiben unangetastet.
-- ---------------------------------------------------------------
DO $$
DECLARE v_ids uuid[];
BEGIN
  SELECT array_agg(f.id) INTO v_ids FROM public.familien f
  WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
    AND NOT EXISTS (SELECT 1 FROM public.personen    p WHERE p.familie_id = f.id)
    AND NOT EXISTS (SELECT 1 FROM public.mitgliedschaften m
                    WHERE m.familie_id = f.id AND m.rolle = 'super_admin');
  IF v_ids IS NULL THEN RAISE NOTICE 'Keine verwaisten Familien.'; RETURN; END IF;
  DELETE FROM public.registrierungs_anfragen WHERE familie_id = ANY(v_ids);
  DELETE FROM public.beziehungen             WHERE familie_id = ANY(v_ids);
  DELETE FROM public.mitgliedschaften        WHERE familie_id = ANY(v_ids);
  DELETE FROM public.familien                WHERE id = ANY(v_ids);
  RAISE NOTICE 'Verwaiste Familien entfernt: %', array_length(v_ids,1);
END $$;

-- ---------------------------------------------------------------
-- TEIL 2 — FUNKTION: beim Löschen des LETZTEN Baums einer Familie
-- auch Familie + Mitgliedschaften (+ Anfragen) entfernen.
-- Schutz: Familien mit super_admin-Mitgliedschaft (Haupt-Account)
-- werden NICHT gelöscht.
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.stammbaum_loeschen(p_tree uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_count integer; v_rest integer; v_hat_super boolean;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.get_meine_rolle(v_fam) = 'familien_owner') THEN
    RAISE EXCEPTION 'Nur der Eigentümer (familien_owner) darf den Stammbaum löschen.';
  END IF;

  -- 1) Beziehungen, die eine Person dieses Baums berühren
  DELETE FROM public.beziehungen b
  WHERE b.person_a IN (SELECT id FROM public.personen WHERE stammbaum_id = p_tree)
     OR b.person_b IN (SELECT id FROM public.personen WHERE stammbaum_id = p_tree);

  -- 2) Personen des Baums
  WITH del AS (DELETE FROM public.personen WHERE stammbaum_id = p_tree RETURNING 1)
  SELECT count(*) INTO v_count FROM del;

  -- 3) Den Baum selbst
  DELETE FROM public.stammbaeume WHERE id = p_tree;

  -- 4) Hat die Familie keinen weiteren Baum mehr UND keinen super_admin
  --    -> Familie komplett abräumen (sonst bleibt eine leere Familie zurück).
  SELECT count(*) INTO v_rest FROM public.stammbaeume WHERE familie_id = v_fam;
  SELECT EXISTS (SELECT 1 FROM public.mitgliedschaften
                 WHERE familie_id = v_fam AND rolle = 'super_admin') INTO v_hat_super;

  IF v_rest = 0 AND NOT v_hat_super THEN
    DELETE FROM public.beziehungen           WHERE familie_id = v_fam;
    DELETE FROM public.personen              WHERE familie_id = v_fam;
    DELETE FROM public.registrierungs_anfragen WHERE familie_id = v_fam;
    DELETE FROM public.mitgliedschaften      WHERE familie_id = v_fam;
    DELETE FROM public.familien              WHERE id = v_fam;
  END IF;

  RETURN v_count;
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_loeschen(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'stammbaum_loeschen erweitert + verwaiste Familien bereinigt' AS status;
