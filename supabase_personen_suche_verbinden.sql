-- =====================================================
-- PERSONEN-SUCHE + SICHERE VERKNÜPFUNG (Blutlinie / bestehende Personen verbinden)
-- Ausführen in: Supabase -> SQL Editor. Idempotent (mehrfach ausführbar).
--
-- Hintergrund (Feature „Bestehende Person verknüpfen" am ＋-Button):
--   * personen_suche(...)  -> Live-Suche über AKTUELLEN + alle VERBUND-sichtbaren
--     Bäume (Vorname/Nachname als Präfix, Geburtsdatum als Teilstring), mit Kontext
--     (Baum, Geburts-/Sterbedatum, Eltern, Ehepartner) für die Ergebnisliste.
--     Datenschutz: NUR sichtbare Familien (sieht_familie) bzw. Super-Admin.
--   * _ist_vorfahre(node, kandidat) -> Zyklus-Helfer (rekursiv über elternteil).
--   * _vkn_pruefe_beziehung(...)    -> verhindert Selbstbezug, Doppelkanten und
--     zyklische Eltern-Kind-Beziehungen (Person darf nicht eigener Vorfahre werden).
--   * _vkn_ausfuehren / verknuepfung_anfragen werden um diese Prüfung ERWEITERT
--     (neu erstellt, Verhalten sonst unverändert: eigene/Verbund-Familie = sofort,
--     fremde Familie = Genehmigungs-Antrag über Obavještenja; Super-Admin = sofort).
--
-- Voraussetzung: supabase_merge_gui.sql (merge_norm), supabase_verbund.sql
--   (sieht_familie, kann_familie_bearbeiten, ist_super_admin),
--   supabase_verknuepfung_anfragen.sql (Tabelle verknuepfungs_anfragen, _person_merge_core).
-- =====================================================


-- ---------- 0) Such-Indizes (Präfix-Suche über normalisierte Namen) ----------
-- merge_norm ist IMMUTABLE -> Ausdrucks-Index möglich. text_pattern_ops erlaubt
-- LIKE 'praefix%' unabhängig von der DB-Collation.
CREATE INDEX IF NOT EXISTS idx_personen_mn_vorname
  ON public.personen (public.merge_norm(vorname) text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_personen_mn_nachname
  ON public.personen (public.merge_norm(nachname) text_pattern_ops);


-- ---------- 1) LIVE-SUCHE über sichtbare (Verbund-)Bäume ----------
CREATE OR REPLACE FUNCTION public.personen_suche(
  p_vorname text DEFAULT NULL, p_nachname text DEFAULT NULL, p_geburt text DEFAULT NULL,
  p_limit int DEFAULT 30, p_offset int DEFAULT 0)
RETURNS TABLE(
  id uuid, name text, given text, surname text,
  birth_date text, death_date text,
  baum text, baum_id uuid, familie_id uuid, identitaet_id uuid,
  eltern text, partner text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH n AS (
    SELECT nullif(public.merge_norm(p_vorname),'')  AS vn,
           nullif(public.merge_norm(p_nachname),'') AS nn,
           nullif(trim(coalesce(p_geburt,'')),'')   AS bd
  )
  SELECT pe.id,
    trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS name,
    pe.vorname AS given, pe.nachname AS surname,
    nullif(trim(coalesce(pe.stammbaum_daten->>'birth_date','')),'') AS birth_date,
    nullif(trim(coalesce(pe.stammbaum_daten->>'death_date','')),'') AS death_date,
    s.name AS baum, pe.stammbaum_id AS baum_id, pe.familie_id, pe.identitaet_id,
    (SELECT string_agg(DISTINCT trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')), ', ')
       FROM public.beziehungen b JOIN public.personen po ON po.id = b.person_a
       WHERE b.typ='elternteil' AND b.person_b = pe.id) AS eltern,
    (SELECT string_agg(DISTINCT trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')), ', ')
       FROM public.beziehungen b
       JOIN public.personen po ON po.id = CASE WHEN b.person_a = pe.id THEN b.person_b ELSE b.person_a END
       WHERE b.typ='ehepartner' AND (b.person_a = pe.id OR b.person_b = pe.id)) AS partner
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  CROSS JOIN n
  WHERE (public.ist_super_admin() OR public.sieht_familie(pe.familie_id))
    AND (n.vn IS NOT NULL OR n.nn IS NOT NULL OR n.bd IS NOT NULL)   -- mind. ein Kriterium
    AND (n.vn IS NULL OR public.merge_norm(pe.vorname)  LIKE n.vn || '%')
    AND (n.nn IS NULL OR public.merge_norm(pe.nachname) LIKE n.nn || '%')
    AND (n.bd IS NULL OR coalesce(pe.stammbaum_daten->>'birth_date','') ILIKE '%'||n.bd||'%')
  ORDER BY pe.nachname, pe.vorname
  LIMIT greatest(1, least(coalesce(p_limit,30), 100))
  OFFSET greatest(0, coalesce(p_offset,0));
$$;
GRANT EXECUTE ON FUNCTION public.personen_suche(text, text, text, int, int) TO authenticated;


-- ---------- 2) ZYKLUS-HELFER: ist p_candidate ein Vorfahre von p_node? ----------
CREATE OR REPLACE FUNCTION public._ist_vorfahre(p_node uuid, p_candidate uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH RECURSIVE up(id) AS (
    SELECT p_node
    UNION
    SELECT b.person_a FROM public.beziehungen b JOIN up ON b.person_b = up.id
     WHERE b.typ = 'elternteil'
  )
  SELECT EXISTS (SELECT 1 FROM up WHERE id = p_candidate AND id <> p_node);
$$;


-- ---------- 3) PRÜFUNG vor dem Verknüpfen (Selbstbezug / Doppelkante / Zyklus) ----------
-- Wirft bei Verletzung: vkn_selbst | vkn_kante_existiert | vkn_zyklus.
-- IDEMPOTENT pro Kante: 'vkn_kante_existiert' wird NUR geworfen, wenn KEINE der zu
-- erzeugenden Kanten neu wäre. Existiert z. B. der zweite Elternteil bereits als Kind-Kante,
-- die erste (gewünschte) aber NICHT, wird NICHT abgebrochen — die fehlende Kante wird ergänzt.
-- (Hintergrund: "Kind verknüpfen" wählt bei genau einem Ehepartner diesen automatisch als
-- zweiten Elternteil; ist dieser bereits Elternteil des Kindes, darf das den Vorgang nicht
-- blockieren, sonst lässt sich der noch fehlende Elternteil nie nachtragen.)
CREATE OR REPLACE FUNCTION public._vkn_pruefe_beziehung(
  p_kontext uuid, p_ziel uuid, p_typ text, p_zweiter uuid)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_parent uuid; v_child uuid;
  v_primaer_neu  boolean;
  v_zweiter_aktiv boolean := false;   -- gültiger zweiter Elternteil im Spiel?
  v_zweiter_neu   boolean := false;   -- ...und seine Kante wäre neu?
BEGIN
  IF p_kontext IS NULL OR p_ziel IS NULL THEN RETURN; END IF;
  IF p_kontext = p_ziel THEN RAISE EXCEPTION 'vkn_selbst'; END IF;

  IF p_typ = 'partner' THEN
    IF EXISTS (SELECT 1 FROM public.beziehungen b WHERE b.typ='ehepartner'
                AND ((b.person_a=p_kontext AND b.person_b=p_ziel)
                  OR (b.person_a=p_ziel    AND b.person_b=p_kontext)))
      THEN RAISE EXCEPTION 'vkn_kante_existiert'; END IF;
    RETURN;
  ELSIF p_typ = 'elternteil' THEN
    v_parent := p_ziel;    v_child := p_kontext;   -- ziel = Elternteil von kontext
  ELSIF p_typ = 'kind' THEN
    v_parent := p_kontext; v_child := p_ziel;      -- kontext = Elternteil von ziel
  ELSE
    RETURN;   -- unbekannter Typ -> keine Spezialprüfung
  END IF;

  -- Eltern-Kind: Selbstbezug + Zyklus bleiben harte Fehler.
  IF v_parent = v_child THEN RAISE EXCEPTION 'vkn_selbst'; END IF;
  -- Künftiger Elternteil darf kein Nachkomme des Kindes sein (sonst Kreis).
  IF public._ist_vorfahre(v_parent, v_child) THEN RAISE EXCEPTION 'vkn_zyklus'; END IF;
  v_primaer_neu := NOT EXISTS (SELECT 1 FROM public.beziehungen b
    WHERE b.typ='elternteil' AND b.person_a=v_parent AND b.person_b=v_child);

  -- Zweiter Elternteil (nur bei typ='kind') ebenfalls prüfen
  IF p_typ='kind' AND p_zweiter IS NOT NULL AND p_zweiter <> v_parent THEN
    IF p_zweiter = v_child THEN RAISE EXCEPTION 'vkn_selbst'; END IF;
    IF public._ist_vorfahre(p_zweiter, v_child) THEN RAISE EXCEPTION 'vkn_zyklus'; END IF;
    v_zweiter_aktiv := true;
    v_zweiter_neu := NOT EXISTS (SELECT 1 FROM public.beziehungen b
      WHERE b.typ='elternteil' AND b.person_a=p_zweiter AND b.person_b=v_child);
  END IF;

  -- Doppelkante NUR, wenn nichts Neues anzulegen ist (weder primär noch zweiter Elternteil).
  IF NOT v_primaer_neu AND NOT (v_zweiter_aktiv AND v_zweiter_neu) THEN
    RAISE EXCEPTION 'vkn_kante_existiert';
  END IF;
END $$;


-- ---------- 4) _vkn_ausfuehren NEU: wie gehabt, aber mit Schutzprüfung ----------
CREATE OR REPLACE FUNCTION public._vkn_ausfuehren(
  p_modus text, p_kontext uuid, p_ziel uuid, p_typ text, p_zweiter uuid,
  p_quelle_fam uuid, p_ziel_fam uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_vq uuid; v_vz uuid;
BEGIN
  IF p_modus = 'merge' THEN
    PERFORM public._person_merge_core(p_ziel, p_kontext, '{}'::jsonb);
    RETURN;
  END IF;

  -- modus='beziehung': erst prüfen (Selbstbezug/Doppelkante/Zyklus), dann anlegen.
  -- INSERTs sind idempotent (NOT EXISTS): bereits vorhandene Kanten werden übersprungen,
  -- nur die fehlende(n) werden ergänzt (passt zur kanten-weisen Prüfung oben).
  PERFORM public._vkn_pruefe_beziehung(p_kontext, p_ziel, p_typ, p_zweiter);

  IF p_kontext IS NOT NULL AND p_ziel IS NOT NULL THEN
    IF p_typ = 'elternteil' THEN
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
      SELECT p_ziel, p_kontext, 'elternteil', p_quelle_fam
      WHERE NOT EXISTS (SELECT 1 FROM public.beziehungen b
        WHERE b.typ='elternteil' AND b.person_a=p_ziel AND b.person_b=p_kontext);
    ELSIF p_typ = 'partner' THEN
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
      SELECT p_kontext, p_ziel, 'ehepartner', p_quelle_fam
      WHERE NOT EXISTS (SELECT 1 FROM public.beziehungen b WHERE b.typ='ehepartner'
        AND ((b.person_a=p_kontext AND b.person_b=p_ziel)
          OR (b.person_a=p_ziel    AND b.person_b=p_kontext)));
    ELSIF p_typ = 'kind' THEN
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
      SELECT p_kontext, p_ziel, 'elternteil', p_quelle_fam
      WHERE NOT EXISTS (SELECT 1 FROM public.beziehungen b
        WHERE b.typ='elternteil' AND b.person_a=p_kontext AND b.person_b=p_ziel);
      IF p_zweiter IS NOT NULL AND p_zweiter <> p_kontext THEN
        INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
        SELECT p_zweiter, p_ziel, 'elternteil', p_quelle_fam
        WHERE NOT EXISTS (SELECT 1 FROM public.beziehungen b
          WHERE b.typ='elternteil' AND b.person_a=p_zweiter AND b.person_b=p_ziel);
      END IF;
    END IF;
  END IF;

  -- Verbünde zusammenlegen (Navigation zwischen den Bäumen; Isolation bleibt sonst gewahrt)
  IF p_quelle_fam IS NOT NULL AND p_ziel_fam IS NOT NULL AND p_quelle_fam <> p_ziel_fam THEN
    SELECT verbund_id INTO v_vq FROM public.familien WHERE id = p_quelle_fam;
    SELECT verbund_id INTO v_vz FROM public.familien WHERE id = p_ziel_fam;
    IF v_vq IS NOT NULL AND v_vz IS NOT NULL AND v_vq <> v_vz THEN
      UPDATE public.familien SET verbund_id = v_vz WHERE verbund_id = v_vq;
    END IF;
  END IF;
END $$;


-- ---------- 5) verknuepfung_anfragen NEU: Schutzprüfung vorab ----------
-- Rückgabe: 'sofort' (eigene/Verbund-Familie bzw. Super-Admin) | 'angefragt' (fremde Familie).
CREATE OR REPLACE FUNCTION public.verknuepfung_anfragen(
  p_modus text, p_kontext uuid, p_ziel uuid, p_typ text DEFAULT NULL,
  p_zweiter uuid DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_qf uuid; v_zf uuid; v_qb uuid;
BEGIN
  IF p_ziel IS NULL THEN RAISE EXCEPTION 'Ziel-Person fehlt.'; END IF;
  SELECT familie_id, stammbaum_id INTO v_qf, v_qb FROM public.personen WHERE id = p_kontext;
  SELECT familie_id INTO v_zf FROM public.personen WHERE id = p_ziel;
  IF v_zf IS NULL THEN RAISE EXCEPTION 'Ziel-Person nicht gefunden.'; END IF;
  IF v_qf IS NOT NULL AND NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_qf)) THEN
    RAISE EXCEPTION 'Keine Berechtigung für die Quell-Familie.';
  END IF;

  -- Schutz: Selbstbezug / Doppelkante / Zyklus (nur Beziehungs-Modus)
  IF coalesce(p_modus,'beziehung') = 'beziehung' THEN
    PERFORM public._vkn_pruefe_beziehung(p_kontext, p_ziel, p_typ, p_zweiter);
  END IF;

  IF public.ist_super_admin() THEN
    PERFORM public._vkn_ausfuehren(coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter, v_qf, v_zf);
    INSERT INTO public.verknuepfungs_anfragen(
      modus, kontext_person, ziel_person, bez_typ, zweiter_elternteil,
      quelle_familie, ziel_familie, quelle_baum, status, entschieden_von, entschieden_am)
    VALUES (coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter,
      v_qf, v_zf, v_qb, 'genehmigt', auth.uid(), now());
    RETURN 'sofort';
  END IF;

  -- Eigene/Verbund-Familie (Ziel sichtbar & bearbeitbar): sofort verknüpfen.
  IF v_zf IS NOT NULL AND public.kann_familie_bearbeiten(v_zf) THEN
    PERFORM public._vkn_ausfuehren(coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter, v_qf, v_zf);
    INSERT INTO public.verknuepfungs_anfragen(
      modus, kontext_person, ziel_person, bez_typ, zweiter_elternteil,
      quelle_familie, ziel_familie, quelle_baum, status, entschieden_von, entschieden_am)
    VALUES (coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter,
      v_qf, v_zf, v_qb, 'genehmigt', auth.uid(), now());
    RETURN 'sofort';
  END IF;

  -- sonst: Antrag erstellen (Genehmigung durch Ziel-Familie-Admin über Obavještenja)
  INSERT INTO public.verknuepfungs_anfragen(
    modus, kontext_person, ziel_person, bez_typ, zweiter_elternteil,
    quelle_familie, ziel_familie, quelle_baum)
  VALUES (coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter, v_qf, v_zf, v_qb);
  RETURN 'angefragt';
END $$;
GRANT EXECUTE ON FUNCTION public.verknuepfung_anfragen(text, uuid, uuid, text, uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'Personen-Suche + sichere Verknüpfung angelegt: personen_suche, _ist_vorfahre, _vkn_pruefe_beziehung; _vkn_ausfuehren/verknuepfung_anfragen gehärtet (+ Indizes)' AS status;
