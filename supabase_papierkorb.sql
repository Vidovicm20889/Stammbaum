-- =====================================================
-- PAPIERKORB / SOFT-DELETE (umkehrbare Löschungen, 30 Tage) — Kern-Backend
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier, Run). IDEMPOTENT.
-- NACH supabase_verbund.sql (kann_familie_bearbeiten) + supabase_blutlinie_rechte.sql
--   (rechte_neu_berechnen, optional) + supabase_stammbaum_auto_leer.sql (wartung_start/ende).
--
-- KONZEPT: Statt physisch zu löschen werden personen/beziehungen mit geloescht_am markiert
-- (Soft-Delete). 30 Tage wiederherstellbar; danach physischer Purge (DA greift CASCADE bewusst).
-- Geltungsbereich v1 (bewusst): NUR der user-seitige Lösch-Pfad (Person/Beziehung löschen).
--   Merge bleibt physisch (eigenes merge_log-Undo; Soft-Delete würde merge_rueckgaengig-PK brechen).
--   Baum-Löschen/Auto-leer bleiben physisch (bewusste Owner-Aktion).
--
-- ZENTRALER AUSBLEND-FILTER (zwei Schichten — siehe separate Edits):
--   Layer 1: RLS-SELECT-Policies personen/beziehungen -> `geloescht_am IS NULL AND (...)`
--            (HIER unten neu erzeugt — NACH dem Spalten-ALTER, da verbund.sql/baum_freigaben_rls.sql
--             beim Frisch-Aufbau VOR den Spalten laufen. Wer verbund.sql/baum_freigaben_rls.sql
--             erneut ausführt, muss DANACH dieses File erneut ausführen). Deckt ALLE Frontend-
--             Direktreads inkl. ladeBaumAusSupabase/Renderer ab.
--   Layer 2: jede SECURITY-DEFINER-RPC, die personen/beziehungen liest, bekommt
--            `AND geloescht_am IS NULL` (DEFINER umgeht RLS!). Diese RPCs lesen Gelöschtes NIE.
--   Der Papierkorb selbst liest bewusst `geloescht_am IS NOT NULL` (DEFINER, admin-gated).
--
-- CASCADE-Kinder (Fotos/Geschichten/Dokumente/…): bei Soft-Delete bleibt die Person physisch
--   -> CASCADE feuert NICHT -> Kinder bleiben erhalten (gut fürs Restore). v1 blendet sie nicht
--   separat aus (nur über die versteckte Person erreichbar) — Erweiterung dokumentiert.
-- BLUTLINIEN-RECHTE: Soft-Delete einer Person löscht auch ihre Kanten -> der beziehungen-Trigger
--   blutlinie_beziehungen feuert -> Rechte werden neu berechnet (sofern blutlinie_familien
--   geloescht_am filtert, Layer 2). Beim Purge feuert ohnehin der DELETE-Trigger.
-- =====================================================


-- =====================================================
-- 1) SPALTEN + INDIZES
-- =====================================================
ALTER TABLE public.personen   ADD COLUMN IF NOT EXISTS geloescht_am  timestamptz;
ALTER TABLE public.personen   ADD COLUMN IF NOT EXISTS geloescht_von uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.personen   ADD COLUMN IF NOT EXISTS loesch_batch  uuid;
ALTER TABLE public.beziehungen ADD COLUMN IF NOT EXISTS geloescht_am  timestamptz;
ALTER TABLE public.beziehungen ADD COLUMN IF NOT EXISTS geloescht_von uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.beziehungen ADD COLUMN IF NOT EXISTS loesch_batch  uuid;

-- Schnelles Filtern aktiver Zeilen (Renderer/Suche) + schnelles Auflisten/Restoren je Batch.
CREATE INDEX IF NOT EXISTS personen_aktiv_idx       ON public.personen   (stammbaum_id) WHERE geloescht_am IS NULL;
CREATE INDEX IF NOT EXISTS personen_geloescht_idx   ON public.personen   (geloescht_am) WHERE geloescht_am IS NOT NULL;
CREATE INDEX IF NOT EXISTS personen_batch_idx       ON public.personen   (loesch_batch) WHERE loesch_batch IS NOT NULL;
CREATE INDEX IF NOT EXISTS beziehungen_geloescht_idx ON public.beziehungen (geloescht_am) WHERE geloescht_am IS NOT NULL;
CREATE INDEX IF NOT EXISTS beziehungen_batch_idx     ON public.beziehungen (loesch_batch) WHERE loesch_batch IS NOT NULL;


-- =====================================================
-- 1b) LAYER 1 — RLS-SELECT-Policies mit `geloescht_am IS NULL` umschließen.
--     Logik IDENTISCH zu supabase_baum_freigaben_rls.sql (Verbund ODER freigegebener Baum),
--     nur zusätzlich der Soft-Delete-Filter. Gilt für ALLE (auch super_admin) -> Gelöschtes ist
--     im normalen UI nirgends sichtbar; der Papierkorb liest über DEFINER-RPCs (RLS-Bypass).
-- =====================================================
DROP POLICY IF EXISTS "personen_select" ON public.personen;
CREATE POLICY "personen_select" ON public.personen FOR SELECT
  USING (
    geloescht_am IS NULL AND (
      public.ist_super_admin()
      OR public.sieht_familie(familie_id)
      OR public.darf_baum_sehen(stammbaum_id)
    )
  );

DROP POLICY IF EXISTS "beziehungen_select" ON public.beziehungen;
CREATE POLICY "beziehungen_select" ON public.beziehungen FOR SELECT
  USING (
    geloescht_am IS NULL AND (
      public.ist_super_admin()
      OR public.sieht_familie(familie_id)
      OR public.darf_beziehung_sehen(person_a, person_b)
    )
  );

-- 1c) BULLETPROOF-Layer: RESTRICTIVE SELECT-Policy erzwingt geloescht_am IS NULL für JEDEN
--     normalen Read. RESTRICTIVE wird mit ALLEN permissiven Policies UND-verknüpft -> selbst
--     alte, filterlose Dashboard-Policies (z. B. „User sieht Personen seiner Familie") können
--     Gelöschtes nicht mehr re-exponieren. SECURITY-DEFINER-RPCs (Papierkorb) laufen als Owner
--     mit BYPASSRLS -> sie umgehen auch diese Policy und lesen Gelöschtes weiterhin.
DROP POLICY IF EXISTS "personen_softdelete_restrict" ON public.personen;
CREATE POLICY "personen_softdelete_restrict" ON public.personen
  AS RESTRICTIVE FOR SELECT USING (geloescht_am IS NULL);

DROP POLICY IF EXISTS "beziehungen_softdelete_restrict" ON public.beziehungen;
CREATE POLICY "beziehungen_softdelete_restrict" ON public.beziehungen
  AS RESTRICTIVE FOR SELECT USING (geloescht_am IS NULL);


-- =====================================================
-- 2) SOFT-DELETE: Person in den Papierkorb (identitätsbewusst: alle Zwillinge + deren Kanten,
--    EIN loesch_batch). Rechte: Bearbeiter (kann_familie_bearbeiten) der jeweiligen Familie.
-- =====================================================
CREATE OR REPLACE FUNCTION public.person_papierkorb(p_person uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_fam   uuid;
  v_ident uuid;
  v_uuids uuid[];
  v_batch uuid := gen_random_uuid();
  v_np    int;
  v_nb    int;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;

  SELECT familie_id, identitaet_id INTO v_fam, v_ident
    FROM public.personen WHERE id = p_person AND geloescht_am IS NULL;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  -- Zwillingsgruppe (identitaet_id) — nur Karten, die der Aufrufer bearbeiten darf; sonst nur diese.
  IF v_ident IS NOT NULL THEN
    SELECT array_agg(id) INTO v_uuids
      FROM public.personen
     WHERE identitaet_id = v_ident AND geloescht_am IS NULL
       AND public.kann_familie_bearbeiten(familie_id);
  END IF;
  IF v_uuids IS NULL OR array_length(v_uuids, 1) IS NULL THEN v_uuids := ARRAY[p_person]; END IF;

  -- Kanten ALLER betroffenen Personen mit demselben Batch soft-löschen (KEINE harte CASCADE).
  WITH upd AS (
    UPDATE public.beziehungen
       SET geloescht_am = now(), geloescht_von = v_me, loesch_batch = v_batch
     WHERE geloescht_am IS NULL
       AND (person_a = ANY(v_uuids) OR person_b = ANY(v_uuids))
    RETURNING 1
  ) SELECT count(*) INTO v_nb FROM upd;

  -- Personen (Zwillinge) soft-löschen.
  WITH upd AS (
    UPDATE public.personen
       SET geloescht_am = now(), geloescht_von = v_me, loesch_batch = v_batch
     WHERE id = ANY(v_uuids) AND geloescht_am IS NULL
    RETURNING 1
  ) SELECT count(*) INTO v_np FROM upd;

  RETURN jsonb_build_object('ok', true, 'batch', v_batch, 'personen', v_np, 'beziehungen', v_nb);
END $$;
GRANT EXECUTE ON FUNCTION public.person_papierkorb(uuid) TO authenticated;


-- =====================================================
-- 3) SOFT-DELETE: einzelne Beziehung lösen (identitätsbewusst über beide Zwillingsgruppen).
--    p_typ: 'elternteil' | 'ehepartner' | (geschwister wird im Frontend auf elternteil abgebildet).
-- =====================================================
CREATE OR REPLACE FUNCTION public.beziehung_papierkorb(p_person uuid, p_other uuid, p_typ text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_fam   uuid;
  v_pg    uuid[];   -- Zwillinge p_person
  v_og    uuid[];   -- Zwillinge p_other
  v_batch uuid := gen_random_uuid();
  v_nb    int;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;

  SELECT familie_id INTO v_fam FROM public.personen WHERE id = p_person AND geloescht_am IS NULL;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  v_pg := public._papierkorb_identgruppe(p_person);
  v_og := public._papierkorb_identgruppe(p_other);

  WITH upd AS (
    UPDATE public.beziehungen
       SET geloescht_am = now(), geloescht_von = v_me, loesch_batch = v_batch
     WHERE geloescht_am IS NULL
       AND typ = p_typ
       AND ( (person_a = ANY(v_pg) AND person_b = ANY(v_og))
          OR (person_a = ANY(v_og) AND person_b = ANY(v_pg)) )
    RETURNING 1
  ) SELECT count(*) INTO v_nb FROM upd;

  RETURN jsonb_build_object('ok', true, 'batch', v_batch, 'beziehungen', v_nb);
END $$;
GRANT EXECUTE ON FUNCTION public.beziehung_papierkorb(uuid, uuid, text) TO authenticated;

-- Helfer: Identitätsgruppe (Zwillings-UUIDs) einer Person, sonst die Person selbst.
CREATE OR REPLACE FUNCTION public._papierkorb_identgruppe(p_person uuid)
RETURNS uuid[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(
    (SELECT array_agg(q.id) FROM public.personen q
      WHERE q.identitaet_id = (SELECT identitaet_id FROM public.personen WHERE id = p_person)
        AND (SELECT identitaet_id FROM public.personen WHERE id = p_person) IS NOT NULL),
    ARRAY[p_person]);
$$;


-- =====================================================
-- 4) PAPIERKORB-ANSICHT (Bearbeiter): gelöschte Batches der bearbeitbaren Familien.
--    DEFINER liest bewusst geloescht_am IS NOT NULL.
-- =====================================================
CREATE OR REPLACE FUNCTION public.papierkorb_liste()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH person_batches AS (   -- Batches mit gelöschten PERSONEN (inkl. ihrer Kanten)
    SELECT max(t.geloescht_am) AS s, jsonb_build_object(
      'batch', t.loesch_batch, 'art', 'person',
      'geloescht_am', max(t.geloescht_am),
      'geloescht_von', max(t.gv_name),
      'stammbaum', max(t.baum),
      'personen', jsonb_agg(DISTINCT jsonb_build_object(
                    'id', t.id, 'name', btrim(coalesce(t.vorname,'')||' '||coalesce(t.nachname,'')))),
      'anzahl_personen', count(DISTINCT t.id),
      'anzahl_beziehungen', max(t.kanten)
    ) AS j
    FROM (
      SELECT p.id, p.vorname, p.nachname, p.geloescht_am, p.loesch_batch,
             s.name AS baum,
             COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)),''), u.email) AS gv_name,
             (SELECT count(*) FROM public.beziehungen b WHERE b.loesch_batch = p.loesch_batch) AS kanten
        FROM public.personen p
        LEFT JOIN public.stammbaeume s ON s.id = p.stammbaum_id
        LEFT JOIN auth.users u         ON u.id = p.geloescht_von
        LEFT JOIN public.profile pr    ON pr.user_id = p.geloescht_von
       WHERE p.geloescht_am IS NOT NULL AND p.loesch_batch IS NOT NULL
         AND public.kann_familie_bearbeiten(p.familie_id)
    ) t
    GROUP BY t.loesch_batch
  ),
  bez_batches AS (   -- NUR-Beziehungs-Batches: Kanten gelöscht, aber KEINE Person im Batch („Beziehung lösen")
    SELECT max(t.geloescht_am) AS s, jsonb_build_object(
      'batch', t.loesch_batch, 'art', 'beziehung',
      'geloescht_am', max(t.geloescht_am),
      'geloescht_von', max(t.gv_name),
      'stammbaum', max(t.baum),
      'beziehungen', jsonb_agg(DISTINCT jsonb_build_object('a', t.a_name, 'b', t.b_name, 'typ', t.typ)),
      'anzahl_beziehungen', count(*)
    ) AS j
    FROM (
      SELECT b.loesch_batch, b.geloescht_am, b.typ,
             sa.name AS baum,
             COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)),''), u.email) AS gv_name,
             btrim(coalesce(pa.vorname,'')||' '||coalesce(pa.nachname,'')) AS a_name,
             btrim(coalesce(pb.vorname,'')||' '||coalesce(pb.nachname,'')) AS b_name
        FROM public.beziehungen b
        LEFT JOIN public.personen   pa ON pa.id = b.person_a
        LEFT JOIN public.personen   pb ON pb.id = b.person_b
        LEFT JOIN public.stammbaeume sa ON sa.id = pa.stammbaum_id
        LEFT JOIN auth.users u          ON u.id = b.geloescht_von
        LEFT JOIN public.profile pr     ON pr.user_id = b.geloescht_von
       WHERE b.geloescht_am IS NOT NULL AND b.loesch_batch IS NOT NULL
         AND public.kann_familie_bearbeiten(b.familie_id)
         AND NOT EXISTS (SELECT 1 FROM public.personen p2 WHERE p2.loesch_batch = b.loesch_batch)
    ) t
    GROUP BY t.loesch_batch
  )
  SELECT coalesce(jsonb_agg(j ORDER BY s DESC), '[]'::jsonb)
  FROM (SELECT s, j FROM person_batches UNION ALL SELECT s, j FROM bez_batches) u;
$$;
GRANT EXECUTE ON FUNCTION public.papierkorb_liste() TO authenticated;


-- =====================================================
-- 5) WIEDERHERSTELLEN (owner/admin): Personen + Kanten desselben Batch zurückholen.
--    Eine Kante NUR, wenn BEIDE Endpunkte existieren UND aktiv sind (keine verwaisten Kanten).
-- =====================================================
CREATE OR REPLACE FUNCTION public.papierkorb_wiederherstellen(p_batch uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_np int; v_nb int; v_skip int;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  -- Berechtigt, wenn der Batch eine bearbeitbare Person ODER (bei Nur-Beziehungs-Batches) eine bearbeitbare Kante enthält.
  IF NOT (
       EXISTS (SELECT 1 FROM public.personen   WHERE loesch_batch = p_batch AND public.kann_familie_bearbeiten(familie_id))
    OR EXISTS (SELECT 1 FROM public.beziehungen WHERE loesch_batch = p_batch AND public.kann_familie_bearbeiten(familie_id))
  ) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  -- 1) Personen des Batch reaktivieren (nur bearbeitbare).
  WITH upd AS (
    UPDATE public.personen
       SET geloescht_am = NULL, geloescht_von = NULL, loesch_batch = NULL
     WHERE loesch_batch = p_batch AND public.kann_familie_bearbeiten(familie_id)
    RETURNING 1
  ) SELECT count(*) INTO v_np FROM upd;

  -- 2) Kanten reaktivieren — NUR wenn beide Endpunkte jetzt aktiv (existiert + geloescht_am IS NULL).
  WITH upd AS (
    UPDATE public.beziehungen b
       SET geloescht_am = NULL, geloescht_von = NULL, loesch_batch = NULL
     WHERE b.loesch_batch = p_batch
       AND EXISTS (SELECT 1 FROM public.personen pa WHERE pa.id = b.person_a AND pa.geloescht_am IS NULL)
       AND EXISTS (SELECT 1 FROM public.personen pb WHERE pb.id = b.person_b AND pb.geloescht_am IS NULL)
    RETURNING 1
  ) SELECT count(*) INTO v_nb FROM upd;

  -- Übrige Kanten des Batch (verwaister Endpunkt) bleiben soft-gelöscht und werden gezählt.
  SELECT count(*) INTO v_skip FROM public.beziehungen WHERE loesch_batch = p_batch;

  RETURN jsonb_build_object('ok', true, 'personen', v_np, 'beziehungen', v_nb, 'ausgelassen', v_skip);
END $$;
GRANT EXECUTE ON FUNCTION public.papierkorb_wiederherstellen(uuid) TO authenticated;


-- =====================================================
-- 6) ENDGÜLTIG LÖSCHEN (owner/admin): einen Batch SOFORT physisch entfernen (CASCADE greift hier).
-- =====================================================
CREATE OR REPLACE FUNCTION public.papierkorb_endgueltig(p_batch uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_ids uuid[]; v_np int; v_nb int;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  SELECT array_agg(id) INTO v_ids FROM public.personen
    WHERE loesch_batch = p_batch AND public.kann_familie_bearbeiten(familie_id);

  IF v_ids IS NOT NULL AND array_length(v_ids,1) IS NOT NULL THEN
    -- Personen-Batch: Kanten der Batch-Personen physisch (kein CASCADE personen->beziehungen).
    DELETE FROM public.beziehungen b
     WHERE b.loesch_batch = p_batch
        OR b.person_a = ANY(v_ids) OR b.person_b = ANY(v_ids);
    -- Personen physisch (CASCADE räumt Fotos/Geschichten/Dokumente/Aufnahmen/Tags/Gedenkseiten/…).
    WITH del AS (DELETE FROM public.personen WHERE id = ANY(v_ids) RETURNING 1)
    SELECT count(*) INTO v_np FROM del;
    RETURN jsonb_build_object('ok', true, 'personen', v_np);
  END IF;

  -- Nur-Beziehungs-Batch („Beziehung lösen"): nur die Kanten physisch (Recht über die Kanten-Familie).
  IF EXISTS (SELECT 1 FROM public.beziehungen WHERE loesch_batch = p_batch
               AND public.kann_familie_bearbeiten(familie_id)) THEN
    WITH del AS (
      DELETE FROM public.beziehungen WHERE loesch_batch = p_batch RETURNING 1
    ) SELECT count(*) INTO v_nb FROM del;
    RETURN jsonb_build_object('ok', true, 'personen', 0, 'beziehungen', v_nb);
  END IF;

  RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
END $$;
GRANT EXECUTE ON FUNCTION public.papierkorb_endgueltig(uuid) TO authenticated;


-- =====================================================
-- 7) AUTO-PURGE (Cron/service_role): physisch löschen, was länger als 30 Tage geloescht ist.
--    HIER greift CASCADE bewusst. Mit Wartungssperre, damit der Auto-leer-Sweep nicht reinfunkt.
-- =====================================================
CREATE OR REPLACE FUNCTION public.papierkorb_purge(p_tage int DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_cut timestamptz := now() - make_interval(days => greatest(1, coalesce(p_tage, 30)));
        v_lock uuid; v_np int; v_nb int;
BEGIN
  BEGIN v_lock := public.wartung_start('papierkorb_purge'); EXCEPTION WHEN others THEN v_lock := NULL; END;

  -- Kanten: selbst zu alt ODER an einer zu alt gelöschten Person.
  WITH del AS (
    DELETE FROM public.beziehungen b
     WHERE (b.geloescht_am IS NOT NULL AND b.geloescht_am < v_cut)
        OR b.person_a IN (SELECT id FROM public.personen WHERE geloescht_am < v_cut)
        OR b.person_b IN (SELECT id FROM public.personen WHERE geloescht_am < v_cut)
    RETURNING 1
  ) SELECT count(*) INTO v_nb FROM del;

  WITH del AS (
    DELETE FROM public.personen WHERE geloescht_am IS NOT NULL AND geloescht_am < v_cut RETURNING 1
  ) SELECT count(*) INTO v_np FROM del;

  IF v_lock IS NOT NULL THEN BEGIN PERFORM public.wartung_ende(v_lock); EXCEPTION WHEN others THEN NULL; END; END IF;
  RETURN jsonb_build_object('ok', true, 'personen', v_np, 'beziehungen', v_nb, 'stichtag', v_cut);
END $$;
REVOKE ALL ON FUNCTION public.papierkorb_purge(int) FROM public, authenticated;
GRANT EXECUTE ON FUNCTION public.papierkorb_purge(int) TO service_role;

-- pg_cron-Snippet (separat AKTIVIEREN — abstimmungspflichtig, EINMAL ausführen):
-- SELECT cron.schedule('papierkorb-purge', '30 3 * * *', $$ SELECT public.papierkorb_purge(30); $$);


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_papierkorb.sql ausgeführt — Spalten + Soft-Delete-RPCs (person/beziehung) + Papierkorb-Liste/Wiederherstellen/Endgueltig + Purge(service_role). FILTER (RLS + RPCs) separat ausführen!' AS status;
