-- =====================================================
-- BACKUP vor Umbau der Blutlinien-/Render-Logik (Spec „Ein Stammbaum = eine Blutlinie")
-- Ausführen in: Supabase -> SQL Editor. VOR jeder Frontend-Änderung.
--
-- Erstellt vollständige Snapshot-Kopien der relevanten Tabellen in ein eigenes Schema
-- `backup_bl`. Kopiert ALLE Spalten (SELECT *), unabhängig vom aktuellen Schema-Stand,
-- damit eine spätere Wiederherstellung/ein Vergleich möglich ist.
--
-- Wiederherstellung (manuell, NUR bei Bedarf): pro Tabelle z. B.
--   TRUNCATE public.beziehungen;  INSERT INTO public.beziehungen SELECT * FROM backup_bl.beziehungen;
-- (FK-sichere Reihenfolge beachten: erst beziehungen/personen leeren, dann in Eltern->Kind-Reihenfolge
--  zurückschreiben; im Zweifel mit dem Vergleich starten, nicht blind truncaten.)
--
-- Hinweis: Snapshot ist statisch (Zeitpunkt der Ausführung). Bei erneutem Lauf werden die
-- Backup-Tabellen NICHT überschrieben (CREATE TABLE IF NOT EXISTS) -> erst alte Sicherung
-- wegräumen, wenn ein frischer Snapshot gewünscht ist (DROP SCHEMA backup_bl CASCADE;).
-- =====================================================

CREATE SCHEMA IF NOT EXISTS backup_bl;

-- Vollständige Datenkopien (alle Spalten). IF NOT EXISTS schützt eine bereits gezogene Sicherung.
CREATE TABLE IF NOT EXISTS backup_bl.personen          AS SELECT * FROM public.personen;
CREATE TABLE IF NOT EXISTS backup_bl.beziehungen       AS SELECT * FROM public.beziehungen;
CREATE TABLE IF NOT EXISTS backup_bl.stammbaeume       AS SELECT * FROM public.stammbaeume;
CREATE TABLE IF NOT EXISTS backup_bl.familien          AS SELECT * FROM public.familien;
CREATE TABLE IF NOT EXISTS backup_bl.mitgliedschaften  AS SELECT * FROM public.mitgliedschaften;

-- Kontroll-Ausgabe: Zeilenzahlen Quelle vs. Backup (müssen übereinstimmen).
SELECT 'personen'         AS tabelle, (SELECT count(*) FROM public.personen)         AS quelle, (SELECT count(*) FROM backup_bl.personen)         AS backup
UNION ALL SELECT 'beziehungen',      (SELECT count(*) FROM public.beziehungen),      (SELECT count(*) FROM backup_bl.beziehungen)
UNION ALL SELECT 'stammbaeume',      (SELECT count(*) FROM public.stammbaeume),      (SELECT count(*) FROM backup_bl.stammbaeume)
UNION ALL SELECT 'familien',         (SELECT count(*) FROM public.familien),         (SELECT count(*) FROM backup_bl.familien)
UNION ALL SELECT 'mitgliedschaften', (SELECT count(*) FROM public.mitgliedschaften), (SELECT count(*) FROM backup_bl.mitgliedschaften);
