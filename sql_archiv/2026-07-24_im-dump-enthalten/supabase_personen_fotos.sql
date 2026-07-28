-- =====================================================
-- FOTO-GALERIE pro Person — Tabelle, RLS, Storage-Bucket + Policies
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Baut auf dem bestehenden Schema/den bestehenden Helfern auf:
--   - public.personen (id, familie_id, stammbaum_id)            -> supabase_multitree_phase5.sql
--   - public.ist_super_admin()                                  -> supabase_verbund.sql
--   - public.sieht_familie(uuid) / kann_familie_bearbeiten(uuid)-> supabase_verbund.sql
--
-- Speichermodell wie der bestehende Medien-Upload (feMediaUpload/avatars):
--   - Metadaten in der DB-Tabelle public.personen_fotos
--   - Binärdaten im Storage-Bucket 'personen-fotos'
--   - Pfadschema:  {stammbaum_id}/{person_id}/{uuid}
--     -> das ERSTE Pfad-Segment (stammbaum_id) steuert die Storage-RLS (Mitgliedschaft).
--
-- IDEMPOTENT: mehrfaches Ausführen ist gefahrlos.
-- =====================================================


-- 1) Tabelle ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.personen_fotos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id     uuid NOT NULL REFERENCES public.personen(id)   ON DELETE CASCADE,
  familie_id    uuid NOT NULL REFERENCES public.familien(id),
  stammbaum_id  uuid          REFERENCES public.stammbaeume(id),
  storage_pfad  text NOT NULL,                 -- Pfad im Bucket 'personen-fotos'
  beschriftung  text,
  ist_hauptbild boolean NOT NULL DEFAULT false,
  aufnahme_datum date,
  sortierung    int  NOT NULL DEFAULT 0,
  erstellt_am   timestamptz NOT NULL DEFAULT now()
);

-- Hilfsindizes: schnelles Laden einer Person + stabile Reihenfolge
CREATE INDEX IF NOT EXISTS personen_fotos_person_idx
  ON public.personen_fotos (person_id, sortierung, erstellt_am);
CREATE INDEX IF NOT EXISTS personen_fotos_familie_idx
  ON public.personen_fotos (familie_id);

-- Genau EIN Hauptbild je Person (partieller Unique-Index; das Setzen hebt das
-- alte Hauptbild zuerst auf, daher kein Konflikt im Normalfall).
CREATE UNIQUE INDEX IF NOT EXISTS personen_fotos_ein_hauptbild
  ON public.personen_fotos (person_id) WHERE ist_hauptbild;


-- 2) RLS auf der Tabelle (verbund-basiert, EXAKT wie personen/beziehungen) -----
ALTER TABLE public.personen_fotos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "personen_fotos_select" ON public.personen_fotos;
DROP POLICY IF EXISTS "personen_fotos_insert" ON public.personen_fotos;
DROP POLICY IF EXISTS "personen_fotos_update" ON public.personen_fotos;
DROP POLICY IF EXISTS "personen_fotos_delete" ON public.personen_fotos;

-- Lesen: Super-Admin alles; sonst nur Fotos sichtbarer Familien (verbundweit)
CREATE POLICY "personen_fotos_select" ON public.personen_fotos FOR SELECT
  USING ( public.ist_super_admin() OR public.sieht_familie(familie_id) );

-- Schreiben/Ändern/Löschen: nur mit Bearbeitungsrecht der Familie
-- (Super-Admin / Familien-Owner / Familien-Admin im selben Verbund)
CREATE POLICY "personen_fotos_insert" ON public.personen_fotos FOR INSERT
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "personen_fotos_update" ON public.personen_fotos FOR UPDATE
  USING      ( public.kann_familie_bearbeiten(familie_id) )
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "personen_fotos_delete" ON public.personen_fotos FOR DELETE
  USING      ( public.kann_familie_bearbeiten(familie_id) );


-- 3) Storage-Bucket -----------------------------------------------------------
-- Public-Read wie 'avatars'/'familien' (stabile Public-URLs für die Baum-Karten/
-- den PDF-Export, ohne Signatur-Ablauf). Die SCHREIB-Rechte sind über die
-- Pfad-/Mitgliedschaftsprüfung unten streng begrenzt.
INSERT INTO storage.buckets (id, name, public)
VALUES ('personen-fotos', 'personen-fotos', true)
ON CONFLICT (id) DO UPDATE SET public = true;


-- 4) Helfer: Darf der eingeloggte User in den Ordner dieses Baums schreiben? ---
-- p_stammbaum_text = erstes Pfad-Segment (stammbaum_id als Text).
CREATE OR REPLACE FUNCTION public.darf_fotoordner_bearbeiten(p_stammbaum_text text)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.stammbaeume s
    WHERE s.id::text = p_stammbaum_text
      AND public.kann_familie_bearbeiten(s.familie_id)
  );
$$;


-- 5) Storage-Policies (auf storage.objects, Bucket 'personen-fotos') ----------
DROP POLICY IF EXISTS "pfotos_select" ON storage.objects;
DROP POLICY IF EXISTS "pfotos_insert" ON storage.objects;
DROP POLICY IF EXISTS "pfotos_update" ON storage.objects;
DROP POLICY IF EXISTS "pfotos_delete" ON storage.objects;

-- SELECT/list: jeder eingeloggte User (nötig für remove()/list(); öffentliche
-- Anzeige läuft zusätzlich über das public-Flag des Buckets).
CREATE POLICY "pfotos_select" ON storage.objects
  FOR SELECT TO authenticated
  USING ( bucket_id = 'personen-fotos' );

-- INSERT/UPDATE/DELETE: nur, wenn das erste Pfad-Segment (stammbaum_id) zu einer
-- vom User BEARBEITBAREN Familie gehört -> kein Schreiben in fremde Baum-Ordner.
CREATE POLICY "pfotos_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK ( bucket_id = 'personen-fotos'
               AND public.darf_fotoordner_bearbeiten((storage.foldername(name))[1]) );
CREATE POLICY "pfotos_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING ( bucket_id = 'personen-fotos'
          AND public.darf_fotoordner_bearbeiten((storage.foldername(name))[1]) );
CREATE POLICY "pfotos_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING ( bucket_id = 'personen-fotos'
          AND public.darf_fotoordner_bearbeiten((storage.foldername(name))[1]) );


-- 6) Kontrolle ----------------------------------------------------------------
SELECT 'personen_fotos + RLS + Bucket personen-fotos + Storage-Policies angelegt' AS status;
