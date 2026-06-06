-- =====================================================
-- MEINE PERSON IM STAMMBAUM — Konto <-> Personenkarte (Self-Service)
-- Ausführen in: Supabase -> SQL Editor. Idempotent (mehrfach ausführbar).
--
-- Hintergrund (siehe CLAUDE.md): Die Verknüpfung Konto<->Karte ist die Spalte
-- personen.user_id (Flag _hatKonto im Frontend). Bisher wurde sie NUR über die
-- Admin-Genehmigung von Registrierungsanfragen (Edge Function anfrage-bearbeiten)
-- gesetzt. Diese Datei ergänzt einen SELBSTBEDIENUNGS-Pfad:
--   - der eingeloggte Nutzer sieht in den Profileinstellungen "Meine Person im
--     Stammbaum" und kann sich (a) an eine bestehende, noch KONTOLOSE Karte hängen
--     oder (b) eine NEUE eigene Karte anlegen + automatisch verknüpfen.
--
-- Entscheidung des Betreibers (bewusst, ohne Genehmigung):
--   - Self-Link erfolgt OHNE Admin-Freigabe, ABER nur auf Karten in einem Baum,
--     den der Nutzer SEHEN darf (sieht_familie -> verbundbasiert).
--   - Pro Karte nur 1 Nutzer (user_id IS NULL Voraussetzung beim Verknüpfen).
--   - Anlegen der eigenen Karte ist ALLEN eingeloggten Nutzern erlaubt (auch reinen
--     Lesemitgliedern) -> daher SECURITY DEFINER (umgeht die admin-only INSERT-RLS),
--     Rechteprüfung: sieht_familie des Zielbaums.
--   HINWEIS (dokumentiert): Das Setzen von user_id triggert die Blutlinien-Auto-
--   Rechte (familien_admin entlang der Blutlinie). Das ist die bewusste Folge dieser
--   Betreiber-Entscheidung.
--
-- Voraussetzungen: supabase_verbund.sql (sieht_familie, kann_familie_bearbeiten,
--   ist_super_admin), supabase_merge_gui.sql (merge_norm).
--
-- Bausteine:
--   1) meine_person_status()                    -> steuert den bedingten Hinweis
--   2) meine_person_kandidaten()                -> kontolose Karten zum Auswählen
--   3) meine_karte_verknuepfen(p_person)        -> Self-Link an bestehende Karte
--   4) meine_karte_erstellen(p_baum, ...)       -> eigene Karte anlegen + verknüpfen
-- =====================================================


-- ---------- 1) STATUS: Bedingung für den Hinweis ----------
-- Liefert genau die drei Fakten der "Neuen Regel":
--   verknuepft       = der Nutzer hat bereits eine Karte (personen.user_id = auth.uid())
--   baum_anzahl      = Anzahl Bäume, die der Nutzer sehen darf
--   personen_anzahl  = Anzahl Personenkarten in sichtbaren Bäumen
-- Frontend zeigt den Hinweis nur, wenn: baum_anzahl>0 UND personen_anzahl>0 UND NICHT verknuepft.
-- Zusätzlich (für die Anzeige im Profil) Name + Baum der eigenen Karte, falls verknüpft.
CREATE OR REPLACE FUNCTION public.meine_person_status()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH meine AS (
    SELECT pe.id, pe.stammbaum_id,
           trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS name
      FROM public.personen pe
     WHERE pe.user_id = auth.uid()
     ORDER BY pe.updated_at DESC NULLS LAST
     LIMIT 1
  )
  SELECT jsonb_build_object(
    'verknuepft',      EXISTS (SELECT 1 FROM meine),
    'person_id',       (SELECT id FROM meine),
    'person_name',     (SELECT name FROM meine),
    'person_baum',     (SELECT s.name FROM public.stammbaeume s
                          WHERE s.id = (SELECT stammbaum_id FROM meine)),
    'person_baum_id',  (SELECT stammbaum_id FROM meine),
    'baum_anzahl',     (SELECT count(*) FROM public.stammbaeume s
                          WHERE public.ist_super_admin() OR public.sieht_familie(s.familie_id)),
    'personen_anzahl', (SELECT count(*) FROM public.personen pe
                          WHERE public.ist_super_admin() OR public.sieht_familie(pe.familie_id)),
    'super_admin',     public.ist_super_admin()
  );
$$;
GRANT EXECUTE ON FUNCTION public.meine_person_status() TO authenticated;


-- ---------- 2) KANDIDATEN: kontolose Karten in sichtbaren Bäumen ----------
-- Nur Karten ohne Konto (user_id IS NULL) und nur aus Bäumen, die der Nutzer sehen darf.
-- (Karten mit Konto sind bewusst NICHT wählbar -> "pro Karte nur 1 Nutzer".)
CREATE OR REPLACE FUNCTION public.meine_person_kandidaten()
RETURNS TABLE(
  person_id uuid, name text, vorname text, nachname text,
  geburtsdatum text, geschlecht text, baum text, baum_id uuid
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT pe.id,
         trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS name,
         pe.vorname, pe.nachname,
         coalesce(pe.stammbaum_daten->>'birth_date', pe.stammbaum_daten->>'geburtsdatum') AS geburtsdatum,
         coalesce(pe.stammbaum_daten->>'sex', pe.stammbaum_daten->>'geschlecht') AS geschlecht,
         s.name AS baum, pe.stammbaum_id AS baum_id
    FROM public.personen pe
    JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
   WHERE pe.user_id IS NULL
     AND (public.ist_super_admin() OR public.sieht_familie(pe.familie_id))
   ORDER BY s.name, name;
$$;
GRANT EXECUTE ON FUNCTION public.meine_person_kandidaten() TO authenticated;


-- ---------- 3) SELF-LINK: an bestehende kontolose Karte hängen ----------
-- Rechte: Karte muss sichtbar sein (sieht_familie) ODER Super-Admin.
-- "1 Nutzer pro Karte": user_id muss NULL sein (oder bereits = ich -> idempotent ok).
CREATE OR REPLACE FUNCTION public.meine_karte_verknuepfen(p_person uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam   uuid;
  v_uid   uuid;
  v_name  text;
  v_baum  uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF p_person IS NULL  THEN RETURN jsonb_build_object('ok', false, 'grund', 'keine_person'); END IF;

  SELECT pe.familie_id, pe.user_id, pe.stammbaum_id,
         trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,''))
    INTO v_fam, v_uid, v_baum, v_name
    FROM public.personen pe WHERE pe.id = p_person;

  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;

  IF NOT (public.ist_super_admin() OR public.sieht_familie(v_fam)) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  IF v_uid IS NOT NULL AND v_uid <> auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'karte_belegt');
  END IF;

  UPDATE public.personen SET user_id = auth.uid() WHERE id = p_person;

  RETURN jsonb_build_object('ok', true, 'person_id', p_person,
                            'name', v_name, 'baum_id', v_baum);
END $$;
GRANT EXECUTE ON FUNCTION public.meine_karte_verknuepfen(uuid) TO authenticated;


-- ---------- 4) EIGENE KARTE ANLEGEN + verknüpfen ----------
-- Erlaubt ALLEN eingeloggten Nutzern, in einem SICHTBAREN Baum die EIGENE Karte
-- anzulegen (auch Lesemitglieder -> daher DEFINER). Setzt user_id = auth.uid().
-- p_daten = vollständiges stammbaum_daten-jsonb (Frontend-Personenobjekt).
-- p_eltern = optionale Liste existierender Eltern-Karten IM SELBEN Baum (elternteil-Kanten).
CREATE OR REPLACE FUNCTION public.meine_karte_erstellen(
  p_baum uuid, p_vorname text, p_nachname text,
  p_daten jsonb DEFAULT '{}'::jsonb, p_eltern uuid[] DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam   uuid;
  v_ext   text;
  v_sd    jsonb;
  v_neu   uuid;
  v_par   uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF p_baum IS NULL    THEN RETURN jsonb_build_object('ok', false, 'grund', 'kein_baum'); END IF;

  SELECT s.familie_id INTO v_fam FROM public.stammbaeume s WHERE s.id = p_baum;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'baum_fehlt'); END IF;

  -- Rechteprüfung: sichtbarer Baum (Lese-Zugriff genügt für die EIGENE Karte) ODER Super-Admin
  IF NOT (public.ist_super_admin() OR public.sieht_familie(v_fam)) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  -- externe_id wie an anderen Stellen erzeugt; sd.id konsistent setzen
  v_ext := 'I' || (extract(epoch from clock_timestamp())*1000)::bigint
                || '_' || substr(replace(gen_random_uuid()::text,'-',''),1,8);
  v_sd  := coalesce(p_daten, '{}'::jsonb) || jsonb_build_object('id', v_ext);

  INSERT INTO public.personen
    (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum,
     stammbaum_daten, user_id)
  VALUES
    (v_fam, p_baum, v_ext, p_vorname, p_nachname, NULL, v_sd, auth.uid())
  RETURNING id INTO v_neu;

  -- optionale Eltern-Kanten (nur Eltern desselben Baums; idempotent)
  IF p_eltern IS NOT NULL THEN
    FOREACH v_par IN ARRAY p_eltern LOOP
      IF v_par IS NOT NULL AND EXISTS (
           SELECT 1 FROM public.personen pp
            WHERE pp.id = v_par AND pp.stammbaum_id = p_baum) THEN
        INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
        SELECT v_fam, v_par, v_neu, 'elternteil'
         WHERE NOT EXISTS (
           SELECT 1 FROM public.beziehungen b2
            WHERE b2.typ='elternteil' AND b2.person_a=v_par AND b2.person_b=v_neu);
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'person_id', v_neu, 'externe_id', v_ext, 'baum_id', p_baum);
END $$;
GRANT EXECUTE ON FUNCTION public.meine_karte_erstellen(uuid, text, text, jsonb, uuid[]) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'Meine-Person-RPCs angelegt: meine_person_status / meine_person_kandidaten / meine_karte_verknuepfen / meine_karte_erstellen' AS status;
