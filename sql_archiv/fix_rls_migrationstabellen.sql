-- =====================================================================
-- FIX fuer Supabase Security-Advisor "rls_disabled_in_public"
-- Diagnose (diagnose_rls_public.sql) ergab genau zwei Tabellen ohne RLS:
--   - migration_personen_map    (218 Zeilen, alte ID-Zuordnung)
--   - migration_feld_konflikte  (leer)
-- Beides sind EINMAL-Migrations-Helfer aus supabase_option_b_2_migration.sql,
-- werden von KEINEM Live-Code / RPC referenziert (verifiziert per Repo-Grep).
-- -> ersatzlos loeschen. Damit sind sie nicht mehr ueber die API erreichbar
--    UND der Advisor-Alarm verschwindet.
-- Idempotent (IF EXISTS). Im Supabase SQL-Editor ausfuehren.
-- =====================================================================

drop table if exists public.migration_personen_map   cascade;
drop table if exists public.migration_feld_konflikte cascade;

-- Kontrolle: sollte 0 Zeilen liefern (keine public-Tabelle mehr ohne RLS)
select t.tablename, t.rowsecurity
from pg_tables t
where t.schemaname = 'public'
  and t.rowsecurity = false
order by t.tablename;
