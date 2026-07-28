-- =====================================================
-- PAPIERKORB — STORAGE-WAISEN-AUFRÄUMUNG (Ergänzung zu supabase_papierkorb.sql)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier, Run). IDEMPOTENT.
-- NACH supabase_papierkorb.sql, supabase_personen_fotos/-dokumente/-aufnahmen, supabase_gedenkseiten.
--
-- PROBLEM: Beim physischen Löschen einer Person (papierkorb_purge nach 30 Tagen ODER
-- papierkorb_endgueltig im Papierkorb) greift CASCADE -> die DB-Zeilen der Medien
-- (personen_fotos/-dokumente/person_aufnahmen/gedenk_eintraege) verschwinden, ABER die
-- Dateien im Storage bleiben als Waisen liegen (Postgres kann den Storage nicht löschen).
--
-- LÖSUNG: BEFORE-DELETE-Trigger auf den 4 Medientabellen schreiben den storage_pfad in die
-- Queue `verwaiste_medien` — ABER NUR, wenn die zugehörige PERSON bereits weg ist (= die Zeile
-- wird per CASCADE eines Personen-DELETE entfernt). Bei normalem Einzel-Medien-Löschen
-- (Galerie/Dokument/Aufnahme/Gedenk-Eintrag löschen) existiert die Person noch -> KEINE
-- Queue-Zeile (das Frontend räumt diesen Pfad ohnehin direkt). Deckt damit Purge, „Endgültig
-- löschen" UND manuelle Personen-Löschung ab, ohne die großen RPCs anfassen zu müssen.
--
-- AUFRÄUMUNG: Das Frontend (super_admin) liest die Queue über verwaiste_medien_holen(), löscht
-- die Dateien je Bucket (Storage-RLS = super_admin darf überall) und markiert sie erledigt.
-- Bewusst KEIN Storage-Löschen aus Postgres (geht nicht) und keine Edge Function nötig
-- (analog zur bestehenden verwaiste_event_medien-Queue).
-- =====================================================


-- =====================================================
-- 1) QUEUE-TABELLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.verwaiste_medien (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket       text NOT NULL,
  pfad         text NOT NULL,
  erfasst_am   timestamptz NOT NULL DEFAULT now(),
  bereinigt    boolean NOT NULL DEFAULT false,
  bereinigt_am timestamptz
);
CREATE INDEX IF NOT EXISTS verwaiste_medien_offen_idx
  ON public.verwaiste_medien (bereinigt) WHERE NOT bereinigt;

ALTER TABLE public.verwaiste_medien ENABLE ROW LEVEL SECURITY;
-- Keine offene Policy -> Zugriff nur über die SECURITY-DEFINER-RPCs unten (super_admin).
-- Der Trigger (DEFINER) schreibt direkt, RLS-Bypass.


-- =====================================================
-- 2) TRIGGER-FUNKTION: storage_pfad in die Queue, NUR wenn die Person schon weg ist (CASCADE).
--    TG_ARGV[0] = Bucket-Name der jeweiligen Medientabelle.
-- =====================================================
CREATE OR REPLACE FUNCTION public._verwaiste_medien_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF OLD.storage_pfad IS NOT NULL AND btrim(OLD.storage_pfad) <> ''
     AND NOT EXISTS (SELECT 1 FROM public.personen WHERE id = OLD.person_id) THEN
    INSERT INTO public.verwaiste_medien (bucket, pfad) VALUES (TG_ARGV[0], OLD.storage_pfad);
  END IF;
  RETURN OLD;
END $$;


-- =====================================================
-- 3) TRIGGER je Medientabelle (BEFORE DELETE) mit dem passenden Bucket
-- =====================================================
DROP TRIGGER IF EXISTS vm_fotos_trg ON public.personen_fotos;
CREATE TRIGGER vm_fotos_trg BEFORE DELETE ON public.personen_fotos
  FOR EACH ROW EXECUTE FUNCTION public._verwaiste_medien_trg('personen-fotos');

DROP TRIGGER IF EXISTS vm_dok_trg ON public.personen_dokumente;
CREATE TRIGGER vm_dok_trg BEFORE DELETE ON public.personen_dokumente
  FOR EACH ROW EXECUTE FUNCTION public._verwaiste_medien_trg('personen-dokumente');

DROP TRIGGER IF EXISTS vm_aufn_trg ON public.person_aufnahmen;
CREATE TRIGGER vm_aufn_trg BEFORE DELETE ON public.person_aufnahmen
  FOR EACH ROW EXECUTE FUNCTION public._verwaiste_medien_trg('person-aufnahmen');

DROP TRIGGER IF EXISTS vm_gedenk_trg ON public.gedenk_eintraege;
CREATE TRIGGER vm_gedenk_trg BEFORE DELETE ON public.gedenk_eintraege
  FOR EACH ROW EXECUTE FUNCTION public._verwaiste_medien_trg('gedenkseiten');


-- =====================================================
-- 4) RPCs (super_admin): offene Waisen holen + erledigt markieren.
--    Die EIGENTLICHE Storage-Löschung macht das Frontend (Storage-RLS = super_admin darf überall).
-- =====================================================
-- Eigene, eindeutige Namen (es existiert bereits verwaiste_medien_erledigt(p_id uuid) für die
-- Event-Medien-Queue — Verwechslung/Overload bewusst vermieden).
CREATE OR REPLACE FUNCTION public.verwaiste_medien_storage_holen()
RETURNS TABLE (id uuid, bucket text, pfad text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id, bucket, pfad FROM public.verwaiste_medien
   WHERE NOT bereinigt AND public.ist_super_admin()
   ORDER BY erfasst_am
   LIMIT 500;
$$;
GRANT EXECUTE ON FUNCTION public.verwaiste_medien_storage_holen() TO authenticated;

CREATE OR REPLACE FUNCTION public.verwaiste_medien_storage_erledigt(p_ids uuid[])
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n int;
BEGIN
  IF NOT public.ist_super_admin() THEN RETURN 0; END IF;
  IF p_ids IS NULL OR array_length(p_ids,1) IS NULL THEN RETURN 0; END IF;
  UPDATE public.verwaiste_medien SET bereinigt = true, bereinigt_am = now()
   WHERE id = ANY(p_ids) AND NOT bereinigt;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;
GRANT EXECUTE ON FUNCTION public.verwaiste_medien_storage_erledigt(uuid[]) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_papierkorb_storage_cleanup.sql ausgeführt — Queue verwaiste_medien + BEFORE-DELETE-Trigger (fotos/dokumente/aufnahmen/gedenk) + Hol-/Erledigt-RPCs (super_admin). Frontend räumt den Storage.' AS status;
