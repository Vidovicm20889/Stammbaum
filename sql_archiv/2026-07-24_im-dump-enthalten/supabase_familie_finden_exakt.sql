-- =====================================================
-- KREIRAJ NALOG: strikter Baum-Abgleich beim Anlegen eines Kontos
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Liefert eine vorhandene Familie zurück, wenn DREI Felder übereinstimmen:
--   Naziv stabla (familien.name), Država (land), Opština (gemeinde).
-- Grad/selo (p_stadt) ist seit v13.9 NICHT mehr Pflicht und NICHT mehr Teil des
--   Abgleichs (Parameter bleibt nur aus Signatur-Kompatibilität zum Frontend erhalten).
-- Vergleich diakritik- und groß-/klein-unempfindlich über merge_norm()
--   (ć č š ž đ -> c c s z d, lower, trim). Voraussetzung: supabase_merge_gui.sql
--   stellt merge_norm() bereit; zur Sicherheit hier noch einmal idempotent angelegt.
-- Für anon UND authenticated freigegeben (Prüfung läuft VOR dem Login).
-- =====================================================

-- Namens-/Ortsnormalisierung (identisch zu merge_norm; idempotent absichern)
CREATE OR REPLACE FUNCTION public.merge_norm(p_txt text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT translate(lower(trim(coalesce(p_txt,''))), 'ćčšžđ', 'ccszd');
$$;

-- 3-Felder-Matching (Name + Land + Gemeinde). Leere Eingaben matchen nur leere
-- Felder (merge_norm('') = ''). p_stadt wird bewusst NICHT mehr verglichen.
DROP FUNCTION IF EXISTS public.familie_finden_exakt(text, text, text, text);
CREATE OR REPLACE FUNCTION public.familie_finden_exakt(
  p_name     text,
  p_land     text,
  p_stadt    text,
  p_gemeinde text
)
RETURNS TABLE(id uuid, name text, land text, stadt text, gemeinde text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT f.id, f.name, f.land, f.stadt, f.gemeinde
  FROM public.familien f
  WHERE public.merge_norm(f.name)     = public.merge_norm(p_name)
    AND public.merge_norm(f.land)     = public.merge_norm(p_land)
    AND public.merge_norm(f.gemeinde) = public.merge_norm(p_gemeinde)
  ORDER BY f.name
  LIMIT 5;
$$;
GRANT EXECUTE ON FUNCTION public.familie_finden_exakt(text, text, text, text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'familie_finden_exakt (3-Felder-Match Name/Land/Gemeinde, merge_norm) angelegt' AS status;
