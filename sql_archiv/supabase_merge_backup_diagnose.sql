-- =====================================================
-- MERGE Dujković/Pisarević -> Vidović-Netzwerk: BACKUP + DIAGNOSE
-- Ausführen in: Supabase -> SQL Editor. NUR Backup + Lesen, ändert nichts am Baum.
-- Schritt 1 (Backup) und Schritt 2 (Diagnose) ausführen, Ergebnis schicken.
-- =====================================================

-- ---------- 1) BACKUP (vor jeder Änderung) ----------
DROP TABLE IF EXISTS public.bak_merge_personen;
DROP TABLE IF EXISTS public.bak_merge_beziehungen;
CREATE TABLE public.bak_merge_personen    AS SELECT * FROM public.personen;
CREATE TABLE public.bak_merge_beziehungen AS SELECT * FROM public.beziehungen;
SELECT (SELECT count(*) FROM public.bak_merge_personen)    AS personen_gesichert,
       (SELECT count(*) FROM public.bak_merge_beziehungen) AS beziehungen_gesichert;
-- (Rollback später nötig? -> aus diesen bak_-Tabellen wiederherstellen.)

-- ---------- 2) DIAGNOSE (nur lesen) ----------
-- a) Die drei Familien/Bäume + Verbund (sind sie wirklich im selben Verbund?)
SELECT f.id AS familie_id, f.name AS familie, f.verbund_id, s.id AS stammbaum_id, s.name AS stammbaum
FROM public.familien f
LEFT JOIN public.stammbaeume s ON s.familie_id = f.id
WHERE f.name ILIKE 'Vidovi%' OR f.name ILIKE 'Pisarevi%' OR f.name ILIKE 'Dujkovi%'
ORDER BY f.name;

-- b) Verknüpfungs-Personen (Mićo/Mico Dujković, Desa Pisarević). Mehrere Treffer = mögliche Dublette!
SELECT pe.id, trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS person,
       f.name AS familie, pe.stammbaum_daten->>'birth_date' AS geboren,
       (SELECT count(*) FROM public.beziehungen b WHERE b.person_a = pe.id OR b.person_b = pe.id) AS beziehungen
FROM public.personen pe
LEFT JOIN public.familien f ON f.id = pe.familie_id
WHERE (pe.vorname ILIKE 'Mi_o' AND pe.nachname ILIKE 'Dujkovi%')      -- Mićo ODER Mico
   OR (pe.vorname ILIKE 'Desa' AND pe.nachname ILIKE 'Pisarevi%')
ORDER BY pe.nachname, f.name;

-- c) Bestehende Beziehungen dieser Personen (woran hängen sie schon?)
WITH ziel AS (
  SELECT id FROM public.personen
  WHERE (vorname ILIKE 'Mi_o' AND nachname ILIKE 'Dujkovi%')
     OR (vorname ILIKE 'Desa' AND nachname ILIKE 'Pisarevi%')
)
SELECT trim(coalesce(pa.vorname,'')||' '||coalesce(pa.nachname,'')) AS person_a,
       b.typ,
       trim(coalesce(pb.vorname,'')||' '||coalesce(pb.nachname,'')) AS person_b
FROM public.beziehungen b
JOIN public.personen pa ON pa.id = b.person_a
JOIN public.personen pb ON pb.id = b.person_b
WHERE b.person_a IN (SELECT id FROM ziel) OR b.person_b IN (SELECT id FROM ziel);
