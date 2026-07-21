-- =====================================================
-- PHASE 5 — BESTEHENDE ABWEICHENDE NACHNAMEN AUSLAGERN: Backup + Kandidaten-Report
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- ZIEL: Personen, die schon in einem Baum liegen, deren Nachname aber NICHT der Blutlinie
-- (= Baumname) entspricht — z. B. „Xerri" im „Scicluna"-Baum — nachträglich in eigene
-- Nachnamen-Bäume auslagern (wie der neue Auto-Flow für neue Personen).
--
-- SICHERHEIT / ROLLBACK (wichtig, weil bestehende Daten verändert werden):
--   1) Dieses Skript legt ZUERST einen VOLLEN Snapshot in das Schema `backup_nachnamen` (Undo-Basis).
--   2) Es liefert einen REPORT der Kandidaten — es verändert NICHTS an den Live-Daten.
--   3) Die eigentliche Auslagerung macht der Admin ANGEMELDET über das In-App-Tool
--      (dort ist auth.uid() gesetzt; die Split-RPC stammbaum_zweig_aus_person verlangt das).
--      Ein Massen-Split direkt im SQL-Editor (auth.uid() = NULL) würde fehlschlagen — bewusst so.
--   4) Undo: die auskommentierte RESTORE-Sektion unten stellt den Snapshot wieder her.
-- =====================================================


-- ---------- 1) VOLLER SNAPSHOT (Undo-Basis) ----------
DROP SCHEMA IF EXISTS backup_nachnamen CASCADE;
CREATE SCHEMA backup_nachnamen;
CREATE TABLE backup_nachnamen.personen    AS SELECT * FROM public.personen;
CREATE TABLE backup_nachnamen.beziehungen AS SELECT * FROM public.beziehungen;
CREATE TABLE backup_nachnamen.stammbaeume AS SELECT * FROM public.stammbaeume;
CREATE TABLE backup_nachnamen.familien    AS SELECT * FROM public.familien;
CREATE TABLE backup_nachnamen.mitgliedschaften AS SELECT * FROM public.mitgliedschaften;


-- ---------- 2) HELFER: „letztes Wort"-Normalisierung wie im Frontend (zweigNachnameNorm) ----------
-- Klammer-/„ - "-Zusatz strippen, Diakritika falten, letztes Wort als Nachname.
CREATE OR REPLACE FUNCTION public._nn_norm(s text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT public.merge_norm(
    regexp_replace(
      split_part(regexp_replace(coalesce(s,''), '\(.*$', ' '), ' - ', 1),
      '.*\s', ''
    )
  );
$$;


-- ---------- 3) KANDIDATEN-REPORT (verändert NICHTS) ----------
-- Personen mit abweichendem Nachnamen, noch NICHT baumübergreifend verknüpft (identitaet_id NULL),
-- kein Platzhalter, nicht gelöscht. Der Admin lagert sie anschließend im In-App-Tool aus.
CREATE OR REPLACE FUNCTION public.nachnamen_migration_report()
RETURNS TABLE(stammbaum_id uuid, baum_name text, person_id uuid, person_name text, nachname text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT s.id, s.name,
         pe.id,
         nullif(btrim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')), ''),
         pe.nachname
    FROM public.personen pe
    JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
   WHERE pe.geloescht_am IS NULL
     AND pe.identitaet_id IS NULL
     AND coalesce(pe.stammbaum_daten->>'platzhalter','') <> 'true'
     AND nullif(btrim(coalesce(pe.nachname,'')),'') IS NOT NULL
     AND public._nn_norm(pe.nachname) <> public._nn_norm(s.name)
   ORDER BY s.name, pe.nachname, pe.vorname;
$$;
GRANT EXECUTE ON FUNCTION public.nachnamen_migration_report() TO authenticated;


-- ---------- REPORT ANZEIGEN ----------
SELECT * FROM public.nachnamen_migration_report();


-- =====================================================
-- UNDO (nur bei Bedarf, NACH einer Migration): stellt den Snapshot wieder her.
-- ACHTUNG: überschreibt Live-Daten mit dem Stand vor der Migration. Vorher sicher sein.
-- Zum Ausführen die folgenden Zeilen entkommentieren:
-- =====================================================
-- BEGIN;
--   DELETE FROM public.beziehungen;      INSERT INTO public.beziehungen      SELECT * FROM backup_nachnamen.beziehungen;
--   DELETE FROM public.personen;         INSERT INTO public.personen         SELECT * FROM backup_nachnamen.personen;
--   DELETE FROM public.mitgliedschaften; INSERT INTO public.mitgliedschaften SELECT * FROM backup_nachnamen.mitgliedschaften;
--   DELETE FROM public.stammbaeume;      INSERT INTO public.stammbaeume      SELECT * FROM backup_nachnamen.stammbaeume;
--   DELETE FROM public.familien;         INSERT INTO public.familien         SELECT * FROM backup_nachnamen.familien;
-- COMMIT;

SELECT 'Phase 5: Snapshot backup_nachnamen angelegt + nachnamen_migration_report() bereit. Auslagerung angemeldet im In-App-Tool.' AS status;
