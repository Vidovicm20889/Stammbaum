-- Aufräum-Kandidaten (NUR LESEN): wirklich leere Bäume + Familien ohne Baum/Personen.
-- Ergebnis = eine JSON-Zelle: anklicken -> Strg+C -> schicken.
SELECT jsonb_pretty(jsonb_build_object(
  'leere_baeume', (SELECT coalesce(jsonb_agg(t),'[]'::jsonb) FROM (
     SELECT s.id, s.name, s.familie_id
     FROM public.stammbaeume s
     WHERE NOT EXISTS (SELECT 1 FROM public.personen p WHERE p.stammbaum_id = s.id)
     ORDER BY s.name) t),
  'geister_familien', (SELECT coalesce(jsonb_agg(t),'[]'::jsonb) FROM (
     SELECT f.id, f.name,
            (SELECT count(*) FROM public.mitgliedschaften m WHERE m.familie_id = f.id) AS mitglieder
     FROM public.familien f
     WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
       AND NOT EXISTS (SELECT 1 FROM public.personen   p WHERE p.familie_id  = f.id)
     ORDER BY f.name) t)
)) AS ergebnis;
