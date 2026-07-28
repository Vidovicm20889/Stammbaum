-- ============================================================
-- Live-Sync (P1): Supabase Realtime für Baumdaten aktivieren
-- ============================================================
-- Zweck: personen / beziehungen / stammbaeume in die Realtime-Publication
-- `supabase_realtime` aufnehmen, damit das Frontend (Channel `stammbaum-sync`)
-- INSERT/UPDATE/DELETE dieser Tabellen live empfängt.
--
-- WICHTIG:
--  * RLS bleibt aktiv und gilt auch für Realtime -> jeder Nutzer empfängt NUR
--    Änderungen an Zeilen, die er per RLS-SELECT lesen darf (Familien-/Verbund-
--    Isolation bleibt gewahrt; Super-Admin sieht alles).
--  * `registrierungs_anfragen` wird BEWUSST NICHT aufgenommen (wird über
--    SECURITY-DEFINER-RPCs ohne direktes RLS-SELECT gelesen -> Realtime würde
--    solche Zeilen ohnehin nicht ausliefern; dafür bleibt das Obav-Polling).
--  * Idempotent: bei erneutem Ausführen werden bereits vorhandene Tabellen
--    in der Publication übersprungen (kein Fehler).
--
-- Ausführen im Supabase SQL-Editor (als Service-Role/Dashboard).
-- ============================================================

-- Die Publication `supabase_realtime` existiert in Supabase-Projekten standardmäßig.
-- Falls sie (z. B. in einem frisch aufgesetzten Projekt) fehlt, anlegen:
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

-- Tabellen idempotent zur Publication hinzufügen (nur, wenn noch nicht enthalten).
DO $$
DECLARE
  t text;
  tabellen text[] := ARRAY['personen', 'beziehungen', 'stammbaeume'];
BEGIN
  FOREACH t IN ARRAY tabellen LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename  = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
      RAISE NOTICE 'Realtime aktiviert für public.%', t;
    ELSE
      RAISE NOTICE 'public.% bereits in Publication supabase_realtime', t;
    END IF;
  END LOOP;
END $$;

-- Damit UPDATE/DELETE-Events die nötigen Identifikationsspalten mitliefern
-- (Standard ist nur der Primary Key) — für DELETE relevant, damit das Frontend
-- weiß, welche Zeile entfernt wurde. Vollständige alte Zeile mitsenden:
ALTER TABLE public.personen    REPLICA IDENTITY FULL;
ALTER TABLE public.beziehungen REPLICA IDENTITY FULL;
ALTER TABLE public.stammbaeume REPLICA IDENTITY FULL;

-- Kontrolle: welche Tabellen sind jetzt live?
SELECT schemaname, tablename
FROM   pg_publication_tables
WHERE  pubname = 'supabase_realtime'
ORDER  BY tablename;
