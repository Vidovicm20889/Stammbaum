-- =====================================================
-- KREIRAJ NALOG: strikter Baum-Abgleich beim Anlegen eines Kontos
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Liefert eine vorhandene Familie zurück, wenn ALLE VIER Felder übereinstimmen:
--   Naziv stabla (familien.name), Država (land), Grad/selo (stadt), Opština (gemeinde).
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

-- Striktes 4-Felder-Matching. Leere Eingaben matchen nur leere Felder
-- (merge_norm('') = ''), d.h. ein vollständig ausgefülltes Formular trifft
-- nur einen ebenso vollständig ausgefüllten Datensatz.
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
    AND public.merge_norm(f.stadt)    = public.merge_norm(p_stadt)
    AND public.merge_norm(f.gemeinde) = public.merge_norm(p_gemeinde)
  ORDER BY f.name
  LIMIT 5;
$$;
GRANT EXECUTE ON FUNCTION public.familie_finden_exakt(text, text, text, text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'familie_finden_exakt (strikter 4-Felder-Match, merge_norm) angelegt' AS status;
