-- =====================================================
-- SCHUTZ: Spiegel-Zwillinge (gleiche identitaet_id) NICHT mergen
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Voraussetzung: supabase_merge_gui.sql (dubletten_scan, _person_merge_core,
--                person_merge_aufgeloest).
--
-- HINTERGRUND (Bug "Zorana verschwindet aus Knežević"):
-- Beim Auto-Zweigbaum (Heirat) wird eine Person als GLEICHE Person über
-- personen.identitaet_id in beide Bäume GESPIEGELT (1 Karte je Baum, beide bleiben
-- sichtbar = gewollt). Das "Dubletten-Merge"-Werkzeug hat diese zwei Zwillingskarten
-- aber als Duplikat vorgeschlagen und zu EINER zusammengeführt -> die Karte im einen
-- Baum verschwand. Zwei Karten mit GLEICHER identitaet_id sind jedoch KEIN Duplikat,
-- sondern bereits dieselbe Person in zwei Bäumen.
--
-- FIX (zwei Schichten):
--  1) dubletten_scan: bereits verknüpfte Zwillinge (gleiche identitaet_id) werden NICHT
--     mehr als Dublette vorgeschlagen.
--  2) person_merge_aufgeloest: harter Riegel — Merge zweier Zwillinge (gleiche
--     identitaet_id) in VERSCHIEDENEN Bäumen wird verweigert (Fehler 'merge_zwillinge').
--     (Gleicher Baum + gleiche identitaet_id = versehentlich doppelte Spiegelkarte im
--      selben Baum -> bleibt mergebar, das ist ein echtes Aufräumen.)
-- =====================================================


-- ---------- 1) dubletten_scan: verknüpfte Zwillinge ausschließen ----------
CREATE OR REPLACE FUNCTION public.dubletten_scan(p_baum_a uuid, p_baum_b uuid, p_min_score int DEFAULT 4)
RETURNS TABLE(id_a uuid, id_b uuid, name_a text, name_b text, score int, gruende text[])
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam_a uuid; v_fam_b uuid;
BEGIN
  SELECT familie_id INTO v_fam_a FROM public.stammbaeume WHERE id = p_baum_a;
  SELECT familie_id INTO v_fam_b FROM public.stammbaeume WHERE id = p_baum_b;
  IF v_fam_a IS NULL OR v_fam_b IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_fam_a) AND public.kann_familie_bearbeiten(v_fam_b)))
    THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;

  RETURN QUERY
  WITH a AS (
    SELECT p.id, p.identitaet_id AS iid,
           public.merge_norm(p.vorname) AS vn, public.merge_norm(p.nachname) AS nn,
           nullif(trim(coalesce(p.stammbaum_daten->>'birth_date','')),'') AS bd,
           trim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')) AS anzeige,
           public.merge_nachbarn(p.id,'eltern')  AS eltern,
           public.merge_nachbarn(p.id,'kinder')  AS kinder,
           public.merge_nachbarn(p.id,'partner') AS partner
    FROM public.personen p WHERE p.stammbaum_id = p_baum_a
  ),
  b AS (
    SELECT p.id, p.identitaet_id AS iid,
           public.merge_norm(p.vorname) AS vn, public.merge_norm(p.nachname) AS nn,
           nullif(trim(coalesce(p.stammbaum_daten->>'birth_date','')),'') AS bd,
           trim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')) AS anzeige,
           public.merge_nachbarn(p.id,'eltern')  AS eltern,
           public.merge_nachbarn(p.id,'kinder')  AS kinder,
           public.merge_nachbarn(p.id,'partner') AS partner
    FROM public.personen p WHERE p.stammbaum_id = p_baum_b
  ),
  paare AS (
    SELECT a.id AS id_a, b.id AS id_b, a.anzeige AS name_a, b.anzeige AS name_b,
      ( CASE WHEN a.vn <> '' AND a.vn = b.vn THEN 2 ELSE 0 END
      + CASE WHEN a.nn <> '' AND a.nn = b.nn THEN 2 ELSE 0 END
      + CASE WHEN a.bd IS NOT NULL AND a.bd = b.bd THEN 3 ELSE 0 END
      + 2 * public.merge_overlap(a.eltern,  b.eltern)
      + 2 * public.merge_overlap(a.kinder,  b.kinder)
      + 2 * public.merge_overlap(a.partner, b.partner) ) AS score,
      ( CASE WHEN a.vn <> '' AND a.vn = b.vn THEN ARRAY['vorname'] ELSE ARRAY[]::text[] END
      || CASE WHEN a.nn <> '' AND a.nn = b.nn THEN ARRAY['nachname'] ELSE ARRAY[]::text[] END
      || CASE WHEN a.bd IS NOT NULL AND a.bd = b.bd THEN ARRAY['geburtsdatum'] ELSE ARRAY[]::text[] END
      || CASE WHEN public.merge_overlap(a.eltern,  b.eltern)  > 0 THEN ARRAY['eltern']  ELSE ARRAY[]::text[] END
      || CASE WHEN public.merge_overlap(a.kinder,  b.kinder)  > 0 THEN ARRAY['kinder']  ELSE ARRAY[]::text[] END
      || CASE WHEN public.merge_overlap(a.partner, b.partner) > 0 THEN ARRAY['partner'] ELSE ARRAY[]::text[] END
      ) AS gruende,
      ( (a.vn <> '' AND a.vn = b.vn)
        OR (a.bd IS NOT NULL AND a.bd = b.bd AND a.nn <> '' AND a.nn = b.nn) ) AS ident,
      -- NEU: schon als gleiche Person verknüpft? (gleiche identitaet_id = kein Duplikat)
      (a.iid IS NOT NULL AND a.iid = b.iid) AS schon_verknuepft
    FROM a CROSS JOIN b
  )
  SELECT q.id_a, q.id_b, q.name_a, q.name_b, q.score, q.gruende
  FROM paare q
  WHERE q.ident AND q.score >= p_min_score
    AND NOT q.schon_verknuepft        -- bereits gespiegelte Zwillinge NICHT als Dublette anbieten
  ORDER BY q.score DESC, q.name_a;
END $$;
GRANT EXECUTE ON FUNCTION public.dubletten_scan(uuid, uuid, int) TO authenticated;


-- ---------- 2) person_merge_aufgeloest: harter Riegel gegen Zwillings-Merge ----------
CREATE OR REPLACE FUNCTION public.person_merge_aufgeloest(
  p_behalten uuid, p_dublette uuid, p_aufloesung jsonb DEFAULT '{}'::jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam_b uuid; v_fam_d uuid;
  v_iid_b uuid; v_iid_d uuid; v_tree_b uuid; v_tree_d uuid;
BEGIN
  IF p_behalten IS NULL OR p_dublette IS NULL OR p_behalten = p_dublette THEN RETURN p_behalten; END IF;
  SELECT familie_id, identitaet_id, stammbaum_id INTO v_fam_b, v_iid_b, v_tree_b
    FROM public.personen WHERE id = p_behalten;
  SELECT familie_id, identitaet_id, stammbaum_id INTO v_fam_d, v_iid_d, v_tree_d
    FROM public.personen WHERE id = p_dublette;
  IF v_fam_b IS NULL OR v_fam_d IS NULL THEN RAISE EXCEPTION 'Person(en) nicht gefunden.'; END IF;

  -- SCHUTZ: dieselbe reale Person (gleiche identitaet_id) in VERSCHIEDENEN Bäumen ist
  -- ein gewollter Spiegel (1 Karte je Baum), KEIN Duplikat. Mergen würde eine Karte
  -- entfernen -> Person verschwindet aus einem Baum. Verweigern.
  IF v_iid_b IS NOT NULL AND v_iid_b = v_iid_d AND v_tree_b IS DISTINCT FROM v_tree_d THEN
    RAISE EXCEPTION 'merge_zwillinge';
  END IF;

  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_fam_b) AND public.kann_familie_bearbeiten(v_fam_d)))
    THEN RAISE EXCEPTION 'Keine Berechtigung (Admin/Owner beider Familien nötig).'; END IF;
  RETURN public._person_merge_core(p_behalten, p_dublette, p_aufloesung);
END $$;
GRANT EXECUTE ON FUNCTION public.person_merge_aufgeloest(uuid, uuid, jsonb) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'Zwillings-Schutz aktiv: dubletten_scan schließt verknüpfte Zwillinge aus; person_merge_aufgeloest verweigert Zwillings-Merge über Bäume.' AS status;
