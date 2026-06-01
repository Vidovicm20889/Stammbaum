-- =====================================================
-- STAMMBAUM Phase A1 — Schema für Supabase-basierten Baum
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
-- =====================================================

-- 1) Manuelle Kartenpositionen (für späteres Verschieben, #2). NULL = Auto-Layout.
ALTER TABLE public.personen ADD COLUMN IF NOT EXISTS pos_x double precision;
ALTER TABLE public.personen ADD COLUMN IF NOT EXISTS pos_y double precision;

-- 2) Eindeutige externe_id je Familie -> macht die Migration idempotent
--    (mehrfaches Ausführen überschreibt statt zu duplizieren).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'personen_familie_externe_uniq'
  ) THEN
    ALTER TABLE public.personen
      ADD CONSTRAINT personen_familie_externe_uniq UNIQUE (familie_id, externe_id);
  END IF;
END $$;

-- Kontrolle
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='personen'
ORDER BY ordinal_position;
