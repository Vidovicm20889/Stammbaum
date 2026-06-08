-- =====================================================
-- milan.vidovic90 SOLL NUR TESTERIC SEHEN (Isolation) + Testeric-Baum reparieren
-- Ausführen in: Supabase -> SQL Editor. Blöcke der Reihe nach ausführen.
-- =====================================================

-- 1) Falls kein Stammbaum existiert: anlegen
INSERT INTO public.stammbaeume (familie_id, name)
SELECT f.id, f.name FROM public.familien f
WHERE f.name ILIKE '%testeric%'
  AND NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id);

-- 2) Vorhandene Testeric-Person(en) mit dem Testeric-Stammbaum verknüpfen
WITH t AS (
  SELECT f.id AS familie_id,
         (SELECT s.id FROM public.stammbaeume s WHERE s.familie_id = f.id ORDER BY s.created_at LIMIT 1) AS stammbaum_id
  FROM public.familien f WHERE f.name ILIKE '%testeric%'
)
UPDATE public.personen p
SET stammbaum_id = t.stammbaum_id
FROM t
WHERE p.familie_id = t.familie_id
  AND t.stammbaum_id IS NOT NULL
  AND (p.stammbaum_id IS NULL OR p.stammbaum_id <> t.stammbaum_id);

-- 3) Testeric in einen EIGENEN, isolierten Verbund legen
--    (falls er – z. B. durch eine Heirats-Verknüpfung – mit Vidović zusammengelegt wurde,
--     würde milan.vidovic90 sonst weiterhin alle Vidović-Daten sehen)
UPDATE public.familien SET verbund_id = gen_random_uuid()
WHERE name ILIKE '%testeric%';

-- 4) ALLE Nicht-Testeric-Mitgliedschaften von milan.vidovic90 entfernen
--    -> danach sieht er ausschließlich Testeric
DELETE FROM public.mitgliedschaften m
USING auth.users u
WHERE m.user_id = u.id
  AND lower(u.email) = 'milan.vidovic90@gmail.com'
  AND m.familie_id NOT IN (SELECT id FROM public.familien WHERE name ILIKE '%testeric%');

-- 5) Sicherstellen, dass er Familien-Admin von Testeric ist
INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv)
SELECT u.id, f.id, 'familien_admin', true
FROM auth.users u CROSS JOIN public.familien f
WHERE lower(u.email) = 'milan.vidovic90@gmail.com' AND f.name ILIKE '%testeric%'
ON CONFLICT (user_id, familie_id) DO UPDATE SET rolle = 'familien_admin', aktiv = true;

-- 6) KONTROLLE: er sollte nur noch Testeric (familien_admin) haben,
--    und der Testeric-Baum sollte >= 1 Person zeigen.
SELECT u.email, f.name AS familie, m.rolle, m.aktiv, f.verbund_id
FROM public.mitgliedschaften m
JOIN auth.users u ON u.id = m.user_id
JOIN public.familien f ON f.id = m.familie_id
WHERE lower(u.email) = 'milan.vidovic90@gmail.com';

SELECT s.name AS stammbaum, count(p.id) AS personen_im_baum
FROM public.stammbaeume s
LEFT JOIN public.personen p ON p.stammbaum_id = s.id
WHERE s.name ILIKE '%testeric%'
GROUP BY s.name;
