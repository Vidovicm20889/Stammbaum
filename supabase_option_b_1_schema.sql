-- =====================================================
-- OPTION B — SCHRITT 1: SCHEMA (FK-Entkopplung + personen.verbund_id + Ansichts-Anker)
-- =====================================================
-- ⚠️ ENTWURF / NOCH NICHT AUSFÜHREN. Reihenfolge des Gesamt-Umbaus:
--   (1) Renderer (Frontend) verifiziert  →  (2) frischer Backup-Snapshot + Restore-Dry-Run
--   →  (3) DIESES Schema-File  →  (4) supabase_option_b_2_migration.sql im DRY-RUN (Rollback)
--   →  Konflikt-Report freigeben  →  (5) Migration scharf  →  (6) Papierkorb-RLS erneut anwenden.
--
-- ZWECK (Option B / Verbund-Graph): „Stammbaum" wird vom HARTEN Container zur FAMILIEN-ANSICHT.
--   * personen.stammbaum_id: FK ENTKOPPELT → bleibt nur noch als nullable HERKUNFTS-TAG
--     (keine harte 1:1-Bindung mehr; eine reale Person lebt im Verbund-Graphen, nicht „im Baum").
--   * personen.verbund_id: NEU (denormalisiert aus familien.verbund_id) = maßgeblicher Container
--     + Index → effizienter Graph-Scope „alle Personen des Verbunds".
--   * stammbaeume.anker_person_id: NEU = Ankerperson einer Familien-Ansicht („Familie X ansehen").
--
-- IDEMPOTENT. Verändert KEINE Personendaten (nur Struktur + ein Backfill der neuen Spalte).
-- Voraussetzungen: supabase_verbund.sql (familien.verbund_id, sieht_familie), supabase_papierkorb.sql
--   (geloescht_am — der Aktiv-Index filtert darauf).
-- =====================================================


-- =====================================================
-- 1) personen.verbund_id (denormalisiert) + Backfill + Aktiv-Index
-- =====================================================
ALTER TABLE public.personen ADD COLUMN IF NOT EXISTS verbund_id uuid;

-- Backfill aus der Familie (jede Person erbt den verbund_id ihrer familie_id).
UPDATE public.personen p
   SET verbund_id = f.verbund_id
  FROM public.familien f
 WHERE f.id = p.familie_id
   AND (p.verbund_id IS DISTINCT FROM f.verbund_id);

-- Schneller Graph-Scope „aktive Personen eines Verbunds".
CREATE INDEX IF NOT EXISTS personen_verbund_aktiv_idx
  ON public.personen (verbund_id) WHERE geloescht_am IS NULL;

-- HINWEIS: NOT NULL bewusst (noch) NICHT gesetzt — der Trigger unten füllt verbund_id bei jedem
-- INSERT/UPDATE; NOT NULL kann nach erfolgreicher Migration nachgezogen werden (separater Schritt).


-- =====================================================
-- 2) verbund_id konsistent halten (Trigger) — zwei Quellen ändern ihn:
--    a) personen.familie_id ändert sich  → verbund_id neu aus der (neuen) Familie ableiten.
--    b) familien.verbund_id ändert sich (Verbund-Merge bei Heirat, trg_beziehung_verbund)
--       → auf alle Personen der Familie propagieren.
-- =====================================================
CREATE OR REPLACE FUNCTION public.personen_verbund_ableiten()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.familie_id IS NOT NULL THEN
    SELECT f.verbund_id INTO NEW.verbund_id FROM public.familien f WHERE f.id = NEW.familie_id;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS personen_verbund_trg ON public.personen;
CREATE TRIGGER personen_verbund_trg
  BEFORE INSERT OR UPDATE OF familie_id ON public.personen
  FOR EACH ROW EXECUTE FUNCTION public.personen_verbund_ableiten();

CREATE OR REPLACE FUNCTION public.familien_verbund_propagieren()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.verbund_id IS DISTINCT FROM OLD.verbund_id THEN
    UPDATE public.personen SET verbund_id = NEW.verbund_id
     WHERE familie_id = NEW.id AND verbund_id IS DISTINCT FROM NEW.verbund_id;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS familien_verbund_propagieren_trg ON public.familien;
CREATE TRIGGER familien_verbund_propagieren_trg
  AFTER UPDATE OF verbund_id ON public.familien
  FOR EACH ROW EXECUTE FUNCTION public.familien_verbund_propagieren();


-- =====================================================
-- 3) FK-ENTKOPPLUNG personen.stammbaum_id  (Entscheidung 3: volle Entkopplung)
--    Die inline-FK (auto-Name, i. d. R. personen_stammbaum_id_fkey) wird gelöst; die SPALTE
--    bleibt als nullable Herkunfts-Tag erhalten. Idempotent über pg_constraint (Name robust
--    ermittelt, falls abweichend benannt).
-- =====================================================
DO $$
DECLARE c text;
BEGIN
  FOR c IN
    SELECT con.conname
      FROM pg_constraint con
      JOIN pg_class rel  ON rel.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = rel.relnamespace
     WHERE n.nspname = 'public' AND rel.relname = 'personen'
       AND con.contype = 'f'
       AND con.confrelid = 'public.stammbaeume'::regclass
  LOOP
    EXECUTE format('ALTER TABLE public.personen DROP CONSTRAINT %I', c);
    RAISE NOTICE 'FK personen->stammbaeume gelöst: %', c;
  END LOOP;
END $$;
-- stammbaum_id bleibt nullable; vorhandene Werte unverändert (Herkunfts-Tag / Ansichts-Hinweis).


-- =====================================================
-- 4) stammbaeume.anker_person_id  — Ankerperson der FAMILIEN-ANSICHT („Familie X ansehen").
--    ON DELETE SET NULL: wird die Ankerperson gelöscht, fällt der Anker weg (Ansicht wählt neu).
-- =====================================================
ALTER TABLE public.stammbaeume
  ADD COLUMN IF NOT EXISTS anker_person_id uuid REFERENCES public.personen(id) ON DELETE SET NULL;

-- Backfill: vorhandene Wurzel als Anker übernehmen, wo noch keiner gesetzt ist.
UPDATE public.stammbaeume s
   SET anker_person_id = s.wurzel_person_id
 WHERE s.anker_person_id IS NULL
   AND s.wurzel_person_id IS NOT NULL
   AND EXISTS (SELECT 1 FROM public.personen p WHERE p.id = s.wurzel_person_id);


NOTIFY pgrst, 'reload schema';
SELECT 'OPTION B Schritt 1 (Schema) — personen.verbund_id + Trigger + FK-Entkopplung stammbaum_id + stammbaeume.anker_person_id. KEINE Personendaten geaendert.' AS status;

-- KONTROLLE (nach Ausführung erwartbar):
--   SELECT count(*) FILTER (WHERE verbund_id IS NULL) AS personen_ohne_verbund FROM public.personen;  -- erwartet 0
--   SELECT conname FROM pg_constraint con JOIN pg_class r ON r.oid=con.conrelid
--     WHERE r.relname='personen' AND con.contype='f' AND con.confrelid='public.stammbaeume'::regclass; -- erwartet 0 Zeilen
