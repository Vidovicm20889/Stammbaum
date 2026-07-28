-- =====================================================
-- MITGLIEDER-VERWALTUNG (Erweiterung) — Deaktivieren statt nur Löschen
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Neu: Spalte mitgliedschaften.aktiv. Deaktivierte Mitgliedschaften zählen
-- NICHT mehr als Zugang -> die Helper-Funktionen berücksichtigen aktiv.
-- =====================================================

-- 1) aktiv-Flag (default true)
ALTER TABLE public.mitgliedschaften ADD COLUMN IF NOT EXISTS aktiv boolean NOT NULL DEFAULT true;

-- 2) Helper-Funktionen: nur AKTIVE Mitgliedschaften geben Rechte
CREATE OR REPLACE FUNCTION public.get_meine_rolle(p_familie_id uuid)
RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT rolle FROM public.mitgliedschaften
  WHERE user_id = auth.uid() AND familie_id = p_familie_id AND aktiv
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.ist_super_admin()
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid() AND rolle = 'super_admin' AND aktiv
  );
$$;

CREATE OR REPLACE FUNCTION public.sieht_familie(p_familie_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mitgliedschaften m
    JOIN public.familien fm ON fm.id = m.familie_id
    WHERE m.user_id = auth.uid() AND m.aktiv
      AND fm.verbund_id = (SELECT verbund_id FROM public.familien WHERE id = p_familie_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.kann_familie_bearbeiten(p_familie_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT public.ist_super_admin() OR EXISTS (
    SELECT 1 FROM public.mitgliedschaften m
    JOIN public.familien fm ON fm.id = m.familie_id
    WHERE m.user_id = auth.uid() AND m.rolle = 'familien_admin' AND m.aktiv
      AND fm.verbund_id = (SELECT verbund_id FROM public.familien WHERE id = p_familie_id)
  );
$$;

-- 3) Liste um aktiv-Status erweitern (Verwalter-Check ebenfalls nur aktiv)
DROP FUNCTION IF EXISTS public.mitglieder_verwaltbar();
CREATE OR REPLACE FUNCTION public.mitglieder_verwaltbar()
RETURNS TABLE (
  mitgliedschaft_id uuid, user_id uuid, email text, rolle text,
  familie_id uuid, familie_name text, aktiv boolean
)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT m.id, m.user_id, u.email, m.rolle, m.familie_id, f.name, m.aktiv
  FROM public.mitgliedschaften m
  JOIN auth.users u      ON u.id = m.user_id
  JOIN public.familien f  ON f.id = m.familie_id
  WHERE public.ist_super_admin()
     OR m.familie_id IN (
       SELECT familie_id FROM public.mitgliedschaften
       WHERE user_id = auth.uid() AND rolle = 'familien_admin' AND aktiv
     )
  ORDER BY f.name, (NOT m.aktiv), u.email;
$$;
GRANT EXECUTE ON FUNCTION public.mitglieder_verwaltbar() TO authenticated;

-- Kontrolle
SELECT 'mitgliedschaften.aktiv + Helper aktualisiert' AS status;
