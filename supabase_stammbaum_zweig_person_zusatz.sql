-- =====================================================
-- ZWEIGBAUM AUS PERSON — + Zusatz (laufende Nummer) für gleichnamige Bäume
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- ERWEITERT/ERSETZT supabase_stammbaum_zweig_person_force.sql (Phase 1: Auto-Nachnamenbaum).
--
-- NEU: Parameter p_zusatz. Wird beim „separaten" Anlegen genutzt, damit ein zweiter Baum
-- desselben Nachnamens als „Xerri (2)" unterscheidbar ist — Zusatz landet im FELD
-- stammbaeume.zusatz (CLAUDE.md-Regel: Unterscheidung ins zusatz-Feld, NICHT in den Namen).
-- Rückwärtskompatibel: bestehende 3-argige Aufrufe (p_wurzel, p_name, p_force) funktionieren
-- weiter (p_zusatz default NULL). Ansonsten unverändert zu ...zweig_person_force.sql.
--
-- ROLLBACK: einfach supabase_stammbaum_zweig_person_force.sql erneut ausführen -> stellt die
-- 3-argige Fassung wieder her (die 4-argige Variante hier wird dann nicht mehr getroffen).
-- =====================================================

-- Mehrdeutige Überladungen vermeiden: beide älteren Signaturen entfernen.
DROP FUNCTION IF EXISTS public.stammbaum_zweig_aus_person(uuid, text);
DROP FUNCTION IF EXISTS public.stammbaum_zweig_aus_person(uuid, text, boolean);

CREATE OR REPLACE FUNCTION public.stammbaum_zweig_aus_person(
  p_wurzel uuid, p_name text, p_force boolean DEFAULT false, p_zusatz text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_fam     uuid;
  v_src     uuid;       -- Quell-Stammbaum (Baum der Wurzelperson)
  v_verbund uuid;
  v_name    text;
  v_zusatz  text;
  v_owner   uuid;
  v_new_fam uuid;       -- neue, eigene Familie für diese Linie (gleicher Verbund)
  v_tree    uuid;
  v_rec     record;
  v_mir     uuid;
  v_n       int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'nicht_angemeldet'; END IF;
  IF p_wurzel IS NULL THEN RAISE EXCEPTION 'zweig_ungueltige_auswahl'; END IF;

  -- Wurzelperson: Familie + Quellbaum + Nachname
  SELECT pe.familie_id, pe.stammbaum_id, pe.nachname
    INTO v_fam, v_src, v_name
    FROM public.personen pe WHERE pe.id = p_wurzel AND pe.geloescht_am IS NULL;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'zweig_person_fehlt'; END IF;

  -- Rechte: Admin/Owner der Familie (oder Super-Admin)
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'zweig_keine_berechtigung'; END IF;

  v_name   := coalesce(nullif(trim(p_name), ''), nullif(trim(v_name), ''));
  IF v_name IS NULL THEN RAISE EXCEPTION 'zweig_kein_name'; END IF;
  v_zusatz := nullif(trim(coalesce(p_zusatz, '')), '');

  SELECT f.verbund_id INTO v_verbund FROM public.familien f WHERE f.id = v_fam;

  -- Existiert im VERBUND schon ein (aktiver) Baum mit diesem Nachnamen? -> Abbruch,
  -- AUSSER der Aufrufer hat ausdrücklich p_force=true gesetzt (zwei gleichnamige, aber
  -- verschiedene Familien sind zulässig — bewusste Entscheidung des Admins).
  IF NOT p_force AND EXISTS (
    SELECT 1 FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
     WHERE coalesce(s.aktiv, true)
       AND public.merge_norm(s.name) = public.merge_norm(v_name)
       AND ((v_verbund IS NOT NULL AND f.verbund_id = v_verbund) OR f.id = v_fam)
  ) THEN
    RAISE EXCEPTION 'zweig_existiert';
  END IF;

  -- ---- Zu spiegelnde Quell-Personen sammeln (nur im Quellbaum) -------------
  -- Wurzel + ihre Nachkommen (rekursiv über elternteil) + Ehepartner aller Gesammelten.
  CREATE TEMP TABLE _zweigp_src ON COMMIT DROP AS
  WITH RECURSIVE nach(pid) AS (
    SELECT p_wurzel
    UNION
    SELECT b.person_b
      FROM public.beziehungen b
      JOIN nach n  ON b.person_a = n.pid
      JOIN public.personen pe ON pe.id = b.person_b
     WHERE b.typ = 'elternteil' AND b.geloescht_am IS NULL
       AND pe.stammbaum_id = v_src AND pe.geloescht_am IS NULL
  )
  SELECT DISTINCT x.pid
    FROM (
      SELECT pid FROM nach
      UNION ALL
      SELECT CASE WHEN b.person_a IN (SELECT pid FROM nach) THEN b.person_b ELSE b.person_a END
        FROM public.beziehungen b
       WHERE b.typ = 'ehepartner' AND b.geloescht_am IS NULL
         AND (b.person_a IN (SELECT pid FROM nach) OR b.person_b IN (SELECT pid FROM nach))
    ) x
    JOIN public.personen pe ON pe.id = x.pid
   WHERE x.pid IS NOT NULL AND pe.stammbaum_id = v_src AND pe.geloescht_am IS NULL;

  -- Jede gesammelte Karte braucht eine identitaet_id (gemeinsame Identität mit Spiegel)
  UPDATE public.personen
     SET identitaet_id = gen_random_uuid()
   WHERE id IN (SELECT pid FROM _zweigp_src) AND identitaet_id IS NULL;

  -- ---- Neue, EIGENE Familie für diese Linie (gleicher Verbund) -------------
  SELECT m.user_id INTO v_owner
    FROM public.mitgliedschaften m
   WHERE m.familie_id = v_fam AND m.rolle = 'familien_owner' AND m.aktiv
   ORDER BY m.aktiv DESC LIMIT 1;
  v_owner := coalesce(v_owner, v_uid);

  INSERT INTO public.familien (name, verbund_id, land, stadt, gemeinde)
  SELECT v_name, v_verbund, f.land, f.stadt, f.gemeinde
    FROM public.familien f WHERE f.id = v_fam
  RETURNING id INTO v_new_fam;

  INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv, auto)
  VALUES (v_owner, v_new_fam, 'familien_owner', true, false)
  ON CONFLICT (user_id, familie_id)
  DO UPDATE SET rolle = 'familien_owner', aktiv = true, auto = false;

  -- Zusatz (laufende Nummer o. Ä.) landet im zusatz-Feld -> Anzeige „Name (Zusatz)".
  INSERT INTO public.stammbaeume (familie_id, name, zusatz, ersteller_id, owner_id, aktiv)
  VALUES (v_new_fam, v_name, v_zusatz, v_uid, v_owner, true)
  RETURNING id INTO v_tree;

  -- ---- Spiegelkarten anlegen (Biografie übernehmen, identitaet teilen) -----
  CREATE TEMP TABLE _zweigp_map (src uuid, mir uuid) ON COMMIT DROP;
  FOR v_rec IN
    SELECT pe.* FROM public.personen pe JOIN _zweigp_src z ON z.pid = pe.id
  LOOP
    INSERT INTO public.personen
      (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum,
       stammbaum_daten, identitaet_id)
    VALUES
      (v_new_fam, v_tree,
       'I' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(replace(v_rec.id::text,'-',''),1,8),
       v_rec.vorname, v_rec.nachname, NULL,
       v_rec.stammbaum_daten, v_rec.identitaet_id)
    RETURNING id INTO v_mir;
    INSERT INTO _zweigp_map (src, mir) VALUES (v_rec.id, v_mir);
  END LOOP;

  -- ---- Beziehungen zwischen den Spiegelkarten neu aufbauen ----------------
  -- (nur Kanten, deren BEIDE Enden gespiegelt wurden -> keine verwaisten Zeilen)
  INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
  SELECT v_new_fam, ma.mir, mb.mir, b.typ
    FROM public.beziehungen b
    JOIN _zweigp_map ma ON ma.src = b.person_a
    JOIN _zweigp_map mb ON mb.src = b.person_b
   WHERE b.geloescht_am IS NULL;

  -- Wurzelperson des neuen Baums setzen (die Person mit dem abweichenden Nachnamen)
  UPDATE public.stammbaeume
     SET wurzel_person_id = (SELECT mir FROM _zweigp_map WHERE src = p_wurzel)
   WHERE id = v_tree;

  SELECT count(*) INTO v_n FROM _zweigp_map;

  RETURN jsonb_build_object('ok', true, 'tree_id', v_tree, 'familie_id', v_new_fam,
                            'name', v_name, 'zusatz', v_zusatz, 'gespiegelt', v_n, 'force', p_force);
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_zweig_aus_person(uuid, text, boolean, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Zweigbaum aus Person + Zusatz: stammbaum_zweig_aus_person(p_wurzel, p_name, p_force, p_zusatz)' AS status;
