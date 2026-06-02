-- =====================================================
-- STAMMBAUM KOMPLETT LÖSCHEN — SECURITY DEFINER RPC
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Löscht einen ganzen Stammbaum restlos:
--   1. alle beziehungen, die eine Person dieses Baums berühren
--   2. alle personen des Baums (stammbaum_id = p_tree)
--   3. den stammbaeume-Eintrag selbst
--
-- Berechtigung: super_admin ODER familien_admin der Familie des Baums
-- (kann_familie_bearbeiten). Läuft als SECURITY DEFINER, damit auch
-- Familien-Admins löschen können (die stammbaeume-DELETE-RLS erlaubt sonst
-- nur Super-Admin).
-- Voraussetzung: kann_familie_bearbeiten() existiert (supabase_verbund.sql).
-- =====================================================

CREATE OR REPLACE FUNCTION public.stammbaum_loeschen(p_tree uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_count integer;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  -- 1) Beziehungen entfernen, die eine Person dieses Baums berühren
  --    (auch baumübergreifende Kanten, deren ein Ende hier liegt)
  DELETE FROM public.beziehungen b
  WHERE b.person_a IN (SELECT id FROM public.personen WHERE stammbaum_id = p_tree)
     OR b.person_b IN (SELECT id FROM public.personen WHERE stammbaum_id = p_tree);

  -- 2) Personen des Baums löschen (Anzahl merken)
  WITH del AS (DELETE FROM public.personen WHERE stammbaum_id = p_tree RETURNING 1)
  SELECT count(*) INTO v_count FROM del;

  -- 3) Den Baum-Eintrag selbst löschen
  DELETE FROM public.stammbaeume WHERE id = p_tree;

  RETURN v_count;
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_loeschen(uuid) TO authenticated;

-- PostgREST-Schema-Cache neu laden (sonst evtl. PGRST202)
NOTIFY pgrst, 'reload schema';

SELECT 'stammbaum_loeschen angelegt' AS status;
