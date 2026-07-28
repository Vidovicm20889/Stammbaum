-- =====================================================
-- PERSON ATOMAR ANLEGEN — Person + ihre Beziehungen in EINER Transaktion
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT (CREATE OR REPLACE).
--
-- HINTERGRUND (Audit „Personen verschwinden", Vorschlag 2): Bisher legt das Frontend
-- (speichereNeuePerson) eine neue Person in ZWEI getrennten Calls an:
--   1) INSERT personen     2) INSERT beziehungen
-- Schlägt Schritt 2 fehl (Netz/RLS/transient), bleibt die Person OHNE jede Kante in der
-- DB -> sie ist eine „lose Insel" und wird im Diagramm NIE gezeichnet (Render-Wurzel
-- erreicht sie nicht). Diese RPC bündelt beides in EINER Funktion = EINER Transaktion:
--   ENTWEDER alles wird angelegt ODER gar nichts (automatischer Rollback bei Fehler).
-- Es kann so keine kanten-lose Person mehr entstehen.
--
-- Deckt alle Anlage-Fälle des Personen-Overlays ab (kind/elternteil/partner/geschwister)
-- inkl. des Platzhalter-Elternteils (Geschwister ohne vorhandene Eltern) — ebenfalls
-- innerhalb derselben Transaktion, damit auch kein loser Platzhalter zurückbleibt.
--
-- p_op (jsonb) — Operationsbeschreibung:
--   {
--     "familie_id":   uuid,                -- Familie der neuen Person (= Kontextperson)
--     "stammbaum_id": uuid,                -- Baum der neuen Person
--     "externe_id":   text,                -- I<timestamp> (vom Frontend erzeugt)
--     "daten":        { ...stammbaum_daten... },   -- jsonb, enthält given/surname/...
--     "edges": [                            -- Kanten der NEUEN Person zu BESTEHENDEN Personen
--        { "other": uuid, "typ": "elternteil"|"ehepartner", "new_ist_a": bool,
--          "partner_art": "ehe"|"partner"|"ex_ehe"|"ex_partner" }  -- nur bei ehepartner, optional
--        -- new_ist_a=true  -> person_a = neu,  person_b = other
--        -- new_ist_a=false -> person_a = other, person_b = neu
--     ],
--     "platzhalter": {                      -- OPTIONAL: Geschwister ohne Eltern
--        "externe_id": text, "daten": { ... },
--        "kinder": [uuid, ...]              -- bestehende Geschwister, die ebenfalls an den
--     }                                     -- Platzhalter gehängt werden (neu wird automatisch Kind)
--   }
--
-- Rückgabe: { ok, person_id, externe_id, platzhalter_id }
--
-- Voraussetzungen: Tabellen personen/beziehungen, Helfer ist_super_admin()/
-- kann_familie_bearbeiten() aus supabase_verbund.sql.
-- =====================================================

CREATE OR REPLACE FUNCTION public.person_anlegen_atomar(p_op jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam   uuid := (p_op->>'familie_id')::uuid;
  v_tree  uuid := (p_op->>'stammbaum_id')::uuid;
  v_ext   text := p_op->>'externe_id';
  v_daten jsonb := p_op->'daten';
  v_new   uuid;
  v_ph    uuid;
  v_phj   jsonb := p_op->'platzhalter';
  v_edge  jsonb;
  v_kid   jsonb;
  v_typ   text;
  v_art   text;
BEGIN
  IF v_fam IS NULL OR v_tree IS NULL THEN RAISE EXCEPTION 'pa_kontext_fehlt'; END IF;
  IF v_ext IS NULL OR v_daten IS NULL OR jsonb_typeof(v_daten) <> 'object' THEN
    RAISE EXCEPTION 'pa_daten_fehlt'; END IF;

  -- Rechte: Bearbeitungsrecht der Familie (Super-Admin / Owner / Admin im Verbund)
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'pa_keine_berechtigung'; END IF;

  -- 1) Neue Person ------------------------------------------------------------
  INSERT INTO public.personen
    (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum, stammbaum_daten)
  VALUES
    (v_fam, v_tree, v_ext,
     coalesce(v_daten->>'given',''), coalesce(v_daten->>'surname',''),
     NULL, v_daten)
  RETURNING id INTO v_new;

  -- 2) Optionaler Platzhalter-Elternteil (Geschwister ohne vorhandene Eltern) --
  --    Neue Person + bestehende Geschwister werden als Kinder daran gehängt.
  IF v_phj IS NOT NULL AND jsonb_typeof(v_phj) = 'object' THEN
    INSERT INTO public.personen
      (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum, stammbaum_daten)
    VALUES
      (v_fam, v_tree, coalesce(v_phj->>'externe_id', 'I'||(extract(epoch from clock_timestamp())*1000)::bigint||'P'),
       coalesce(v_phj->'daten'->>'given',''), coalesce(v_phj->'daten'->>'surname',''),
       NULL, coalesce(v_phj->'daten', '{}'::jsonb))
    RETURNING id INTO v_ph;

    -- neue Person als Kind des Platzhalters
    INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
    VALUES (v_fam, v_ph, v_new, 'elternteil');

    -- bestehende Geschwister ebenfalls an den Platzhalter (idempotent gegen Doppel-Kante)
    FOR v_kid IN SELECT * FROM jsonb_array_elements(coalesce(v_phj->'kinder', '[]'::jsonb)) LOOP
      INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
      SELECT v_fam, v_ph, (v_kid#>>'{}')::uuid, 'elternteil'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.beziehungen b
         WHERE b.person_a = v_ph AND b.person_b = (v_kid#>>'{}')::uuid AND b.typ = 'elternteil'
           AND b.geloescht_am IS NULL);
    END LOOP;
  END IF;

  -- 3) Kanten der neuen Person zu bestehenden Personen ------------------------
  FOR v_edge IN SELECT * FROM jsonb_array_elements(coalesce(p_op->'edges', '[]'::jsonb)) LOOP
    v_typ := v_edge->>'typ';
    IF v_typ NOT IN ('elternteil','ehepartner') THEN
      RAISE EXCEPTION 'pa_kante_typ_ungueltig: %', v_typ; END IF;
    IF (v_edge->>'other') IS NULL THEN CONTINUE; END IF;

    -- Partner-Art nur bei ehepartner (sonst NULL); ungültige Werte -> NULL (= 'ehe').
    v_art := CASE WHEN v_typ = 'ehepartner'
                   AND (v_edge->>'partner_art') IN ('ehe','partner','ex_ehe','ex_partner')
                  THEN v_edge->>'partner_art' ELSE NULL END;

    IF coalesce((v_edge->>'new_ist_a')::boolean, false) THEN
      INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ, partner_art)
      VALUES (v_fam, v_new, (v_edge->>'other')::uuid, v_typ, v_art);
    ELSE
      INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ, partner_art)
      VALUES (v_fam, (v_edge->>'other')::uuid, v_new, v_typ, v_art);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'person_id', v_new,
                            'externe_id', v_ext, 'platzhalter_id', v_ph);
END $$;

GRANT EXECUTE ON FUNCTION public.person_anlegen_atomar(jsonb) TO authenticated;

NOTIFY pgrst, 'reload schema';

SELECT 'Atomare Personenanlage angelegt: person_anlegen_atomar(p_op jsonb)' AS status;
