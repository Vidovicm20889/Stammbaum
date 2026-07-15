-- =====================================================================
-- Diagnose: welche Tabellen im public-Schema haben KEIN Row-Level-Security?
-- (das meldet Supabase' Security-Advisor als "rls_disabled_in_public")
-- REIN LESEND - aendert nichts. Im Supabase SQL-Editor ausfuehren.
-- =====================================================================
select
  t.tablename                                             as tabelle,
  t.rowsecurity                                           as rls_an,      -- false = das Problem
  (select count(*) from pg_policies p
     where p.schemaname = 'public' and p.tablename = t.tablename) as policies,
  c.reltuples::bigint                                     as ca_zeilen    -- grobe Zeilenschaetzung
from pg_tables t
join pg_class c
  on c.relname = t.tablename
 and c.relnamespace = 'public'::regnamespace
where t.schemaname = 'public'
  and t.rowsecurity = false
order by t.tablename;
