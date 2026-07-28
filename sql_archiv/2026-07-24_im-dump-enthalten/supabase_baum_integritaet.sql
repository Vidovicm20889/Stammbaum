-- =====================================================
-- BAUM-INTEGRITÄT — read-only Diagnose („TÜV-Bericht" für einen Stammbaum)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT (CREATE OR REPLACE).
-- Diese Funktion SCHREIBT NICHTS — sie liest nur und meldet Auffälligkeiten.
--
-- HINTERGRUND (Audit „Personen verschwinden"): Der Frontend-Renderer zeichnet den
-- Diagramm-Baum IMMER aus EINER Wurzel heraus und traversiert nur deren zusammen-
-- hängende Kanten-Komponente (baueBaumDaten/baueKnoten in stammbaum.html). Jede
-- Person OHNE Kanten-Pfad zu dieser Wurzel wird NICHT gezeichnet — obwohl die Zeile
-- in der DB existiert. Diese Funktion macht genau solche Fälle sichtbar und trennt:
--   • „Zeile existiert, aber unsichtbar"  -> Inseln / lose Personen (Anzeigeproblem)
--   • „Zeile/Kante wirklich kaputt"       -> verwaiste Kanten / fehlende Zuordnung (Datenproblem)
--
-- Verbindungs-Begriff (wie der Renderer): Kanten sind 'elternteil' + 'ehepartner',
-- UNGERICHTET ausgewertet. Zusätzlich werden baumübergreifende Brücken über
-- identitaet_id berücksichtigt (eine Person, die per identitaet_id in diesen Baum
-- gespiegelt ist bzw. deren Elternteil in einem anderen Baum liegt, gilt als
-- verbunden — analog zur Render-Brücke). Dadurch möglichst wenige Falsch-Treffer.
--
-- EHRLICHE GRENZE: Der Renderer ist single-root + gerichtet; diese Prüfung nutzt
-- ungerichtete Komponenten-Bildung als konservativen Näherungswert. „Hauptbaum" =
-- die GRÖSSTE Komponente (die der Renderer praktisch immer als Wurzel-Komponente
-- zeichnet). „Inseln" = alle übrigen Komponenten = im Diagramm unsichtbar. In sehr
-- seltenen Konstellationen (gerichtete Eigenheiten) kann eine Person in der
-- Hauptkomponente trotzdem ungezeichnet bleiben — solche Fälle deckt diese v1 nicht ab.
--
-- Voraussetzungen: Tabellen personen/beziehungen/stammbaeume/familien (+ verbund_id),
-- Helfer ist_super_admin()/kann_familie_bearbeiten() aus supabase_verbund.sql.
-- =====================================================

CREATE OR REPLACE FUNCTION public.baum_integritaet_pruefen(p_stammbaum_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam     uuid;
  v_verbund uuid;
  v_name    text;
  v_seed    uuid;
  v_c       int := 0;
  v_main    int;
  v_total   int;
  v_result  jsonb;
  v_inseln  jsonb;
  v_lose    jsonb;
  v_waisen  jsonb;
  v_ohnebaum jsonb;
BEGIN
  IF p_stammbaum_id IS NULL THEN RAISE EXCEPTION 'baum_id_fehlt'; END IF;

  SELECT s.familie_id, s.name INTO v_fam, v_name
    FROM public.stammbaeume s WHERE s.id = p_stammbaum_id;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'baum_fehlt'; END IF;

  -- Rechte: nur Admin/Owner der Familie (oder Super-Admin) — reine Diagnose,
  -- aber sie listet Personen-Stammdaten auf -> nicht für lesende Mitglieder.
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'keine_berechtigung';
  END IF;

  SELECT f.verbund_id INTO v_verbund FROM public.familien f WHERE f.id = v_fam;

  -- ---- 1) Personen DIESES Baums ------------------------------------------------
  DROP TABLE IF EXISTS _bp_intree;
  CREATE TEMP TABLE _bp_intree ON COMMIT DROP AS
    SELECT pe.id, pe.identitaet_id
      FROM public.personen pe
     WHERE pe.stammbaum_id = p_stammbaum_id
       AND pe.geloescht_am IS NULL;

  SELECT count(*) INTO v_total FROM _bp_intree;

  -- ---- 2) Map: BELIEBIGE personen.id -> Repräsentant in DIESEM Baum ------------
  --        (sich selbst, falls im Baum; ODER ein identitaet_id-Zwilling im Baum).
  --        So zählen baumübergreifende Eltern-/Partner-Kanten als Brücke mit.
  DROP TABLE IF EXISTS _bp_map;
  CREATE TEMP TABLE _bp_map ON COMMIT DROP AS
    SELECT it.id AS any_id, it.id AS rep FROM _bp_intree it
    UNION
    SELECT pe.id AS any_id, it.id AS rep
      FROM public.personen pe
      JOIN _bp_intree it ON it.identitaet_id = pe.identitaet_id
     WHERE pe.identitaet_id IS NOT NULL
       AND pe.geloescht_am IS NULL
       AND pe.stammbaum_id IS DISTINCT FROM p_stammbaum_id;

  -- ---- 3) Ungerichtete Kanten auf Baum-Repräsentanten -------------------------
  DROP TABLE IF EXISTS _bp_edges;
  CREATE TEMP TABLE _bp_edges ON COMMIT DROP AS
    SELECT DISTINCT ma.rep AS a, mb.rep AS b
      FROM public.beziehungen b
      JOIN _bp_map ma ON ma.any_id = b.person_a
      JOIN _bp_map mb ON mb.any_id = b.person_b
     WHERE b.typ IN ('elternteil','ehepartner')
       AND b.geloescht_am IS NULL
       AND ma.rep <> mb.rep;

  -- ---- 4) Zusammenhangskomponenten bilden (iterative BFS je Saat) --------------
  DROP TABLE IF EXISTS _bp_comp;
  CREATE TEMP TABLE _bp_comp (pid uuid PRIMARY KEY, comp int) ON COMMIT DROP;

  LOOP
    SELECT it.id INTO v_seed
      FROM _bp_intree it
     WHERE NOT EXISTS (SELECT 1 FROM _bp_comp c WHERE c.pid = it.id)
     LIMIT 1;
    EXIT WHEN v_seed IS NULL;
    v_c := v_c + 1;

    INSERT INTO _bp_comp(pid, comp)
    WITH RECURSIVE reach(pid) AS (
      SELECT v_seed
      UNION
      SELECT CASE WHEN e.a = r.pid THEN e.b ELSE e.a END
        FROM _bp_edges e
        JOIN reach r ON (e.a = r.pid OR e.b = r.pid)
    )
    SELECT DISTINCT pid, v_c FROM reach
    ON CONFLICT (pid) DO NOTHING;
  END LOOP;

  -- Größte Komponente = „Hauptbaum" (die der Renderer als Wurzel-Komponente zeichnet)
  SELECT comp INTO v_main
    FROM _bp_comp
   GROUP BY comp
   ORDER BY count(*) DESC, comp ASC
   LIMIT 1;

  -- ---- 5) INSELN: Komponenten außer der Hauptkomponente (= im Diagramm unsichtbar)
  SELECT coalesce(jsonb_agg(ins ORDER BY (ins->>'groesse')::int DESC), '[]'::jsonb)
    INTO v_inseln
    FROM (
      SELECT jsonb_build_object(
               'komponente', c.comp,
               'groesse', count(*),
               'personen', jsonb_agg(
                 jsonb_build_object(
                   'externe_id', pe.externe_id,
                   'name', nullif(trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')), ''),
                   'platzhalter', coalesce((pe.stammbaum_daten->>'platzhalter')::boolean, false),
                   'hat_konto', pe.user_id IS NOT NULL,
                   'verknuepft', pe.identitaet_id IS NOT NULL
                 ) ORDER BY pe.vorname, pe.nachname)
             ) AS ins
        FROM _bp_comp c
        JOIN public.personen pe ON pe.id = c.pid
       WHERE c.comp <> coalesce(v_main, -1)
       GROUP BY c.comp
    ) q;

  -- ---- 6) LOSE Personen: gar keine Kante (Grad 0) -----------------------------
  SELECT coalesce(jsonb_agg(
           jsonb_build_object(
             'externe_id', pe.externe_id,
             'name', nullif(trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')), ''),
             'platzhalter', coalesce((pe.stammbaum_daten->>'platzhalter')::boolean, false),
             'hat_konto', pe.user_id IS NOT NULL,
             'verknuepft', pe.identitaet_id IS NOT NULL
           ) ORDER BY pe.vorname, pe.nachname), '[]'::jsonb)
    INTO v_lose
    FROM _bp_intree it
    JOIN public.personen pe ON pe.id = it.id
   WHERE NOT EXISTS (SELECT 1 FROM _bp_edges e WHERE e.a = it.id OR e.b = it.id);

  -- ---- 7) VERWAISTE KANTEN: Beziehung dieser Familie mit fehlendem Endpunkt ----
  SELECT coalesce(jsonb_agg(
           jsonb_build_object('beziehung_id', b.id, 'person_a', b.person_a,
                              'person_b', b.person_b, 'typ', b.typ)), '[]'::jsonb)
    INTO v_waisen
    FROM public.beziehungen b
   WHERE b.familie_id = v_fam
     AND b.geloescht_am IS NULL
     AND ( NOT EXISTS (SELECT 1 FROM public.personen p WHERE p.id = b.person_a AND p.geloescht_am IS NULL)
        OR NOT EXISTS (SELECT 1 FROM public.personen p WHERE p.id = b.person_b AND p.geloescht_am IS NULL) );

  -- ---- 8) FEHLENDE ZUORDNUNG: Personen der Familie ohne stammbaum_id ----------
  SELECT coalesce(jsonb_agg(
           jsonb_build_object('id', pe.id, 'externe_id', pe.externe_id,
             'name', nullif(trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')), ''))), '[]'::jsonb)
    INTO v_ohnebaum
    FROM public.personen pe
   WHERE pe.familie_id = v_fam AND pe.stammbaum_id IS NULL AND pe.geloescht_am IS NULL;

  -- ---- 9) Ergebnis-Bericht -----------------------------------------------------
  v_result := jsonb_build_object(
    'ok', true,
    'stammbaum_id', p_stammbaum_id,
    'name', v_name,
    'familie_id', v_fam,
    'verbund_id', v_verbund,
    'verbund_fehlt', v_verbund IS NULL,            -- sollte NIE true sein (NOT NULL)
    'personen_gesamt', v_total,
    'komponenten', v_c,
    'hauptkomponente', v_main,
    'hauptkomponente_groesse', (SELECT count(*) FROM _bp_comp WHERE comp = v_main),
    'inseln', coalesce(v_inseln, '[]'::jsonb),               -- unsichtbar im Diagramm (Zeile existiert)
    'inseln_personen', (SELECT count(*) FROM _bp_comp WHERE comp <> coalesce(v_main,-1)),
    'lose_personen', coalesce(v_lose, '[]'::jsonb),          -- ohne jede Kante
    'verwaiste_kanten', coalesce(v_waisen, '[]'::jsonb),     -- Datenproblem
    'ohne_stammbaum', coalesce(v_ohnebaum, '[]'::jsonb),     -- Datenproblem
    'geprueft_am', now()
  );

  RETURN v_result;
END $$;

GRANT EXECUTE ON FUNCTION public.baum_integritaet_pruefen(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

SELECT 'Diagnose angelegt: baum_integritaet_pruefen(p_stammbaum_id) — read-only Integritäts-Bericht' AS status;
