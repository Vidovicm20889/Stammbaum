-- =====================================================
-- BACKUP-TABELLEN FINDEN & AUFRÄUMEN
-- Ausführen in: Supabase -> SQL Editor.
--
-- Hintergrund: Diverse Einmal-Skripte (Split/Merge/Restore/Diagnose, siehe sql_archiv/)
-- haben Sicherungskopien als Tabellen mit Präfix `bak_` (bzw. Suffix `_backup`) angelegt.
-- Diese sind reine Wegwerf-Sicherungen und gehören NICHT zum Schema (siehe SCHEMA.md).
--
-- WICHTIG — diese sind KEINE Wegwerf-Backups, NIE löschen (matchen die Filter unten auch nicht):
--   * merge_log              -> wird von merge_rueckgaengig gelesen (Merge rückgängig)
--   * familien_audit         -> Audit-Protokoll (Owner-Wechsel, Auto-Löschungen)
--   * verwaiste_event_medien -> Queue für Storage-Aufräumung
--   * wartungs_sperren       -> aktive Wartungs-/Sperr-Zeilen
--   * anfrage_log            -> Protokoll der Zugangsanfragen
-- Alle produktiven Tabellen stehen in SCHEMA.md.
--
-- VORGEHEN: Erst SCHRITT 1 ausführen und die Liste prüfen. Dann SCHRITT 2 ausführen
-- (generiert die DROP-Befehle als Text). Diese kopieren, NOCHMALS PRÜFEN und ausführen.
-- SCHRITT 3 ist der fertige DROP für ALLE bak_-Tabellen (nur ausführen, wenn die Liste passt).
-- =====================================================


-- ---------------------------------------------------------------------------
-- SCHRITT 1 — Alle Backup-Tabellen mit Größe & Zeilenzahl anzeigen
-- ---------------------------------------------------------------------------
SELECT
  c.relname                                   AS tabelle,
  pg_size_pretty(pg_total_relation_size(c.oid)) AS groesse,
  c.reltuples::bigint                         AS zeilen_geschaetzt
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'                         -- nur echte Tabellen
  AND (c.relname LIKE 'bak\_%' OR c.relname LIKE '%\_backup')
ORDER BY pg_total_relation_size(c.oid) DESC;


-- ---------------------------------------------------------------------------
-- SCHRITT 2 — DROP-Befehle GENERIEREN (nur Text, löscht noch NICHTS)
--             Ergebnis kopieren, prüfen, dann ausführen.
-- ---------------------------------------------------------------------------
SELECT string_agg(
         format('DROP TABLE IF EXISTS public.%I CASCADE;', c.relname),
         E'\n' ORDER BY c.relname
       ) AS drop_befehle
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND (c.relname LIKE 'bak\_%' OR c.relname LIKE '%\_backup');


-- ---------------------------------------------------------------------------
-- SCHRITT 3 — FERTIGER SAMMEL-DROP für ALLE bak_-/_backup-Tabellen
--             NUR ausführen, wenn die Liste aus SCHRITT 1 wirklich nur
--             unnötige Sicherungen enthält. CASCADE entfernt auch evtl.
--             abhängige Views/Constraints dieser Backup-Tabellen.
-- ---------------------------------------------------------------------------
-- DO $$
-- DECLARE r record;
-- BEGIN
--   FOR r IN
--     SELECT c.relname
--       FROM pg_class c
--       JOIN pg_namespace n ON n.oid = c.relnamespace
--      WHERE n.nspname = 'public'
--        AND c.relkind = 'r'
--        AND (c.relname LIKE 'bak\_%' OR c.relname LIKE '%\_backup')
--   LOOP
--     EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE;', r.relname);
--     RAISE NOTICE 'gelöscht: %', r.relname;
--   END LOOP;
-- END $$;
