-- =====================================================
-- ANALYTIK: Nutzungs-Statistik (Produkt-Analytics, STRIKT INTERN)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- ZWECK: Betreiber-Kennzahlen für den SUPER-ADMIN:
--   * Wie viele Konten gibt es, wie viele sind neu?
--   * Wie viele sind AKTIV (DAU/WAU/MAU) — echte Nutzung, nicht nur Login?
--   * Wie viele sind INAKTIV / eingeschlafen (registriert, aber lange keine Aktion)?
--   * Welche Aktionen werden am meisten benutzt (Top-Features)?
--   * Verlauf: tägliche aktive Nutzer + Ereignisse (für Diagramme).
--
-- DATENSCHUTZ/KINDERSCHUTZ (hart): Das Ereignis-Log speichert NUR
--   {eigene user_id, Feature-Name, optionaler Mini-Kontext ohne Inhalte, Zeit}.
--   KEINE Personeninhalte, KEINE Klartexte, nichts verbundübergreifend Sichtbares.
--   Lesen NUR super_admin (über SECURITY-DEFINER-RPC; kein direktes RLS-SELECT).
--   Schreiben NUR über die RPC ereignis_track (stempelt user_id/Zeit serverseitig).
--
-- ABHÄNGIGKEITEN: public.ist_super_admin() (supabase_rls_setup.sql),
--   public.mein_verbund() (supabase_beitraege.sql).
-- =====================================================

-- ── 1) Ereignis-Log ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.nutzer_ereignisse (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  verbund_id uuid,                          -- Segmentierung (best-effort, aus mein_verbund())
  aktion     text NOT NULL,                 -- Feature-Name, z. B. 'login','person_offnen','pdf_export'
  detail     jsonb,                         -- optionaler Mini-Kontext (KEINE Inhalte)
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ne_created        ON public.nutzer_ereignisse (created_at);
CREATE INDEX IF NOT EXISTS idx_ne_user_created   ON public.nutzer_ereignisse (user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ne_aktion_created ON public.nutzer_ereignisse (aktion, created_at);

-- RLS an, ABER bewusst OHNE Policies für 'authenticated' -> direkter Client-Zugriff
-- (SELECT/INSERT/UPDATE/DELETE) ist gesperrt. Alles läuft über die SECURITY-DEFINER-RPCs
-- unten (Owner = postgres, umgehen RLS kontrolliert). Rekursionsfrei per Definition.
ALTER TABLE public.nutzer_ereignisse ENABLE ROW LEVEL SECURITY;

-- ── 2) Schreiben: gebündelt (ein Roundtrip pro Batch) ────────────
-- Erwartet ein JSON-ARRAY: [{aktion, detail?, ts?}, ...]. user_id/verbund_id/Zeit werden
-- serverseitig gestempelt (Client-'ts' nur als Fallback, nie in der Zukunft). Best-effort:
-- ungültige/leere Einträge werden übersprungen, max. 200 je Aufruf (Missbrauchsschutz).
CREATE OR REPLACE FUNCTION public.ereignis_track(p_events jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
BEGIN
  IF v_me IS NULL THEN RETURN; END IF;                         -- nur eingeloggt
  IF p_events IS NULL OR jsonb_typeof(p_events) <> 'array' THEN RETURN; END IF;

  BEGIN
    v_verb := public.mein_verbund();
  EXCEPTION WHEN OTHERS THEN
    v_verb := NULL;
  END;

  INSERT INTO public.nutzer_ereignisse (user_id, verbund_id, aktion, detail, created_at)
  SELECT
    v_me,
    v_verb,
    left(coalesce(e->>'aktion', ''), 60),
    CASE WHEN jsonb_typeof(e->'detail') = 'object' THEN e->'detail' ELSE NULL END,
    LEAST(now(), coalesce((e->>'ts')::timestamptz, now()))     -- nie in der Zukunft
  FROM jsonb_array_elements(p_events) WITH ORDINALITY AS t(e, ord)
  WHERE coalesce(e->>'aktion', '') <> ''
    AND ord <= 200;
END;
$$;
GRANT EXECUTE ON FUNCTION public.ereignis_track(jsonb) TO authenticated;

-- ── 3) Lesen: Übersicht (Momentwerte) — NUR super_admin ──────────
-- Liefert EIN jsonb-Objekt mit allen Kernzahlen + Top-Aktionen (30 Tage).
CREATE OR REPLACE FUNCTION public.analytik_uebersicht()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_gesamt   int;
  v_neu1     int; v_neu7 int; v_neu30 int;
  v_akt1     int; v_akt7 int; v_akt30 int;
  v_inaktiv  int; v_nie int;
  v_ereig30  int;
  v_top      jsonb;
BEGIN
  IF NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'nicht_berechtigt';
  END IF;

  SELECT count(*) INTO v_gesamt FROM auth.users;

  SELECT count(*) FILTER (WHERE created_at >= now() - interval '1 day'),
         count(*) FILTER (WHERE created_at >= now() - interval '7 days'),
         count(*) FILTER (WHERE created_at >= now() - interval '30 days')
    INTO v_neu1, v_neu7, v_neu30
    FROM auth.users;

  SELECT count(DISTINCT user_id) FILTER (WHERE created_at >= now() - interval '1 day'),
         count(DISTINCT user_id) FILTER (WHERE created_at >= now() - interval '7 days'),
         count(DISTINCT user_id) FILTER (WHERE created_at >= now() - interval '30 days'),
         count(*)                FILTER (WHERE created_at >= now() - interval '30 days')
    INTO v_akt1, v_akt7, v_akt30, v_ereig30
    FROM public.nutzer_ereignisse;

  -- inaktiv = Konto vorhanden, aber KEINE Aktion in den letzten 30 Tagen (inkl. nie).
  SELECT count(*) INTO v_inaktiv
    FROM auth.users u
   WHERE NOT EXISTS (
     SELECT 1 FROM public.nutzer_ereignisse e
      WHERE e.user_id = u.id AND e.created_at >= now() - interval '30 days');

  -- nie aktiv = Konto vorhanden, überhaupt kein Ereignis erfasst.
  SELECT count(*) INTO v_nie
    FROM auth.users u
   WHERE NOT EXISTS (SELECT 1 FROM public.nutzer_ereignisse e WHERE e.user_id = u.id);

  SELECT coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) INTO v_top
    FROM (
      SELECT aktion,
             count(*)              AS anzahl,
             count(DISTINCT user_id) AS nutzer
        FROM public.nutzer_ereignisse
       WHERE created_at >= now() - interval '30 days'
       GROUP BY aktion
       ORDER BY anzahl DESC
       LIMIT 15
    ) x;

  RETURN jsonb_build_object(
    'nutzer_gesamt', v_gesamt,
    'neu',    jsonb_build_object('d1', v_neu1, 'd7', v_neu7, 'd30', v_neu30),
    'aktiv',  jsonb_build_object('d1', v_akt1, 'd7', v_akt7, 'd30', v_akt30),
    'inaktiv_30', v_inaktiv,
    'nie_aktiv',  v_nie,
    'ereignisse_30', v_ereig30,
    'top_aktionen', v_top,
    'stand', now()
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.analytik_uebersicht() TO authenticated;

-- ── 4) Lesen: Tages-Verlauf (für Diagramme) — NUR super_admin ────
-- Lückenlose Reihe der letzten p_tage Tage: aktive Nutzer + Ereignisse je Tag.
CREATE OR REPLACE FUNCTION public.analytik_dau(p_tage int DEFAULT 30)
RETURNS TABLE (tag date, aktive_nutzer int, ereignisse int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'nicht_berechtigt';
  END IF;

  p_tage := greatest(1, least(coalesce(p_tage, 30), 365));

  RETURN QUERY
  WITH tage AS (
    -- date-Argumente sind zu timestamp UND timestamptz castbar -> generate_series wäre
    -- mehrdeutig; daher explizit auf timestamptz casten.
    SELECT generate_series(
             (now()::date - (p_tage - 1))::timestamptz,
             now()::date::timestamptz,
             interval '1 day')::date AS d
  ),
  agg AS (
    SELECT created_at::date AS d,
           count(DISTINCT user_id) AS n,
           count(*)                AS c
      FROM public.nutzer_ereignisse
     WHERE created_at >= now()::date - (p_tage - 1)
     GROUP BY created_at::date
  )
  SELECT tage.d,
         coalesce(agg.n, 0)::int,
         coalesce(agg.c, 0)::int
    FROM tage LEFT JOIN agg ON agg.d = tage.d
   ORDER BY tage.d;
END;
$$;
GRANT EXECUTE ON FUNCTION public.analytik_dau(int) TO authenticated;

-- ── 4b) Lesen: Nutzerliste (Report aktiv/inaktiv je Konto) — NUR super_admin ──
-- Ein Datensatz je Konto: E-Mail, Name (aus profile), registriert, letzter Login,
-- letzte getrackte Aktivität, Gesamt-Ereignisse und ein aktiv-Flag (Aktivität in p_tage).
-- Sortiert: zuletzt aktive zuerst, nie aktive zuletzt. Aktive/inaktive filtert das Frontend.
CREATE OR REPLACE FUNCTION public.analytik_nutzer_liste(p_tage int DEFAULT 30)
RETURNS TABLE (
  user_id           uuid,
  email             text,
  name              text,
  registriert       timestamptz,
  letzter_login     timestamptz,
  letzte_aktivitaet timestamptz,
  ereignisse        bigint,
  aktiv             boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'nicht_berechtigt';
  END IF;

  p_tage := greatest(1, least(coalesce(p_tage, 30), 365));

  RETURN QUERY
  SELECT
    u.id,
    u.email::text,
    nullif(btrim(coalesce(p.vorname, '') || ' ' || coalesce(p.nachname, '')), ''),
    u.created_at,
    u.last_sign_in_at,
    ev.letzte,
    coalesce(ev.anz, 0),
    (ev.letzte IS NOT NULL AND ev.letzte >= now() - make_interval(days => p_tage))
  FROM auth.users u
  LEFT JOIN public.profile p ON p.user_id = u.id
  LEFT JOIN LATERAL (
    SELECT max(e.created_at) AS letzte, count(*) AS anz
      FROM public.nutzer_ereignisse e
     WHERE e.user_id = u.id
  ) ev ON true
  ORDER BY (ev.letzte IS NOT NULL) DESC, ev.letzte DESC NULLS LAST, u.created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.analytik_nutzer_liste(int) TO authenticated;

-- ── 5) Aufräumen: alte Ereignisse kappen (Tabellenwuchs) ─────────
-- Standard: > 365 Tage löschen. Von Hand oder per pg_cron (Snippet unten).
CREATE OR REPLACE FUNCTION public.analytik_purge(p_tage int DEFAULT 365)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_n int;
BEGIN
  DELETE FROM public.nutzer_ereignisse
   WHERE created_at < now() - make_interval(days => greatest(30, coalesce(p_tage, 365)));
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.analytik_purge(int) TO service_role;

-- Optional (abstimmungs-/setup-pflichtig): täglicher Auto-Purge via pg_cron.
-- pg_cron einmalig aktivieren, dann EINMAL ausführen:
--   SELECT cron.schedule('analytik-purge', '30 3 * * *', $$SELECT public.analytik_purge(365);$$);

NOTIFY pgrst, 'reload schema';

SELECT 'OK: Analytik angelegt (nutzer_ereignisse, ereignis_track, analytik_uebersicht, analytik_dau, analytik_nutzer_liste, analytik_purge)' AS status;
