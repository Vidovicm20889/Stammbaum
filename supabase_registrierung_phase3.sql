-- =====================================================
-- ZUGANGSANFRAGEN Phase 3 — Familien-Standort + Familien-Suche
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
-- =====================================================

-- 1) Neue (optionale) Standort-Spalten an den Familien
ALTER TABLE public.familien ADD COLUMN IF NOT EXISTS land     text;
ALTER TABLE public.familien ADD COLUMN IF NOT EXISTS stadt    text;
ALTER TABLE public.familien ADD COLUMN IF NOT EXISTS gemeinde text;

-- 2) Antrags-Tabelle um die Filterangaben des Antragstellers erweitern
ALTER TABLE public.registrierungs_anfragen ADD COLUMN IF NOT EXISTS stadt    text;
ALTER TABLE public.registrierungs_anfragen ADD COLUMN IF NOT EXISTS gemeinde text;

-- 3) "land" automatisch aus den Geburtsorten der Mitglieder befüllen
--    (häufigster nicht-leerer Wert je Familie). Robust über mögliche JSON-Schlüssel.
WITH bp AS (
  SELECT familie_id,
    COALESCE(NULLIF(stammbaum_daten->>'birth_place',''),
             NULLIF(stammbaum_daten->>'geburtsort',''),
             NULLIF(stammbaum_daten->>'geburtsland','')) AS ort
  FROM public.personen
),
gez AS (
  SELECT familie_id, ort, count(*) AS n
  FROM bp WHERE ort IS NOT NULL
  GROUP BY familie_id, ort
),
top AS (
  SELECT DISTINCT ON (familie_id) familie_id, ort
  FROM gez ORDER BY familie_id, n DESC
)
UPDATE public.familien f SET land = top.ort
FROM top
WHERE f.id = top.familie_id AND (f.land IS NULL OR f.land = '');

-- 4) Öffentliche Familienliste um die Standort-Spalten erweitern
--    (DROP nötig, weil sich die Rückgabespalten ändern)
DROP FUNCTION IF EXISTS public.oeffentliche_familien();
CREATE OR REPLACE FUNCTION public.oeffentliche_familien()
RETURNS TABLE (id uuid, name text, land text, stadt text, gemeinde text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT id, name, land, stadt, gemeinde FROM public.familien ORDER BY name;
$$;
GRANT EXECUTE ON FUNCTION public.oeffentliche_familien() TO anon, authenticated;

-- 5) Familien-Suche: ODER-Verknüpfung über Standort-Spalten UND Geburtsorte der
--    Mitglieder; zusätzlich Namensfilter (p_query). Wenn keine Standortangabe
--    gemacht wurde, werden alle Familien (nur nach Name gefiltert) zurückgegeben.
CREATE OR REPLACE FUNCTION public.suche_familien(
  p_land      text DEFAULT NULL,
  p_stadt     text DEFAULT NULL,
  p_gemeinde  text DEFAULT NULL,
  p_geburtsort text DEFAULT NULL,
  p_query     text DEFAULT NULL
)
RETURNS TABLE (id uuid, name text, land text, stadt text, gemeinde text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT f.id, f.name, f.land, f.stadt, f.gemeinde
  FROM public.familien f
  WHERE
    (
      (NULLIF(p_land,'')     IS NOT NULL AND f.land     ILIKE '%'||p_land||'%')     OR
      (NULLIF(p_stadt,'')    IS NOT NULL AND f.stadt    ILIKE '%'||p_stadt||'%')    OR
      (NULLIF(p_gemeinde,'') IS NOT NULL AND f.gemeinde ILIKE '%'||p_gemeinde||'%') OR
      EXISTS (
        SELECT 1 FROM public.personen pe
        WHERE pe.familie_id = f.id AND pe.geloescht_am IS NULL AND (
          (NULLIF(p_geburtsort,'') IS NOT NULL AND
            COALESCE(pe.stammbaum_daten->>'birth_place', pe.stammbaum_daten->>'geburtsort','')
              ILIKE '%'||p_geburtsort||'%') OR
          (NULLIF(p_land,'') IS NOT NULL AND
            COALESCE(pe.stammbaum_daten->>'birth_place', pe.stammbaum_daten->>'geburtsort','')
              ILIKE '%'||p_land||'%')
        )
      ) OR
      (COALESCE(p_land,'')='' AND COALESCE(p_stadt,'')='' AND
       COALESCE(p_gemeinde,'')='' AND COALESCE(p_geburtsort,'')='')
    )
    AND (NULLIF(p_query,'') IS NULL OR f.name ILIKE '%'||p_query||'%')
  ORDER BY f.name
  LIMIT 20;
$$;
GRANT EXECUTE ON FUNCTION public.suche_familien(text,text,text,text,text) TO anon, authenticated;

-- Kontrolle
SELECT id, name, land, stadt, gemeinde FROM public.familien ORDER BY name;
