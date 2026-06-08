-- Welche Backup-Bäume/-Familien fehlen heute? + alle aktuellen Bäume (für das Remapping).
-- Ergebnis = eine JSON-Zelle: anklicken -> Strg+C -> schicken. (Nur lesen.)
SELECT jsonb_pretty(jsonb_build_object(
  'fehlende_baeume', (SELECT coalesce(jsonb_agg(t),'[]'::jsonb) FROM (
     SELECT b.stammbaum_id, count(*) AS personen,
            string_agg(DISTINCT b.nachname, ', ') AS nachnamen
     FROM public.bak_merge_personen b
     WHERE b.stammbaum_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.id = b.stammbaum_id)
     GROUP BY b.stammbaum_id) t),
  'fehlende_familien', (SELECT coalesce(jsonb_agg(t),'[]'::jsonb) FROM (
     SELECT b.familie_id, count(*) AS personen,
            string_agg(DISTINCT b.nachname, ', ') AS nachnamen
     FROM public.bak_merge_personen b
     WHERE b.familie_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.familien f WHERE f.id = b.familie_id)
     GROUP BY b.familie_id) t),
  'aktuelle_baeume', (SELECT coalesce(jsonb_agg(t),'[]'::jsonb) FROM (
     SELECT s.id, s.name, s.familie_id FROM public.stammbaeume s ORDER BY s.name) t),
  'aktuelle_familien', (SELECT coalesce(jsonb_agg(t),'[]'::jsonb) FROM (
     SELECT f.id, f.name FROM public.familien f ORDER BY f.name) t)
)) AS ergebnis;
