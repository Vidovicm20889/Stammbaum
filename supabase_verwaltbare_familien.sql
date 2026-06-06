-- =====================================================
-- BUGFIX: vollständige, berechtigungsbasierte Familienliste fürs
-- „Upravljanje članovima"-Dropdown (Porodica).
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Problem vorher: Das Dropdown wurde aus mitglieder_verwaltbar abgeleitet -> eine
-- Familie erschien nur, wenn sie mindestens eine (sichtbare) Mitglieds-Zeile hatte.
-- Familien ohne Mitglieder fehlten – auch beim Super-Admin.
--
-- Diese RPC liefert die Familien direkt aus der familien-Tabelle, rollenbasiert:
--   super_admin                       -> ALLE Familien
--   familien_owner / familien_admin   -> alle Familien, in denen der User diese
--                                        (aktive) Rolle hat
--
-- ZUSATZ (ab Version 10.1): baum_namen = kommaseparierte Liste der Stammbäume
-- (stammbaeume) DIESER Familie. Hintergrund: Rollen sind familien-gebunden, das
-- Dropdown zeigt Familien-NAMEN. Ein Stammbaum kann aber anders heißen als seine
-- Familie (z. B. ein bei Heirat entstandener Zweigbaum „Stojanović" innerhalb der
-- Familie „Vidović"). Damit der Admin die Familie auch über den BAUM-Namen findet,
-- liefern wir die Baum-Namen mit; das Frontend hängt sie an das Such-Label.
-- =====================================================

DROP FUNCTION IF EXISTS public.verwaltbare_familien();
CREATE OR REPLACE FUNCTION public.verwaltbare_familien()
RETURNS TABLE(familie_id uuid, familie_name text, baum_namen text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT f.id, f.name,
    (SELECT string_agg(DISTINCT s.name, ', ' ORDER BY s.name)
       FROM public.stammbaeume s WHERE s.familie_id = f.id) AS baum_namen
  FROM public.familien f
  WHERE public.ist_super_admin()
     OR f.id IN (
        SELECT m.familie_id FROM public.mitgliedschaften m
        WHERE m.user_id = auth.uid()
          AND m.rolle IN ('familien_owner', 'familien_admin')
          AND m.aktiv
     )
  ORDER BY f.name;
$$;
GRANT EXECUTE ON FUNCTION public.verwaltbare_familien() TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'verwaltbare_familien (rollenbasierte, vollständige Familienliste) angelegt' AS status;
