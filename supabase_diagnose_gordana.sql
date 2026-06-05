-- =====================================================
-- DIAGNOSE (NUR LESEN — ändert nichts): Gordana / Mićo-Dubletten + Junk-Bäume
-- Ausführen in: Supabase -> SQL Editor. Ergebnisse der 5 Blöcke zurückschicken.
-- =====================================================

-- ---------- A) MERGE-LOG: was wurde zuletzt gemergt/gelöscht? (Backup für Restore) ----------
SELECT id AS log_id, erstellt_am, rueckgaengig,
       behalten_id,
       dublette_id,
       dublette_person->>'vorname' AS dub_vorname,
       dublette_person->>'nachname' AS dub_nachname,
       dublette_person->'stammbaum_daten'->>'birth_date' AS dub_geboren,
       dublette_person->>'stammbaum_id' AS dub_stammbaum_id,
       jsonb_array_length(coalesce(dublette_kanten,'[]'::jsonb)) AS anzahl_kanten
FROM public.merge_log
ORDER BY erstellt_am DESC
LIMIT 30;

-- ---------- B) VERKNÜPFUNGS-ANTRÄGE (was wurde versucht/ausgeführt?) ----------
SELECT id, created_at, modus, bez_typ, status,
       kontext_person, ziel_person, quelle_familie, ziel_familie, quelle_baum
FROM public.verknuepfungs_anfragen
ORDER BY created_at DESC
LIMIT 30;

-- ---------- C) Alle GORDANA- und MIĆO-Karten: wo liegen sie, welcher Baum/Verbund? ----------
SELECT pe.id,
       trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS person,
       pe.stammbaum_daten->>'birth_date'  AS geboren,
       pe.stammbaum_daten->>'geburtsland' AS geburtsland,
       s.name  AS baum,
       f.name  AS familie,
       f.verbund_id,
       (SELECT count(*) FROM public.beziehungen b WHERE b.person_a = pe.id OR b.person_b = pe.id) AS kanten
FROM public.personen pe
LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
LEFT JOIN public.familien    f ON f.id = pe.familie_id
WHERE (pe.vorname ILIKE 'Gord%')
   OR (pe.vorname ILIKE 'Mi_o' AND pe.nachname ILIKE 'Vidovi%')
   OR (pe.vorname ILIKE 'Mico' AND pe.nachname ILIKE 'Vidovi%')
ORDER BY person, baum;

-- ---------- D) Beziehungen dieser Karten (woran hängen sie?) ----------
WITH ziel AS (
  SELECT pe.id FROM public.personen pe
  WHERE (pe.vorname ILIKE 'Gord%')
     OR (pe.vorname ILIKE 'Mi_o' AND pe.nachname ILIKE 'Vidovi%')
)
SELECT trim(coalesce(pa.vorname,'')||' '||coalesce(pa.nachname,'')) AS person_a,
       b.typ,
       trim(coalesce(pb.vorname,'')||' '||coalesce(pb.nachname,'')) AS person_b,
       fa.name AS baum_a, fb.name AS baum_b
FROM public.beziehungen b
JOIN public.personen pa ON pa.id = b.person_a
JOIN public.personen pb ON pb.id = b.person_b
LEFT JOIN public.stammbaeume fa ON fa.id = pa.stammbaum_id
LEFT JOIN public.stammbaeume fb ON fb.id = pb.stammbaum_id
WHERE b.person_a IN (SELECT id FROM ziel) OR b.person_b IN (SELECT id FROM ziel)
ORDER BY person_a, b.typ;

-- ---------- E) ALLE Stammbäume mit Personenzahl (Junk-/leere Bäume erkennen) ----------
SELECT s.id AS stammbaum_id, s.name AS baum, f.name AS familie, f.verbund_id,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
FROM public.stammbaeume s
LEFT JOIN public.familien f ON f.id = s.familie_id
ORDER BY personen ASC, baum;
