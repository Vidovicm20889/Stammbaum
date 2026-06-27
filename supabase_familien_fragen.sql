-- =====================================================
-- FAMILIEN-FRAGEN ("Wer ist das?" / fehlende Daten erfragen) — Crowdsourcing (Social, Prompt 6)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_reaktionen_kommentare.sql UND supabase_beitraege.sql ausführen.
--
-- KONZEPT: Ein Mitglied stellt eine Frage an den Verbund — entweder mit ANGEHÄNGTEM FOTO
-- („Wer ist auf diesem Bild?") oder mit BEZUG auf eine Person („Kennt jemand das Geburtsdatum
-- von …?"). ANTWORTEN = Kommentare aus dem Engagement-System (ziel_typ='frage'). Ein BEARBEITER
-- (owner/admin im Verbund / super_admin) kann die Frage als gelöst markieren und dabei die
-- identifizierte Person festhalten bzw. die Personenkarte bearbeiten (Datenhoheit bleibt beim
-- Menschen — KEINE automatische Datenübernahme).
--
-- STRIKT VERBUND-GEBUNDEN: eine Frage gehört zu genau EINEM verbund_id; SELECT nur für dessen
-- Mitglieder (KEIN baum_freigaben-Pfad). Schreiben ausschließlich über SECURITY-DEFINER-RPCs.
--
-- BEWUSSTE v1-ABWEICHUNGEN (dokumentiert):
--   * Foto-Tagging (Feature 4) existiert noch nicht -> beim Lösen einer Foto-Frage wird die
--     identifizierte Person in `geloest_person` festgehalten (Anzeige „Identifiziert als …");
--     das eigentliche Galerie-Tagging wird nachgezogen, sobald Feature 4 da ist.
--   * Das angehängte Foto ist ein HOCHGELADENES Bild (Bucket 'beitraege', wiederverwendet) — KEIN
--     personen_fotos-FK, weil „Wer ist das?" typischerweise ein noch nicht zugeordnetes Bild ist.
--   * Daten-Lücken: der Bearbeiter überträgt den Wert manuell im Personen-Editor (kein Auto-Write).
--
-- Voraussetzungen: supabase_reaktionen_kommentare.sql (ist_in_verbund/darf_verbund_moderieren/
--   _ziel_verbund + reaktionen/kommentare-CHECK), supabase_beitraege.sql (mein_verbund, Bucket
--   'beitraege'), supabase_profile.sql, supabase_multitree_phase5.sql.
-- =====================================================


-- =====================================================
-- 0) ziel_typ 'frage' freischalten (Engagement-CHECKs + _ziel_verbund erweitern)
-- =====================================================
ALTER TABLE public.reaktionen DROP CONSTRAINT IF EXISTS reaktionen_ziel_typ_check;
ALTER TABLE public.reaktionen ADD  CONSTRAINT reaktionen_ziel_typ_check
  CHECK (ziel_typ IN ('foto','geschichte','beitrag','person','event','frage'));

ALTER TABLE public.kommentare DROP CONSTRAINT IF EXISTS kommentare_ziel_typ_check;
ALTER TABLE public.kommentare ADD  CONSTRAINT kommentare_ziel_typ_check
  CHECK (ziel_typ IN ('foto','geschichte','beitrag','person','event','frage'));


-- =====================================================
-- 1) TABELLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.familien_fragen (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id     uuid NOT NULL,
  steller_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  frage          text NOT NULL,
  foto_pfad      text,                                              -- optionales Bild (Bucket 'beitraege')
  foto_url       text,
  person_id      uuid REFERENCES public.personen(id) ON DELETE SET NULL,   -- Bezugsperson (Daten-Lücke)
  status         text NOT NULL DEFAULT 'offen' CHECK (status IN ('offen','geloest')),
  geloest_person uuid REFERENCES public.personen(id) ON DELETE SET NULL,   -- identifizierte Person (Foto-ID)
  geloest_von    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  geloescht      boolean NOT NULL DEFAULT false,
  erstellt_am    timestamptz NOT NULL DEFAULT now(),
  geloest_am     timestamptz
);
CREATE INDEX IF NOT EXISTS familien_fragen_verbund_idx ON public.familien_fragen (verbund_id, status, erstellt_am DESC);

ALTER TABLE public.familien_fragen ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fragen_select" ON public.familien_fragen;
CREATE POLICY "fragen_select" ON public.familien_fragen FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );
-- (KEINE INSERT/UPDATE/DELETE-Policies -> nur die RPCs unten schreiben.)


-- =====================================================
-- 2) _ziel_verbund um 'frage' erweitern (alle bisherigen Zweige bleiben)
-- =====================================================
CREATE OR REPLACE FUNCTION public._ziel_verbund(p_typ text, p_ziel uuid)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v uuid;
BEGIN
  IF p_ziel IS NULL THEN RETURN NULL; END IF;
  IF p_typ = 'person' THEN
    SELECT f.verbund_id INTO v FROM public.personen p
      JOIN public.familien f ON f.id = p.familie_id WHERE p.id = p_ziel AND p.geloescht_am IS NULL;
  ELSIF p_typ = 'foto' THEN
    SELECT f.verbund_id INTO v FROM public.personen_fotos x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSIF p_typ = 'geschichte' THEN
    SELECT f.verbund_id INTO v FROM public.personen_geschichten x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSIF p_typ = 'event' THEN
    SELECT f.verbund_id INTO v FROM public.events x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSIF p_typ = 'beitrag' THEN
    SELECT b.verbund_id INTO v FROM public.beitraege b WHERE b.id = p_ziel;
  ELSIF p_typ = 'frage' THEN
    SELECT fr.verbund_id INTO v FROM public.familien_fragen fr WHERE fr.id = p_ziel;
  ELSE
    v := NULL;
  END IF;
  RETURN v;
END $$;


-- =====================================================
-- 3) RPCs
-- =====================================================

-- 3a) Frage stellen (Text Pflicht; optional Foto und/oder Bezugsperson).
CREATE OR REPLACE FUNCTION public.frage_stellen(
  p_frage text, p_foto_pfad text DEFAULT NULL, p_foto_url text DEFAULT NULL,
  p_person_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_ref  uuid := NULL;
  v_neu  uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  IF p_frage IS NULL OR btrim(p_frage) = '' THEN RAISE EXCEPTION 'leer'; END IF;
  v_verb := public.mein_verbund();
  IF v_verb IS NULL THEN RAISE EXCEPTION 'kein_verbund'; END IF;

  IF p_person_id IS NOT NULL AND public.ist_in_verbund(public._ziel_verbund('person', p_person_id)) THEN
    v_ref := p_person_id;
  END IF;

  INSERT INTO public.familien_fragen (verbund_id, steller_id, frage, foto_pfad, foto_url, person_id)
  VALUES (v_verb, v_me, btrim(p_frage), p_foto_pfad, p_foto_url, v_ref)
  RETURNING id INTO v_neu;

  RETURN jsonb_build_object('ok', true, 'id', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.frage_stellen(text, text, text, uuid) TO authenticated;


-- 3b) Frage als GELÖST markieren (nur Bearbeiter: owner/admin im Verbund / super_admin).
--     p_geloest_person = optional die identifizierte Person (Foto-ID). Muss im Verbund liegen.
CREATE OR REPLACE FUNCTION public.frage_loesen(p_id uuid, p_geloest_person uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid; v_gp uuid := NULL;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  SELECT verbund_id INTO v_verb FROM public.familien_fragen WHERE id = p_id AND geloescht = false;
  IF v_verb IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF NOT public.darf_verbund_moderieren(v_verb) THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;
  IF p_geloest_person IS NOT NULL AND public.ist_in_verbund(public._ziel_verbund('person', p_geloest_person)) THEN
    v_gp := p_geloest_person;
  END IF;
  UPDATE public.familien_fragen
     SET status = 'geloest', geloest_person = v_gp, geloest_von = auth.uid(), geloest_am = now()
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.frage_loesen(uuid, uuid) TO authenticated;


-- 3c) Frage wieder öffnen (nur Bearbeiter).
CREATE OR REPLACE FUNCTION public.frage_wieder_oeffnen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  SELECT verbund_id INTO v_verb FROM public.familien_fragen WHERE id = p_id AND geloescht = false;
  IF v_verb IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF NOT public.darf_verbund_moderieren(v_verb) THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;
  UPDATE public.familien_fragen
     SET status = 'offen', geloest_person = NULL, geloest_von = NULL, geloest_am = NULL
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.frage_wieder_oeffnen(uuid) TO authenticated;


-- 3d) Frage löschen (soft): Steller ODER Moderator. Gibt foto_pfad für Storage-Cleanup zurück.
CREATE OR REPLACE FUNCTION public.frage_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid; v_verb uuid; v_pfad text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  SELECT steller_id, verbund_id, foto_pfad INTO v_owner, v_verb, v_pfad
    FROM public.familien_fragen WHERE id = p_id;
  IF v_verb IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF v_owner IS DISTINCT FROM auth.uid() AND NOT public.darf_verbund_moderieren(v_verb) THEN
    RAISE EXCEPTION 'keine_berechtigung';
  END IF;
  UPDATE public.familien_fragen SET geloescht = true, foto_pfad = NULL, foto_url = NULL WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'foto_pfad', v_pfad);
END $$;
GRANT EXECUTE ON FUNCTION public.frage_loeschen(uuid) TO authenticated;


-- 3e) Fragen holen (verbund-intern; optional nur offene; keyset-paginiert über erstellt_am).
--     Liefert Steller-Anzeige/Avatar, Foto-URL, Bezugsperson-/Lösung-Name, Antwort-Anzahl, darf_*.
CREATE OR REPLACE FUNCTION public.fragen_holen(
  p_nur_offen boolean DEFAULT false, p_limit int DEFAULT 20, p_vor timestamptz DEFAULT NULL)
RETURNS TABLE(
  id uuid, steller_id uuid, frage text, foto_url text,
  person_id uuid, person_name text, status text,
  geloest_person uuid, geloest_person_name text,
  erstellt_am timestamptz, geloest_am timestamptz,
  steller_name text, steller_avatar text, antworten int,
  darf_loesen boolean, darf_loeschen boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    fr.id, fr.steller_id, fr.frage, fr.foto_url,
    fr.person_id,
    (SELECT trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) FROM public.personen pe WHERE pe.id = fr.person_id AND pe.geloescht_am IS NULL) AS person_name,
    fr.status,
    fr.geloest_person,
    (SELECT trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) FROM public.personen pe WHERE pe.id = fr.geloest_person AND pe.geloescht_am IS NULL) AS geloest_person_name,
    fr.erstellt_am, fr.geloest_am,
    COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''),
             initcap(replace(replace(replace(split_part(u.email,'@',1),'.',' '),'_',' '),'-',' ')),
             u.email) AS steller_name,
    CASE WHEN COALESCE(pr.avatar_sichtbarkeit,'verbund') <> 'privat'
         THEN COALESCE(pr.avatar_thumb_url, pr.avatar_url) END AS steller_avatar,
    (SELECT count(*)::int FROM public.kommentare k
       WHERE k.ziel_typ = 'frage' AND k.ziel_id = fr.id AND k.geloescht = false) AS antworten,
    public.darf_verbund_moderieren(fr.verbund_id) AS darf_loesen,
    (fr.steller_id = auth.uid() OR public.darf_verbund_moderieren(fr.verbund_id)) AS darf_loeschen
  FROM public.familien_fragen fr
  LEFT JOIN auth.users u    ON u.id = fr.steller_id
  LEFT JOIN public.profile pr ON pr.user_id = fr.steller_id
  WHERE fr.geloescht = false
    AND public.ist_in_verbund(fr.verbund_id)
    AND (NOT p_nur_offen OR fr.status = 'offen')
    AND (p_vor IS NULL OR fr.erstellt_am < p_vor)
  ORDER BY fr.erstellt_am DESC
  LIMIT greatest(1, least(coalesce(p_limit, 20), 50));
$$;
GRANT EXECUTE ON FUNCTION public.fragen_holen(boolean, int, timestamptz) TO authenticated;


-- =====================================================
-- 4) REALTIME-PUBLICATION (neue/aktualisierte Fragen live; Antworten laufen über kommentare)
-- =====================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'familien_fragen'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.familien_fragen;
  END IF;
END $$;
ALTER TABLE public.familien_fragen REPLICA IDENTITY FULL;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_familien_fragen.sql ausgeführt — familien_fragen (verbund-RLS) + RPCs + ziel_typ frage + Realtime' AS status;
