-- ============================================================================
-- DIREKT-CHAT MIT ENTDECKTER PERSON (Regel gelockert, ab v14.x)
-- ----------------------------------------------------------------------------
-- Betreiber-Entscheidung: Chat/Kontakt zu einer ENTDECKTEN Person (fremder Verbund) ist FREI
-- (keine vorherige Genehmigung nötig — wie eine Instagram-DM; Empfänger kann ignorieren).
-- NUR der Baumzugriff (Lesezugriff auf den Stammbaum) bleibt genehmigungspflichtig.
-- Minderjährige bleiben AUSGESCHLOSSEN (personen_entdecken/_person_entdeckbar filtern das hart).
--
-- Ersetzt die frühere Regel „Kontakt erst nach Genehmigung" (CLAUDE.md entsprechend angepasst).
-- Idempotent. Voraussetzungen: kontakt_verbindungen, _person_entdeckbar, direkt_chat_finden_oder_anlegen.
-- ============================================================================

-- 1) Direkt-Chat freischalten: legt die kontakt_verbindung an (erlaubt darf_chatten) und liefert
--    die Ziel-user_id zurück -> Frontend öffnet danach den 1:1-Chat (direkt_chat_finden_oder_anlegen).
CREATE OR REPLACE FUNCTION public.entdeckte_person_anschreiben(p_ziel_person uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_ziel uuid;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  -- HART: Karte muss für mich entdeckbar sein (fremder Verbund, kein Minderjähriger, Opt-in/Konto).
  IF NOT public._person_entdeckbar(p_ziel_person) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'nicht_entdeckbar');
  END IF;
  SELECT user_id INTO v_ziel FROM public.personen WHERE id = p_ziel_person AND geloescht_am IS NULL;
  IF v_ziel IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'kein_konto'); END IF;
  IF v_ziel = v_me THEN RETURN jsonb_build_object('ok', false, 'grund', 'eigene_karte'); END IF;
  INSERT INTO public.kontakt_verbindungen (user_a, user_b)
  VALUES (LEAST(v_me, v_ziel), GREATEST(v_me, v_ziel))
  ON CONFLICT (user_a, user_b) DO NOTHING;
  RETURN jsonb_build_object('ok', true, 'ziel_user', v_ziel);
END $$;
GRANT EXECUTE ON FUNCTION public.entdeckte_person_anschreiben(uuid) TO authenticated;

-- 2) kontakt_anfrage_stellen: Baumzugriff braucht KEINE vorab genehmigte Kontakt-Verbindung mehr —
--    fehlt sie, wird sie hier angelegt (Kontakt/Chat ist ja frei). Nur der Baumzugriff selbst bleibt
--    genehmigungspflichtig. (Rest der Funktion unverändert.)
CREATE OR REPLACE FUNCTION public.kontakt_anfrage_stellen(
  p_ziel_person uuid, p_typ text, p_nachricht text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me      uuid := auth.uid();
  v_fam     uuid; v_baum uuid; v_ziel_user uuid; v_verb uuid;
  v_neu     uuid;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF p_ziel_person IS NULL OR p_typ NOT IN ('kontakt','baumzugriff') THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'parameter');
  END IF;

  SELECT pe.familie_id, pe.stammbaum_id, pe.user_id, f.verbund_id
    INTO v_fam, v_baum, v_ziel_user, v_verb
    FROM public.personen pe JOIN public.familien f ON f.id = pe.familie_id
   WHERE pe.id = p_ziel_person AND pe.geloescht_am IS NULL;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'person_fehlt'); END IF;

  IF NOT public._person_entdeckbar(p_ziel_person) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'nicht_entdeckbar');
  END IF;
  IF v_ziel_user IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'kein_konto');
  END IF;
  IF v_ziel_user = v_me THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'eigene_karte');
  END IF;

  IF p_typ = 'baumzugriff' THEN
    -- Kontakt/Chat ist frei -> fehlende Verbindung hier anlegen (statt Anfrage abzulehnen).
    INSERT INTO public.kontakt_verbindungen (user_a, user_b)
    VALUES (LEAST(v_me, v_ziel_user), GREATEST(v_me, v_ziel_user))
    ON CONFLICT (user_a, user_b) DO NOTHING;
    -- Schon Lesezugriff auf den Baum? -> nichts zu tun.
    IF EXISTS (SELECT 1 FROM public.baum_freigaben bf
                WHERE bf.user_id = v_me AND bf.stammbaum_id = v_baum AND bf.status = 'aktiv') THEN
      RETURN jsonb_build_object('ok', false, 'grund', 'schon_freigegeben');
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.kontakt_anfragen
              WHERE von_user = v_me AND ziel_person_id = p_ziel_person AND typ = p_typ AND status = 'offen') THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'schon_offen');
  END IF;

  INSERT INTO public.kontakt_anfragen (
    von_user, ziel_person_id, ziel_familie_id, ziel_verbund_id, typ, ziel_stammbaum_id, nachricht)
  VALUES (
    v_me, p_ziel_person, v_fam, v_verb, p_typ,
    CASE WHEN p_typ = 'baumzugriff' THEN v_baum ELSE NULL END,
    nullif(btrim(coalesce(p_nachricht,'')), ''))
  RETURNING id INTO v_neu;

  RETURN jsonb_build_object('ok', true, 'anfrage_id', v_neu, 'typ', p_typ);
END $$;
GRANT EXECUTE ON FUNCTION public.kontakt_anfrage_stellen(uuid, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Direkt-Chat frei (entdeckte_person_anschreiben) + Baumzugriff legt Verbindung selbst an' AS status;
