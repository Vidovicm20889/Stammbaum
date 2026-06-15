-- =====================================================
-- BEZIEHUNG VERSCHIEBEN / UMHÄNGEN (Admin)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT (CREATE OR REPLACE).
--
-- ZWECK: Eine falsch angelegte Beziehung korrigieren, OHNE eine Person zu löschen. Verschiebt
-- die Rolle der Person X relativ zur offenen Person P von ihrer aktuellen Rolle in eine neue:
--   p_neu_typ ∈ {eltern, kind, partner, geschwister}   (Rolle von X bezogen auf P)
-- Beide Personen bleiben erhalten; nur die Kanten in `beziehungen` werden umgesetzt.
--
-- KANTEN-MODELL: `beziehungen` kennt nur `elternteil` (person_a=Elternteil -> person_b=Kind)
-- und `ehepartner` (symmetrisch). Geschwister haben KEINE eigene Kante (gemeinsame Eltern).
--   eltern       : elternteil  X -> P
--   kind         : elternteil  P -> X
--   partner      : ehepartner  P <-> X
--   geschwister  : elternteil  (Eltern von P) -> X   (kein eigener Kantentyp)
--
-- ABLAUF (ATOMAR, eine Transaktion): Validieren -> ALLE P<->X-Kanten lösen (inkl. X von P's
-- Eltern, falls Geschwister) -> neue Rollen-Kanten setzen. So entsteht kein inkonsistenter
-- Zwischenzustand. Bei Eltern/Kind/Geschwister liefert die Funktion `sync_kind` zurück -> das
-- Frontend ruft danach kind_baeume_sync(sync_kind) (Spiegelung in alle Eltern-Bäume). Die
-- Blutlinien-Auto-Rechte werden über die bestehenden personen/beziehungen-Trigger neu berechnet.
--
-- IDENTITÄTSBEWUSST: Operiert auf der ganzen identitaet_id-Gruppe beider Personen (wie das
-- Lösen im Frontend), damit gespiegelte Karten konsistent bleiben.
--
-- RECHTE: kann_familie_bearbeiten() für BEIDE Familien (verbundbasiert) oder Super-Admin ->
-- Isolation gegen fremde Verbünde bleibt gewahrt.
--
-- VALIDIERUNG (verbindlich; das Frontend prüft zusätzlich für sofortiges Feedback):
--   bezv_self                -> X (oder ihr Zwilling) ist P selbst
--   bezv_zyklus              -> würde „Person ist eigener Vor-/Nachfahre" erzeugen
--   bezv_geschwister_konflikt-> X und P sind Geschwister -> nicht als Eltern erlaubt
--   bezv_partner_inzest      -> Partner-Ziel bei direkter Blutlinie/Geschwistern
--   bezv_zu_viele_eltern     -> P hat bereits 2 Eltern (ohne Ersetzen-Angabe)
--   bezv_kein_recht          -> keine Bearbeitungsrechte
--
-- Voraussetzungen: Tabellen personen/beziehungen/stammbaeume/familien; Helfer
-- ist_super_admin()/kann_familie_bearbeiten() (supabase_verbund.sql); Funktion
-- kind_baeume_sync() (supabase_kind_baeume_sync.sql, vom Frontend mit sync_kind aufgerufen).
-- =====================================================

CREATE OR REPLACE FUNCTION public.beziehung_verschieben(
  p_person uuid,
  p_other  uuid,
  p_neu_typ text,
  p_ersetzt_elternteil uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_P uuid[]; v_X uuid[];
  v_p_fam uuid; v_p_baum uuid; v_x_fam uuid;
  v_pparents uuid[];
  v_anc uuid[]; v_desc uuid[];
  v_sibling boolean;
  v_parentcount int;
  v_ph_ext text; v_ph_id uuid;
  v_sync_kind uuid := NULL;
BEGIN
  IF p_person IS NULL OR p_other IS NULL OR p_neu_typ IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'parameter_fehlt');
  END IF;
  IF p_neu_typ NOT IN ('eltern','kind','partner','geschwister') THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'typ_unbekannt');
  END IF;

  -- Identitätsgruppen (gespiegelte Karten = dieselbe reale Person)
  SELECT array_agg(pp.id) INTO v_P FROM personen pp
   WHERE pp.id = p_person
      OR pp.identitaet_id = (SELECT identitaet_id FROM personen WHERE id = p_person AND identitaet_id IS NOT NULL);
  SELECT array_agg(pp.id) INTO v_X FROM personen pp
   WHERE pp.id = p_other
      OR pp.identitaet_id = (SELECT identitaet_id FROM personen WHERE id = p_other AND identitaet_id IS NOT NULL);
  IF v_P IS NULL OR v_X IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'person_fehlt');
  END IF;

  -- Selbst (auch eigener Zwilling)
  IF v_P && v_X THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'bezv_self');
  END IF;

  SELECT familie_id, stammbaum_id INTO v_p_fam, v_p_baum FROM personen WHERE id = p_person;
  SELECT familie_id INTO v_x_fam FROM personen WHERE id = p_other;

  -- Rechte: beide Familien editierbar (oder Super-Admin)
  IF NOT (ist_super_admin()
          OR (kann_familie_bearbeiten(v_p_fam) AND kann_familie_bearbeiten(v_x_fam))) THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'bezv_kein_recht');
  END IF;

  -- Eltern von P
  SELECT array_agg(DISTINCT person_a) INTO v_pparents
    FROM beziehungen WHERE typ = 'elternteil' AND person_b = ANY(v_P);
  v_pparents := COALESCE(v_pparents, ARRAY[]::uuid[]);

  -- Vorfahren von P (rekursiv über elternteil)
  WITH RECURSIVE anc(id) AS (
    SELECT person_a FROM beziehungen WHERE typ = 'elternteil' AND person_b = ANY(v_P)
    UNION
    SELECT b.person_a FROM beziehungen b JOIN anc ON b.person_b = anc.id WHERE b.typ = 'elternteil'
  ) SELECT array_agg(id) INTO v_anc FROM anc;
  v_anc := COALESCE(v_anc, ARRAY[]::uuid[]);

  -- Nachfahren von P (rekursiv über elternteil)
  WITH RECURSIVE des(id) AS (
    SELECT person_b FROM beziehungen WHERE typ = 'elternteil' AND person_a = ANY(v_P)
    UNION
    SELECT b.person_b FROM beziehungen b JOIN des ON b.person_a = des.id WHERE b.typ = 'elternteil'
  ) SELECT array_agg(id) INTO v_desc FROM des;
  v_desc := COALESCE(v_desc, ARRAY[]::uuid[]);

  -- Geschwister? (X teilt einen Elternteil mit P)
  v_sibling := cardinality(v_pparents) > 0 AND EXISTS (
    SELECT 1 FROM beziehungen
     WHERE typ = 'elternteil' AND person_b = ANY(v_X) AND person_a = ANY(v_pparents)
  );

  -- ---- Validierung je Zieltyp ----
  IF p_neu_typ = 'eltern' THEN
    IF v_X && v_desc THEN RETURN jsonb_build_object('ok',false,'fehler','bezv_zyklus'); END IF;
    IF v_sibling     THEN RETURN jsonb_build_object('ok',false,'fehler','bezv_geschwister_konflikt'); END IF;
    SELECT count(DISTINCT person_a) INTO v_parentcount
      FROM beziehungen
     WHERE typ = 'elternteil' AND person_b = ANY(v_P) AND NOT (person_a = ANY(v_X));
    IF p_ersetzt_elternteil IS NOT NULL THEN v_parentcount := v_parentcount - 1; END IF;
    IF v_parentcount >= 2 THEN RETURN jsonb_build_object('ok',false,'fehler','bezv_zu_viele_eltern'); END IF;
  ELSIF p_neu_typ = 'kind' THEN
    IF v_X && v_anc THEN RETURN jsonb_build_object('ok',false,'fehler','bezv_zyklus'); END IF;
  ELSIF p_neu_typ = 'partner' THEN
    IF (v_X && v_anc) OR (v_X && v_desc) OR v_sibling THEN
      RETURN jsonb_build_object('ok',false,'fehler','bezv_partner_inzest');
    END IF;
  ELSIF p_neu_typ = 'geschwister' THEN
    IF (v_X && v_anc) OR (v_X && v_desc) THEN
      RETURN jsonb_build_object('ok',false,'fehler','bezv_zyklus');
    END IF;
  END IF;

  -- ---- CLEAR: alle P<->X-Kanten + X von P's Eltern lösen (falls Geschwister) ----
  DELETE FROM beziehungen WHERE typ = 'elternteil'
     AND ((person_a = ANY(v_X) AND person_b = ANY(v_P))
       OR (person_a = ANY(v_P) AND person_b = ANY(v_X)));
  DELETE FROM beziehungen WHERE typ = 'ehepartner'
     AND ((person_a = ANY(v_P) AND person_b = ANY(v_X))
       OR (person_a = ANY(v_X) AND person_b = ANY(v_P)));
  IF cardinality(v_pparents) > 0 THEN
    DELETE FROM beziehungen WHERE typ = 'elternteil'
       AND person_a = ANY(v_pparents) AND person_b = ANY(v_X);
  END IF;

  -- ---- SET: neue Rolle setzen ----
  IF p_neu_typ = 'eltern' THEN
    -- optional: einen vorhandenen Elternteil von P ersetzen (dessen Identitätsgruppe lösen)
    IF p_ersetzt_elternteil IS NOT NULL THEN
      DELETE FROM beziehungen WHERE typ = 'elternteil' AND person_b = ANY(v_P)
        AND person_a IN (
          SELECT id FROM personen
           WHERE id = p_ersetzt_elternteil
              OR identitaet_id = (SELECT identitaet_id FROM personen WHERE id = p_ersetzt_elternteil AND identitaet_id IS NOT NULL)
        );
    END IF;
    INSERT INTO beziehungen(person_a, person_b, typ, familie_id)
      VALUES (p_other, p_person, 'elternteil', v_p_fam);
    v_sync_kind := p_person;

  ELSIF p_neu_typ = 'kind' THEN
    INSERT INTO beziehungen(person_a, person_b, typ, familie_id)
      VALUES (p_person, p_other, 'elternteil', v_x_fam);
    v_sync_kind := p_other;

  ELSIF p_neu_typ = 'partner' THEN
    INSERT INTO beziehungen(person_a, person_b, typ, familie_id)
      VALUES (p_person, p_other, 'ehepartner', v_p_fam);

  ELSIF p_neu_typ = 'geschwister' THEN
    IF cardinality(v_pparents) > 0 THEN
      INSERT INTO beziehungen(person_a, person_b, typ, familie_id)
        SELECT pa, p_other, 'elternteil', v_x_fam FROM unnest(v_pparents) AS pa;
    ELSE
      -- P hat keine Eltern -> Platzhalter-Elternteil anlegen, P und X daran hängen
      v_ph_ext := 'I' || (extract(epoch from clock_timestamp()) * 1000)::bigint::text || 'P';
      INSERT INTO personen(familie_id, stammbaum_id, externe_id, stammbaum_daten)
        VALUES (v_p_fam, v_p_baum, v_ph_ext,
                jsonb_build_object('id', v_ph_ext, 'given','', 'surname','', 'name','',
                  'sex','', 'platzhalter', true, 'angelegt_aus','beziehung-verschieben-geschwister'))
        RETURNING id INTO v_ph_id;
      INSERT INTO beziehungen(person_a, person_b, typ, familie_id) VALUES
        (v_ph_id, p_person, 'elternteil', v_p_fam),
        (v_ph_id, p_other,  'elternteil', v_p_fam);
    END IF;
    v_sync_kind := p_other;
  END IF;

  RETURN jsonb_build_object('ok', true, 'sync_kind', v_sync_kind);
END;
$$;

GRANT EXECUTE ON FUNCTION public.beziehung_verschieben(uuid, uuid, text, uuid) TO authenticated;
