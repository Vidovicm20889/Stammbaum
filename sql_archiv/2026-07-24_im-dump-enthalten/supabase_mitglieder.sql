-- =====================================================
-- MITGLIEDER-VERWALTUNG — RPCs für das Admin-Panel
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Sichtbarkeit/Verwaltung:
--   super_admin   -> alle Familien
--   familien_admin -> nur die EIGENE(n) Familie(n) (wo er familien_admin ist)
-- Schreiben (Rolle ändern / entfernen / hinzufügen) regelt die bestehende
-- mitgliedschaften-RLS (super_admin oder familien_admin der familie).
-- =====================================================

-- 1) Verwaltbare Mitglieder (mit E-Mail) auflisten
CREATE OR REPLACE FUNCTION public.mitglieder_verwaltbar()
RETURNS TABLE (
  mitgliedschaft_id uuid,
  user_id           uuid,
  email             text,
  rolle             text,
  familie_id        uuid,
  familie_name      text
)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT m.id, m.user_id, u.email, m.rolle, m.familie_id, f.name
  FROM public.mitgliedschaften m
  JOIN auth.users u     ON u.id = m.user_id
  JOIN public.familien f ON f.id = m.familie_id
  WHERE public.ist_super_admin()
     OR m.familie_id IN (
       SELECT familie_id FROM public.mitgliedschaften
       WHERE user_id = auth.uid() AND rolle = 'familien_admin'
     )
  ORDER BY f.name, u.email;
$$;
GRANT EXECUTE ON FUNCTION public.mitglieder_verwaltbar() TO authenticated;

-- 2) Vorhandenen User per E-Mail finden (zum Hinzufügen). Liefert id oder NULL.
CREATE OR REPLACE FUNCTION public.user_per_email(p_email text)
RETURNS uuid
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT id FROM auth.users WHERE lower(email) = lower(trim(p_email)) LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.user_per_email(text) TO authenticated;

-- 3) Doppel-Mitgliedschaften (gleicher User + gleiche Familie) verhindern
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mitgliedschaften_user_familie_uniq') THEN
    ALTER TABLE public.mitgliedschaften
      ADD CONSTRAINT mitgliedschaften_user_familie_uniq UNIQUE (user_id, familie_id);
  END IF;
END $$;

-- Kontrolle
SELECT 'mitglieder_verwaltbar + user_per_email angelegt' AS status;
