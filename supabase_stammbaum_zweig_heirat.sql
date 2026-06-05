-- =====================================================
-- AUTO-ZWEIGBAUM BEI HEIRAT  (neuer Nachname -> neuer Stammbaum)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Voraussetzungen:
--   * supabase_gleiche_person.sql       -> personen.identitaet_id
--   * supabase_gleiche_person_sync.sql  -> public.merge_norm(text), Trigger ident_sync
--   * supabase_verbund.sql              -> public.kann_familie_bearbeiten(uuid), familien.verbund_id
--
-- Idee (siehe CLAUDE.md "Auto-Zweigbaum bei Heirat"): Heiratet im Baum eine
-- Person und es entsteht durch den eingeheirateten Partner ein NEUER Nachname,
-- kann für diese Linie ein eigener Stammbaum angelegt werden – in DERSELBEN
-- Familie (gleicher Verbund -> Sichtbarkeit/Rechte automatisch, Isolation gewahrt,
-- kein separater Owner pro Baum: Owner hängt an der Familie).
--
-- Personen werden NICHT verschoben/kopiert, sondern als GLEICHE Person über
-- personen.identitaet_id in den neuen Baum GESPIEGELT (beide Karten bleiben
-- sichtbar, Biografie hält der vorhandene Trigger ident_sync synchron):
--   * Wurzel des neuen Baums   = eingeheirateter Partner (p_wurzel)
--   * dessen Ehepartner        = p_partner (die Person aus der Herkunftsfamilie)
--   * + zum Zeitpunkt des Anlegens vorhandene gemeinsame Nachkommen (rekursiv,
--     nur im Quellbaum) inkl. deren Ehepartner, damit die Linie zusammenbleibt.
-- Beziehungen werden zwischen den gespiegelten Karten neu aufgebaut (keine
-- verwaisten Zeilen). Spätere Nachkommen werden NICHT automatisch nachgespiegelt
-- (bewusste v1-Grenze; Auto-Sync-Trigger ist der nächste Ausbauschritt).
-- =====================================================

CREATE OR REPLACE FUNCTION public.stammbaum_zweig_aus_heirat(
  p_wurzel uuid, p_partner uuid, p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_fam     uuid;
  v_src     uuid;       -- Quell-Stammbaum (Baum der Wurzelperson)
  v_fam_p   uuid;
  v_verbund uuid;
  v_name    text;
  v_owner   uuid;
  v_tree    uuid;
  v_rec     record;
  v_mir     uuid;
  v_n       int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'nicht_angemeldet'; END IF;
  IF p_wurzel IS NULL OR p_partner IS NULL OR p_wurzel = p_partner THEN
    RAISE EXCEPTION 'zweig_ungueltige_auswahl'; END IF;

  -- Wurzel (eingeheirateter Partner): Familie + Quellbaum + Nachname
  SELECT pe.familie_id, pe.stammbaum_id, pe.nachname
    INTO v_fam, v_src, v_name
    FROM public.personen pe WHERE pe.id = p_wurzel;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'zweig_person_fehlt'; END IF;

  -- Partner muss zur selben Familie gehören (Isolation)
  SELECT pe.familie_id INTO v_fam_p FROM public.personen pe WHERE pe.id = p_partner;
  IF v_fam_p IS NULL OR v_fam_p <> v_fam THEN RAISE EXCEPTION 'zweig_person_fehlt'; END IF;

  -- Rechte: Admin/Owner der Familie
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'zweig_keine_berechtigung'; END IF;

  v_name := coalesce(nullif(trim(p_name), ''), nullif(trim(v_name), ''));
  IF v_name IS NULL THEN RAISE EXCEPTION 'zweig_kein_name'; END IF;

  -- Existiert im VERBUND schon ein (aktiver) Baum mit diesem Nachnamen? -> Abbruch
  SELECT f.verbund_id INTO v_verbund FROM public.familien f WHERE f.id = v_fam;
  IF EXISTS (
    SELECT 1 FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
     WHERE coalesce(s.aktiv, true)
       AND public.merge_norm(s.name) = public.merge_norm(v_name)
       AND ((v_verbund IS NOT NULL AND f.verbund_id = v_verbund) OR f.id = v_fam)
  ) THEN
    RAISE EXCEPTION 'zweig_existiert';
  END IF;

  -- ---- Zu spiegelnde Quell-Personen sammeln (nur im Quellbaum) -------------
  -- Wurzel + ihre Nachkommen (rekursiv über elternteil) + p_partner
  -- + Ehepartner aller bisher gesammelten Personen.
  CREATE TEMP TABLE _zweig_src ON COMMIT DROP AS
  WITH RECURSIVE nach(pid) AS (
    SELECT p_wurzel
    UNION
    SELECT b.person_b
      FROM public.beziehungen b
      JOIN nach n  ON b.person_a = n.pid
      JOIN public.personen pe ON pe.id = b.person_b
     WHERE b.typ = 'elternteil' AND pe.stammbaum_id = v_src
  )
  SELECT DISTINCT x.pid
    FROM (
      SELECT pid FROM nach
      UNION ALL SELECT p_partner
      UNION ALL
      SELECT CASE WHEN b.person_a IN (SELECT pid FROM nach) THEN b.person_b ELSE b.person_a END
        FROM public.beziehungen b
       WHERE b.typ = 'ehepartner'
         AND (b.person_a IN (SELECT pid FROM nach) OR b.person_b IN (SELECT pid FROM nach))
    ) x
    JOIN public.personen pe ON pe.id = x.pid
   WHERE x.pid IS NOT NULL AND pe.stammbaum_id = v_src;

  -- Jede gesammelte Karte braucht eine identitaet_id (gemeinsame Identität mit Spiegel)
  UPDATE public.personen
     SET identitaet_id = gen_random_uuid()
   WHERE id IN (SELECT pid FROM _zweig_src) AND identitaet_id IS NULL;

  -- ---- Neuen Stammbaum in DERSELBEN Familie anlegen -----------------------
  SELECT m.user_id INTO v_owner
    FROM public.mitgliedschaften m
   WHERE m.familie_id = v_fam AND m.rolle = 'familien_owner' AND m.aktiv
   ORDER BY m.aktiv DESC LIMIT 1;

  INSERT INTO public.stammbaeume (familie_id, name, ersteller_id, owner_id, aktiv)
  VALUES (v_fam, v_name, v_uid, coalesce(v_owner, v_uid), true)
  RETURNING id INTO v_tree;

  -- ---- Spiegelkarten anlegen (Biografie übernehmen, identitaet teilen) -----
  CREATE TEMP TABLE _zweig_map (src uuid, mir uuid) ON COMMIT DROP;
  FOR v_rec IN
    SELECT pe.* FROM public.personen pe JOIN _zweig_src z ON z.pid = pe.id
  LOOP
    INSERT INTO public.personen
      (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum,
       stammbaum_daten, identitaet_id)
    VALUES
      (v_fam, v_tree,
       'I' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(replace(v_rec.id::text,'-',''),1,8),
       v_rec.vorname, v_rec.nachname, NULL,
       v_rec.stammbaum_daten, v_rec.identitaet_id)
    RETURNING id INTO v_mir;
    INSERT INTO _zweig_map (src, mir) VALUES (v_rec.id, v_mir);
  END LOOP;

  -- ---- Beziehungen zwischen den Spiegelkarten neu aufbauen ----------------
  -- (nur Kanten, deren BEIDE Enden gespiegelt wurden -> keine verwaisten Zeilen)
  INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
  SELECT v_fam, ma.mir, mb.mir, b.typ
    FROM public.beziehungen b
    JOIN _zweig_map ma ON ma.src = b.person_a
    JOIN _zweig_map mb ON mb.src = b.person_b;

  -- Wurzelperson des neuen Baums setzen (eingeheirateter Partner)
  UPDATE public.stammbaeume
     SET wurzel_person_id = (SELECT mir FROM _zweig_map WHERE src = p_wurzel)
   WHERE id = v_tree;

  SELECT count(*) INTO v_n FROM _zweig_map;

  RETURN jsonb_build_object('ok', true, 'tree_id', v_tree, 'name', v_name, 'gespiegelt', v_n);
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_zweig_aus_heirat(uuid, uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Auto-Zweigbaum bei Heirat angelegt: stammbaum_zweig_aus_heirat(p_wurzel, p_partner, p_name)' AS status;
