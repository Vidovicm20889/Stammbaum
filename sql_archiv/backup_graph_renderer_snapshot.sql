-- =====================================================
-- DATEN-SNAPSHOT vor dem Renderer-Umbau (Single-Root -> Graph, Option C)
-- EINMAL ausführen in: Supabase -> SQL Editor (NICHT Teil des idempotenten Neuaufbaus -> sql_archiv).
--
-- ZWECK: Option C ändert NUR das Frontend-Rendering (KEINE Datenmigration). Dieser Snapshot ist
-- die Sicherheit "wie bei früheren Eingriffen" (analog Schema backup_bl vor der Blutlinien-Render-
-- Änderung) — falls wider Erwarten doch Daten berührt werden, lässt sich der Stand vergleichen/
-- zurückspielen. Code-Backup separat: Git-Tag `pre-graph-renderer-v14.8`.
--
-- IDEMPOTENT: mehrfaches Ausführen überschreibt den Snapshot (fester Schema-/Tabellenname).
-- Greift NUR lesend auf die Produktivtabellen zu (CREATE TABLE AS SELECT) — verändert sie NICHT.
-- =====================================================

CREATE SCHEMA IF NOT EXISTS backup_graph;

DROP TABLE IF EXISTS backup_graph.personen;
DROP TABLE IF EXISTS backup_graph.beziehungen;
DROP TABLE IF EXISTS backup_graph.stammbaeume;
DROP TABLE IF EXISTS backup_graph.familien;
DROP TABLE IF EXISTS backup_graph.mitgliedschaften;
DROP TABLE IF EXISTS backup_graph.meta;

CREATE TABLE backup_graph.personen        AS SELECT * FROM public.personen;
CREATE TABLE backup_graph.beziehungen     AS SELECT * FROM public.beziehungen;
CREATE TABLE backup_graph.stammbaeume     AS SELECT * FROM public.stammbaeume;
CREATE TABLE backup_graph.familien        AS SELECT * FROM public.familien;
CREATE TABLE backup_graph.mitgliedschaften AS SELECT * FROM public.mitgliedschaften;

-- Vorher-Zählung je Verbund festhalten (Akzeptanzkriterium: NACH dem Umbau identisch).
CREATE TABLE backup_graph.meta AS
  SELECT now() AS snapshot_am,
         (SELECT count(*) FROM public.personen)        AS personen,
         (SELECT count(*) FROM public.beziehungen)     AS beziehungen,
         (SELECT count(*) FROM public.stammbaeume)     AS stammbaeume,
         (SELECT count(*) FROM public.familien)        AS familien,
         (SELECT count(*) FROM public.mitgliedschaften) AS mitgliedschaften;

-- Personen/Beziehungen je Verbund (für Vorher/Nachher-Vergleich des Renderer-Umbaus).
DROP TABLE IF EXISTS backup_graph.zaehlung_je_verbund;
CREATE TABLE backup_graph.zaehlung_je_verbund AS
  SELECT f.verbund_id,
         count(DISTINCT pe.id) AS personen,
         count(DISTINCT b.ctid) AS beziehungen
    FROM public.familien f
    LEFT JOIN public.personen pe   ON pe.familie_id = f.id
    LEFT JOIN public.beziehungen b ON b.familie_id = f.id
   GROUP BY f.verbund_id;

SELECT 'Snapshot backup_graph erstellt' AS status, * FROM backup_graph.meta;
