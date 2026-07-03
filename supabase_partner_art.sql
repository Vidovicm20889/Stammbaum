-- =====================================================
-- PARTNER-ART (Ehepartner / Partner / Ex-Ehepartner / Ex-Partner)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- ZWECK: Feinere Partner-Beziehungen, ohne das Kanten-Modell aufzubrechen. Der Kanten-Typ
-- in `beziehungen` bleibt 'ehepartner' (alle bestehende Logik — Rendering, gemeinsame Kinder,
-- Zweigbaum, Löschen — funktioniert unverändert weiter). Die 4 Varianten sind eine zusätzliche
-- Kennzeichnung auf der Kante + geschlechtsabhängiges Label im Frontend:
--   'ehe'        -> Ehemann / Ehefrau
--   'partner'    -> Partner/in (unverheiratet)
--   'ex_ehe'     -> Exmann / Exfrau (geschieden/getrennt, war verheiratet)
--   'ex_partner' -> Ex-Partner/in
-- NULL = Bestand = wie 'ehe' (rückwärtskompatibel; kein Backfill nötig).
--
-- Voraussetzungen: Tabelle beziehungen; Helfer ist_super_admin()/kann_familie_bearbeiten()
-- (supabase_verbund.sql). Betrifft NUR 'ehepartner'-Kanten (elternteil bleibt NULL).
-- =====================================================

-- 1) Spalte -------------------------------------------------------------------
ALTER TABLE public.beziehungen ADD COLUMN IF NOT EXISTS partner_art text;

-- CHECK idempotent (drop+add): nur die 4 gültigen Werte oder NULL.
ALTER TABLE public.beziehungen DROP CONSTRAINT IF EXISTS beziehungen_partner_art_chk;
ALTER TABLE public.beziehungen ADD CONSTRAINT beziehungen_partner_art_chk
  CHECK (partner_art IS NULL OR partner_art IN ('ehe','partner','ex_ehe','ex_partner'));

-- 2) RPC: Art einer BESTEHENDEN Partnerschaft umstellen -----------------------
-- Identitätsbewusst (ganze identitaet_id-Gruppe beider Personen, wie das Löschen/Verschieben),
-- damit gespiegelte Karten konsistent bleiben. Rechte: kann_familie_bearbeiten() für BEIDE
-- Familien (verbundbasiert) oder Super-Admin -> Isolation bleibt gewahrt.
CREATE OR REPLACE FUNCTION public.partner_art_setzen(p_person uuid, p_other uuid, p_art text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_P uuid[]; v_X uuid[]; v_p_fam uuid; v_x_fam uuid; v_n int;
BEGIN
  IF p_person IS NULL OR p_other IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'parameter_fehlt');
  END IF;
  IF p_art IS NULL OR p_art NOT IN ('ehe','partner','ex_ehe','ex_partner') THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'art_unbekannt');
  END IF;

  -- Identitätsgruppen (gespiegelte Karten = dieselbe reale Person)
  SELECT array_agg(pp.id) INTO v_P FROM personen pp
   WHERE pp.geloescht_am IS NULL
     AND (pp.id = p_person
      OR pp.identitaet_id = (SELECT identitaet_id FROM personen WHERE id = p_person AND identitaet_id IS NOT NULL AND geloescht_am IS NULL));
  SELECT array_agg(pp.id) INTO v_X FROM personen pp
   WHERE pp.geloescht_am IS NULL
     AND (pp.id = p_other
      OR pp.identitaet_id = (SELECT identitaet_id FROM personen WHERE id = p_other AND identitaet_id IS NOT NULL AND geloescht_am IS NULL));
  IF v_P IS NULL OR v_X IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'person_fehlt');
  END IF;

  SELECT familie_id INTO v_p_fam FROM personen WHERE id = p_person AND geloescht_am IS NULL;
  SELECT familie_id INTO v_x_fam FROM personen WHERE id = p_other  AND geloescht_am IS NULL;

  IF NOT (ist_super_admin()
          OR (kann_familie_bearbeiten(v_p_fam) AND kann_familie_bearbeiten(v_x_fam))) THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'bezv_kein_recht');
  END IF;

  UPDATE beziehungen SET partner_art = p_art
   WHERE typ = 'ehepartner' AND geloescht_am IS NULL
     AND ((person_a = ANY(v_P) AND person_b = ANY(v_X))
       OR (person_a = ANY(v_X) AND person_b = ANY(v_P)));
  GET DIAGNOSTICS v_n = ROW_COUNT;

  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'keine_partnerkante');
  END IF;
  RETURN jsonb_build_object('ok', true, 'aktualisiert', v_n);
END $$;

GRANT EXECUTE ON FUNCTION public.partner_art_setzen(uuid, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

SELECT 'OK: beziehungen.partner_art + partner_art_setzen() angelegt' AS status;
