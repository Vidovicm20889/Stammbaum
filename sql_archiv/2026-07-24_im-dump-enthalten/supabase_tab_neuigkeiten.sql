-- ============================================================================
-- TAB-NEUIGKEITEN-BADGES (Feed / Events / Mapa) — „ungelesen"-Zähler je Tab
-- ----------------------------------------------------------------------------
-- Zeigt auf den oberen Tabs eine Info-Zahl (wie das Obavještenja-Badge), sobald
-- seit dem letzten Öffnen etwas Neues dazukam. Öffnet der Nutzer den Tab, wird
-- der „gelesen"-Zeitpunkt aktualisiert -> Badge verschwindet.
--
-- Geltung je Tab:
--   feed   = neue Aktivitäten (aktivitaeten) im VERBUND des Nutzers
--   events = neue Events (des aktiven Baums) + neue Terminumfragen (des Baums)
--            (Kalender ist nur eine Ansicht der Events -> automatisch enthalten)
--   mapa   = neue Events des aktiven Baums MIT Koordinaten (nur die erscheinen auf der Karte)
--
-- „gelesen"-Status ist GERÄTEÜBERGREIFEND (eigene Tabelle je user_id, nicht localStorage).
-- Idempotent -> im Supabase SQL-Editor ausführbar.
-- ============================================================================

-- 1) Tabelle: je (Nutzer, Tab) ein Zeitpunkt „zuletzt gesehen" ----------------
CREATE TABLE IF NOT EXISTS public.tab_gelesen (
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tab        text NOT NULL CHECK (tab IN ('feed','events','mapa')),
  gelesen_am timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, tab)
);

ALTER TABLE public.tab_gelesen ENABLE ROW LEVEL SECURITY;

-- Direkter Zugriff nur auf die EIGENE Zeile (rekursionsfrei). Schreiben läuft
-- ausschließlich über die SECURITY-DEFINER-RPCs unten.
DROP POLICY IF EXISTS tab_gelesen_self ON public.tab_gelesen;
CREATE POLICY tab_gelesen_self ON public.tab_gelesen
  FOR SELECT USING (auth.uid() = user_id);

-- 2) Tab als „gesehen" markieren (beim Öffnen des Tabs) -----------------------
CREATE OR REPLACE FUNCTION public.tab_gesehen(p_tab text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  IF p_tab NOT IN ('feed','events','mapa') THEN RETURN; END IF;
  INSERT INTO public.tab_gelesen (user_id, tab, gelesen_am)
  VALUES (auth.uid(), p_tab, now())
  ON CONFLICT (user_id, tab) DO UPDATE SET gelesen_am = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.tab_gesehen(text) TO authenticated;

-- 3) Zähler je Tab holen -------------------------------------------------------
-- VOLATILE (nicht STABLE): beim ERSTEN Aufruf ohne gelesen_am wird der Zeitpunkt
-- lazy auf now() gesetzt (Insert), damit der bestehende Altbestand NICHT als
-- „neu" aufblitzt. Danach nur noch Zählungen.
CREATE OR REPLACE FUNCTION public.tab_neuigkeiten(p_tree uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_feed_t timestamptz;
  v_ev_t   timestamptz;
  v_map_t  timestamptz;
  v_fam    uuid;
  v_feed   int := 0;
  v_events int := 0;
  v_mapa   int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('feed', 0, 'events', 0, 'mapa', 0);
  END IF;

  -- gelesen_am je Tab lesen; fehlt sie -> Erststart: auf now() setzen (lazy init)
  SELECT gelesen_am INTO v_feed_t FROM public.tab_gelesen WHERE user_id = v_uid AND tab = 'feed';
  SELECT gelesen_am INTO v_ev_t   FROM public.tab_gelesen WHERE user_id = v_uid AND tab = 'events';
  SELECT gelesen_am INTO v_map_t  FROM public.tab_gelesen WHERE user_id = v_uid AND tab = 'mapa';

  IF v_feed_t IS NULL THEN
    INSERT INTO public.tab_gelesen (user_id, tab, gelesen_am) VALUES (v_uid, 'feed', now())
      ON CONFLICT (user_id, tab) DO NOTHING;
    v_feed_t := now();
  END IF;
  IF v_ev_t IS NULL THEN
    INSERT INTO public.tab_gelesen (user_id, tab, gelesen_am) VALUES (v_uid, 'events', now())
      ON CONFLICT (user_id, tab) DO NOTHING;
    v_ev_t := now();
  END IF;
  IF v_map_t IS NULL THEN
    INSERT INTO public.tab_gelesen (user_id, tab, gelesen_am) VALUES (v_uid, 'mapa', now())
      ON CONFLICT (user_id, tab) DO NOTHING;
    v_map_t := now();
  END IF;

  -- FEED: neue Aktivitäten im Verbund des Nutzers (erstellt_am zuerst -> Index)
  SELECT count(*) INTO v_feed
    FROM public.aktivitaeten a
   WHERE a.erstellt_am > v_feed_t
     AND public.ist_in_verbund(a.verbund_id);

  -- EVENTS + MAPA: nur, wenn ein sichtbarer Baum geöffnet ist
  IF p_tree IS NOT NULL THEN
    SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
    IF v_fam IS NOT NULL AND (public.ist_super_admin() OR public.sieht_familie(v_fam)) THEN
      -- EVENTS: neue Events + neue Terminumfragen des Baums
      SELECT
        (SELECT count(*) FROM public.events e
           WHERE e.stammbaum_id = p_tree AND e.created_at > v_ev_t)
      + (SELECT count(*) FROM public.terminfindung tf
           WHERE tf.stammbaum_id = p_tree AND tf.erstellt_am > v_ev_t)
        INTO v_events;

      -- MAPA: neue Events des Baums MIT Koordinaten
      SELECT count(*) INTO v_mapa
        FROM public.events e
       WHERE e.stammbaum_id = p_tree
         AND e.created_at > v_map_t
         AND e.latitude IS NOT NULL AND e.longitude IS NOT NULL;
    END IF;
  END IF;

  RETURN jsonb_build_object('feed', v_feed, 'events', v_events, 'mapa', v_mapa);
END;
$$;
GRANT EXECUTE ON FUNCTION public.tab_neuigkeiten(uuid) TO authenticated;
