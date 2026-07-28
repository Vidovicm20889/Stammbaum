-- ============================================================================
-- Feature 7 — Neuen Baum aus einer Person anlegen (Identitäts-SPIEGEL, keine Kopie)
-- ----------------------------------------------------------------------------
-- Legt eine NEUE Familie + Stammbaum an, Wurzel = SPIEGEL (gleiche identitaet_id) der Person.
-- Umfang: person | eltern | kinder | beides. Tiefe: 'direkt' (nur direkte Generation) oder
-- 'linie' (ganze Ahnen-/Nachkommenlinie, rekursiv). Beziehungen (elternteil + ehepartner) zwischen
-- den gespiegelten Personen werden nachgebildet.
--
-- Verbund/Isolation: neue Familie EXPLIZIT in den Verbund der Quelle (verbund_id) -> co-sichtbar,
-- Isolation gewahrt (familien.verbund_id DEFAULT wäre eigener Verbund).
-- Atomar (eine Transaktion). Idempotent. Im Supabase SQL-Editor ausführen.
-- ============================================================================

DROP FUNCTION IF EXISTS public.person_neuer_baum(uuid, text, text, text);

CREATE OR REPLACE FUNCTION public.person_neuer_baum(
  p_person uuid, p_name text, p_zusatz text DEFAULT NULL, p_umfang text DEFAULT 'person', p_tiefe text DEFAULT 'direkt')
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_srcfam uuid; v_verb uuid; v_newfam uuid; v_tree uuid; v_root uuid; v_mir uuid;
  v_maxgen int; v_incl_e boolean; v_incl_k boolean;
  v_rec    record; v_ext text; v_seq int := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'nicht_angemeldet'; END IF;
  IF coalesce(trim(p_name),'') = '' THEN RAISE EXCEPTION 'name_erforderlich'; END IF;
  IF p_umfang NOT IN ('person','eltern','kinder','beides') THEN p_umfang := 'person'; END IF;
  v_incl_e := p_umfang IN ('eltern','beides');
  v_incl_k := p_umfang IN ('kinder','beides');
  v_maxgen := CASE WHEN p_tiefe = 'linie' THEN 40 ELSE 1 END;

  SELECT familie_id INTO v_srcfam FROM public.personen WHERE id = p_person AND geloescht_am IS NULL;
  IF v_srcfam IS NULL THEN RAISE EXCEPTION 'person_unbekannt'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_srcfam)) THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = v_srcfam;

  -- 1) Personenmenge = Wurzel + (Ahnen bis maxgen) + (Nachkommen bis maxgen), ohne Platzhalter
  CREATE TEMP TABLE _pnb_set (id uuid PRIMARY KEY) ON COMMIT DROP;
  INSERT INTO _pnb_set VALUES (p_person);
  IF v_incl_e THEN
    INSERT INTO _pnb_set
      SELECT id FROM (
        WITH RECURSIVE anc(id, gen) AS (
          SELECT p_person, 0
          UNION
          SELECT b.person_a, a.gen + 1
            FROM anc a
            JOIN public.beziehungen b ON b.person_b = a.id AND b.typ = 'elternteil' AND b.geloescht_am IS NULL
            JOIN public.personen po ON po.id = b.person_a AND po.geloescht_am IS NULL
                 AND coalesce((po.stammbaum_daten->>'platzhalter')::boolean, false) = false
           WHERE a.gen < v_maxgen
        ) SELECT DISTINCT id FROM anc WHERE id <> p_person
      ) q
    ON CONFLICT DO NOTHING;
  END IF;
  IF v_incl_k THEN
    INSERT INTO _pnb_set
      SELECT id FROM (
        WITH RECURSIVE des(id, gen) AS (
          SELECT p_person, 0
          UNION
          SELECT b.person_b, d.gen + 1
            FROM des d
            JOIN public.beziehungen b ON b.person_a = d.id AND b.typ = 'elternteil' AND b.geloescht_am IS NULL
            JOIN public.personen po ON po.id = b.person_b AND po.geloescht_am IS NULL
                 AND coalesce((po.stammbaum_daten->>'platzhalter')::boolean, false) = false
           WHERE d.gen < v_maxgen
        ) SELECT DISTINCT id FROM des WHERE id <> p_person
      ) q
    ON CONFLICT DO NOTHING;
  END IF;

  -- 2) identitaet_id für alle Betroffenen sicherstellen
  UPDATE public.personen SET identitaet_id = gen_random_uuid()
   WHERE id IN (SELECT id FROM _pnb_set) AND identitaet_id IS NULL;

  -- 3) neue Familie (im Verbund) + Baum + Owner
  INSERT INTO public.familien (name, verbund_id) VALUES (trim(p_name), v_verb) RETURNING id INTO v_newfam;
  INSERT INTO public.stammbaeume (familie_id, name, zusatz, ersteller_id, owner_id, aktiv)
    VALUES (v_newfam, trim(p_name), nullif(trim(coalesce(p_zusatz,'')),''), v_uid, v_uid, true) RETURNING id INTO v_tree;
  INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv)
    VALUES (v_uid, v_newfam, 'familien_owner', true)
    ON CONFLICT (user_id, familie_id) DO UPDATE SET rolle = 'familien_owner', aktiv = true;

  -- 4) Spiegel jeder Person (Mapping original -> mirror), Wurzel merken
  CREATE TEMP TABLE _pnb_map (orig uuid PRIMARY KEY, mir uuid) ON COMMIT DROP;
  FOR v_rec IN
    SELECT pe.id, pe.vorname, pe.nachname, pe.stammbaum_daten, pe.identitaet_id
      FROM public.personen pe WHERE pe.id IN (SELECT id FROM _pnb_set)
  LOOP
    v_seq := v_seq + 1;
    v_ext := 'I' || (extract(epoch from now())*1000)::bigint || 'N' || v_seq::text;
    INSERT INTO public.personen
      (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum, stammbaum_daten, identitaet_id)
      VALUES (v_newfam, v_tree, v_ext, v_rec.vorname, v_rec.nachname, NULL,
              coalesce(v_rec.stammbaum_daten,'{}'::jsonb) || jsonb_build_object('id', v_ext), v_rec.identitaet_id)
      RETURNING id INTO v_mir;
    INSERT INTO _pnb_map VALUES (v_rec.id, v_mir);
    IF v_rec.id = p_person THEN v_root := v_mir; END IF;
  END LOOP;
  UPDATE public.stammbaeume SET wurzel_person_id = v_root WHERE id = v_tree;

  -- 5) Beziehungen zwischen gespiegelten Personen nachbilden (elternteil + ehepartner; beide Enden in der Menge)
  INSERT INTO public.beziehungen (person_a, person_b, typ, partner_art, familie_id)
    SELECT ma.mir, mb.mir, b.typ, b.partner_art, v_newfam
      FROM public.beziehungen b
      JOIN _pnb_map ma ON ma.orig = b.person_a
      JOIN _pnb_map mb ON mb.orig = b.person_b
     WHERE b.typ IN ('elternteil','ehepartner') AND b.geloescht_am IS NULL;

  RETURN v_tree;
END;
$$;
GRANT EXECUTE ON FUNCTION public.person_neuer_baum(uuid, text, text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

SELECT 'person_neuer_baum (Feature 7, Umfang + Tiefe direkt/linie, Identitäts-Spiegel) angelegt' AS status;
