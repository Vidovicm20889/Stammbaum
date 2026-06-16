-- =====================================================
-- WÖCHENTLICHER FAMILIEN-DIGEST — E-Mail-Wochenzusammenfassung (Feature C)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_benachrichtigungen_anlaesse.sql (Einstellungstabelle),
-- supabase_aktivitaeten.sql (Aktivitäts-Stream) und supabase_familien_fragen.sql.
--
-- KONZEPT: EINE ruhige Wochen-Mail je Mitglied (statt Einzel-Benachrichtigungen). Sammelt je
-- VERBUND die Aktivität der letzten 7 Tage (neue Beiträge/Fotos/Personen/Geschichten/Events),
-- die anstehenden Geburtstage/Gedenktage der nächsten 7 Tage und offene Familien-Fragen.
-- Versand über die Edge Function `woechentlicher-digest` (Resend), wöchentlich per pg_cron+pg_net.
--
-- DATENSCHUTZ (CLAUDE.md): NUR Zähler + datensparsame Highlights. KEINE Beitrags-/Nachrichten-
-- Texte, keine Fotos, keine Chat-Inhalte in der Mail. Namen anstehender Geburtstage/Gedenktage
-- sind verbund-intern (Empfänger ist Verbund-Mitglied) — konsistent mit anlaesse-erinnerung.
-- STRIKT VERBUND-GEBUNDEN: jede Mail betrifft genau EINEN Verbund des Empfängers.
--
-- ANTI-DOPPELVERSAND: Tabelle digest_versand(user_id, verbund_id, woche_start) mit UNIQUE.
-- „Leere Woche" -> der Sammel-RPC liefert die Zeile gar nicht erst (keine Mail).
--
-- Voraussetzungen: supabase_verbund.sql (familien.verbund_id, mitgliedschaften, ist_super_admin),
--   supabase_profile.sql (profile.sprache), supabase_benachrichtigungen_anlaesse.sql
--   (benachrichtigungs_einstellungen), supabase_aktivitaeten.sql (aktivitaeten),
--   supabase_familien_fragen.sql (familien_fragen), personen.stammbaum_daten (ISO-Daten).
-- =====================================================


-- =====================================================
-- 1) Opt-out-Schalter an die bestehende Einstellungstabelle (Default: an)
-- =====================================================
ALTER TABLE public.benachrichtigungs_einstellungen
  ADD COLUMN IF NOT EXISTS email_woechentlicher_digest boolean NOT NULL DEFAULT true;


-- =====================================================
-- 2) Versand-Protokoll (gegen Doppelversand je Woche/Verbund/Nutzer)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.digest_versand (
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  verbund_id  uuid NOT NULL,
  woche_start date NOT NULL,                     -- Montag der Versandwoche
  gesendet_am timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, verbund_id, woche_start)
);
CREATE INDEX IF NOT EXISTS digest_versand_idx ON public.digest_versand (woche_start);

-- RLS an, KEINE Policies -> nur service_role (Edge Function) liest/schreibt; normale Nutzer
-- haben keinen Zugriff (Protokoll ist rein technisch).
ALTER TABLE public.digest_versand ENABLE ROW LEVEL SECURITY;


-- =====================================================
-- 3) Sammel-RPC: je Empfänger+Verbund eine Zeile mit Zählern + Highlights.
--    SECURITY DEFINER, NUR service_role (läuft im Cron-/Edge-Kontext ohne auth.uid()).
--    Liefert eine Zeile NUR, wenn es „etwas Neues" gibt (Aktivität 7 Tage ODER anstehender
--    Geburtstag/Gedenktag 7 Tage ODER neu geöffnete Frage 7 Tage) UND der Nutzer NICHT
--    opted-out ist UND diese Woche noch keine Mail bekam.
-- =====================================================
CREATE OR REPLACE FUNCTION public.digest_woche_sammeln(p_woche_start date DEFAULT NULL)
RETURNS TABLE(
  user_id uuid, verbund_id uuid, email text, name text, sprache text, woche_start date,
  cnt_beitraege int, cnt_fotos int, cnt_personen int, cnt_geschichten int, cnt_events int,
  geburtstage jsonb, gedenktage jsonb, offene_fragen int, neue_fragen int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
#variable_conflict use_column
DECLARE v_woche date := coalesce(p_woche_start, (date_trunc('week', current_date))::date);
BEGIN
  RETURN QUERY
  WITH akt AS (   -- Aktivität der letzten 7 Tage je Verbund
    SELECT a.verbund_id,
      count(*) FILTER (WHERE a.typ = 'beitrag_neu')    AS c_beitraege,
      count(*) FILTER (WHERE a.typ = 'foto_neu')       AS c_fotos,
      count(*) FILTER (WHERE a.typ = 'person_neu')     AS c_personen,
      count(*) FILTER (WHERE a.typ = 'geschichte_neu') AS c_geschichten,
      count(*) FILTER (WHERE a.typ = 'event_neu')      AS c_events
    FROM public.aktivitaeten a
    WHERE a.erstellt_am >= now() - interval '7 days'
    GROUP BY a.verbund_id
  ),
  geb AS (        -- Geburtstage der nächsten 7 Tage je Verbund (lebende; identitäts-entdoppelt)
    SELECT verbund_id, jsonb_agg(nm ORDER BY nm) AS namen
    FROM (
      SELECT DISTINCT ON (fv.verbund_id, coalesce(pe.identitaet_id, pe.id))
        fv.verbund_id,
        nullif(btrim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')), '') AS nm
      FROM public.personen pe
      JOIN public.familien fv ON fv.id = pe.familie_id
      WHERE coalesce((pe.stammbaum_daten->>'platzhalter')::boolean, false) = false
        AND coalesce((pe.stammbaum_daten->>'deceased')::boolean, false) = false
        AND coalesce(pe.stammbaum_daten->>'death_date','') = ''
        AND pe.stammbaum_daten->>'birth_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        AND substr(pe.stammbaum_daten->>'birth_date', 6, 5) IN
            (SELECT to_char(current_date + g, 'MM-DD') FROM generate_series(0, 6) g)
      ORDER BY fv.verbund_id, coalesce(pe.identitaet_id, pe.id)
    ) s WHERE nm IS NOT NULL GROUP BY verbund_id
  ),
  ged AS (        -- Gedenktage der nächsten 7 Tage je Verbund (verstorbene; identitäts-entdoppelt)
    SELECT verbund_id, jsonb_agg(nm ORDER BY nm) AS namen
    FROM (
      SELECT DISTINCT ON (fv.verbund_id, coalesce(pe.identitaet_id, pe.id))
        fv.verbund_id,
        nullif(btrim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')), '') AS nm
      FROM public.personen pe
      JOIN public.familien fv ON fv.id = pe.familie_id
      WHERE coalesce((pe.stammbaum_daten->>'platzhalter')::boolean, false) = false
        AND pe.stammbaum_daten->>'death_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        AND substr(pe.stammbaum_daten->>'death_date', 6, 5) IN
            (SELECT to_char(current_date + g, 'MM-DD') FROM generate_series(0, 6) g)
      ORDER BY fv.verbund_id, coalesce(pe.identitaet_id, pe.id)
    ) s WHERE nm IS NOT NULL GROUP BY verbund_id
  ),
  fragen AS (     -- offene Fragen (Kontext) + in den letzten 7 Tagen NEU geöffnete (Trigger)
    SELECT verbund_id,
      count(*) FILTER (WHERE status = 'offen')                                              AS offen,
      count(*) FILTER (WHERE status = 'offen' AND erstellt_am >= now() - interval '7 days') AS neu
    FROM public.familien_fragen
    WHERE coalesce(geloescht, false) = false
    GROUP BY verbund_id
  ),
  empf AS (       -- Empfänger: aktive Verbund-Mitglieder, opted-in, diese Woche noch nicht versorgt
    SELECT DISTINCT m.user_id, f.verbund_id, u.email,
      nullif(btrim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')), '') AS nm,
      coalesce(pr.sprache, 'de') AS spr
    FROM public.mitgliedschaften m
    JOIN public.familien f  ON f.id = m.familie_id
    JOIN auth.users u       ON u.id = m.user_id
    LEFT JOIN public.profile pr ON pr.user_id = m.user_id
    WHERE coalesce(m.aktiv, true) = true
      AND u.email IS NOT NULL
      AND f.verbund_id IS NOT NULL
      AND NOT EXISTS (   -- Opt-out: irgendeine Familienzeile dieses Verbunds explizit auf false
        SELECT 1 FROM public.benachrichtigungs_einstellungen e
        JOIN public.familien fe ON fe.id = e.familie_id
        WHERE e.user_id = m.user_id AND fe.verbund_id = f.verbund_id
          AND e.email_woechentlicher_digest = false
      )
      AND NOT EXISTS (   -- diese Woche bereits versendet
        SELECT 1 FROM public.digest_versand dv
        WHERE dv.user_id = m.user_id AND dv.verbund_id = f.verbund_id AND dv.woche_start = v_woche
      )
  )
  SELECT e.user_id, e.verbund_id, e.email::text, e.nm, e.spr, v_woche,
    coalesce(akt.c_beitraege,0)::int, coalesce(akt.c_fotos,0)::int, coalesce(akt.c_personen,0)::int,
    coalesce(akt.c_geschichten,0)::int, coalesce(akt.c_events,0)::int,
    coalesce(geb.namen, '[]'::jsonb), coalesce(ged.namen, '[]'::jsonb),
    coalesce(fragen.offen,0)::int, coalesce(fragen.neu,0)::int
  FROM empf e
  LEFT JOIN akt    ON akt.verbund_id    = e.verbund_id
  LEFT JOIN geb    ON geb.verbund_id    = e.verbund_id
  LEFT JOIN ged    ON ged.verbund_id    = e.verbund_id
  LEFT JOIN fragen ON fragen.verbund_id = e.verbund_id
  WHERE (coalesce(akt.c_beitraege,0) + coalesce(akt.c_fotos,0) + coalesce(akt.c_personen,0)
         + coalesce(akt.c_geschichten,0) + coalesce(akt.c_events,0)) > 0
     OR coalesce(jsonb_array_length(geb.namen), 0) > 0
     OR coalesce(jsonb_array_length(ged.namen), 0) > 0
     OR coalesce(fragen.neu, 0) > 0;
END $$;
REVOKE ALL ON FUNCTION public.digest_woche_sammeln(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.digest_woche_sammeln(date) TO service_role;


-- =====================================================
-- 4) Versand protokollieren (idempotent). p_rows = [{user_id, verbund_id, woche_start}, …]
-- =====================================================
CREATE OR REPLACE FUNCTION public.digest_markiere_gesendet(p_rows jsonb)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n int;
BEGIN
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN RETURN 0; END IF;
  INSERT INTO public.digest_versand (user_id, verbund_id, woche_start)
  SELECT (x->>'user_id')::uuid, (x->>'verbund_id')::uuid, (x->>'woche_start')::date
    FROM jsonb_array_elements(p_rows) x
  ON CONFLICT (user_id, verbund_id, woche_start) DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;
REVOKE ALL ON FUNCTION public.digest_markiere_gesendet(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.digest_markiere_gesendet(jsonb) TO service_role;


-- =====================================================
-- 5) Wöchentlicher Trigger via pg_cron + pg_net — NACH REVIEW EINMAL AUSFÜHREN
--    Voraussetzungen:
--      a) Extensions pg_cron UND pg_net aktivieren (Dashboard -> Database -> Extensions).
--      b) Edge Function `woechentlicher-digest` deployen (Dashboard -> Edge Functions,
--         Code: supabase/functions/woechentlicher-digest/index.ts) inkl. Secrets
--         (RESEND_API_KEY etc.) UND dem selbst vergebenen Secret CRON_SECRET.
--      c) Für diese Function „Verify JWT" AUS (dann zählt nur der Header x-cron-secret).
--      d) <PROJECT_REF> + <CRON_SECRET> einsetzen.
--    Montags 08:00 UTC:
--
--   -- SELECT cron.schedule(
--   --   'woechentlicher-digest', '0 8 * * 1',
--   --   $cron$
--   --     SELECT net.http_post(
--   --       url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/woechentlicher-digest',
--   --       headers := jsonb_build_object('Content-Type','application/json','x-cron-secret','<CRON_SECRET>'),
--   --       body    := '{}'::jsonb
--   --     );
--   --   $cron$
--   -- );
--   -- Aushängen: SELECT cron.unschedule('woechentlicher-digest');
--
--    Manueller Testlauf (liefert die Sammel-Zeilen, OHNE zu versenden):
--      SELECT * FROM public.digest_woche_sammeln();


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_woechentlicher_digest.sql ausgeführt — email_woechentlicher_digest + digest_versand + digest_woche_sammeln/markiere_gesendet (Edge Function + pg_net-Cron separat aktivieren)' AS status;
