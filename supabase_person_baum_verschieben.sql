-- =====================================================
-- PERSON IN ANDEREN STAMMBAUM VERSCHIEBEN (Admin)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT (CREATE OR REPLACE).
--
-- HINTERGRUND: Erscheint eine Karte in der „Lose Karten"-Leiste (im Diagramm nicht
-- erreichbar), kann sie schlicht im FALSCHEN Stammbaum liegen. Diese RPC verschiebt eine
-- Personenkarte von ihrem aktuellen Stammbaum in einen anderen (setzt stammbaum_id +
-- familie_id neu). Beziehungen (beziehungen) referenzieren Personen-UUIDs (kein Baum-Bezug)
-- und bleiben erhalten; die Karte rendert danach im Ziel-Baum.
--
-- RECHTE: Admin/Owner/Super-Admin der QUELL- UND ZIEL-Familie (verbundbasiert über
-- kann_familie_bearbeiten -> Isolation gegen fremde Verbünde bleibt gewahrt: ein normaler
-- Admin kann nur zwischen Bäumen seines eigenen Verbunds verschieben). Für ALLE Admins.
--
-- GRENZEN (bewusst, v1):
--   • Identitäts-gespiegelte Karten (identitaet_id): Verschieben ist erlaubt, solange im
--     Ziel-Baum noch KEIN Zwilling derselben realen Person liegt (sonst Duplikat -> Abbruch).
--   • Hat die Person Beziehungen zu Personen, die im Quell-Baum verbleiben, spannen diese
--     Kanten danach über zwei Bäume und werden im Ziel-Baum nicht gerendert (die Person wäre
--     dort zunächst „lose", bis sie neu verknüpft wird). Für den Lose-Karten-Fall (keine
--     Beziehungen) ist das irrelevant; das Frontend warnt vorher, falls Beziehungen bestehen.
--
-- Voraussetzungen: Tabellen personen/stammbaeume/familien; Helfer ist_super_admin()/
-- kann_familie_bearbeiten() aus supabase_verbund.sql. Blutlinien-Auto-Rechte werden durch die
-- bestehenden personen-Trigger automatisch neu berechnet (familie_id ändert sich).
-- =====================================================

CREATE OR REPLACE FUNCTION public.person_baum_verschieben(p_person uuid, p_ziel_baum uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_alt_fam   uuid;
  v_alt_baum  uuid;
  v_ident     uuid;
  v_ziel_fam  uuid;
  v_twins     int;
BEGIN
  IF p_person IS NULL OR p_ziel_baum IS NULL THEN
    RAISE EXCEPTION 'parameter_fehlt';
  END IF;

  SELECT familie_id, stammbaum_id, identitaet_id
    INTO v_alt_fam, v_alt_baum, v_ident
    FROM public.personen WHERE id = p_person;
  IF v_alt_fam IS NULL THEN RAISE EXCEPTION 'person_fehlt'; END IF;

  SELECT familie_id INTO v_ziel_fam
    FROM public.stammbaeume WHERE id = p_ziel_baum;
  IF v_ziel_fam IS NULL THEN RAISE EXCEPTION 'ziel_baum_fehlt'; END IF;

  -- Schon im Ziel-Baum -> nichts zu tun (idempotent)
  IF p_ziel_baum = v_alt_baum THEN
    RETURN jsonb_build_object('ok', true, 'unveraendert', true);
  END IF;

  -- Rechte: beide Familien editierbar (oder Super-Admin)
  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_alt_fam)
              AND public.kann_familie_bearbeiten(v_ziel_fam))) THEN
    RAISE EXCEPTION 'keine_berechtigung';
  END IF;

  -- Identitäts-Zwilling bereits im Ziel-Baum? -> würde Duplikat erzeugen
  IF v_ident IS NOT NULL THEN
    SELECT count(*) INTO v_twins
      FROM public.personen
     WHERE identitaet_id = v_ident AND stammbaum_id = p_ziel_baum;
    IF v_twins > 0 THEN RAISE EXCEPTION 'ziel_hat_zwilling'; END IF;
  END IF;

  UPDATE public.personen
     SET stammbaum_id = p_ziel_baum,
         familie_id   = v_ziel_fam
   WHERE id = p_person;

  RETURN jsonb_build_object('ok', true, 'alt_baum', v_alt_baum, 'ziel_baum', p_ziel_baum);
END;
$$;

GRANT EXECUTE ON FUNCTION public.person_baum_verschieben(uuid, uuid) TO authenticated;
