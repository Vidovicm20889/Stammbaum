-- ============================================================
-- Konflikterkennung (P5): updated_at auf personen für Optimistic Locking
-- ============================================================
-- Zweck: Das Frontend merkt sich beim Öffnen des Personen-Editors den Stand
-- (updated_at) und prüft beim Speichern, ob die Zeile zwischenzeitlich von
-- jemand anderem geändert wurde. Ist updated_at gewandert -> Konflikt-Dialog
-- (Meine überschreiben / Aktuelle übernehmen / Unterschiede vergleichen).
--
-- WICHTIG / Konventionen:
--  * Idempotent: ADD COLUMN IF NOT EXISTS + CREATE OR REPLACE + DROP/CREATE TRIGGER.
--  * BEFORE UPDATE-Trigger setzt updated_at = now() bei JEDER Änderung (auch durch
--    andere Trigger wie ident_sync/Blutlinie -> Zwillinge bekommen ebenfalls einen
--    neuen Stand, was korrekt ist: ihre Daten haben sich geändert).
--  * Bestehende Zeilen werden mit DEFAULT now() befüllt (einmaliger Backfill).
--  * Reine Lese-/Vergleichslogik im Frontend; keine RLS-Änderung nötig.
--
-- Ausführen im Supabase SQL-Editor.
-- ============================================================

ALTER TABLE public.personen
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.personen_touch_updated()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_personen_touch_updated ON public.personen;
CREATE TRIGGER trg_personen_touch_updated
  BEFORE UPDATE ON public.personen
  FOR EACH ROW
  EXECUTE FUNCTION public.personen_touch_updated();

-- Kontrolle:
SELECT column_name, data_type
FROM   information_schema.columns
WHERE  table_schema = 'public' AND table_name = 'personen' AND column_name = 'updated_at';
