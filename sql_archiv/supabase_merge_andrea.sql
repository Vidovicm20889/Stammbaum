-- =====================================================
-- MERGE Andrea (Dubletten zusammenführen): Desa / Mićo Dujković / Gordana Dujković
-- Ausführen in: Supabase -> SQL Editor. Voraussetzung: supabase_person_merge.sql
-- (Funktion person_zusammenfuehren) + Backup (bak_merge_* aus der Diagnose-Datei).
--
-- WICHTIG: Teil 1 ZUERST prüfen! Sind die jeweils 2 Karten wirklich dieselbe Person?
-- person_zusammenfuehren hängt alle Beziehungen/Events/Konto der Dublette auf die
-- bleibende Karte um und löscht NUR die redundante Kopie (kein Datenverlust).
-- =====================================================

-- ---------- 1) SICHERHEITS-CHECK (nur lesen): Beziehungen der 6 betroffenen Karten ----------
WITH ids AS (
  SELECT unnest(ARRAY[
    '7d12816e-cd27-40a3-a710-c717edf5a3e1',  -- Desa (BLEIBT)
    'c9cbe6b2-c1f0-4066-a6b3-deb38723aa38',  -- Desa/Desanka (Dublette)
    '55de8c61-6f85-4570-bd26-1e0f75cc38dc',  -- Mićo Dujković (BLEIBT)
    'e0edbdcd-2d4b-47ea-b878-98131106948e',  -- Mićo Dujković (Dublette)
    '4ceaf37c-52e6-441b-a712-2a43c9ff005d',  -- Gordana Dujković (BLEIBT)
    'bab6cec0-080b-453b-a4ec-7308fca30e3f'   -- Gordana Dujković (Dublette)
  ]::uuid[]) AS pid
)
SELECT pk.id AS person_id, trim(coalesce(pk.vorname,'')||' '||coalesce(pk.nachname,'')) AS person,
       fk.name AS familie, b.typ,
       CASE WHEN b.person_a = pk.id THEN '→' ELSE '←' END AS richtung,
       trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')) AS partner, fo.name AS partner_familie
FROM ids i
JOIN public.personen pk ON pk.id = i.pid
LEFT JOIN public.familien fk ON fk.id = pk.familie_id
LEFT JOIN public.beziehungen b ON (b.person_a = pk.id OR b.person_b = pk.id)
LEFT JOIN public.personen po ON po.id = CASE WHEN b.person_a = pk.id THEN b.person_b ELSE b.person_a END
LEFT JOIN public.familien fo ON fo.id = po.familie_id
ORDER BY person, person_id, b.typ;

-- ---------- 2) MERGE (atomar) — erst ausführen, wenn Teil 1 passt ----------
BEGIN;
SELECT public.person_zusammenfuehren('7d12816e-cd27-40a3-a710-c717edf5a3e1','c9cbe6b2-c1f0-4066-a6b3-deb38723aa38'); -- Desa
SELECT public.person_zusammenfuehren('55de8c61-6f85-4570-bd26-1e0f75cc38dc','e0edbdcd-2d4b-47ea-b878-98131106948e'); -- Mićo Dujković
SELECT public.person_zusammenfuehren('4ceaf37c-52e6-441b-a712-2a43c9ff005d','bab6cec0-080b-453b-a4ec-7308fca30e3f'); -- Gordana
COMMIT;

-- ---------- 3) KONTROLLE: Beziehungen der 3 bleibenden Karten + Mićo Vidović finden ----------
WITH ids AS (
  SELECT unnest(ARRAY[
    '7d12816e-cd27-40a3-a710-c717edf5a3e1',  -- Desa
    '55de8c61-6f85-4570-bd26-1e0f75cc38dc',  -- Mićo Dujković
    '4ceaf37c-52e6-441b-a712-2a43c9ff005d'   -- Gordana
  ]::uuid[]) AS pid
)
SELECT trim(coalesce(pk.vorname,'')||' '||coalesce(pk.nachname,'')) AS person, fk.name AS familie,
       b.typ, CASE WHEN b.person_a = pk.id THEN '→' ELSE '←' END AS richtung,
       trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')) AS partner, fo.name AS partner_familie, po.id AS partner_id
FROM ids i
JOIN public.personen pk ON pk.id = i.pid
LEFT JOIN public.familien fk ON fk.id = pk.familie_id
LEFT JOIN public.beziehungen b ON (b.person_a = pk.id OR b.person_b = pk.id)
LEFT JOIN public.personen po ON po.id = CASE WHEN b.person_a = pk.id THEN b.person_b ELSE b.person_a END
LEFT JOIN public.familien fo ON fo.id = po.familie_id
ORDER BY person;

-- Mićo Vidović (Ehemann von Desa, Vater von Gordana) — ID für die finalen Verbindungskanten
SELECT pe.id, trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS person, f.name AS familie,
       pe.stammbaum_daten->>'birth_date' AS geboren
FROM public.personen pe JOIN public.familien f ON f.id = pe.familie_id
WHERE pe.vorname ILIKE 'Mi_o' AND pe.nachname ILIKE 'Vidovi%';
