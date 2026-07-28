-- =====================================================
-- ZUGANGSANFRAGEN Phase 2 — SQL-Helfer für die Edge Functions
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
-- =====================================================

-- Liefert die E-Mail-Adressen aller Admins, die über eine Anfrage informiert
-- werden sollen: ALLE Super-Admins + die Familien-Admins der betroffenen Familie.
-- SECURITY DEFINER -> darf auf auth.users zugreifen. Aufruf durch die Edge
-- Function erfolgt mit Service-Role-Key.
CREATE OR REPLACE FUNCTION public.admin_emails_fuer_familie(p_familie_id uuid)
RETURNS TABLE (email text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT DISTINCT u.email
  FROM public.mitgliedschaften m
  JOIN auth.users u ON u.id = m.user_id
  WHERE m.rolle = 'super_admin'
     OR (m.rolle = 'familien_admin' AND m.familie_id = p_familie_id);
$$;

GRANT EXECUTE ON FUNCTION public.admin_emails_fuer_familie(uuid) TO service_role;

-- Kontrolle
SELECT 'admin_emails_fuer_familie angelegt' AS status;
