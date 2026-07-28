-- =====================================================
-- BENACHRICHTIGUNGEN — Supabase Realtime aktivieren
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Zweck: Der Ungelesen-Indikator am Profilsymbol soll OHNE Reload erscheinen,
-- sobald eine neue Benachrichtigung (z. B. Event-Einladung) eintrifft. Das Frontend
-- abonniert `benachrichtigungen` per Supabase Realtime (Channel 'benachr-sync',
-- gefiltert auf user_id = auth.uid()). Damit Realtime Änderungen ausliefert, muss
-- die Tabelle in der Publication `supabase_realtime` liegen.
--
-- benachrichtigungen hat eine echte RLS-SELECT-Policy (eigene Zeilen) -> Realtime
-- liefert jedem Nutzer NUR seine eigenen Zeilen (Isolation bleibt gewahrt).
-- Voraussetzung: supabase_benachrichtigungen.sql.
-- =====================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'benachrichtigungen'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.benachrichtigungen;
  END IF;
END $$;

-- Kontrolle: Tabelle sollte jetzt in der Publication gelistet sein.
SELECT 'benachrichtigungen in supabase_realtime?' AS info, count(*) AS treffer
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
  AND tablename = 'benachrichtigungen';
