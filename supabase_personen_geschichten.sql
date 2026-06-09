-- =====================================================
-- MEHRSPRACHIGE LEBENSGESCHICHTEN pro Person — Tabelle, RLS, Sync, Backfill
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- HINTERGRUND
-- Das bisherige einfache Biografie-/Notiz-Feld liegt in
--   personen.stammbaum_daten->>'beschreibung'
-- und wird heute auf zwei Wegen synchronisiert (DAS BLEIBT UNVERÄNDERT):
--   1) ident_sync (supabase_gleiche_person_sync.sql): kopiert bei jeder Änderung das
--      KOMPLETTE stammbaum_daten auf alle identitaet_id-Zwillingskarten -> beschreibung
--      bleibt über verknüpfte Personen synchron.
--   2) profil_person_sync (supabase_profil_person_sync.sql): beschreibung <-> profile.biografie.
--
-- DIESE DATEI erweitert das Konzept additiv um STRUKTURIERTE, MEHRSPRACHIGE Geschichten
-- (eigene Tabelle), OHNE das beschreibung-Feld oder dessen Sync anzutasten. Die neue
-- Tabelle bekommt einen EIGENEN Identitäts-Sync-Trigger, der dieselbe Logik wie ident_sync
-- nachbildet: eine Geschichte einer Person wird auf alle identitaet_id-Zwillinge gespiegelt.
--
-- Benennung/RLS/Storage-Konvention exakt wie supabase_personen_fotos.sql
-- (familie_id steuert die verbund-basierte RLS; ist_super_admin/sieht_familie/
--  kann_familie_bearbeiten stammen aus supabase_verbund.sql).
--
-- IDEMPOTENT: mehrfaches Ausführen ist gefahrlos.
-- =====================================================


-- 1) Tabelle ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.personen_geschichten (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id       uuid NOT NULL REFERENCES public.personen(id)   ON DELETE CASCADE,
  familie_id      uuid NOT NULL REFERENCES public.familien(id),
  stammbaum_id    uuid          REFERENCES public.stammbaeume(id),
  sprache         text NOT NULL CHECK (sprache IN ('de','sr','hr','ba','en')),
  titel           text,
  text            text,                          -- Markdown-Quelle
  veroeffentlicht boolean NOT NULL DEFAULT true,
  aktualisiert_am timestamptz NOT NULL DEFAULT now(),
  -- Eine Geschichte je Person UND Sprache (Quelle der Sprach-Tabs/Spiegel-Upsert)
  UNIQUE (person_id, sprache)
);

CREATE INDEX IF NOT EXISTS personen_geschichten_person_idx
  ON public.personen_geschichten (person_id);
CREATE INDEX IF NOT EXISTS personen_geschichten_familie_idx
  ON public.personen_geschichten (familie_id);


-- 2) aktualisiert_am automatisch pflegen (BEFORE INSERT/UPDATE) ----------------
CREATE OR REPLACE FUNCTION public.personen_geschichten_touch()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.aktualisiert_am := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS personen_geschichten_touch_trg ON public.personen_geschichten;
CREATE TRIGGER personen_geschichten_touch_trg
  BEFORE INSERT OR UPDATE ON public.personen_geschichten
  FOR EACH ROW EXECUTE FUNCTION public.personen_geschichten_touch();


-- 3) RLS (verbund-basiert, wie personen/personen_fotos) -----------------------
ALTER TABLE public.personen_geschichten ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "geschichten_select" ON public.personen_geschichten;
DROP POLICY IF EXISTS "geschichten_insert" ON public.personen_geschichten;
DROP POLICY IF EXISTS "geschichten_update" ON public.personen_geschichten;
DROP POLICY IF EXISTS "geschichten_delete" ON public.personen_geschichten;

-- Lesen: Super-Admin alles; sonst sichtbare Familie (verbundweit) — Entwürfe
-- (veroeffentlicht=false) NUR für Bearbeiter der Familie.
CREATE POLICY "geschichten_select" ON public.personen_geschichten FOR SELECT
  USING ( public.ist_super_admin()
          OR ( public.sieht_familie(familie_id)
               AND ( veroeffentlicht OR public.kann_familie_bearbeiten(familie_id) ) ) );

-- Schreiben/Ändern/Löschen: nur mit Bearbeitungsrecht der Familie
-- (Super-Admin / Familien-Owner / Familien-Admin im selben Verbund).
CREATE POLICY "geschichten_insert" ON public.personen_geschichten FOR INSERT
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "geschichten_update" ON public.personen_geschichten FOR UPDATE
  USING      ( public.kann_familie_bearbeiten(familie_id) )
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "geschichten_delete" ON public.personen_geschichten FOR DELETE
  USING      ( public.kann_familie_bearbeiten(familie_id) );


-- 4) Identitäts-Sync: Geschichte auf alle Zwillinge spiegeln ------------------
-- Spiegelt INSERT/UPDATE/DELETE einer Geschichte auf alle Karten mit derselben
-- identitaet_id (analog ident_sync für stammbaum_daten). Jede Zwillingskarte
-- bekommt ihre eigene Zeile mit eigener familie_id/stammbaum_id, aber gleichem
-- (sprache, titel, text, veroeffentlicht). Loop-Schutz: GUC + pg_trigger_depth.
CREATE OR REPLACE FUNCTION public.trg_geschichte_ident_sync()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_person uuid := COALESCE(NEW.person_id, OLD.person_id);
  v_ident  uuid;
BEGIN
  IF coalesce(current_setting('app.geschicht_sync_off', true), '0') = '1' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  IF pg_trigger_depth() > 1 THEN RETURN COALESCE(NEW, OLD); END IF;

  SELECT identitaet_id INTO v_ident FROM public.personen WHERE id = v_person;
  IF v_ident IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;   -- keine Zwillinge

  PERFORM set_config('app.geschicht_sync_off', '1', true);

  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.personen_geschichten g
     USING public.personen tw
     WHERE g.person_id = tw.id
       AND tw.identitaet_id = v_ident
       AND tw.id <> v_person
       AND g.sprache = OLD.sprache;
  ELSE
    INSERT INTO public.personen_geschichten
       (person_id, familie_id, stammbaum_id, sprache, titel, text, veroeffentlicht)
    SELECT tw.id, tw.familie_id, tw.stammbaum_id,
           NEW.sprache, NEW.titel, NEW.text, NEW.veroeffentlicht
      FROM public.personen tw
     WHERE tw.identitaet_id = v_ident AND tw.id <> v_person
    ON CONFLICT (person_id, sprache) DO UPDATE SET
       titel           = EXCLUDED.titel,
       text            = EXCLUDED.text,
       veroeffentlicht = EXCLUDED.veroeffentlicht;
  END IF;

  PERFORM set_config('app.geschicht_sync_off', '0', true);
  RETURN COALESCE(NEW, OLD);
END $$;

DROP TRIGGER IF EXISTS geschichte_ident_sync ON public.personen_geschichten;
CREATE TRIGGER geschichte_ident_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.personen_geschichten
  FOR EACH ROW EXECUTE FUNCTION public.trg_geschichte_ident_sync();


-- 5) Backfill: bestehende beschreibung -> de-Geschichte -----------------------
-- Sync-Trigger kurz deaktivieren; jede Zwillingskarte hat dank ident_sync ohnehin
-- dieselbe beschreibung und wird hier direkt einzeln getroffen (kein Spiegeln nötig).
ALTER TABLE public.personen_geschichten DISABLE TRIGGER geschichte_ident_sync;

INSERT INTO public.personen_geschichten
  (person_id, familie_id, stammbaum_id, sprache, titel, text, veroeffentlicht)
SELECT pe.id, pe.familie_id, pe.stammbaum_id, 'de',
       NULL, pe.stammbaum_daten->>'beschreibung', true
FROM public.personen pe
WHERE pe.familie_id IS NOT NULL
  AND coalesce(trim(pe.stammbaum_daten->>'beschreibung'), '') <> ''
ON CONFLICT (person_id, sprache) DO NOTHING;

ALTER TABLE public.personen_geschichten ENABLE TRIGGER geschichte_ident_sync;


-- 6) Kontrolle ----------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
SELECT 'personen_geschichten + RLS + ident-Sync-Trigger + Backfill (beschreibung->de) angelegt' AS status;
