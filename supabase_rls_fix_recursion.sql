-- =====================================================
-- FIX: "infinite recursion detected in policy for relation mitgliedschaften" (42P17)
-- Ausführen in: Supabase -> SQL Editor
-- WICHTIG: Editor komplett leeren, NUR diesen Inhalt einfügen, dann Run.
--
-- Strategie: ALLE Policies auf mitgliedschaften entfernen (egal welcher Name),
-- danach rekursionssicher neu aufbauen. Die SELECT-Policy nutzt KEINE Funktion
-- und KEINE Subquery auf mitgliedschaften -> Rekursion ist technisch unmoeglich.
-- =====================================================


-- 1) Helper-Funktionen sicher als SECURITY DEFINER (fuer die Write-Policies)
CREATE OR REPLACE FUNCTION public.get_meine_rolle(p_familie_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT rolle FROM public.mitgliedschaften
  WHERE user_id = auth.uid() AND familie_id = p_familie_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.ist_super_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid() AND rolle = 'super_admin'
  );
$$;


-- 2) ALLE vorhandenen Policies auf mitgliedschaften entfernen (dynamisch, egal welcher Name)
DO $$
DECLARE pol record;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'mitgliedschaften'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.mitgliedschaften', pol.policyname);
  END LOOP;
END $$;


-- 3) GENAU EINE SELECT-Policy: jeder liest nur seine eigene(n) Zeile(n).
--    KEINE Funktion, KEINE Subquery -> keine Rekursion. Das ist alles,
--    was die App zum Laden der Rolle braucht.
CREATE POLICY "mitglied_select_eigene" ON public.mitgliedschaften
FOR SELECT USING ( user_id = auth.uid() );


-- 4) Write-Policies (INSERT/UPDATE/DELETE) ueber die SECURITY-DEFINER-Funktionen.
--    Diese betreffen NUR Schreiboperationen, nicht das SELECT -> keine Rekursion
--    beim Laden der Rolle.
CREATE POLICY "mitglied_insert" ON public.mitgliedschaften
FOR INSERT WITH CHECK (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

CREATE POLICY "mitglied_update" ON public.mitgliedschaften
FOR UPDATE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

CREATE POLICY "mitglied_delete" ON public.mitgliedschaften
FOR DELETE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);


-- 5) Kontrolle: sollte GENAU diese 4 Policies zeigen (select/insert/update/delete)
SELECT policyname, cmd FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'mitgliedschaften'
ORDER BY cmd;
