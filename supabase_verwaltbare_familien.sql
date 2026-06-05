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
-- =====================================================

DROP FUNCTION IF EXISTS public.verwaltbare_familien();
CREATE OR REPLACE FUNCTION public.verwaltbare_familien()
RETURNS TABLE(familie_id uuid, familie_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT f.id, f.name
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
