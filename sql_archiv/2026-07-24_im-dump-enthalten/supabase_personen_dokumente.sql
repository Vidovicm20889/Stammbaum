-- =====================================================
-- DOKUMENTE & QUELLEN pro Person — Tabelle, RLS, Storage-Bucket + Policies
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Baut auf dem bestehenden Schema/den bestehenden Helfern auf (analog Foto-Galerie,
-- supabase_personen_fotos.sql):
--   - public.personen (id, familie_id, stammbaum_id)            -> supabase_multitree_phase5.sql
--   - public.ist_super_admin()                                  -> supabase_verbund.sql
--   - public.sieht_familie(uuid) / kann_familie_bearbeiten(uuid)-> supabase_verbund.sql
--
-- Speichermodell wie der bestehende Medien-Upload (Galerie/avatars):
--   - Metadaten in der DB-Tabelle public.personen_dokumente
--   - Binärdaten im Storage-Bucket 'personen-dokumente' (PDF + Bilder)
--   - Pfadschema:  {stammbaum_id}/{person_id}/{uuid}
--     -> das ERSTE Pfad-Segment (stammbaum_id) steuert die Storage-RLS (Mitgliedschaft).
--
-- UNTERSCHIED ZUR FOTO-GALERIE (bewusst): Der Bucket ist NICHT public. Geburts-/
-- Heiratsurkunden, Kirchenbücher etc. sind sensible personenbezogene Belege und
-- sollen nicht weltweit per URL abrufbar sein. Lesen läuft über signierte URLs,
-- gegated durch sieht_familie (verbundweit), Schreiben durch kann_familie_bearbeiten
-- -> dasselbe tree_id-basierte RLS-Muster wie bei den Fotos, nur lese-gated.
--
-- IDEMPOTENT: mehrfaches Ausführen ist gefahrlos.
-- =====================================================


-- 1) Tabelle ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.personen_dokumente (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id     uuid          REFERENCES public.personen(id)    ON DELETE CASCADE,  -- nullable: baum-/quellen-bezogene Belege ohne feste Person möglich
  familie_id    uuid NOT NULL REFERENCES public.familien(id),
  stammbaum_id  uuid          REFERENCES public.stammbaeume(id),
  storage_pfad  text NOT NULL,                 -- Pfad im Bucket 'personen-dokumente'
  titel         text,
  dok_typ       text NOT NULL DEFAULT 'sonstiges'
                CHECK (dok_typ IN ('geburtsurkunde','heiratsurkunde','kirchenbuch','brief','sonstiges')),
  quellenangabe text,                          -- Freitext, genealogische Quellenzitierung
  dok_datum     date,                          -- Datum des Dokuments (kanonisch ISO)
  sortierung    int  NOT NULL DEFAULT 0,
  erstellt_am   timestamptz NOT NULL DEFAULT now()
);

-- Hilfsindizes: schnelles Laden einer Person + stabile Reihenfolge
CREATE INDEX IF NOT EXISTS personen_dokumente_person_idx
  ON public.personen_dokumente (person_id, sortierung, erstellt_am);
CREATE INDEX IF NOT EXISTS personen_dokumente_familie_idx
  ON public.personen_dokumente (familie_id);


-- 2) RLS auf der Tabelle (verbund-basiert, EXAKT wie personen/personen_fotos) ---
ALTER TABLE public.personen_dokumente ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "personen_dokumente_select" ON public.personen_dokumente;
DROP POLICY IF EXISTS "personen_dokumente_insert" ON public.personen_dokumente;
DROP POLICY IF EXISTS "personen_dokumente_update" ON public.personen_dokumente;
DROP POLICY IF EXISTS "personen_dokumente_delete" ON public.personen_dokumente;

-- Lesen: Super-Admin alles; sonst nur Belege sichtbarer Familien (verbundweit)
CREATE POLICY "personen_dokumente_select" ON public.personen_dokumente FOR SELECT
  USING ( public.ist_super_admin() OR public.sieht_familie(familie_id) );

-- Schreiben/Ändern/Löschen: nur mit Bearbeitungsrecht der Familie
-- (Super-Admin / Familien-Owner / Familien-Admin im selben Verbund)
CREATE POLICY "personen_dokumente_insert" ON public.personen_dokumente FOR INSERT
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "personen_dokumente_update" ON public.personen_dokumente FOR UPDATE
  USING      ( public.kann_familie_bearbeiten(familie_id) )
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "personen_dokumente_delete" ON public.personen_dokumente FOR DELETE
  USING      ( public.kann_familie_bearbeiten(familie_id) );


-- 3) Storage-Bucket -----------------------------------------------------------
-- BEWUSST NICHT public (anders als 'personen-fotos'/'avatars'): Urkunden sind
-- sensibel -> Zugriff nur über signierte URLs + RLS (siehe unten).
INSERT INTO storage.buckets (id, name, public)
VALUES ('personen-dokumente', 'personen-dokumente', false)
ON CONFLICT (id) DO UPDATE SET public = false;


-- 4) Helfer: Darf der eingeloggte User den Ordner dieses Baums SEHEN / BEARBEITEN?
-- p_stammbaum_text = erstes Pfad-Segment (stammbaum_id als Text).
CREATE OR REPLACE FUNCTION public.darf_dokordner_sehen(p_stammbaum_text text)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT public.ist_super_admin() OR EXISTS (
    SELECT 1 FROM public.stammbaeume s
    WHERE s.id::text = p_stammbaum_text
      AND public.sieht_familie(s.familie_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.darf_dokordner_bearbeiten(p_stammbaum_text text)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.stammbaeume s
    WHERE s.id::text = p_stammbaum_text
      AND public.kann_familie_bearbeiten(s.familie_id)
  );
$$;


-- 5) Storage-Policies (auf storage.objects, Bucket 'personen-dokumente') ------
DROP POLICY IF EXISTS "pdok_select" ON storage.objects;
DROP POLICY IF EXISTS "pdok_insert" ON storage.objects;
DROP POLICY IF EXISTS "pdok_update" ON storage.objects;
DROP POLICY IF EXISTS "pdok_delete" ON storage.objects;

-- SELECT/list (nötig für createSignedUrl/remove): nur, wenn das erste Pfad-Segment
-- (stammbaum_id) zu einer vom User SICHTBAREN Familie gehört (verbundweit lesen).
CREATE POLICY "pdok_select" ON storage.objects
  FOR SELECT TO authenticated
  USING ( bucket_id = 'personen-dokumente'
          AND public.darf_dokordner_sehen((storage.foldername(name))[1]) );

-- INSERT/UPDATE/DELETE: nur, wenn das erste Pfad-Segment (stammbaum_id) zu einer
-- vom User BEARBEITBAREN Familie gehört -> kein Schreiben in fremde Baum-Ordner.
CREATE POLICY "pdok_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK ( bucket_id = 'personen-dokumente'
               AND public.darf_dokordner_bearbeiten((storage.foldername(name))[1]) );
CREATE POLICY "pdok_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING ( bucket_id = 'personen-dokumente'
          AND public.darf_dokordner_bearbeiten((storage.foldername(name))[1]) );
CREATE POLICY "pdok_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING ( bucket_id = 'personen-dokumente'
          AND public.darf_dokordner_bearbeiten((storage.foldername(name))[1]) );


-- 6) Kontrolle ----------------------------------------------------------------
SELECT 'personen_dokumente + RLS + Bucket personen-dokumente (privat) + Storage-Policies angelegt' AS status;
