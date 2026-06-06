-- =====================================================
-- PROFIL <-> PERSONENKARTE: bidirektionale Synchronisation gemeinsamer Stammdaten
-- Ausführen in: Supabase -> SQL Editor. Idempotent (mehrfach ausführbar).
--
-- Hintergrund (siehe CLAUDE.md): profile (Konto-Stammdaten) und personen.stammbaum_daten
-- (Karte) sind getrennte Stores; Nutzer können OHNE verknüpfte Karte existieren (Profil-
-- name ist dann einzige Quelle für Badge/Presence/Login). Ein echtes "Single Source of
-- Truth" (Profil liest alles aus der Karte) wäre ein großer Umbau -> stattdessen
-- BIDIREKTIONALE SYNC über DB-Trigger (Spec Abschnitt 10 erlaubt das ausdrücklich).
--
-- Warum Trigger statt Frontend: Spec-Beispiel 3 verlangt "Admin ändert Karte -> Profil
-- aktualisiert sich". Der Admin ist NICHT der verknüpfte Nutzer und darf dessen profile-
-- Zeile per RLS nicht schreiben -> nur SECURITY-DEFINER-Trigger erfüllen beide Richtungen
-- (auch für read-only-Selbstverknüpfte). Offene BAUM-Ansichten aktualisiert der bestehende
-- Live-Sync (personen-UPDATE -> Realtime). Bewusste Grenze: fremde offene PROFIL-Ansichten
-- updaten nicht live (profile-RLS = nur eigene Zeile, nicht in der Realtime-Publication).
--
-- Verknüpfung = personen.user_id (siehe supabase_meine_person.sql). Erstverknüpfung:
-- "Karte gewinnt" -> ergibt sich automatisch, weil das Setzen von user_id ein personen-
-- UPDATE ist, das den Karte->Profil-Trigger feuert.
--
-- Feld-Mapping (profile-Spalte  <->  personen):
--   vorname       <-> personen.vorname  / stammbaum_daten->>'given'
--   nachname      <-> personen.nachname / stammbaum_daten->>'surname'
--   geburtsname   <-> stammbaum_daten->>'ehename'      (Geburtsname/Mädchenname)
--   geschlecht    <-> stammbaum_daten->>'sex'
--   geburtsdatum  <-> stammbaum_daten->>'birth_date'   (ISO/Freitext)
--   sterbedatum   <-> stammbaum_daten->>'death_date'
--   biografie     <-> stammbaum_daten->>'beschreibung'
--   avatar_url    <-> stammbaum_daten->>'foto' / 'avatar'  (URL im Bucket avatars)
-- NICHT synchronisiert (nur Profil): E-Mail, Passwort, Sprache, Land, Zeitzone, Telefon,
--   Datenschutz, Rollen. NICHT synchronisiert (nur Karte): Beziehungen/Blutlinie/Baum.
--
-- Loop-Schutz: GUC app.pp_sync. Beim propagierenden UPDATE auf '1' gesetzt -> der jeweils
-- andere Trigger erkennt das und bricht ab (keine Endlosschleife).
--
-- Voraussetzungen: supabase_profile.sql (Tabelle profile), supabase_meine_person.sql
--   (Verknüpfungs-RPCs). Koexistiert mit personen-Triggern (ident_sync, *_touch_updated,
--   Blutlinien-Recompute) — diese laufen weiter (nur unsere zwei Funktionen prüfen das GUC).
-- =====================================================


-- ---------- 1) Profil um die synchronisierten Stammdaten-Spalten erweitern ----------
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS geburtsname  text;   -- Geburtsname/Mädchenname (ehename)
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS geschlecht   text;   -- '', 'M', 'F'
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS geburtsdatum text;   -- ISO/Freitext
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS sterbedatum  text;   -- ISO/Freitext (selten; meist person->profile)
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS biografie    text;   -- Kurzbeschreibung


-- ---------- 2) KARTE -> PROFIL ----------
-- Feuert bei INSERT/UPDATE einer Karte mit gesetztem user_id; schreibt die gemeinsamen
-- Felder in die profile-Zeile des verknüpften Nutzers (legt sie bei Bedarf an).
CREATE OR REPLACE FUNCTION public.personen_sync_to_profile()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_sd   jsonb := coalesce(NEW.stammbaum_daten, '{}'::jsonb);
  v_foto text;
BEGIN
  IF NEW.user_id IS NULL THEN RETURN NEW; END IF;                         -- keine Verknüpfung
  IF current_setting('app.pp_sync', true) = '1' THEN RETURN NEW; END IF;  -- Loop-Schutz

  -- Nur bei Erst-Link ODER tatsächlich geänderten Synced-Feldern (sonst kein Schreib-Churn).
  IF TG_OP = 'UPDATE'
     AND OLD.user_id IS NOT DISTINCT FROM NEW.user_id
     AND coalesce(OLD.vorname,'')  = coalesce(NEW.vorname,'')
     AND coalesce(OLD.nachname,'') = coalesce(NEW.nachname,'')
     AND coalesce(OLD.stammbaum_daten->>'given','')        = coalesce(v_sd->>'given','')
     AND coalesce(OLD.stammbaum_daten->>'surname','')      = coalesce(v_sd->>'surname','')
     AND coalesce(OLD.stammbaum_daten->>'ehename','')      = coalesce(v_sd->>'ehename','')
     AND coalesce(OLD.stammbaum_daten->>'sex','')          = coalesce(v_sd->>'sex','')
     AND coalesce(OLD.stammbaum_daten->>'birth_date','')   = coalesce(v_sd->>'birth_date','')
     AND coalesce(OLD.stammbaum_daten->>'death_date','')   = coalesce(v_sd->>'death_date','')
     AND coalesce(OLD.stammbaum_daten->>'beschreibung','') = coalesce(v_sd->>'beschreibung','')
     AND coalesce(OLD.stammbaum_daten->>'foto', OLD.stammbaum_daten->>'avatar','')
         = coalesce(v_sd->>'foto', v_sd->>'avatar','')
  THEN
    RETURN NEW;
  END IF;

  v_foto := coalesce(v_sd->>'foto', v_sd->>'avatar');

  PERFORM set_config('app.pp_sync', '1', true);
  INSERT INTO public.profile
    (user_id, vorname, nachname, geburtsname, geschlecht, geburtsdatum, sterbedatum, biografie, avatar_url)
  VALUES (
    NEW.user_id,
    coalesce(NEW.vorname,  v_sd->>'given'),
    coalesce(NEW.nachname, v_sd->>'surname'),
    v_sd->>'ehename', v_sd->>'sex', v_sd->>'birth_date', v_sd->>'death_date', v_sd->>'beschreibung',
    NULLIF(v_foto, '')
  )
  ON CONFLICT (user_id) DO UPDATE SET
    vorname      = EXCLUDED.vorname,
    nachname     = EXCLUDED.nachname,
    geburtsname  = EXCLUDED.geburtsname,
    geschlecht   = EXCLUDED.geschlecht,
    geburtsdatum = EXCLUDED.geburtsdatum,
    sterbedatum  = EXCLUDED.sterbedatum,
    biografie    = EXCLUDED.biografie,
    -- Karten-Foto nur übernehmen, wenn vorhanden -> sonst hochgeladenen Profil-Avatar behalten.
    avatar_url   = COALESCE(EXCLUDED.avatar_url, profile.avatar_url);
  PERFORM set_config('app.pp_sync', '0', true);

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS personen_sync_to_profile_trg ON public.personen;
CREATE TRIGGER personen_sync_to_profile_trg
  AFTER INSERT OR UPDATE ON public.personen
  FOR EACH ROW EXECUTE FUNCTION public.personen_sync_to_profile();


-- ---------- 3) PROFIL -> KARTE(N) ----------
-- Feuert bei INSERT/UPDATE der eigenen profile-Zeile; schreibt die gemeinsamen Felder in
-- ALLE verknüpften Karten des Nutzers (ident_sync spiegelt anschließend auf Zwillingskarten).
CREATE OR REPLACE FUNCTION public.profile_sync_to_personen()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_patch jsonb;
BEGIN
  IF current_setting('app.pp_sync', true) = '1' THEN RETURN NEW; END IF;  -- Loop-Schutz

  -- Nur, wenn sich ein synchronisiertes Feld geändert hat (Sprache/Telefon etc. ignorieren).
  IF TG_OP = 'UPDATE'
     AND coalesce(OLD.vorname,'')      = coalesce(NEW.vorname,'')
     AND coalesce(OLD.nachname,'')     = coalesce(NEW.nachname,'')
     AND coalesce(OLD.geburtsname,'')  = coalesce(NEW.geburtsname,'')
     AND coalesce(OLD.geschlecht,'')   = coalesce(NEW.geschlecht,'')
     AND coalesce(OLD.geburtsdatum,'') = coalesce(NEW.geburtsdatum,'')
     AND coalesce(OLD.sterbedatum,'')  = coalesce(NEW.sterbedatum,'')
     AND coalesce(OLD.biografie,'')    = coalesce(NEW.biografie,'')
     AND coalesce(OLD.avatar_url,'')   = coalesce(NEW.avatar_url,'')
  THEN
    RETURN NEW;
  END IF;

  v_patch := jsonb_build_object(
    'given',        coalesce(NEW.vorname,''),
    'surname',      coalesce(NEW.nachname,''),
    'name',         trim(coalesce(NEW.vorname,'') || ' ' || coalesce(NEW.nachname,'')),
    'ehename',      coalesce(NEW.geburtsname,''),
    'sex',          coalesce(NEW.geschlecht,''),
    'birth_date',   coalesce(NEW.geburtsdatum,''),
    'death_date',   coalesce(NEW.sterbedatum,''),
    'beschreibung', coalesce(NEW.biografie,'')
  );
  -- Foto nur setzen, wenn ein Profil-Avatar existiert (sonst Karten-Foto nicht löschen).
  IF NEW.avatar_url IS NOT NULL AND NEW.avatar_url <> '' THEN
    v_patch := v_patch || jsonb_build_object('foto', NEW.avatar_url, 'avatar', NEW.avatar_url);
  END IF;

  PERFORM set_config('app.pp_sync', '1', true);
  UPDATE public.personen
     SET vorname  = NEW.vorname,
         nachname = NEW.nachname,
         stammbaum_daten = coalesce(stammbaum_daten, '{}'::jsonb) || v_patch
   WHERE user_id = NEW.user_id;
  PERFORM set_config('app.pp_sync', '0', true);

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS profile_sync_to_personen_trg ON public.profile;
CREATE TRIGGER profile_sync_to_personen_trg
  AFTER INSERT OR UPDATE ON public.profile
  FOR EACH ROW EXECUTE FUNCTION public.profile_sync_to_personen();


-- ---------- 4) Backfill bestehender Verknüpfungen ("Karte gewinnt") ----------
-- Trigger kurz deaktivieren, damit der Backfill nicht zurück in personen schreibt.
ALTER TABLE public.profile DISABLE TRIGGER profile_sync_to_personen_trg;

INSERT INTO public.profile
  (user_id, vorname, nachname, geburtsname, geschlecht, geburtsdatum, sterbedatum, biografie, avatar_url)
SELECT DISTINCT ON (pe.user_id)
  pe.user_id,
  coalesce(pe.vorname,  pe.stammbaum_daten->>'given'),
  coalesce(pe.nachname, pe.stammbaum_daten->>'surname'),
  pe.stammbaum_daten->>'ehename', pe.stammbaum_daten->>'sex',
  pe.stammbaum_daten->>'birth_date', pe.stammbaum_daten->>'death_date',
  pe.stammbaum_daten->>'beschreibung',
  NULLIF(coalesce(pe.stammbaum_daten->>'foto', pe.stammbaum_daten->>'avatar'), '')
FROM public.personen pe
WHERE pe.user_id IS NOT NULL
ORDER BY pe.user_id, pe.updated_at DESC NULLS LAST
ON CONFLICT (user_id) DO UPDATE SET
  vorname      = COALESCE(EXCLUDED.vorname,  profile.vorname),
  nachname     = COALESCE(EXCLUDED.nachname, profile.nachname),
  geburtsname  = EXCLUDED.geburtsname,
  geschlecht   = EXCLUDED.geschlecht,
  geburtsdatum = EXCLUDED.geburtsdatum,
  sterbedatum  = EXCLUDED.sterbedatum,
  biografie    = EXCLUDED.biografie,
  avatar_url   = COALESCE(EXCLUDED.avatar_url, profile.avatar_url);

ALTER TABLE public.profile ENABLE TRIGGER profile_sync_to_personen_trg;


-- ---------- 5) Verknüpfung aufheben (Self-Service) ----------
-- Setzt user_id der eigenen Karte(n) auf NULL -> Sync endet, BEIDE Datensätze bleiben
-- erhalten. (Blutlinien-Auto-Rechte werden durch den personen-Trigger neu berechnet.)
CREATE OR REPLACE FUNCTION public.meine_karte_loesen()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_n int;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  UPDATE public.personen SET user_id = NULL WHERE user_id = auth.uid();
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'geloest', v_n);
END $$;
GRANT EXECUTE ON FUNCTION public.meine_karte_loesen() TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'Profil<->Karte-Sync aktiv: Trigger personen_sync_to_profile_trg / profile_sync_to_personen_trg + meine_karte_loesen()' AS status;
