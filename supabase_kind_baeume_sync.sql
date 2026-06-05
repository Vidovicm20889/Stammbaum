-- =====================================================
-- KIND IN ALLE BÄUME BEIDER ELTERN SPIEGELN
-- Ausführen in: Supabase -> SQL Editor. Idempotent (mehrfach ausführbar).
--
-- Problem (siehe CLAUDE.md "Auto-Zweigbaum bei Heirat", v1-Grenze): Ein Kind wird
-- nur in dem Baum angelegt, über dessen Elternteil die Anlage gestartet wurde
-- (personen.stammbaum_id = Baum der Klick-Person). Die baumübergreifende Sichtbarkeit
-- hing allein an der fragilen Render-Zeit-Zusammenführung über identitaet_id.
--
-- Lösung: kind_baeume_sync(p_kind) berechnet die Zuordnung IMMER aus BEIDEN Eltern und
-- spiegelt das Kind datenseitig (gleiche identitaet_id -> Trigger ident_sync hält Biografie
-- synchron) in JEDEN Baum, in dem irgendeine Karte irgendeines Elternteils liegt — sofern
-- der aufrufende Nutzer diesen Baum bearbeiten darf (Isolation gewahrt). Beziehungen werden
-- zwischen den korrekten Karten je Baum neu aufgebaut (keine verwaisten Zeilen).
--
-- Aufruf: Frontend ruft die RPC nach Kind-Anlage bzw. nach Eltern-Verknüpfung
-- (kein DB-Trigger -> kontrolliert, kein Rekursionsrisiko; Trigger wäre möglicher P2).
--
-- Bewusste v1-Grenze: gespiegelt wird das Kind selbst + seine Elternkanten. Bereits
-- vorhandene EIGENE Nachkommen des Kindes werden (noch) nicht rekursiv mitgespiegelt.
--
-- Voraussetzungen: supabase_gleiche_person.sql (identitaet_id + Trigger ident_sync),
--   supabase_verbund.sql (kann_familie_bearbeiten, ist_super_admin).
-- =====================================================

CREATE OR REPLACE FUNCTION public.kind_baeume_sync(p_kind uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam   uuid;
  v_ident uuid;
  v_sd    jsonb;
  v_vn    text;
  v_nn    text;
  v_rec   record;
  v_mir   uuid;
  v_tfam  uuid;
  v_n     int := 0;
BEGIN
  IF p_kind IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'kein_kind'); END IF;

  SELECT pe.familie_id, pe.identitaet_id, pe.stammbaum_daten, pe.vorname, pe.nachname
    INTO v_fam, v_ident, v_sd, v_vn, v_nn
    FROM public.personen pe WHERE pe.id = p_kind;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'kind_fehlt'; END IF;

  -- Rechte: Admin/Owner der Kind-Familie oder Super-Admin
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'keine_berechtigung';
  END IF;

  -- identitaet_id am Kind sicherstellen (gemeinsame Identität mit allen Spiegelkarten)
  IF v_ident IS NULL THEN
    v_ident := gen_random_uuid();
    UPDATE public.personen SET identitaet_id = v_ident WHERE id = p_kind;
  END IF;

  -- Kind-Identitätsgruppe (alle Karten = dieselbe reale Kind-Person)
  CREATE TEMP TABLE _ks_kind ON COMMIT DROP AS
    SELECT pe.id FROM public.personen pe
     WHERE pe.id = p_kind OR pe.identitaet_id = v_ident;

  -- Eltern = person_a aller elternteil-Kanten zu IRGENDEINER Kind-Karte
  CREATE TEMP TABLE _ks_eltern ON COMMIT DROP AS
    SELECT DISTINCT b.person_a AS pid
      FROM public.beziehungen b JOIN _ks_kind k ON b.person_b = k.id
     WHERE b.typ = 'elternteil';

  -- Alle Elternkarten über Bäume (Identitätsgruppen der Eltern)
  CREATE TEMP TABLE _ks_ek ON COMMIT DROP AS
    SELECT DISTINCT pe.id, pe.stammbaum_id
      FROM public.personen pe
     WHERE pe.id IN (SELECT pid FROM _ks_eltern)
        OR pe.identitaet_id IN (
             SELECT pi.identitaet_id FROM public.personen pi
              WHERE pi.id IN (SELECT pid FROM _ks_eltern) AND pi.identitaet_id IS NOT NULL);

  -- Zielbäume = DISTINCT Bäume der Elternkarten, in denen das Kind noch FEHLT
  FOR v_rec IN
    SELECT DISTINCT ek.stammbaum_id AS tree
      FROM _ks_ek ek
     WHERE ek.stammbaum_id IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM public.personen kc JOIN _ks_kind k ON kc.id = k.id
          WHERE kc.stammbaum_id = ek.stammbaum_id)
  LOOP
    SELECT s.familie_id INTO v_tfam FROM public.stammbaeume s WHERE s.id = v_rec.tree;
    IF v_tfam IS NULL THEN CONTINUE; END IF;
    -- Nur in Bäume spiegeln, die der Nutzer bearbeiten darf (Isolation)
    IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_tfam)) THEN CONTINUE; END IF;

    -- Spiegelkarte des Kindes in diesem Baum
    INSERT INTO public.personen
      (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum,
       stammbaum_daten, identitaet_id)
    VALUES
      (v_tfam, v_rec.tree,
       'I' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(replace(p_kind::text,'-',''),1,8),
       v_vn, v_nn, NULL, v_sd, v_ident)
    RETURNING id INTO v_mir;

    -- Eltern-Kanten zu allen Elternkarten DIESES Baums (idempotent: keine Doppelkanten)
    INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
    SELECT v_tfam, ek.id, v_mir, 'elternteil'
      FROM _ks_ek ek
     WHERE ek.stammbaum_id = v_rec.tree
       AND NOT EXISTS (
         SELECT 1 FROM public.beziehungen b2
          WHERE b2.typ = 'elternteil' AND b2.person_a = ek.id AND b2.person_b = v_mir);

    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'gespiegelt', v_n);
END $$;

GRANT EXECUTE ON FUNCTION public.kind_baeume_sync(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Kind-Baum-Sync angelegt: kind_baeume_sync(p_kind) — spiegelt Kind in alle Bäume beider Eltern' AS status;
