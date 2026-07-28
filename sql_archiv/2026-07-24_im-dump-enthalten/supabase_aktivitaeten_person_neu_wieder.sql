-- =====================================================
-- AKTIVITÄTEN: "Neue Person" auf der Wand WIEDER aktivieren.
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- HINTERGRUND: supabase_aktivitaeten.sql legt bei jeder echten Nutzer-Anlage einer Person
-- eine Aktivität vom Typ 'person_neu' an (Trigger akt_person_neu auf public.personen).
-- Mit supabase_aktivitaeten_kein_person_neu.sql wurde dieser Trigger entfernt (Nutzerwunsch).
-- Diese Datei stellt den Trigger + die Triggerfunktion wieder her, sodass neu angelegte
-- Personen wieder im Familien-Feed ("Wand") erscheinen — für alle im Verbund sichtbar.
--
-- WICHTIG: Diese Datei ist das GEGENSTÜCK zu supabase_aktivitaeten_kein_person_neu.sql.
-- Damit die Aktivierung dauerhaft bleibt, den Kill-Switch NICHT mehr ausführen
-- (idealerweise nach sql_archiv/ verschieben).
--
-- KEIN BACKFILL (bewusst, wie beim Original): Es werden NUR ab jetzt neu angelegte
-- Personen protokolliert. Alte Bestandspersonen fluten den Feed NICHT rückwirkend
-- (der frühere Kill-Switch hat zudem die alten 'person_neu'-Zeilen gelöscht).
--
-- Anti-Spam-Invarianten bleiben erhalten (aus supabase_aktivitaeten.sql):
--   * NUR bei echter Nutzer-Aktion (auth.uid() gesetzt) — Bulk/Import via service_role NICHT.
--   * KEINE Platzhalter-Personen (stammbaum_daten->>'platzhalter' = 'true').
--   * KEINE identitaet_id-Spiegelkarten (nur die erste Karte je Identität zählt).
-- Voraussetzung: supabase_aktivitaeten.sql wurde bereits ausgeführt (Tabelle aktivitaeten,
-- Helfer _akt_log).
-- =====================================================

CREATE OR REPLACE FUNCTION public.akt_trg_person() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF coalesce(NEW.stammbaum_daten->>'platzhalter','') = 'true' THEN RETURN NEW; END IF;
  IF NEW.identitaet_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personen WHERE identitaet_id = NEW.identitaet_id AND id <> NEW.id)
  THEN RETURN NEW; END IF;   -- Spiegelkarte -> nur die erste zählt
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
  PERFORM public._akt_log(v_verb, 'person_neu', NEW.id);
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS akt_person_neu ON public.personen;
CREATE TRIGGER akt_person_neu AFTER INSERT ON public.personen
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_person();

NOTIFY pgrst, 'reload schema';

SELECT 'OK: Trigger akt_person_neu wiederhergestellt — neue Personen erscheinen wieder im Feed' AS status;
