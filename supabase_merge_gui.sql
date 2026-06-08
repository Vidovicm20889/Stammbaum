-- =====================================================
-- BÄUME VERBINDEN & PERSONEN-MERGE mit DUBLETTENPRÜFUNG (Super-Admin GUI)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Voraussetzung: supabase_person_merge.sql (person_zusammenfuehren),
--   supabase_verbund.sql (familien_verbinden, kann_familie_bearbeiten, ist_super_admin).
--
-- Liefert die Bausteine für das Frontend-GUI:
--   1) merge_norm(text)                      -> Namens-Normalisierung (Diakritika)
--   2) merge_overlap(text[],text[])          -> Anzahl gemeinsamer Namen
--   3) merge_nachbarn(person, rolle)         -> normalisierte Nachbarnamen (Eltern/Kinder/Partner)
--   4) dubletten_scan(baum_a, baum_b, min)   -> Kandidatenpaare mit Score + Gründen
--   5) personen_feld_diff(a, b)              -> Feldvergleich (nur_a/nur_b/gleich/konflikt)
--   6) merge_log (Tabelle)                   -> Snapshot der gelöschten Karte (Backup)
--   7) person_merge_aufgeloest(behalten,dublette,aufloesung) -> Merge MIT Konfliktauflösung
--   8) merge_rueckgaengig(log_id)            -> Wiederherstellung (best-effort, Super-Admin)
-- =====================================================


-- ---------- 1) Namens-Normalisierung (lower + Diakritika ć č š ž đ entfernen) ----------
CREATE OR REPLACE FUNCTION public.merge_norm(p_txt text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT translate(lower(trim(coalesce(p_txt,''))), 'ćčšžđ', 'ccszd');
$$;


-- ---------- 1b) Zwei jsonb zusammenführen: nicht-leere Werte der PRIMÄR-Karte gewinnen, ----------
-- leere/fehlende werden aus der SEKUNDÄR-Karte ergänzt (Fall A der Vollständigkeitsprüfung).
-- Nicht-String-Werte (z. B. deceased=true) werden immer von der Primärkarte übernommen.
CREATE OR REPLACE FUNCTION public.merge_fill(p_primary jsonb, p_secondary jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_secondary,'{}'::jsonb) || (
    SELECT coalesce(jsonb_object_agg(k, v), '{}'::jsonb)
    FROM jsonb_each(coalesce(p_primary,'{}'::jsonb)) AS e(k, v)
    WHERE v IS NOT NULL
      AND v <> 'null'::jsonb
      AND NOT (jsonb_typeof(v) = 'string' AND trim(v #>> '{}') = '')
  );
$$;


-- ---------- 2) Überschneidung zweier Namens-Arrays (gemeinsame, nicht-leere) ----------
CREATE OR REPLACE FUNCTION public.merge_overlap(a text[], b text[])
RETURNS int LANGUAGE sql IMMUTABLE AS $$
  SELECT count(DISTINCT x)::int
  FROM unnest(coalesce(a,'{}')) x
  WHERE x <> '' AND x = ANY(coalesce(b,'{}'));
$$;


-- ---------- 3) Normalisierte Nachbarnamen einer Person nach Rolle ----------
-- p_rolle: 'eltern' | 'kinder' | 'partner'. Vergleicht über Bäume hinweg per NAME,
-- nicht per id (deshalb auch bei abweichenden Stammdaten Blutlinien-Match möglich).
CREATE OR REPLACE FUNCTION public.merge_nachbarn(p_person uuid, p_rolle text)
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(
    array_agg(DISTINCT public.merge_norm(trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')))),
    '{}'::text[])
  FROM public.beziehungen b
  JOIN public.personen po ON po.id = CASE
      WHEN p_rolle = 'eltern'  AND b.typ = 'elternteil' AND b.person_b = p_person THEN b.person_a
      WHEN p_rolle = 'kinder'  AND b.typ = 'elternteil' AND b.person_a = p_person THEN b.person_b
      WHEN p_rolle = 'partner' AND b.typ = 'ehepartner' AND b.person_a = p_person THEN b.person_b
      WHEN p_rolle = 'partner' AND b.typ = 'ehepartner' AND b.person_b = p_person THEN b.person_a
      ELSE NULL END;
$$;
GRANT EXECUTE ON FUNCTION public.merge_nachbarn(uuid, text) TO authenticated;


-- ---------- 4) DUBLETTEN-SCAN über zwei Stammbäume ----------
-- Vergleicht jede Person aus Baum A gegen jede aus Baum B. Score:
--   Vorname gleich +2, Nachname gleich +2, Geburtsdatum (beide gesetzt) gleich +3,
--   je gemeinsamem Elternteil/Kind/Ehepartner (Name) +2.
-- gruende = Code-Liste (Frontend übersetzt): vorname|nachname|geburtsdatum|eltern|kinder|partner
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
    SELECT p.id,
           public.merge_norm(p.vorname) AS vn, public.merge_norm(p.nachname) AS nn,
           nullif(trim(coalesce(p.stammbaum_daten->>'birth_date','')),'') AS bd,
           trim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')) AS anzeige,
           public.merge_nachbarn(p.id,'eltern')  AS eltern,
           public.merge_nachbarn(p.id,'kinder')  AS kinder,
           public.merge_nachbarn(p.id,'partner') AS partner
    FROM public.personen p WHERE p.stammbaum_id = p_baum_a
  ),
  b AS (
    SELECT p.id,
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
      -- Identitäts-Vorbedingung: gleicher Vorname ODER (gleiches Geburtsdatum UND gleicher Nachname).
      -- Verhindert falsch-positive Struktur-Treffer zwischen Ehepartnern/Geschwistern
      -- (die teilen Kinder/Eltern, sind aber verschiedene Personen).
      ( (a.vn <> '' AND a.vn = b.vn)
        OR (a.bd IS NOT NULL AND a.bd = b.bd AND a.nn <> '' AND a.nn = b.nn) ) AS ident
    FROM a CROSS JOIN b
  )
  SELECT q.id_a, q.id_b, q.name_a, q.name_b, q.score, q.gruende
  FROM paare q
  WHERE q.ident AND q.score >= p_min_score
  ORDER BY q.score DESC, q.name_a;
END $$;
GRANT EXECUTE ON FUNCTION public.dubletten_scan(uuid, uuid, int) TO authenticated;


-- ---------- 5) FELD-DIFF zweier Personen (für Konfliktauflösung) ----------
-- status: nur_a (nur A gefüllt) | nur_b | gleich | konflikt. Leere-in-beiden werden weggelassen.
CREATE OR REPLACE FUNCTION public.personen_feld_diff(p_a uuid, p_b uuid)
RETURNS TABLE(feld text, wert_a text, wert_b text, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_sa jsonb; v_sb jsonb; v_fa uuid; v_fb uuid;
BEGIN
  SELECT stammbaum_daten, familie_id INTO v_sa, v_fa FROM public.personen WHERE id = p_a;
  SELECT stammbaum_daten, familie_id INTO v_sb, v_fb FROM public.personen WHERE id = p_b;
  IF v_fa IS NULL OR v_fb IS NULL THEN RAISE EXCEPTION 'Person(en) nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_fa) AND public.kann_familie_bearbeiten(v_fb)))
    THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  v_sa := coalesce(v_sa,'{}'::jsonb); v_sb := coalesce(v_sb,'{}'::jsonb);

  RETURN QUERY
  WITH felder AS (
    SELECT unnest(ARRAY[
      'given','surname','sex','titel','namenszusatz','ehename',
      'birth_date','birth_place','geburtsland','getauft','death_date',
      'hochzeitsort','hochzeit_standesamt','hochzeit_kirchlich','beziehung',
      'email','telefon','facebook','instagram',
      'wohnort_land','wohnort_stadt','adresse','beruf','ausbildung','beschreibung'
    ]) AS f
  ),
  d AS (
    SELECT f,
      nullif(trim(coalesce(v_sa->>f,'')),'') AS wa,
      nullif(trim(coalesce(v_sb->>f,'')),'') AS wb
    FROM felder
  )
  SELECT d.f, d.wa, d.wb,
    CASE
      WHEN d.wa IS NOT NULL AND d.wb IS NULL THEN 'nur_a'
      WHEN d.wb IS NOT NULL AND d.wa IS NULL THEN 'nur_b'
      WHEN d.wa = d.wb THEN 'gleich'
      ELSE 'konflikt'
    END
  FROM d
  WHERE d.wa IS NOT NULL OR d.wb IS NOT NULL;
END $$;
GRANT EXECUTE ON FUNCTION public.personen_feld_diff(uuid, uuid) TO authenticated;


-- ---------- 6) MERGE-LOG: Backup der gelöschten Karte (Pflicht: keine Löschung ohne Sicherung) ----------
CREATE TABLE IF NOT EXISTS public.merge_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  erstellt_am     timestamptz NOT NULL DEFAULT now(),
  ausgefuehrt_von uuid DEFAULT auth.uid(),
  behalten_id     uuid,
  dublette_id     uuid,
  dublette_person jsonb,   -- vollständige gelöschte personen-Zeile
  dublette_kanten jsonb,   -- alle beziehungen-Zeilen der Dublette (vor dem Umhängen)
  aufloesung      jsonb,   -- die vom Super-Admin gewählte Konfliktauflösung
  rueckgaengig    boolean NOT NULL DEFAULT false
);
ALTER TABLE public.merge_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "merge_log_select" ON public.merge_log;
CREATE POLICY "merge_log_select" ON public.merge_log FOR SELECT USING ( public.ist_super_admin() );


-- ---------- 7) MERGE MIT KONFLIKTAUFLÖSUNG ----------
-- Wie person_zusammenfuehren, aber:
--   * füllt leere Felder von 'behalten' aus 'dublette' (behalten gewinnt),
--   * legt dann p_aufloesung (gelöste Konfliktwerte/manuell) drüber,
--   * sichert die Dublette in merge_log VOR dem Löschen,
--   * legt beide Familien in denselben Verbund (Navigation zwischen Bäumen bleibt).
-- Rechte: super_admin ODER Admin/Owner BEIDER Familien.
-- 7a) KERN-MERGE ohne Rechteprüfung (intern). Aufrufer MUSS die Rechte vorher prüfen
--     (öffentlich nur über person_merge_aufgeloest bzw. verknuepfung_entscheiden erreichbar).
CREATE OR REPLACE FUNCTION public._person_merge_core(
  p_behalten uuid, p_dublette uuid, p_aufloesung jsonb DEFAULT '{}'::jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam_b uuid; v_fam_d uuid; v_user_b uuid; v_user_d uuid;
  v_sd_b jsonb; v_sd_d jsonb; v_merged jsonb;
  v_pers jsonb; v_kanten jsonb; v_vb_b uuid; v_vb_d uuid;
  v_tree_d uuid; v_rest_d int;
BEGIN
  IF p_behalten IS NULL OR p_dublette IS NULL OR p_behalten = p_dublette THEN RETURN p_behalten; END IF;
  SELECT familie_id, user_id, stammbaum_daten INTO v_fam_b, v_user_b, v_sd_b FROM public.personen WHERE id = p_behalten;
  SELECT familie_id, user_id, stammbaum_daten, stammbaum_id
    INTO v_fam_d, v_user_d, v_sd_d, v_tree_d FROM public.personen WHERE id = p_dublette;
  IF v_fam_b IS NULL OR v_fam_d IS NULL THEN RAISE EXCEPTION 'Person(en) nicht gefunden.'; END IF;
  p_aufloesung := coalesce(p_aufloesung, '{}'::jsonb);

  -- 0) BACKUP der Dublette (Person + ihre Kanten) vor jeder Änderung
  SELECT to_jsonb(p) INTO v_pers FROM public.personen p WHERE p.id = p_dublette;
  SELECT coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb) INTO v_kanten
    FROM public.beziehungen b WHERE b.person_a = p_dublette OR b.person_b = p_dublette;
  INSERT INTO public.merge_log(behalten_id, dublette_id, dublette_person, dublette_kanten, aufloesung)
    VALUES (p_behalten, p_dublette, v_pers, v_kanten, p_aufloesung);

  -- 1) Beziehungen der Dublette auf die bleibende Person umhängen
  UPDATE public.beziehungen SET person_a = p_behalten WHERE person_a = p_dublette;
  UPDATE public.beziehungen SET person_b = p_behalten WHERE person_b = p_dublette;
  DELETE FROM public.beziehungen WHERE person_a = person_b;                       -- Self-Edges
  DELETE FROM public.beziehungen b USING public.beziehungen b2                    -- exakte Duplikate
   WHERE b.ctid > b2.ctid AND b.person_a = b2.person_a AND b.person_b = b2.person_b AND b.typ = b2.typ;
  DELETE FROM public.beziehungen b USING public.beziehungen b2                    -- gespiegelte Ehepartner
   WHERE b.ctid > b2.ctid AND b.typ = 'ehepartner' AND b2.typ = 'ehepartner'
     AND b.person_a = b2.person_b AND b.person_b = b2.person_a;

  -- 2) Event-Teilnehmer umhängen (falls Tabelle existiert)
  BEGIN
    UPDATE public.event_teilnehmer SET person_id = p_behalten WHERE person_id = p_dublette;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  -- 3) Konto-Verknüpfung übernehmen, falls nur die Dublette ein Konto hatte
  IF v_user_d IS NOT NULL AND v_user_b IS NULL THEN
    UPDATE public.personen SET user_id = v_user_d WHERE id = p_behalten;
  END IF;

  -- 4) Daten zusammenführen: nicht-leere Werte von 'behalten' gewinnen, leere aus 'dublette'
  --    ergänzen (merge_fill), dann Konfliktauflösung des Super-Admins drüber.
  v_merged := public.merge_fill(v_sd_b, v_sd_d) || p_aufloesung;
  v_merged := jsonb_set(v_merged, '{name}',
                to_jsonb(trim(coalesce(v_merged->>'given','')||' '||coalesce(v_merged->>'surname',''))));
  UPDATE public.personen
     SET stammbaum_daten = v_merged,
         vorname = coalesce(v_merged->>'given',''),
         nachname = coalesce(v_merged->>'surname','')
   WHERE id = p_behalten;

  -- 5) redundante Kopie löschen
  DELETE FROM public.personen WHERE id = p_dublette;

  -- 5b) Wird der Quellbaum der Dublette dadurch leer (letzte Person gemergt),
  --     auto-löschen (kontoschonend, mit Audit + Storage-Queue). Nur wenn der
  --     Quellbaum NICHT der Behalten-Baum ist. Siehe supabase_stammbaum_auto_leer.sql.
  IF v_tree_d IS NOT NULL THEN
    SELECT count(*) INTO v_rest_d FROM public.personen WHERE stammbaum_id = v_tree_d;
    IF coalesce(v_rest_d,0) = 0 THEN
      PERFORM public._baum_auto_loeschen(v_tree_d, 'merge_leer');
    END IF;
  END IF;

  -- 6) beide Familien in denselben Verbund (Navigation zwischen Bäumen erhalten)
  IF v_fam_b <> v_fam_d THEN
    SELECT verbund_id INTO v_vb_b FROM public.familien WHERE id = v_fam_b;
    SELECT verbund_id INTO v_vb_d FROM public.familien WHERE id = v_fam_d;
    IF v_vb_b IS NOT NULL AND v_vb_d IS NOT NULL AND v_vb_b <> v_vb_d THEN
      UPDATE public.familien SET verbund_id = v_vb_b WHERE verbund_id = v_vb_d;
    END IF;
  END IF;

  RETURN p_behalten;
END $$;

-- 7b) ÖFFENTLICHE Variante MIT Rechteprüfung (Wrapper um den Kern).
CREATE OR REPLACE FUNCTION public.person_merge_aufgeloest(
  p_behalten uuid, p_dublette uuid, p_aufloesung jsonb DEFAULT '{}'::jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam_b uuid; v_fam_d uuid;
BEGIN
  IF p_behalten IS NULL OR p_dublette IS NULL OR p_behalten = p_dublette THEN RETURN p_behalten; END IF;
  SELECT familie_id INTO v_fam_b FROM public.personen WHERE id = p_behalten;
  SELECT familie_id INTO v_fam_d FROM public.personen WHERE id = p_dublette;
  IF v_fam_b IS NULL OR v_fam_d IS NULL THEN RAISE EXCEPTION 'Person(en) nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_fam_b) AND public.kann_familie_bearbeiten(v_fam_d)))
    THEN RAISE EXCEPTION 'Keine Berechtigung (Admin/Owner beider Familien nötig).'; END IF;
  RETURN public._person_merge_core(p_behalten, p_dublette, p_aufloesung);
END $$;
GRANT EXECUTE ON FUNCTION public.person_merge_aufgeloest(uuid, uuid, jsonb) TO authenticated;

-- person_zusammenfuehren als konfliktfreie Kurzform auf das neue RPC umlegen
CREATE OR REPLACE FUNCTION public.person_zusammenfuehren(p_behalten uuid, p_dublette uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.person_merge_aufgeloest(p_behalten, p_dublette, '{}'::jsonb);
END $$;
GRANT EXECUTE ON FUNCTION public.person_zusammenfuehren(uuid, uuid) TO authenticated;


-- ---------- 8) WIEDERHERSTELLUNG (best-effort, Super-Admin) ----------
-- Stellt die gelöschte Dublette-Karte + ihre ursprünglichen Beziehungen wieder her.
-- Hinweis: Die bleibende Karte behält die gemergten Felder (kein vollständiger Roll-back);
-- dient als Sicherheitsnetz. Die id der Kanten wird neu vergeben (keine Konflikte).
CREATE OR REPLACE FUNCTION public.merge_rueckgaengig(p_log_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_pers jsonb; v_kanten jsonb; v_did uuid; v_rg boolean;
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'Nur Super-Admin.'; END IF;
  SELECT dublette_person, dublette_kanten, dublette_id, rueckgaengig
    INTO v_pers, v_kanten, v_did, v_rg FROM public.merge_log WHERE id = p_log_id;
  IF v_pers IS NULL THEN RAISE EXCEPTION 'Log-Eintrag nicht gefunden.'; END IF;
  IF v_rg THEN RAISE EXCEPTION 'Bereits rückgängig gemacht.'; END IF;

  -- Person zurückspielen (mit Original-id), falls nicht schon vorhanden
  IF NOT EXISTS (SELECT 1 FROM public.personen WHERE id = v_did) THEN
    INSERT INTO public.personen SELECT * FROM jsonb_populate_record(NULL::public.personen, v_pers);
  END IF;

  -- Ursprüngliche Kanten zurückspielen (Spalte 'id' weglassen -> neue id), nur wenn beide Enden existieren
  INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
  SELECT (e->>'familie_id')::uuid, (e->>'person_a')::uuid, (e->>'person_b')::uuid, e->>'typ'
  FROM jsonb_array_elements(coalesce(v_kanten,'[]'::jsonb)) e
  WHERE EXISTS (SELECT 1 FROM public.personen WHERE id = (e->>'person_a')::uuid)
    AND EXISTS (SELECT 1 FROM public.personen WHERE id = (e->>'person_b')::uuid);

  UPDATE public.merge_log SET rueckgaengig = true WHERE id = p_log_id;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.merge_rueckgaengig(uuid) TO authenticated;


-- ---------- 9) PERSONEN-KONTEXT (für die Kandidaten-Anzeige im GUI) ----------
-- Liefert je Person: Anzeigename, Baum, Geburtsdatum/-ort, Eltern, Partner, Kinderzahl —
-- damit der Super-Admin sieht, OB zwei Karten wirklich dieselbe Person sind.
CREATE OR REPLACE FUNCTION public.merge_person_info(p_ids uuid[])
RETURNS TABLE(id uuid, name text, baum text, geboren text, geburtsort text,
              eltern text, partner text, kinder int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT pe.id,
    trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS name,
    s.name || coalesce(' (' || nullif(btrim(s.zusatz),'') || ')', '') AS baum,
    nullif(trim(coalesce(pe.stammbaum_daten->>'birth_date','')),'')  AS geboren,
    nullif(trim(coalesce(pe.stammbaum_daten->>'birth_place','')),'') AS geburtsort,
    (SELECT string_agg(DISTINCT trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')), ', ')
       FROM public.beziehungen b JOIN public.personen po ON po.id = b.person_a
       WHERE b.typ = 'elternteil' AND b.person_b = pe.id)  AS eltern,
    (SELECT string_agg(DISTINCT trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')), ', ')
       FROM public.beziehungen b
       JOIN public.personen po ON po.id = CASE WHEN b.person_a = pe.id THEN b.person_b ELSE b.person_a END
       WHERE b.typ = 'ehepartner' AND (b.person_a = pe.id OR b.person_b = pe.id))  AS partner,
    (SELECT count(*)::int FROM public.beziehungen b
       WHERE b.typ = 'elternteil' AND b.person_a = pe.id)  AS kinder
  FROM public.personen pe
  LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  WHERE pe.id = ANY(p_ids)
    AND (public.ist_super_admin() OR public.sieht_familie(pe.familie_id));
$$;
GRANT EXECUTE ON FUNCTION public.merge_person_info(uuid[]) TO authenticated;


-- ---------- 10) STAMMBÄUME ZUSAMMENFÜHREN (Duplikat-Baum auflösen) ----------
-- Verschiebt ALLE Personen aus p_quelle in p_ziel und löscht den (dann leeren) Quell-Baum.
-- Nur wählen, wenn beide Bäume DIESELBE Familie sind (Duplikat, z. B. 'Dujkovic' -> 'Dujković').
-- Gleiche Familie  -> nur stammbaum_id der Personen wird umgehängt (Beziehungen unberührt).
-- Andere Familie   -> zusätzlich familie_id der Personen + ihrer Beziehungen auf die Ziel-Familie,
--                     Verbünde zusammenlegen (Sichtbarkeit bleibt). Nur Super-Admin.
CREATE OR REPLACE FUNCTION public.stammbaeume_zusammenfuehren(p_quelle uuid, p_ziel uuid)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fq uuid; v_fz uuid; v_anz int; v_vq uuid; v_vz uuid;
BEGIN
  IF p_quelle IS NULL OR p_ziel IS NULL OR p_quelle = p_ziel THEN RAISE EXCEPTION 'Ungültige Auswahl.'; END IF;
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'Nur Super-Admin darf Stammbäume zusammenführen.'; END IF;
  SELECT familie_id INTO v_fq FROM public.stammbaeume WHERE id = p_quelle;
  SELECT familie_id INTO v_fz FROM public.stammbaeume WHERE id = p_ziel;
  IF v_fq IS NULL OR v_fz IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;

  -- Personen in den Ziel-Baum (und ggf. die Ziel-Familie) umhängen
  UPDATE public.personen SET stammbaum_id = p_ziel, familie_id = v_fz WHERE stammbaum_id = p_quelle;
  GET DIAGNOSTICS v_anz = ROW_COUNT;

  -- Bei familienübergreifend: Beziehungen der verschobenen Personen auf die Ziel-Familie ziehen
  IF v_fq <> v_fz THEN
    UPDATE public.beziehungen b SET familie_id = v_fz
     WHERE b.familie_id = v_fq
       AND ( EXISTS (SELECT 1 FROM public.personen p WHERE p.id = b.person_a AND p.familie_id = v_fz)
          OR EXISTS (SELECT 1 FROM public.personen p WHERE p.id = b.person_b AND p.familie_id = v_fz) );
    -- Verbünde zusammenlegen (kontenübergreifende Sicht bleibt erhalten)
    SELECT verbund_id INTO v_vq FROM public.familien WHERE id = v_fq;
    SELECT verbund_id INTO v_vz FROM public.familien WHERE id = v_fz;
    IF v_vq IS NOT NULL AND v_vz IS NOT NULL AND v_vq <> v_vz THEN
      UPDATE public.familien SET verbund_id = v_vz WHERE verbund_id = v_vq;
    END IF;
  END IF;

  -- Events des Quell-Baums mitnehmen (falls Tabelle/Spalte existiert)
  BEGIN
    UPDATE public.events SET stammbaum_id = p_ziel WHERE stammbaum_id = p_quelle;
  EXCEPTION WHEN undefined_table THEN NULL; WHEN undefined_column THEN NULL; END;

  -- leeren Quell-Baum löschen — über die auditierte Auto-Löschung
  -- (Events wurden oben auf den Ziel-Baum umgehängt -> keine Storage-Waisen).
  -- Siehe supabase_stammbaum_auto_leer.sql.
  PERFORM public._baum_auto_loeschen(p_quelle, 'merge_zusammenfuehrung');
  RETURN v_anz;
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaeume_zusammenfuehren(uuid, uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'merge-gui RPCs angelegt: dubletten_scan (mit Identitäts-Vorbedingung), personen_feld_diff, person_merge_aufgeloest, merge_person_info, stammbaeume_zusammenfuehren, merge_rueckgaengig (+ merge_log)' AS status;
