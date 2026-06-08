-- =====================================================
-- DIAGNOSE (NUR LESEN) — Bug "Zorana verschwindet aus Knežević"
-- Ausführen in: Supabase -> SQL Editor. Ändert NICHTS.
-- Jeder Block liefert EINE Zeile mit einer JSON-Spalte -> Feld anklicken,
-- kopieren und hier zurückgeben (am besten alle 5).
-- =====================================================

-- 1) Alle Karten "Zorana" + "Milanko" + Eltern (Nada/Milan Knežević)
SELECT coalesce(jsonb_agg(t ORDER BY t.vorname, t.baum), '[]') AS block1_karten
FROM (
  SELECT pe.id, pe.externe_id, pe.vorname, pe.nachname,
         s.name AS baum, pe.stammbaum_id,
         f.name AS familie, pe.familie_id,
         pe.identitaet_id, pe.user_id
  FROM public.personen pe
  LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  LEFT JOIN public.familien    f ON f.id = pe.familie_id
  WHERE pe.vorname ILIKE 'zorana%'
     OR pe.vorname ILIKE 'milanko%'
     OR (pe.vorname ILIKE 'nada%'  AND (pe.nachname ILIKE '%knez%' OR pe.nachname ILIKE '%knež%'))
     OR (pe.vorname ILIKE 'milan%' AND (pe.nachname ILIKE '%knez%' OR pe.nachname ILIKE '%knež%'))
) t;

-- 2) Beziehungen, an denen eine "Zorana"-Karte beteiligt ist (Eltern + Partner)
SELECT coalesce(jsonb_agg(t ORDER BY t.typ, t.person_a), '[]') AS block2_beziehungen
FROM (
  SELECT b.typ,
         a.vorname || ' ' || a.nachname AS person_a, sa.name AS baum_a,
         c.vorname || ' ' || c.nachname AS person_b, sc.name AS baum_b,
         b.person_a AS id_a, b.person_b AS id_b
  FROM public.beziehungen b
  JOIN public.personen a ON a.id = b.person_a
  JOIN public.personen c ON c.id = b.person_b
  LEFT JOIN public.stammbaeume sa ON sa.id = a.stammbaum_id
  LEFT JOIN public.stammbaeume sc ON sc.id = c.stammbaum_id
  WHERE a.vorname ILIKE 'zorana%' OR c.vorname ILIKE 'zorana%'
) t;

-- 3) Personenzahl je Baum (Knežević / Simić)
SELECT coalesce(jsonb_agg(t ORDER BY t.baum), '[]') AS block3_baumgroessen
FROM (
  SELECT s.name AS baum, s.id AS stammbaum_id,
         (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
  FROM public.stammbaeume s
  WHERE s.name ILIKE '%knez%' OR s.name ILIKE '%knež%' OR s.name ILIKE '%simi%'
) t;

-- 4) Alle Personen IM Knežević-Baum
SELECT coalesce(jsonb_agg(t ORDER BY t.vorname), '[]') AS block4_knezevic_personen
FROM (
  SELECT pe.vorname, pe.nachname, pe.identitaet_id, pe.externe_id
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  WHERE s.name ILIKE '%knez%' OR s.name ILIKE '%knež%'
) t;

-- 5) Quelltext der aktuell deployten RPC (spiegelt vs. verschiebt)
SELECT to_jsonb(t) AS block5_rpc_quelltext
FROM (
  SELECT p.proname,
         pg_get_functiondef(p.oid) AS funktions_quelltext
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'stammbaum_zweig_aus_heirat'
) t;
