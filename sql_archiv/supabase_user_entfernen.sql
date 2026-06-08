-- =====================================================
-- USER VOLLSTÄNDIG ENTFERNEN: milan.vidovic90@gmail.com
-- Ausführen in: Supabase -> SQL Editor.
-- Entfernt nur das LOGIN-KONTO + dessen Verknüpfungen.
-- Genealogie (personen/familien/stammbaeume/beziehungen) bleibt erhalten.
-- =====================================================

-- ---------------------------------------------------------------
-- VORSCHAU (nichts wird geändert)
-- ---------------------------------------------------------------
SELECT id, email, created_at FROM auth.users
WHERE lower(email) = 'milan.vidovic90@gmail.com';

SELECT f.name AS familie, m.rolle, m.aktiv
FROM public.mitgliedschaften m
JOIN public.familien f ON f.id = m.familie_id
JOIN auth.users u      ON u.id = m.user_id
WHERE lower(u.email) = 'milan.vidovic90@gmail.com'
ORDER BY f.name;

-- ---------------------------------------------------------------
-- LÖSCHEN (FK-sichere Reihenfolge: erst Verknüpfungen, dann Konto)
-- ---------------------------------------------------------------
DELETE FROM public.mitgliedschaften
WHERE user_id = (SELECT id FROM auth.users WHERE lower(email) = 'milan.vidovic90@gmail.com');

DELETE FROM public.registrierungs_anfragen
WHERE lower(email) = 'milan.vidovic90@gmail.com';

-- Falls diese Tabellen die E-Mail/den User referenzieren, mit entfernen
-- (Spaltennamen ggf. anpassen; Zeilen sind sicherheitshalber auskommentiert):
-- DELETE FROM public.rollen_anfragen WHERE lower(email) = 'milan.vidovic90@gmail.com';
-- DELETE FROM public.lizenzen WHERE user_id = (SELECT id FROM auth.users WHERE lower(email) = 'milan.vidovic90@gmail.com');

-- Das Auth-Konto selbst (verschwindet aus Authentication -> Users;
-- identities/sessions werden per FK-CASCADE mitgelöscht)
DELETE FROM auth.users
WHERE lower(email) = 'milan.vidovic90@gmail.com';

-- ---------------------------------------------------------------
-- KONTROLLE: sollte 0 Zeilen liefern
-- ---------------------------------------------------------------
SELECT count(*) AS noch_vorhanden FROM auth.users
WHERE lower(email) = 'milan.vidovic90@gmail.com';

-- ---------------------------------------------------------------
-- OPTIONAL — verwaiste Familien (kein Owner/Mitglied mehr, keine Personen,
-- kein super_admin) aufräumen. Nur ausführen, wenn du das willst.
-- ---------------------------------------------------------------
-- DO $$
-- DECLARE v_ids uuid[];
-- BEGIN
--   SELECT array_agg(f.id) INTO v_ids FROM public.familien f
--   WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
--     AND NOT EXISTS (SELECT 1 FROM public.personen    p WHERE p.familie_id = f.id)
--     AND NOT EXISTS (SELECT 1 FROM public.mitgliedschaften m WHERE m.familie_id = f.id);
--   IF v_ids IS NULL THEN RAISE NOTICE 'Keine verwaisten Familien.'; RETURN; END IF;
--   DELETE FROM public.registrierungs_anfragen WHERE familie_id = ANY(v_ids);
--   DELETE FROM public.beziehungen             WHERE familie_id = ANY(v_ids);
--   DELETE FROM public.mitgliedschaften        WHERE familie_id = ANY(v_ids);
--   DELETE FROM public.familien                WHERE id = ANY(v_ids);
-- END $$;
