-- ============================================================================
-- DIAGNOSE (+ optionaler Cleanup): verwaiste Familien (0 Stammbäume)
-- ----------------------------------------------------------------------------
-- Nach FIX #6 (supabase_verwaltbare_familien_nur_mit_baum.sql) sind tree-lose Familien
-- in der UI unsichtbar (Nav UND Einstellungen). Die Zeilen bleiben aber in der DB —
-- BEWUSST kontoschonend (die Auto-Cleanup-Logik behält Familie/Mitgliedschaften, damit
-- der Owner über „Kreiraj novo stablo" wieder einen Baum anlegen kann).
--
-- Dieses Skript ist NUR Diagnose. Führe die DELETEs NUR aus, wenn du solche „leeren"
-- Familien wirklich entfernen willst (dann verliert der Owner die Möglichkeit, ohne
-- Neuanlage weiterzumachen). Einmal-/Vorfall-Skript -> gehört nicht zum Neuaufbau.
-- ============================================================================

-- 1) Welche Familien haben 0 Stammbäume? (mit Mitglieder-/Super-Admin-Info)
SELECT f.id, f.name,
       (SELECT count(*) FROM public.stammbaeume s WHERE s.familie_id = f.id) AS baeume,
       (SELECT count(*) FROM public.mitgliedschaften m WHERE m.familie_id = f.id) AS mitglieder,
       EXISTS (SELECT 1 FROM public.mitgliedschaften m
                WHERE m.familie_id = f.id AND m.rolle = 'super_admin')            AS hat_super_admin
  FROM public.familien f
 WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s2 WHERE s2.familie_id = f.id)
 ORDER BY f.name;

-- 2) OPTIONAL/DESTRUKTIV — verwaiste Familien OHNE super_admin-Mitgliedschaft physisch löschen.
--    ERST Schritt 1 prüfen! FK-sichere Reihenfolge (Kinder vor Eltern).
--    Zum Ausführen die folgenden Zeilen auskommentieren (BEGIN/COMMIT drum herum empfohlen).
--
-- WITH verwaist AS (
--   SELECT f.id FROM public.familien f
--    WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
--      AND NOT EXISTS (SELECT 1 FROM public.mitgliedschaften m
--                       WHERE m.familie_id = f.id AND m.rolle = 'super_admin')
-- )
-- , d_anfr AS (DELETE FROM public.registrierungs_anfragen WHERE familie_id IN (SELECT id FROM verwaist) RETURNING 1)
-- , d_mit  AS (DELETE FROM public.mitgliedschaften        WHERE familie_id IN (SELECT id FROM verwaist) RETURNING 1)
-- DELETE FROM public.familien WHERE id IN (SELECT id FROM verwaist);
