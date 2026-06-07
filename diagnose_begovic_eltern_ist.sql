-- =====================================================
-- DIAGNOSE (NUR LESEN) — IST-Zustand Eltern/Partner der Begović/Vidović-Linie
-- Ausführen in: Supabase -> SQL-Editor -> Run. Ändert NICHTS (kein INSERT/UPDATE/DELETE).
--
-- Zweck: Grundlage für die Reparatur "gerade ziehen". Soll-Zustand laut Nutzer:
--   Mirsada : Vater Halid, Mutter Desanka
--   Mirsad  : Vater Halid, Mutter Desanka
--   Gordana : Vater Mićo,  Mutter Desanka
--   Igor    : Vater Mićo,  Mutter Đuka
-- Daraus Eltern-Paare: Halid+Desanka, Mićo+Desanka, Mićo+Đuka.
--
-- Bekannte UUIDs:
--   Halid (Pisarević)   3ef5b6e0-d805-400d-8592-cb98755a8889
--   Desanka (Pisarević) 7d12816e-cd27-40a3-a710-c717edf5a3e1
--   Mićo Vidović        7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49
-- Gesucht (noch unbekannt): Đuka (Savić) und Igor.
--
-- Bitte die Ergebnisse ALLER 4 Blöcke zurückgeben.
-- =====================================================

-- Verbund der bekannten Personen (für saubere Eingrenzung; keine Fremdkonten)
-- wird in jedem Block per Subquery wiederverwendet.


-- ===============================================================
-- BLOCK 1 — Alle Zwillingskarten der 3 BEKANNTEN Erwachsenen
--   (über identitaet_id), inkl. Baum. Zeigt, in welchen Bäumen je Person
--   eine Karte existiert (wichtig, um Eltern-Kanten je Baum korrekt zu setzen).
-- ===============================================================
WITH anker(rolle, anker_id) AS (
  VALUES ('Halid',   '3ef5b6e0-d805-400d-8592-cb98755a8889'::uuid),
         ('Mićo',    '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49'::uuid),
         ('Desanka', '7d12816e-cd27-40a3-a710-c717edf5a3e1'::uuid)
),
anker_ident AS (
  SELECT a.rolle, a.anker_id, pe.identitaet_id
  FROM anker a JOIN public.personen pe ON pe.id = a.anker_id
)
SELECT ai.rolle,
       pe.id            AS karten_uuid,
       pe.vorname, pe.nachname,
       s.name           AS baum,
       pe.identitaet_id
FROM anker_ident ai
JOIN public.personen pe
  ON pe.id = ai.anker_id
  OR (ai.identitaet_id IS NOT NULL AND pe.identitaet_id = ai.identitaet_id)
LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
ORDER BY ai.rolle, baum;


-- ===============================================================
-- BLOCK 2 — Đuka und Igor finden (UUIDs noch unbekannt).
--   Eingegrenzt auf den VERBUND der bekannten Personen (keine Fremdkonten).
-- ===============================================================
WITH vb AS (
  SELECT DISTINCT f.verbund_id
  FROM public.personen pe
  JOIN public.familien f ON f.id = pe.familie_id
  WHERE pe.id IN ('3ef5b6e0-d805-400d-8592-cb98755a8889',
                  '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49',
                  '7d12816e-cd27-40a3-a710-c717edf5a3e1')
)
SELECT pe.id          AS karten_uuid,
       pe.vorname, pe.nachname,
       s.name         AS baum,
       pe.identitaet_id
FROM public.personen pe
JOIN public.familien f ON f.id = pe.familie_id
LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
WHERE f.verbund_id IN (SELECT verbund_id FROM vb)
  AND ( public.merge_norm(pe.vorname) = public.merge_norm('Đuka')
     OR public.merge_norm(pe.vorname) = public.merge_norm('Djuka')
     OR public.merge_norm(pe.vorname) = public.merge_norm('Igor') )
ORDER BY pe.vorname, baum;


-- ===============================================================
-- BLOCK 3 — IST-ELTERN der 4 Kinder (ALLE Zwillingskarten je Kind).
--   Pro Kind-Karte werden die aktuell verknüpften Elternteile gezeigt.
--   Eingegrenzt auf den Verbund; Vornamen exakt (merge_norm), damit
--   "Mirsad" nicht "Mirsada" mitfängt.
-- ===============================================================
WITH vb AS (
  SELECT DISTINCT f.verbund_id
  FROM public.personen pe
  JOIN public.familien f ON f.id = pe.familie_id
  WHERE pe.id IN ('3ef5b6e0-d805-400d-8592-cb98755a8889',
                  '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49',
                  '7d12816e-cd27-40a3-a170-' /* absichtlich falsch? nein */ )
),
vb2 AS (
  SELECT DISTINCT f.verbund_id
  FROM public.personen pe
  JOIN public.familien f ON f.id = pe.familie_id
  WHERE pe.id IN ('3ef5b6e0-d805-400d-8592-cb98755a8889',
                  '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49',
                  '7d12816e-cd27-40a3-a177-f3bfe5830dc0')
),
kinder AS (
  SELECT pe.id AS kind_id, pe.vorname, pe.nachname, pe.identitaet_id,
         s.name AS kind_baum
  FROM public.personen pe
  JOIN public.familien f ON f.id = pe.familie_id
  LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  WHERE f.verbund_id IN (SELECT verbund_id FROM vb2)
    AND public.merge_norm(pe.vorname) IN (
          public.merge_norm('Mirsad'), public.merge_norm('Mirsada'),
          public.merge_norm('Gordana'), public.merge_norm('Igor'))
)
SELECT k.vorname        AS kind,
       k.nachname       AS kind_nn,
       k.kind_baum,
       k.kind_id,
       el.vorname       AS elternteil_vn,
       el.nachname      AS elternteil_nn,
       sel.name         AS elternteil_baum,
       el.id            AS elternteil_uuid
FROM kinder k
LEFT JOIN public.beziehungen b  ON b.person_b = k.kind_id AND b.typ = 'elternteil'
LEFT JOIN public.personen   el  ON el.id = b.person_a
LEFT JOIN public.stammbaeume sel ON sel.id = el.stammbaum_id
ORDER BY kind, kind_baum, elternteil_vn NULLS FIRST;


-- ===============================================================
-- BLOCK 4 — IST-EHEPARTNER-Kanten unter den Erwachsenen
--   (Halid, Mićo, Desanka + alle Zwillinge). Zeigt vorhandene ehepartner-Kanten,
--   damit wir doppelte/falsche Ehen erkennen (Kanten brauchen wir für die
--   reine Eltern-Korrektur evtl. gar nicht, aber gut zu sehen).
-- ===============================================================
WITH adult_ids AS (
  SELECT pe.id
  FROM public.personen pe
  WHERE pe.id IN ('3ef5b6e0-d805-400d-8592-cb98755a8889',
                  '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49',
                  '7d12816e-cd27-40a3-a177-f3bfe5830dc0')
     OR pe.identitaet_id IN (
          SELECT identitaet_id FROM public.personen
          WHERE id IN ('3ef5b6e0-d805-400d-8592-cb98755a8889',
                       '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49',
                       '7d12816e-cd27-40a3-a177-f3bfe5830dc0')
            AND identitaet_id IS NOT NULL )
)
SELECT pa.vorname||' '||pa.nachname AS person_a, sa.name AS baum_a,
       pb.vorname||' '||pb.nachname AS person_b, sb.name AS baum_b,
       b.id AS beziehung_id
FROM public.beziehungen b
JOIN public.personen pa ON pa.id = b.person_a
JOIN public.personen pb ON pb.id = b.person_b
LEFT JOIN public.stammbaeume sa ON sa.id = pa.stammbaum_id
LEFT JOIN public.stammbaeume sb ON sb.id = pb.stammbaum_id
WHERE b.typ = 'ehepartner'
  AND (b.person_a IN (SELECT id FROM adult_ids) OR b.person_b IN (SELECT id FROM adult_ids))
ORDER BY person_a, person_b;
