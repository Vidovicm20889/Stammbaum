-- =====================================================
-- DIAGNOSE: milan.vidovic90 / Familie Testeric
-- Ausführen in: Supabase -> SQL Editor (nur SELECTs, ändert nichts).
-- =====================================================

-- 1) Mitgliedschaften von milan.vidovic90 (welche Familien + Rollen sieht/verwaltet er?)
SELECT u.email, f.name AS familie, m.rolle, m.aktiv, f.id AS familie_id, f.verbund_id
FROM public.mitgliedschaften m
JOIN auth.users u    ON u.id = m.user_id
JOIN public.familien f ON f.id = m.familie_id
WHERE lower(u.email) = 'milan.vidovic90@gmail.com'
ORDER BY f.name;

-- 2) Alle Familien namens Testeric + ihre Stammbäume + Personenzahl
SELECT f.id AS familie_id, f.name AS familie, f.verbund_id,
       s.id AS stammbaum_id, s.name AS stammbaum,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen_im_baum,
       (SELECT count(*) FROM public.personen p WHERE p.familie_id  = f.id) AS personen_in_familie
FROM public.familien f
LEFT JOIN public.stammbaeume s ON s.familie_id = f.id
WHERE f.name ILIKE '%testeric%'
ORDER BY f.name, s.name;

-- 3) Gibt es in Testeric Personen ohne stammbaum_id (verwaiste Personen)?
SELECT p.id, p.vorname, p.nachname, p.stammbaum_id, p.familie_id
FROM public.personen p
JOIN public.familien f ON f.id = p.familie_id
WHERE f.name ILIKE '%testeric%';
