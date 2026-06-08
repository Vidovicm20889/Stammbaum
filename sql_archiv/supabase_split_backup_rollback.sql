-- =====================================================
-- MANUELLES SICHERUNGSNETZ für supabase_split_familien.sql
-- (Ersatz für das Plan-Backup). Im SQL-Editor ausführen.
-- =====================================================

-- ===============================================================
-- TEIL 1 — BACKUP: VOR der Migration ausführen.
-- Speichert den aktuellen Zustand aller betroffenen Spalten/IDs.
-- ===============================================================
DROP TABLE IF EXISTS public.bak_split_stammbaeume;
DROP TABLE IF EXISTS public.bak_split_personen;
DROP TABLE IF EXISTS public.bak_split_beziehungen;
DROP TABLE IF EXISTS public.bak_split_familien_ids;
DROP TABLE IF EXISTS public.bak_split_mitglied_ids;

CREATE TABLE public.bak_split_stammbaeume  AS SELECT id, familie_id FROM public.stammbaeume;
CREATE TABLE public.bak_split_personen     AS SELECT id, familie_id FROM public.personen;
CREATE TABLE public.bak_split_beziehungen  AS SELECT id, familie_id FROM public.beziehungen;
CREATE TABLE public.bak_split_familien_ids AS SELECT id FROM public.familien;
CREATE TABLE public.bak_split_mitglied_ids AS SELECT id FROM public.mitgliedschaften;

SELECT 'Backup angelegt' AS status,
       (SELECT count(*) FROM public.bak_split_stammbaeume)  AS stammbaeume,
       (SELECT count(*) FROM public.bak_split_personen)     AS personen,
       (SELECT count(*) FROM public.bak_split_beziehungen)  AS beziehungen,
       (SELECT count(*) FROM public.bak_split_familien_ids) AS familien,
       (SELECT count(*) FROM public.bak_split_mitglied_ids) AS mitgliedschaften;


-- ===============================================================
-- TEIL 2 — ROLLBACK: NUR ausführen, wenn die Migration rückgängig
-- gemacht werden soll. Stellt den Zustand vor der Migration wieder her.
-- (Vorher den ganzen folgenden Block einkommentieren.)
-- ===============================================================
-- DO $$
-- BEGIN
--   -- 1) familie_id auf den alten Stand zurücksetzen
--   UPDATE public.stammbaeume s SET familie_id = b.familie_id
--   FROM public.bak_split_stammbaeume b WHERE b.id = s.id AND s.familie_id <> b.familie_id;
--
--   UPDATE public.personen p SET familie_id = b.familie_id
--   FROM public.bak_split_personen b WHERE b.id = p.id AND p.familie_id <> b.familie_id;
--
--   UPDATE public.beziehungen z SET familie_id = b.familie_id
--   FROM public.bak_split_beziehungen b WHERE b.id = z.id AND z.familie_id <> b.familie_id;
--
--   -- 2) während der Migration NEU angelegte Mitgliedschaften entfernen
--   DELETE FROM public.mitgliedschaften m
--   WHERE m.id NOT IN (SELECT id FROM public.bak_split_mitglied_ids);
--
--   -- 3) während der Migration NEU angelegte Familien entfernen
--   DELETE FROM public.familien f
--   WHERE f.id NOT IN (SELECT id FROM public.bak_split_familien_ids);
-- END $$;
-- SELECT 'Rollback ausgeführt' AS status;


-- ===============================================================
-- TEIL 3 — AUFRÄUMEN: wenn alles passt und du die Backup-Tabellen
-- nicht mehr brauchst (optional, jederzeit später).
-- ===============================================================
-- DROP TABLE IF EXISTS public.bak_split_stammbaeume;
-- DROP TABLE IF EXISTS public.bak_split_personen;
-- DROP TABLE IF EXISTS public.bak_split_beziehungen;
-- DROP TABLE IF EXISTS public.bak_split_familien_ids;
-- DROP TABLE IF EXISTS public.bak_split_mitglied_ids;
