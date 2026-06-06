-- =====================================================
-- DIAGNOSE (NUR LESEN) — "Begović fehlt als Stammbaum/Familie im Dropdown"
-- Ausführen in: Supabase -> SQL Editor. Ändert NICHTS.
-- Klärt: Existiert irgendein Begović-BAUM/-FAMILIE (auch inaktiv/leer)? Oder leben
-- die Begović-Personen nur als Zweig IM Pisarević-Baum (= kein eigener Baum angelegt)?
-- Jeder Block liefert eine JSON-Spalte -> Feld anklicken, kopieren, zurückgeben.
-- =====================================================

-- 1) Alle Personen namens Begović: in welchem BAUM / welcher FAMILIE liegen sie?
SELECT coalesce(jsonb_agg(t ORDER BY t.baum, t.vorname), '[]') AS block1_begovic_personen
FROM (
  SELECT pe.vorname, pe.nachname,
         s.name AS baum, pe.stammbaum_id,
         f.name AS familie, pe.familie_id, f.verbund_id,
         pe.identitaet_id, pe.user_id
  FROM public.personen pe
  LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  LEFT JOIN public.familien    f ON f.id = pe.familie_id
  WHERE pe.nachname ILIKE '%begov%'
) t;

-- 2) Gibt es überhaupt einen STAMMBAUM namens Begović (auch inaktiv/0 Personen)?
SELECT coalesce(jsonb_agg(t ORDER BY t.name), '[]') AS block2_begovic_baeume
FROM (
  SELECT s.id, s.name, s.aktiv, s.familie_id, f.name AS familie, f.verbund_id,
         (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
  FROM public.stammbaeume s
  LEFT JOIN public.familien f ON f.id = s.familie_id
  WHERE s.name ILIKE '%begov%'
) t;

-- 3) Gibt es eine FAMILIE namens Begović?
SELECT coalesce(jsonb_agg(t ORDER BY t.name), '[]') AS block3_begovic_familien
FROM (
  SELECT f.id, f.name, f.verbund_id,
         (SELECT count(*) FROM public.stammbaeume s WHERE s.familie_id = f.id) AS baeume,
         (SELECT count(*) FROM public.personen p   WHERE p.familie_id   = f.id) AS personen
  FROM public.familien f
  WHERE f.name ILIKE '%begov%'
) t;

-- 4) Kontext: der Pisarević-Baum (Familie + Verbund) — dorthin gehören die Begović aktuell
SELECT coalesce(jsonb_agg(t ORDER BY t.baum), '[]') AS block4_pisarevic_kontext
FROM (
  SELECT s.id AS stammbaum_id, s.name AS baum, s.aktiv,
         f.id AS familie_id, f.name AS familie, f.verbund_id,
         (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
  FROM public.stammbaeume s
  JOIN public.familien f ON f.id = s.familie_id
  WHERE s.name ILIKE '%pisar%'
) t;

-- 5) Beziehungen rund um die Begović-Linie (Eltern/Partner) — Grundlage für ein evtl. Auslagern
SELECT coalesce(jsonb_agg(t ORDER BY t.typ, t.person_a), '[]') AS block5_begovic_beziehungen
FROM (
  SELECT b.typ,
         a.vorname || ' ' || a.nachname AS person_a, sa.name AS baum_a, b.person_a AS id_a,
         c.vorname || ' ' || c.nachname AS person_b, sc.name AS baum_b, b.person_b AS id_b
  FROM public.beziehungen b
  JOIN public.personen a ON a.id = b.person_a
  JOIN public.personen c ON c.id = b.person_b
  LEFT JOIN public.stammbaeume sa ON sa.id = a.stammbaum_id
  LEFT JOIN public.stammbaeume sc ON sc.id = c.stammbaum_id
  WHERE a.nachname ILIKE '%begov%' OR c.nachname ILIKE '%begov%'
) t;
