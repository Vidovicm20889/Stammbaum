-- =====================================================
-- E-MAIL-ERINNERUNG BEI UNGELESENER AKTIVITÄT (Chat + Benachrichtigungen)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT (mehrfach ausführbar).
--
-- ZWECK: Wenn eine Chat-Nachricht ODER eine Benachrichtigung 12 Stunden lang NICHT in der App
-- gelesen wurde, bekommt der Nutzer EINE zusammenfassende Erinnerungs-Mail (nur Anzahl + Link,
-- KEINE Inhalte). Auslöser ist das NICHT-Gelesenhaben binnen 12 h. Versand über die Edge Function
-- `ungelesen-erinnerung` (Resend), per pg_cron stündlich getriggert.
--
-- DATENSCHUTZ: Die Mail enthält NUR Zähler (X ungelesene Nachrichten / Y ungelesene
-- Benachrichtigungen) + App-Link. KEINE Nachrichtentexte, KEINE Personendaten.
--
-- ANTI-DOPPEL-MAIL: Tabelle `erinnerungs_mails` protokolliert je (user, anlass_typ, anlass_ref)
-- — pro ungelesenem Anlass (= einzelne Nachricht / Benachrichtigung) wird HÖCHSTENS EINE Mail je
-- Nutzer verschickt. Liest der Nutzer, fällt der Anlass aus der Ungelesen-Berechnung -> kein
-- Versand mehr (zusätzlich durch das Protokoll gesperrt).
--
-- OPT-OUT: zwei Schalter je Nutzer in `benachrichtigungs_einstellungen` (Default true =
-- eingeschaltet). Das Frontend schreibt sie (wie die Anlass-Einstellungen) je Familie; die
-- Sende-Logik wertet sie per bool_or (default true, wenn keine Zeile) NUTZERWEIT aus.
--
-- Voraussetzungen: supabase_chat.sql (chat_nachrichten/chat_teilnehmer),
--   supabase_benachrichtigungen.sql (benachrichtigungen: user_id/gelesen/created_at),
--   supabase_benachrichtigungen_anlaesse.sql (benachrichtigungs_einstellungen),
--   supabase_profile.sql (profile: vorname/nachname/sprache).
-- =====================================================


-- =====================================================
-- 1) OPT-OUT-SPALTEN (an die bestehende Einstellungstabelle hängen; Default true)
-- =====================================================
ALTER TABLE public.benachrichtigungs_einstellungen
  ADD COLUMN IF NOT EXISTS email_ungelesene_nachrichten       boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS email_ungelesene_benachrichtigungen boolean NOT NULL DEFAULT true;


-- =====================================================
-- 2) VERSAND-PROTOKOLL (gegen Doppel-Mails)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.erinnerungs_mails (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlass_typ  text NOT NULL CHECK (anlass_typ IN ('chat', 'benachrichtigung')),
  anlass_ref  uuid NOT NULL,
  gesendet_am timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT erinnerungs_mails_uniq UNIQUE (user_id, anlass_typ, anlass_ref)
);
CREATE INDEX IF NOT EXISTS erinnerungs_mails_user_idx ON public.erinnerungs_mails(user_id);

ALTER TABLE public.erinnerungs_mails ENABLE ROW LEVEL SECURITY;
-- Nutzer darf NUR sein eigenes Protokoll lesen (rekursionsfrei, kein Self-Subquery).
-- Schreiben ausschließlich über die SECURITY-DEFINER-RPC (service_role-Kontext).
DROP POLICY IF EXISTS erinnerungs_mails_select_own ON public.erinnerungs_mails;
CREATE POLICY erinnerungs_mails_select_own ON public.erinnerungs_mails
  FOR SELECT USING (auth.uid() = user_id);


-- =====================================================
-- 3) RPC: OFFENE ERINNERUNGEN (nur service_role; vom Cron/Edge-Kontext aufgerufen)
--    Liefert je Nutzer GEBÜNDELT: Empfänger-Mail/Name/Sprache, Anzahl + Referenzen der
--    NEUEN (noch nicht gemailten) ungelesenen Anlässe (>12 h), gefiltert nach Opt-in.
--    Lese-Status wird ZUM AUFRUFZEITPUNKT ausgewertet -> inzwischen Gelesenes fällt heraus.
-- =====================================================
CREATE OR REPLACE FUNCTION public.ungelesen_erinnerung_offen()
RETURNS TABLE(
  user_id        uuid,
  email          text,
  name           text,
  sprache        text,
  anzahl_chat    int,
  anzahl_benachr int,
  chat_refs      uuid[],
  benachr_refs   uuid[]
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH cutoff AS (SELECT now() - interval '12 hours' AS ts),
  -- Opt-in je Nutzer (default true, wenn KEINE Einstellungszeile existiert)
  pref AS (
    SELECT e.user_id,
           coalesce(bool_or(e.email_ungelesene_nachrichten), true)        AS chat_an,
           coalesce(bool_or(e.email_ungelesene_benachrichtigungen), true) AS benachr_an
      FROM public.benachrichtigungs_einstellungen e
     GROUP BY e.user_id
  ),
  -- (a) Ungelesene Chat-Nachrichten: >12 h alt, nach zuletzt_gelesen_am, NICHT vom Nutzer selbst,
  --     nicht gelöscht, noch nicht protokolliert. Eine Zeile je (Empfänger, Nachricht).
  chat_unread AS (
    SELECT t.user_id, m.id AS ref
      FROM public.chat_nachrichten m
      JOIN public.chat_teilnehmer t ON t.chat_id = m.chat_id
      CROSS JOIN cutoff c
     WHERE m.erstellt_am < c.ts
       AND m.geloescht = false
       AND m.absender_id IS DISTINCT FROM t.user_id
       AND (t.zuletzt_gelesen_am IS NULL OR m.erstellt_am > t.zuletzt_gelesen_am)
       AND NOT EXISTS (
         SELECT 1 FROM public.erinnerungs_mails em
          WHERE em.user_id = t.user_id AND em.anlass_typ = 'chat' AND em.anlass_ref = m.id)
  ),
  -- (b) Ungelesene Benachrichtigungen: gelesen=false, >12 h alt, noch nicht protokolliert.
  benachr_unread AS (
    SELECT b.user_id, b.id AS ref
      FROM public.benachrichtigungen b
      CROSS JOIN cutoff c
     WHERE b.gelesen = false
       AND b.created_at < c.ts
       AND NOT EXISTS (
         SELECT 1 FROM public.erinnerungs_mails em
          WHERE em.user_id = b.user_id AND em.anlass_typ = 'benachrichtigung' AND em.anlass_ref = b.id)
  ),
  chat_agg AS (
    SELECT cu.user_id, array_agg(cu.ref) AS refs, count(*)::int AS anz
      FROM chat_unread cu
      LEFT JOIN pref p ON p.user_id = cu.user_id
     WHERE coalesce(p.chat_an, true)
     GROUP BY cu.user_id
  ),
  benachr_agg AS (
    SELECT bu.user_id, array_agg(bu.ref) AS refs, count(*)::int AS anz
      FROM benachr_unread bu
      LEFT JOIN pref p ON p.user_id = bu.user_id
     WHERE coalesce(p.benachr_an, true)
     GROUP BY bu.user_id
  ),
  betroffene AS (
    SELECT chat_agg.user_id FROM chat_agg
    UNION
    SELECT benachr_agg.user_id FROM benachr_agg
  )
  SELECT
    u.user_id,
    au.email::text AS email,
    nullif(btrim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')), '') AS name,
    coalesce(pr.sprache, 'de') AS sprache,
    coalesce(ca.anz, 0)  AS anzahl_chat,
    coalesce(ba.anz, 0)  AS anzahl_benachr,
    coalesce(ca.refs, ARRAY[]::uuid[]) AS chat_refs,
    coalesce(ba.refs, ARRAY[]::uuid[]) AS benachr_refs
  FROM betroffene u
  JOIN auth.users au       ON au.id = u.user_id
  LEFT JOIN public.profile pr ON pr.user_id = u.user_id
  LEFT JOIN chat_agg ca    ON ca.user_id = u.user_id
  LEFT JOIN benachr_agg ba ON ba.user_id = u.user_id
  WHERE au.email IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.ungelesen_erinnerung_offen() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ungelesen_erinnerung_offen() TO service_role;


-- =====================================================
-- 4) RPC: ALS GESENDET PROTOKOLLIEREN (nur service_role). Idempotent (ON CONFLICT DO NOTHING).
-- =====================================================
CREATE OR REPLACE FUNCTION public.ungelesen_erinnerung_erledigt(
  p_user uuid, p_chat_refs uuid[], p_benachr_refs uuid[]
) RETURNS int
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH ins AS (
    INSERT INTO public.erinnerungs_mails(user_id, anlass_typ, anlass_ref)
    SELECT p_user, 'chat', r           FROM unnest(coalesce(p_chat_refs, ARRAY[]::uuid[]))    AS r
    UNION ALL
    SELECT p_user, 'benachrichtigung', r FROM unnest(coalesce(p_benachr_refs, ARRAY[]::uuid[])) AS r
    ON CONFLICT (user_id, anlass_typ, anlass_ref) DO NOTHING
    RETURNING 1
  )
  SELECT count(*)::int FROM ins;
$$;

REVOKE ALL ON FUNCTION public.ungelesen_erinnerung_erledigt(uuid, uuid[], uuid[]) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ungelesen_erinnerung_erledigt(uuid, uuid[], uuid[]) TO service_role;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_ungelesen_erinnerung.sql ausgeführt — Opt-out-Spalten + erinnerungs_mails + RPCs ungelesen_erinnerung_offen/erledigt' AS status;


-- =====================================================
-- 5) AKTIVIERUNG (abstimmungs-/setup-pflichtig — NICHT automatisch):
--    Edge Function `ungelesen-erinnerung` übers Dashboard deployen (Secrets wie die anderen
--    Functions: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY, CRON_SECRET, optional
--    MAIL_FROM/APP_URL/TEST_EMAIL). Dann pg_cron + pg_net aktivieren und stündlich aufrufen.
--    Ersetze <PROJEKT-REF> und <CRON_SECRET> durch die echten Werte. EINMAL ausführen:
--
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
--   CREATE EXTENSION IF NOT EXISTS pg_net;
--   SELECT cron.schedule('ungelesen-erinnerung', '0 * * * *', $cron$
--     SELECT net.http_post(
--       url     := 'https://<PROJEKT-REF>.functions.supabase.co/ungelesen-erinnerung',
--       headers := jsonb_build_object('Content-Type','application/json','x-cron-secret','<CRON_SECRET>'),
--       body    := '{}'::jsonb
--     );
--   $cron$);
-- =====================================================
