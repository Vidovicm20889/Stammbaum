-- =====================================================
-- SPRACH-/VIDEO-ZEITZEUGEN pro Person — Tabelle, RLS, Storage-Bucket + Policies
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- KONZEPT: Stimmen/Erinnerungen der Älteren ans Familienarchiv binden — eine Aufnahme
-- (Audio ODER Video) hängt an EINER Personenkarte (person_id). Aufnahme direkt im Browser
-- (MediaRecorder-API, KEINE neue Library) oder Datei-Upload; optionaler Titel + Transkript.
--
-- Baut auf dem bestehenden Schema/den bestehenden Helfern auf (analog Foto-Galerie/Dokumente,
-- supabase_personen_fotos.sql / supabase_personen_dokumente.sql):
--   - public.personen (id, familie_id, stammbaum_id)            -> supabase_multitree_phase5.sql
--   - public.ist_super_admin()                                  -> supabase_verbund.sql
--   - public.sieht_familie(uuid) / kann_familie_bearbeiten(uuid)-> supabase_verbund.sql
--
-- Speichermodell wie der bestehende Medien-Upload (Galerie/Dokumente):
--   - Metadaten in der DB-Tabelle public.person_aufnahmen
--   - Binärdaten im Storage-Bucket 'person-aufnahmen' (Audio/Video)
--   - Pfadschema:  {stammbaum_id}/{person_id}/{uuid}.{ext}
--     -> das ERSTE Pfad-Segment (stammbaum_id) steuert die Storage-RLS (Mitgliedschaft).
--
-- DATENSCHUTZ (bewusst, wie Dokumente — NICHT wie Fotos): Der Bucket ist NICHT public.
-- Aufnahmen lebender Personen sind besonders sensibel und bleiben STRIKT verbund-intern
-- (Lesen über signierte URLs, gegated durch sieht_familie; KEIN baum_freigaben-Pfad).
--
-- HINWEIS (Betrieb): Audio/Video sind media-/egress-intensiv (Supabase-Egress!). Dieses Feature
-- ist als PREMIUM-/LIMIT-KANDIDAT markiert (spätere Kopplung an abo_status). v1 begrenzt
-- clientseitig auf max. 50 MB je Aufnahme; ein hartes Server-Limit/Quota folgt mit dem Abo-Modell.
--
-- ABWEICHUNG vom Feature-Prompt (dokumentiert): Der Prompt nannte eine Spalte `verbund_id`.
-- Wir folgen stattdessen dem ETABLIERTEN, verbund-bewussten Medien-RLS-Muster
-- (`familie_id` + `stammbaum_id` + sieht_familie/kann_familie_bearbeiten), wie es Fotos/
-- Dokumente nutzen — das hält die Storage-Pfad-RLS konsistent (erstes Segment = stammbaum_id)
-- und vermeidet eine dritte, abweichende Sichtbarkeits-Logik. sieht_familie ist verbundweit.
--
-- IDEMPOTENT: mehrfaches Ausführen ist gefahrlos.
-- =====================================================


-- 1) Tabelle ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.person_aufnahmen (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id     uuid NOT NULL REFERENCES public.personen(id)   ON DELETE CASCADE,
  familie_id    uuid NOT NULL REFERENCES public.familien(id),
  stammbaum_id  uuid          REFERENCES public.stammbaeume(id),
  storage_pfad  text NOT NULL,                 -- Pfad im Bucket 'person-aufnahmen'
  typ           text NOT NULL DEFAULT 'audio'
                CHECK (typ IN ('audio','video')),
  titel         text,
  transkript    text,                          -- optionales Freitext-Transkript
  dauer_sek     int  NOT NULL DEFAULT 0,        -- Länge in Sekunden (best-effort)
  sortierung    int  NOT NULL DEFAULT 0,
  erstellt_von  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  erstellt_am   timestamptz NOT NULL DEFAULT now()
);

-- Hilfsindizes: schnelles Laden einer Person + stabile Reihenfolge
CREATE INDEX IF NOT EXISTS person_aufnahmen_person_idx
  ON public.person_aufnahmen (person_id, sortierung, erstellt_am);
CREATE INDEX IF NOT EXISTS person_aufnahmen_familie_idx
  ON public.person_aufnahmen (familie_id);


-- 2) RLS auf der Tabelle (verbund-basiert, EXAKT wie personen/personen_dokumente) ---
ALTER TABLE public.person_aufnahmen ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "person_aufnahmen_select" ON public.person_aufnahmen;
DROP POLICY IF EXISTS "person_aufnahmen_insert" ON public.person_aufnahmen;
DROP POLICY IF EXISTS "person_aufnahmen_update" ON public.person_aufnahmen;
DROP POLICY IF EXISTS "person_aufnahmen_delete" ON public.person_aufnahmen;

-- Lesen: Super-Admin alles; sonst nur Aufnahmen sichtbarer Familien (verbundweit)
CREATE POLICY "person_aufnahmen_select" ON public.person_aufnahmen FOR SELECT
  USING ( public.ist_super_admin() OR public.sieht_familie(familie_id) );

-- Schreiben/Ändern/Löschen: nur mit Bearbeitungsrecht der Familie
-- (Super-Admin / Familien-Owner / Familien-Admin im selben Verbund)
CREATE POLICY "person_aufnahmen_insert" ON public.person_aufnahmen FOR INSERT
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "person_aufnahmen_update" ON public.person_aufnahmen FOR UPDATE
  USING      ( public.kann_familie_bearbeiten(familie_id) )
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "person_aufnahmen_delete" ON public.person_aufnahmen FOR DELETE
  USING      ( public.kann_familie_bearbeiten(familie_id) );


-- 3) Storage-Bucket -----------------------------------------------------------
-- BEWUSST NICHT public (wie 'personen-dokumente'): Aufnahmen lebender Personen sind
-- sensibel -> Zugriff nur über signierte URLs + RLS (siehe unten).
INSERT INTO storage.buckets (id, name, public)
VALUES ('person-aufnahmen', 'person-aufnahmen', false)
ON CONFLICT (id) DO UPDATE SET public = false;


-- 4) Helfer: Darf der eingeloggte User den Ordner dieses Baums SEHEN / BEARBEITEN?
-- p_stammbaum_text = erstes Pfad-Segment (stammbaum_id als Text).
CREATE OR REPLACE FUNCTION public.darf_aufnordner_sehen(p_stammbaum_text text)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT public.ist_super_admin() OR EXISTS (
    SELECT 1 FROM public.stammbaeume s
    WHERE s.id::text = p_stammbaum_text
      AND public.sieht_familie(s.familie_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.darf_aufnordner_bearbeiten(p_stammbaum_text text)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.stammbaeume s
    WHERE s.id::text = p_stammbaum_text
      AND public.kann_familie_bearbeiten(s.familie_id)
  );
$$;


-- 5) Storage-Policies (auf storage.objects, Bucket 'person-aufnahmen') --------
DROP POLICY IF EXISTS "paufn_select" ON storage.objects;
DROP POLICY IF EXISTS "paufn_insert" ON storage.objects;
DROP POLICY IF EXISTS "paufn_update" ON storage.objects;
DROP POLICY IF EXISTS "paufn_delete" ON storage.objects;

-- SELECT/list (nötig für createSignedUrl/remove): nur, wenn das erste Pfad-Segment
-- (stammbaum_id) zu einer vom User SICHTBAREN Familie gehört (verbundweit lesen).
CREATE POLICY "paufn_select" ON storage.objects
  FOR SELECT TO authenticated
  USING ( bucket_id = 'person-aufnahmen'
          AND public.darf_aufnordner_sehen((storage.foldername(name))[1]) );

-- INSERT/UPDATE/DELETE: nur, wenn das erste Pfad-Segment (stammbaum_id) zu einer
-- vom User BEARBEITBAREN Familie gehört -> kein Schreiben in fremde Baum-Ordner.
CREATE POLICY "paufn_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK ( bucket_id = 'person-aufnahmen'
               AND public.darf_aufnordner_bearbeiten((storage.foldername(name))[1]) );
CREATE POLICY "paufn_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING ( bucket_id = 'person-aufnahmen'
          AND public.darf_aufnordner_bearbeiten((storage.foldername(name))[1]) );
CREATE POLICY "paufn_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING ( bucket_id = 'person-aufnahmen'
          AND public.darf_aufnordner_bearbeiten((storage.foldername(name))[1]) );


-- 6) Kontrolle ----------------------------------------------------------------
SELECT 'person_aufnahmen + RLS + Bucket person-aufnahmen (privat) + Storage-Policies angelegt' AS status;
