-- =====================================================
-- DIAGNOSE: Kinder fehlen in Bäumen, in denen die Eltern existieren
-- NUR SELECT — ändert nichts. Ausführen im Supabase SQL Editor.
-- Jeder Abschnitt liefert EINE JSON-Zelle -> einfach kopieren und schicken.
--
-- Hypothese: Ein Kind wurde nur in EINEM Baum (z. B. Dušanić) angelegt.
-- Die Eltern existieren auch in einem anderen Baum (z. B. Vidović/Rakić),
-- aber das Kind ist dort weder physisch gespiegelt noch render-gebrückt.
-- Die Render-Brücke greift NUR, wenn die ELTERN per identitaet_id verknüpft
-- sind. Diese Diagnose prüft genau das.
--
-- Tipp: Die drei Abschnitte einzeln markieren + ausführen (oder nacheinander).
-- =====================================================

-- ---------------------------------------------------------------
-- 1) Die betroffenen Personen + ihre Karten je Baum + identitaet_id
--    (Mirjana, Lazo, Ljubica, Željko — Namen ggf. anpassen)
-- ---------------------------------------------------------------
SELECT jsonb_pretty(jsonb_agg(t ORDER BY t.vorname, t.baum)) AS abschnitt_1_personen
FROM (
  SELECT
    pe.vorname,
    pe.nachname,
    s.name              AS baum,
    pe.identitaet_id,
    pe.id               AS karte_id,
    pe.externe_id
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  WHERE lower(pe.vorname) LIKE 'mirjan%'
     OR lower(pe.vorname) LIKE 'lazo%'
     OR lower(pe.vorname) LIKE 'ljubic%'
     OR lower(pe.vorname) LIKE 'zeljk%'
     OR lower(pe.vorname) LIKE 'želj%'
) t;

-- ---------------------------------------------------------------
-- 2) GENERISCH: Alle Kinder, deren Eltern in MEHREREN Bäumen Karten
--    haben, das Kind aber NICHT in jedem dieser Bäume existiert.
--    Das ist die vollständige Liste der "fehlt im Baum"-Fälle.
-- ---------------------------------------------------------------
WITH eltern_kanten AS (
  SELECT b.person_a AS eltern_id, b.person_b AS kind_id
  FROM public.beziehungen b
  WHERE b.typ = 'elternteil'
),
ident AS (
  SELECT pe.id, COALESCE(pe.identitaet_id, pe.id) AS grp
  FROM public.personen pe
),
kind_grp AS (
  SELECT ek.kind_id, ki.grp AS kind_grp
  FROM eltern_kanten ek
  JOIN ident ki ON ki.id = ek.kind_id
),
kind_baeume AS (
  SELECT DISTINCT kg.kind_grp, pe.stammbaum_id
  FROM kind_grp kg
  JOIN public.personen all_pe ON COALESCE(all_pe.identitaet_id, all_pe.id) = kg.kind_grp
  JOIN public.personen pe ON pe.id = all_pe.id
),
eltern_grp AS (
  SELECT ek.kind_id, ei.grp AS eltern_grp
  FROM eltern_kanten ek
  JOIN ident ei ON ei.id = ek.eltern_id
),
eltern_baeume AS (
  SELECT DISTINCT eg.kind_id, pe.stammbaum_id
  FROM eltern_grp eg
  JOIN public.personen ep ON COALESCE(ep.identitaet_id, ep.id) = eg.eltern_grp
  JOIN public.personen pe ON pe.id = ep.id
)
SELECT jsonb_pretty(COALESCE(jsonb_agg(t ORDER BY t.kind, t.fehlt_im_baum), '[]'::jsonb)) AS abschnitt_2_fehlende_kinder
FROM (
  SELECT
    k.vorname || ' ' || k.nachname            AS kind,
    s_fehlt.name                              AS fehlt_im_baum,
    k.identitaet_id                           AS kind_identitaet_id,
    (SELECT string_agg(DISTINCT s2.name, ', ')
       FROM public.personen pe2
       JOIN public.stammbaeume s2 ON s2.id = pe2.stammbaum_id
      WHERE COALESCE(pe2.identitaet_id, pe2.id) = COALESCE(k.identitaet_id, k.id)
    )                                         AS kind_existiert_in_baeumen
  FROM eltern_baeume eb
  JOIN public.personen k ON k.id = eb.kind_id
  JOIN public.stammbaeume s_fehlt ON s_fehlt.id = eb.stammbaum_id
  WHERE NOT EXISTS (
    SELECT 1 FROM kind_baeume kb
    WHERE kb.kind_grp = COALESCE(k.identitaet_id, k.id)
      AND kb.stammbaum_id = eb.stammbaum_id
  )
) t;

-- ---------------------------------------------------------------
-- 3) Sind die ELTERN baumübergreifend verknüpft? (entscheidet, ob
--    Render-Brücke / kind_baeume_sync überhaupt greifen können)
--    identitaet_id = NULL bei einem Eltern-Zwilling = Brücke kaputt.
-- ---------------------------------------------------------------
SELECT jsonb_pretty(jsonb_agg(t ORDER BY t.eltern_name, t.baum)) AS abschnitt_3_eltern_verknuepfung
FROM (
  SELECT
    pe.vorname || ' ' || pe.nachname AS eltern_name,
    s.name                           AS baum,
    pe.identitaet_id,
    CASE WHEN pe.identitaet_id IS NULL THEN '⚠️ NICHT verknüpft' ELSE 'ok' END AS status
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  WHERE pe.id IN (
    SELECT DISTINCT b.person_a
    FROM public.beziehungen b
    WHERE b.typ = 'elternteil'
      AND b.person_b IN (
        SELECT pe2.id FROM public.personen pe2
        WHERE lower(pe2.vorname) LIKE 'željk%' OR lower(pe2.vorname) LIKE 'zeljk%'
           OR lower(pe2.vorname) LIKE 'ljubic%'
      )
  )
) t;
