-- =====================================================
-- MITGLIEDER-VERWALTUNG — KOMPLETT (in einem Rutsch ausführen)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
-- Voraussetzung: supabase_verbund.sql wurde bereits ausgeführt (verbund_id vorhanden).
-- =====================================================

-- 1) aktiv-Flag + Schutz gegen Doppel-Mitgliedschaften
ALTER TABLE public.mitgliedschaften ADD COLUMN IF NOT EXISTS aktiv boolean NOT NULL DEFAULT true;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mitgliedschaften_user_familie_uniq') THEN
    ALTER TABLE public.mitgliedschaften
      ADD CONSTRAINT mitgliedschaften_user_familie_uniq UNIQUE (user_id, familie_id);
  END IF;
END $$;

-- 2) Helper: nur AKTIVE Mitgliedschaften geben Rechte
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

-- 3) Mitglieder auflisten (mit E-Mail + Name aus Registrierungs-Anfrage, falls vorhanden)
DROP FUNCTION IF EXISTS public.mitglieder_verwaltbar();
CREATE OR REPLACE FUNCTION public.mitglieder_verwaltbar()
RETURNS TABLE (
  mitgliedschaft_id uuid, user_id uuid, email text, name text,
  rolle text, familie_id uuid, familie_name text, aktiv boolean
)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT m.id, m.user_id, u.email,
    trim(coalesce(ra.vorname,'') || ' ' || coalesce(ra.nachname,'')) AS name,
    m.rolle, m.familie_id, f.name, m.aktiv
  FROM public.mitgliedschaften m
  JOIN auth.users u      ON u.id = m.user_id
  JOIN public.familien f  ON f.id = m.familie_id
  LEFT JOIN LATERAL (
    SELECT vorname, nachname FROM public.registrierungs_anfragen r
    WHERE lower(r.email) = lower(u.email) ORDER BY r.created_at DESC LIMIT 1
  ) ra ON true
  WHERE public.ist_super_admin()
     OR m.familie_id IN (
       SELECT familie_id FROM public.mitgliedschaften
       WHERE user_id = auth.uid() AND rolle = 'familien_admin' AND aktiv
     )
  ORDER BY f.name, (NOT m.aktiv), u.email;
$$;
GRANT EXECUTE ON FUNCTION public.mitglieder_verwaltbar() TO authenticated;

-- 4) User per E-Mail finden (zum Hinzufügen)
CREATE OR REPLACE FUNCTION public.user_per_email(p_email text)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT id FROM auth.users WHERE lower(email) = lower(trim(p_email)) LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.user_per_email(text) TO authenticated;

-- 5) PostgREST-Schema-Cache neu laden (sonst evtl. PGRST202)
NOTIFY pgrst, 'reload schema';

-- Kontrolle
SELECT 'Mitglieder-Verwaltung komplett angelegt' AS status;
