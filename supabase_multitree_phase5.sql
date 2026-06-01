-- =====================================================
-- MULTI-TREE Phase B1 — eigene Stammbäume (stammbaeume) + Zuordnung
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Modell: Ein Tenant (familie) kann mehrere Stammbäume (stammbaeume) haben.
-- Jede Person gehört zu genau einem Stammbaum (personen.stammbaum_id).
-- Baumübergreifende Verknüpfung = Beziehung (ehepartner) zwischen Personen
-- unterschiedlicher Stammbäume.
-- =====================================================

-- 1) Stammbäume-Tabelle
CREATE TABLE IF NOT EXISTS public.stammbaeume (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  familie_id       uuid NOT NULL REFERENCES public.familien(id),
  name             text NOT NULL,
  wurzel_person_id uuid,                              -- optional: ältester Vorfahre
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (familie_id, name)                           -- idempotente Migration
);

-- 2) Zuordnung an Personen
ALTER TABLE public.personen
  ADD COLUMN IF NOT EXISTS stammbaum_id uuid REFERENCES public.stammbaeume(id);

-- 3) RLS für stammbaeume
ALTER TABLE public.stammbaeume ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stammbaeume_select" ON public.stammbaeume;
DROP POLICY IF EXISTS "stammbaeume_insert" ON public.stammbaeume;
DROP POLICY IF EXISTS "stammbaeume_update" ON public.stammbaeume;
DROP POLICY IF EXISTS "stammbaeume_delete" ON public.stammbaeume;

-- Lesen: Super-Admin alle; Mitglieder die Bäume ihrer Familie
CREATE POLICY "stammbaeume_select" ON public.stammbaeume
FOR SELECT USING (
  ist_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid() AND familie_id = stammbaeume.familie_id
  )
);
-- Schreiben: Super-Admin oder Familien-Admin
CREATE POLICY "stammbaeume_insert" ON public.stammbaeume
FOR INSERT WITH CHECK (
  ist_super_admin() OR get_meine_rolle(familie_id) = 'familien_admin'
);
CREATE POLICY "stammbaeume_update" ON public.stammbaeume
FOR UPDATE USING (
  ist_super_admin() OR get_meine_rolle(familie_id) = 'familien_admin'
);
CREATE POLICY "stammbaeume_delete" ON public.stammbaeume
FOR DELETE USING ( ist_super_admin() );

-- Kontrolle
SELECT 'stammbaeume + personen.stammbaum_id angelegt' AS status;
