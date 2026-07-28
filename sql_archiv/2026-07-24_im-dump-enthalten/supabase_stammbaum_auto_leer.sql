-- =====================================================
-- AUTO-LÖSCHUNG LEERER STAMMBÄUME (kontoschonend) + WARTUNGS-LOCK
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Sinkt ein Baum durch Löschen auf 0 Personen, wird er automatisch entfernt —
-- aber NUR der Baum (stammbaeume-Zeile + baum-eigene beziehungen, Events per
-- CASCADE). Familie / Mitgliedschaften / Anfragen bleiben IMMER bestehen, auch
-- beim letzten Baum (tree-loser Nutzer landet auf "Kreiraj novo stablo").
-- Das ist die BEWUSSTE Abweichung zur manuellen stammbaum_loeschen(), die beim
-- letzten Baum das ganze Konto abräumt.
--
-- Bausteine:
--   1) wartungs_sperren        -> aktive Operationen (Merge/Restore/Migration/…)
--   2) ist_wartung_aktiv(tree) -> Guard: läuft gerade etwas auf dem Baum?
--   3) wartung_start/_ende     -> Lock setzen/lösen (Super-Admin)
--   4) verwaiste_event_medien  -> Queue: Event-ids, deren Storage-Medien das
--                                 Frontend noch abräumen muss (DB kann das nicht)
--   5) _baum_auto_loeschen(tree,grund)        -> INTERN (kein Rechte-Check)
--   6) stammbaum_loesche_wenn_leer(tree,grund)-> ÖFFENTLICH, owner/super_admin
--   7) auto_leere_baeume_aufraeumen()         -> Sweep für Batch-Quellen (super)
--
-- Voraussetzung: ist_super_admin() (mitglieder_komplett), get_meine_rolle()
--   (supabase_rolle_owner), familien_audit (familie_einstellungen).
-- =====================================================


-- 1) WARTUNGS-LOCK -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.wartungs_sperren (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  art           text NOT NULL CHECK (art IN
                  ('merge','restore','migration','bereinigung','massenloeschung','import')),
  familie_id    uuid,                       -- optional: nur diese Familie sperren
  stammbaum_id  uuid,                       -- optional: nur diesen Baum sperren
  global        boolean NOT NULL DEFAULT false,  -- true = ALLE Bäume sperren
  gestartet_von uuid DEFAULT auth.uid(),
  gestartet_am  timestamptz NOT NULL DEFAULT now(),
  beendet_am    timestamptz,
  aktiv         boolean NOT NULL DEFAULT true,
  notiz         text
);
CREATE INDEX IF NOT EXISTS wartungs_sperren_aktiv_idx
  ON public.wartungs_sperren(aktiv) WHERE aktiv;
ALTER TABLE public.wartungs_sperren ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "wartung_select" ON public.wartungs_sperren;
CREATE POLICY "wartung_select" ON public.wartungs_sperren
  FOR SELECT USING ( public.ist_super_admin() );


-- 2) Guard: läuft eine aktive Wartung, die diesen Baum betrifft? ------
CREATE OR REPLACE FUNCTION public.ist_wartung_aktiv(p_tree uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  RETURN EXISTS (
    SELECT 1 FROM public.wartungs_sperren w
     WHERE w.aktiv
       -- Stale-Schutz: vergessene Locks (z. B. Tab geschlossen) nach 2 h ignorieren,
       -- damit Auto-Löschungen nicht dauerhaft app-weit blockiert bleiben.
       AND w.gestartet_am > now() - interval '2 hours'
       AND ( w.global
          OR (w.stammbaum_id IS NOT NULL AND w.stammbaum_id = p_tree)
          OR (w.familie_id   IS NOT NULL AND w.familie_id   = v_fam) )
  );
END $$;
GRANT EXECUTE ON FUNCTION public.ist_wartung_aktiv(uuid) TO authenticated;


-- 3) Lock setzen / lösen (nur Super-Admin) ---------------------------
DROP FUNCTION IF EXISTS public.wartung_start(text, uuid, uuid, boolean, text);
CREATE OR REPLACE FUNCTION public.wartung_start(
  p_art text, p_stammbaum uuid DEFAULT NULL, p_familie uuid DEFAULT NULL,
  p_global boolean DEFAULT false, p_notiz text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_fam uuid := p_familie;
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'wartung_keine_berechtigung'; END IF;
  -- Familie aus dem Baum ableiten, falls nur der Baum übergeben wurde
  IF v_fam IS NULL AND p_stammbaum IS NOT NULL THEN
    SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_stammbaum;
  END IF;
  INSERT INTO public.wartungs_sperren (art, familie_id, stammbaum_id, global, notiz)
  VALUES (p_art, v_fam, p_stammbaum, coalesce(p_global,false), p_notiz)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.wartung_start(text, uuid, uuid, boolean, text) TO authenticated;

DROP FUNCTION IF EXISTS public.wartung_ende(uuid);
CREATE OR REPLACE FUNCTION public.wartung_ende(p_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'wartung_keine_berechtigung'; END IF;
  UPDATE public.wartungs_sperren SET aktiv = false, beendet_am = now()
   WHERE id = p_id AND aktiv;
  RETURN FOUND;
END $$;
GRANT EXECUTE ON FUNCTION public.wartung_ende(uuid) TO authenticated;

-- Sicherheitsnetz: alle (eigenen) Locks einer Art schließen (z. B. nach Abbruch)
DROP FUNCTION IF EXISTS public.wartung_ende_alle(text);
CREATE OR REPLACE FUNCTION public.wartung_ende_alle(p_art text DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_n integer;
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'wartung_keine_berechtigung'; END IF;
  UPDATE public.wartungs_sperren SET aktiv = false, beendet_am = now()
   WHERE aktiv AND (p_art IS NULL OR art = p_art);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;
GRANT EXECUTE ON FUNCTION public.wartung_ende_alle(text) TO authenticated;


-- 4) QUEUE: Event-Medien, die das Frontend aus dem Storage räumen muss --
--    (Postgres kann den Storage-Bucket `events` nicht löschen -> hier nur
--     vormerken; raeumeVerwaisteMedien() im Frontend erledigt das Aufräumen.)
CREATE TABLE IF NOT EXISTS public.verwaiste_event_medien (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id     uuid NOT NULL,
  stammbaum_id uuid,
  familie_id   uuid,
  erfasst_am   timestamptz NOT NULL DEFAULT now(),
  bereinigt    boolean NOT NULL DEFAULT false,
  bereinigt_am timestamptz
);
CREATE INDEX IF NOT EXISTS verwaiste_event_medien_offen_idx
  ON public.verwaiste_event_medien(bereinigt) WHERE NOT bereinigt;
ALTER TABLE public.verwaiste_event_medien ENABLE ROW LEVEL SECURITY;
-- Lesen/Markieren dürfen Admins/Owner/Super-Admin (über RPCs unten);
-- direktes SELECT für eingeloggte Nutzer offen lassen wäre unkritisch (nur ids),
-- wir kapseln es aber bewusst in RPCs. Default: keine offene Policy.

-- Offene Medien-Aufträge holen (für das Frontend-Aufräumen).
-- Sichtbar für Admin/Owner der betroffenen Familie ODER Super-Admin.
DROP FUNCTION IF EXISTS public.verwaiste_medien_offen();
CREATE OR REPLACE FUNCTION public.verwaiste_medien_offen()
RETURNS TABLE(id uuid, event_id uuid, stammbaum_id uuid, familie_id uuid)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
    SELECT v.id, v.event_id, v.stammbaum_id, v.familie_id
      FROM public.verwaiste_event_medien v
     WHERE NOT v.bereinigt
       AND ( public.ist_super_admin()
          OR (v.familie_id IS NOT NULL AND public.kann_familie_bearbeiten(v.familie_id)) )
     ORDER BY v.erfasst_am
     LIMIT 200;
END $$;
GRANT EXECUTE ON FUNCTION public.verwaiste_medien_offen() TO authenticated;

-- Einen Auftrag als erledigt markieren (nachdem das Frontend den Storage räumte).
DROP FUNCTION IF EXISTS public.verwaiste_medien_erledigt(uuid);
CREATE OR REPLACE FUNCTION public.verwaiste_medien_erledigt(p_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.verwaiste_event_medien WHERE id = p_id;
  IF v_fam IS NULL AND NOT public.ist_super_admin() THEN RAISE EXCEPTION 'medien_unbekannt'; END IF;
  IF NOT ( public.ist_super_admin()
        OR (v_fam IS NOT NULL AND public.kann_familie_bearbeiten(v_fam)) ) THEN
    RAISE EXCEPTION 'medien_keine_berechtigung';
  END IF;
  UPDATE public.verwaiste_event_medien SET bereinigt = true, bereinigt_am = now() WHERE id = p_id;
  RETURN FOUND;
END $$;
GRANT EXECUTE ON FUNCTION public.verwaiste_medien_erledigt(uuid) TO authenticated;


-- 5) INTERN: einen Baum löschen, WENN er leer ist (kein Rechte-Check).
--    Aufrufer MUSS Rechte/Lock vorher prüfen. Räumt NUR den Baum ab; Familie /
--    Mitgliedschaften / Anfragen bleiben unberührt (kontoschonend).
CREATE OR REPLACE FUNCTION public._baum_auto_loeschen(p_tree uuid, p_grund text DEFAULT 'auto_leer')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_name text; v_anz int; v_event_ids uuid[] := '{}';
BEGIN
  SELECT familie_id, name INTO v_fam, v_name FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'baum_unbekannt'); END IF;

  -- Nur löschen, wenn wirklich 0 Personen übrig (Sicherheit)
  SELECT count(*) INTO v_anz FROM public.personen WHERE stammbaum_id = p_tree;
  IF v_anz > 0 THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'baum_nicht_leer', 'personen', v_anz);
  END IF;

  -- Event-ids für späteres Storage-Aufräumen sichern (Events fallen gleich per CASCADE)
  BEGIN
    SELECT coalesce(array_agg(e.id), '{}') INTO v_event_ids
      FROM public.events e WHERE e.stammbaum_id = p_tree;
  EXCEPTION WHEN undefined_table THEN v_event_ids := '{}';
            WHEN undefined_column THEN v_event_ids := '{}'; END;

  IF coalesce(array_length(v_event_ids,1),0) > 0 THEN
    INSERT INTO public.verwaiste_event_medien (event_id, stammbaum_id, familie_id)
    SELECT unnest(v_event_ids), p_tree, v_fam;
  END IF;

  -- defensive: restliche Beziehungen, die noch Personen dieses Baums berühren
  DELETE FROM public.beziehungen b
   WHERE b.person_a IN (SELECT id FROM public.personen WHERE stammbaum_id = p_tree)
      OR b.person_b IN (SELECT id FROM public.personen WHERE stammbaum_id = p_tree);

  -- offene Verknüpfungs-Anfragen für diesen Baum (falls Tabelle/Spalte existiert)
  BEGIN
    DELETE FROM public.verknuepfungs_anfragen WHERE stammbaum_id = p_tree;
  EXCEPTION WHEN undefined_table THEN NULL; WHEN undefined_column THEN NULL; END;

  -- Audit VOR dem Löschen (familien_audit.stammbaum_id hat keinen FK -> egal, aber sauber)
  INSERT INTO public.familien_audit
    (familie_id, stammbaum_id, aktion, geaendert_von, alte_werte, neue_werte)
  VALUES (
    v_fam, p_tree, 'auto_leer_geloescht', auth.uid(),
    jsonb_build_object('stammbaum_id', p_tree, 'name', v_name, 'personen_vorher', v_anz),
    jsonb_build_object('grund', coalesce(p_grund,'auto_leer'),
                       'event_medien', to_jsonb(v_event_ids))
  );

  -- Baum selbst löschen (Events hängen per ON DELETE CASCADE)
  DELETE FROM public.stammbaeume WHERE id = p_tree;

  RETURN jsonb_build_object(
    'ok', true, 'stammbaum_id', p_tree, 'name', v_name,
    'familie_id', v_fam, 'event_ids', to_jsonb(v_event_ids)
  );
END $$;


-- 6) ÖFFENTLICH: Baum löschen, WENN leer — owner/super_admin, Lock-Guard.
--    Vom Frontend nach dem Löschen der letzten Person aufgerufen.
DROP FUNCTION IF EXISTS public.stammbaum_loesche_wenn_leer(uuid, text);
CREATE OR REPLACE FUNCTION public.stammbaum_loesche_wenn_leer(p_tree uuid, p_grund text DEFAULT 'auto_leer')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_anz int;
BEGIN
  IF p_tree IS NULL THEN RAISE EXCEPTION 'baum_unbekannt'; END IF;
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'baum_unbekannt'; END IF;

  -- Rechte: Owner-Exklusivrecht bleibt -> nur familien_owner ODER super_admin
  IF NOT ( public.ist_super_admin() OR public.get_meine_rolle(v_fam) = 'familien_owner' ) THEN
    RAISE EXCEPTION 'auto_leer_nur_owner';
  END IF;

  -- Schutz: keine Auto-Löschung während laufender Wartung (Merge/Restore/…)
  IF public.ist_wartung_aktiv(p_tree) THEN RAISE EXCEPTION 'wartung_aktiv'; END IF;

  -- Nur bei wirklich 0 Personen
  SELECT count(*) INTO v_anz FROM public.personen WHERE stammbaum_id = p_tree;
  IF v_anz > 0 THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'baum_nicht_leer', 'personen', v_anz);
  END IF;

  RETURN public._baum_auto_loeschen(p_tree, p_grund);
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_loesche_wenn_leer(uuid, text) TO authenticated;


-- 7) SWEEP: alle leeren Bäume aufräumen (für Batch-Quellen) — Super-Admin.
--    Wird nach Bereinigung / Massenlöschung / Import / Merge aufgerufen.
--    Überspringt Bäume mit aktiver Wartung. Liefert die gelöschten Bäume samt
--    Event-ids (für das Frontend-Storage-Aufräumen).
DROP FUNCTION IF EXISTS public.auto_leere_baeume_aufraeumen();
CREATE OR REPLACE FUNCTION public.auto_leere_baeume_aufraeumen()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tree uuid; v_res jsonb; v_liste jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'auto_leer_nur_super_admin'; END IF;

  FOR v_tree IN
    SELECT s.id FROM public.stammbaeume s
     WHERE NOT EXISTS (SELECT 1 FROM public.personen p WHERE p.stammbaum_id = s.id)
       AND NOT public.ist_wartung_aktiv(s.id)
  LOOP
    v_res := public._baum_auto_loeschen(v_tree, 'auto_leer_sweep');
    IF (v_res->>'ok')::boolean THEN
      v_liste := v_liste || jsonb_build_array(v_res);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'geloescht', jsonb_array_length(v_liste), 'baeume', v_liste);
END $$;
GRANT EXECUTE ON FUNCTION public.auto_leere_baeume_aufraeumen() TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'auto-leer: wartungs_sperren + verwaiste_event_medien + stammbaum_loesche_wenn_leer + auto_leere_baeume_aufraeumen angelegt' AS status;
