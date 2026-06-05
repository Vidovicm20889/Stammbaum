-- =====================================================
-- PODEŠAVANJE PORODICE — Stammbaum-Stammdaten bearbeiten (pro Stammbaum)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Erlaubt Familien-Owner/-Admin (und Super-Admin) das Bearbeiten der Stammdaten
-- EINES Stammbaums. Familienmitglieder (nur Lesen) dürfen die Werte nur ansehen.
--
-- Datenmodell:
--   * Kern-/Matching-Felder (Duplikatcheck, konsistent zur Konto-Anlage) auf
--     public.familien:  name, land, stadt, gemeinde, opis
--   * „Grad / selo" ist EIN Feld (familien.stadt) – konsistent zur restlichen App.
--   * Reiche Zusatz-Stammdaten PRO STAMMBAUM in public.stammbaeume.einstellungen
--     (jsonb): region, geschichte, ursprung, hintergrund, ereignisse,
--     bekannte_mitglieder, motto, ansprechpartner, kontakt_email, webseite,
--     foto_url, foto_path, wappen_url, wappen_path
--
-- Enthält:
--   1) Spalten familien.opis + stammbaeume.einstellungen
--   2) Audit-Tabelle familien_audit (wer/wann/alt/neu, inkl. stammbaum_id)
--   3) meine_verwaltbaren_baeume()         -> Bäume mit Bearbeitungsrecht (Multi-Auswahl)
--   4) stammbaum_einstellungen_holen(id)    -> aktuelle Werte + can_edit (rechtegeprüft)
--   5) stammbaum_einstellungen_speichern(...) -> Validierung (inkl. E-Mail-Format) +
--      Duplikatcheck (EXKL. eigener Familie) + Update familien/stammbaeume + Sync + Audit
--   6) Storage-Policies für Bucket 'familien' (Foto/Wappen)
--
-- Voraussetzung: ist_super_admin(), kann_familie_bearbeiten(uuid), sieht_familie(uuid),
--   merge_norm(text). Bucket 'familien' im Dashboard anlegen (PUBLIC empfohlen).
-- =====================================================

-- 1) Spalten ---------------------------------------------------------
ALTER TABLE public.familien    ADD COLUMN IF NOT EXISTS opis          text;
ALTER TABLE public.stammbaeume ADD COLUMN IF NOT EXISTS einstellungen jsonb NOT NULL DEFAULT '{}'::jsonb;

-- merge_norm idempotent absichern (ć č š ž đ -> c c s z d, lower, trim)
CREATE OR REPLACE FUNCTION public.merge_norm(p_txt text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT translate(lower(trim(coalesce(p_txt,''))), 'ćčšžđ', 'ccszd');
$$;

-- Zentrale E-Mail-Format-Prüfung (Backend-Validierung, Feature „Email Format Check")
-- Identisch zu supabase_email_validierung.sql (Reihenfolge der Ausführung egal).
CREATE OR REPLACE FUNCTION public.ist_gueltige_email(p_email text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' AND p_email !~ '\.\.';
$$;

-- 2) Audit-Tabelle ---------------------------------------------------
CREATE TABLE IF NOT EXISTS public.familien_audit (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  familie_id    uuid NOT NULL,
  stammbaum_id  uuid,
  aktion        text NOT NULL DEFAULT 'stammbaum_einstellungen',
  geaendert_von uuid,
  geaendert_am  timestamptz NOT NULL DEFAULT now(),
  alte_werte    jsonb,
  neue_werte    jsonb
);
ALTER TABLE public.familien_audit ADD COLUMN IF NOT EXISTS stammbaum_id uuid;
CREATE INDEX IF NOT EXISTS familien_audit_familie_idx ON public.familien_audit(familie_id);
ALTER TABLE public.familien_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS familien_audit_select ON public.familien_audit;
CREATE POLICY familien_audit_select ON public.familien_audit
  FOR SELECT TO authenticated
  USING (public.ist_super_admin() OR public.kann_familie_bearbeiten(familie_id));

-- 3) Verwaltbare Bäume (für Multi-Auswahl) ---------------------------
DROP FUNCTION IF EXISTS public.meine_verwaltbaren_baeume();
CREATE OR REPLACE FUNCTION public.meine_verwaltbaren_baeume()
RETURNS TABLE(id uuid, name text, familie_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT s.id, s.name, s.familie_id
  FROM public.stammbaeume s
  WHERE public.ist_super_admin() OR public.kann_familie_bearbeiten(s.familie_id)
  ORDER BY s.name;
$$;
GRANT EXECUTE ON FUNCTION public.meine_verwaltbaren_baeume() TO authenticated;

-- 4) Aktuelle Werte laden (Lesen erlaubt für alle, die die Familie sehen) --
DROP FUNCTION IF EXISTS public.stammbaum_einstellungen_holen(uuid);
CREATE OR REPLACE FUNCTION public.stammbaum_einstellungen_holen(p_stammbaum_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_rec record;
BEGIN
  IF p_stammbaum_id IS NULL THEN RAISE EXCEPTION 'fe_keine_familie'; END IF;
  SELECT s.familie_id, s.name, s.einstellungen, f.land, f.stadt, f.gemeinde, f.opis
    INTO v_rec
    FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
   WHERE s.id = p_stammbaum_id;
  IF v_rec.familie_id IS NULL THEN RAISE EXCEPTION 'fe_keine_familie'; END IF;
  v_fam := v_rec.familie_id;
  IF NOT (public.ist_super_admin() OR public.sieht_familie(v_fam)) THEN
    RAISE EXCEPTION 'fe_keine_berechtigung';
  END IF;
  RETURN jsonb_build_object(
    'name', v_rec.name, 'opis', v_rec.opis,
    'land', v_rec.land, 'stadt', v_rec.stadt, 'gemeinde', v_rec.gemeinde,
    'einstellungen', coalesce(v_rec.einstellungen, '{}'::jsonb),
    'can_edit', (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam))
  );
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_einstellungen_holen(uuid) TO authenticated;

-- 5) Speichern (Validierung + Duplikatcheck + Update + Sync + Audit) --
DROP FUNCTION IF EXISTS public.stammbaum_einstellungen_speichern(uuid, text, text, text, text, text, jsonb);
CREATE OR REPLACE FUNCTION public.stammbaum_einstellungen_speichern(
  p_stammbaum_id uuid,
  p_name         text,
  p_opis         text,
  p_land         text,
  p_stadt        text,
  p_gemeinde     text,
  p_einstellungen jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam   uuid;
  v_old   record;
  v_name  text := trim(coalesce(p_name,''));
  v_land  text := trim(coalesce(p_land,''));
  v_stadt text := trim(coalesce(p_stadt,''));
  v_gem   text := trim(coalesce(p_gemeinde,''));
  v_opis  text := nullif(trim(coalesce(p_opis,'')), '');
  v_einst jsonb := coalesce(p_einstellungen, '{}'::jsonb);
  v_mail  text := nullif(trim(coalesce(v_einst->>'kontakt_email','')), '');
BEGIN
  IF p_stammbaum_id IS NULL THEN RAISE EXCEPTION 'fe_keine_familie'; END IF;

  SELECT s.familie_id, s.name AS s_name, f.name AS f_name, f.land, f.stadt, f.gemeinde, f.opis
    INTO v_old
    FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
   WHERE s.id = p_stammbaum_id;
  IF v_old.familie_id IS NULL THEN RAISE EXCEPTION 'fe_keine_familie'; END IF;
  v_fam := v_old.familie_id;

  -- Rechteprüfung: nur Super-Admin oder Owner/Admin DIESER Familie
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'fe_keine_berechtigung';
  END IF;

  -- Pflichtfelder: Naziv stabla, Država (Herkunftsland), Grad (Stadt), Opština (Gemeinde)
  IF v_name = '' OR v_land = '' OR v_stadt = '' OR v_gem = '' THEN
    RAISE EXCEPTION 'fe_pflicht';
  END IF;

  -- Backend-E-Mail-Validierung (Kontakt-E-Mail, falls gesetzt)
  IF v_mail IS NOT NULL AND NOT public.ist_gueltige_email(v_mail) THEN
    RAISE EXCEPTION 'fe_email_ungueltig';
  END IF;

  -- Duplikatcheck NUR, wenn sich ein Matching-Feld geändert hat (merge_norm =
  -- diakritik-/groß-klein-unempfindlich), eigene Familie ausgeschlossen.
  IF public.merge_norm(v_name)  IS DISTINCT FROM public.merge_norm(v_old.f_name)
     OR public.merge_norm(v_land)  IS DISTINCT FROM public.merge_norm(v_old.land)
     OR public.merge_norm(v_stadt) IS DISTINCT FROM public.merge_norm(v_old.stadt)
     OR public.merge_norm(v_gem)   IS DISTINCT FROM public.merge_norm(v_old.gemeinde)
  THEN
    IF EXISTS (
      SELECT 1 FROM public.familien f
      WHERE f.id <> v_fam
        AND public.merge_norm(f.name)     = public.merge_norm(v_name)
        AND public.merge_norm(f.land)     = public.merge_norm(v_land)
        AND public.merge_norm(f.stadt)    = public.merge_norm(v_stadt)
        AND public.merge_norm(f.gemeinde) = public.merge_norm(v_gem)
    ) THEN
      RAISE EXCEPTION 'fe_duplikat';
    END IF;
  END IF;

  -- Kern-/Matching-Felder auf der Familie aktualisieren
  UPDATE public.familien
     SET name = v_name, land = v_land, stadt = v_stadt, gemeinde = v_gem, opis = v_opis
   WHERE id = v_fam;

  -- Reiche Zusatzdaten am Stammbaum; Name mitführen (sichtbarer Baum-Name)
  UPDATE public.stammbaeume
     SET einstellungen = v_einst, name = v_name
   WHERE id = p_stammbaum_id;

  -- Weitere Bäume derselben Familie, die noch den ALTEN Familiennamen trugen,
  -- mit umbenennen (abweichend benannte Unterbäume bleiben unberührt).
  IF v_name IS DISTINCT FROM v_old.f_name THEN
    UPDATE public.stammbaeume
       SET name = v_name
     WHERE familie_id = v_fam
       AND id <> p_stammbaum_id
       AND lower(trim(name)) = lower(trim(coalesce(v_old.f_name,'')));
  END IF;

  -- Audit (wer/wann/alt/neu)
  INSERT INTO public.familien_audit (familie_id, stammbaum_id, geaendert_von, alte_werte, neue_werte)
  VALUES (
    v_fam, p_stammbaum_id, auth.uid(),
    jsonb_build_object('name', v_old.f_name, 'land', v_old.land, 'stadt', v_old.stadt,
                       'gemeinde', v_old.gemeinde, 'opis', v_old.opis),
    jsonb_build_object('name', v_name, 'land', v_land, 'stadt', v_stadt,
                       'gemeinde', v_gem, 'opis', v_opis, 'einstellungen', v_einst)
  );

  RETURN jsonb_build_object('ok', true, 'name', v_name);
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_einstellungen_speichern(uuid, text, text, text, text, text, jsonb) TO authenticated;

-- 6) Storage-Policies für Bucket 'familien' (Foto/Wappen) -------------
-- Bucket 'familien' bitte im Dashboard anlegen (PUBLIC = einfachste Anzeige).
-- Lesen öffentlich; Schreiben/Löschen nur für eingeloggte Nutzer.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='storage' AND tablename='objects') THEN
    DROP POLICY IF EXISTS familien_medien_select ON storage.objects;
    CREATE POLICY familien_medien_select ON storage.objects
      FOR SELECT TO public USING (bucket_id = 'familien');
    DROP POLICY IF EXISTS familien_medien_insert ON storage.objects;
    CREATE POLICY familien_medien_insert ON storage.objects
      FOR INSERT TO authenticated WITH CHECK (bucket_id = 'familien');
    DROP POLICY IF EXISTS familien_medien_update ON storage.objects;
    CREATE POLICY familien_medien_update ON storage.objects
      FOR UPDATE TO authenticated USING (bucket_id = 'familien');
    DROP POLICY IF EXISTS familien_medien_delete ON storage.objects;
    CREATE POLICY familien_medien_delete ON storage.objects
      FOR DELETE TO authenticated USING (bucket_id = 'familien');
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
SELECT 'familie_einstellungen: opis/einstellungen + audit + RPCs (verwaltbare_baeume/holen/speichern) + Storage-Policies angelegt' AS status;
