-- ============================================================================
-- ABMELDEN / UNSUBSCRIBE — Ein-Klick-Abmeldung aus Erinnerungs-/Status-Mails
-- ----------------------------------------------------------------------------
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
-- Setzt die 5 Bool-Spalten in ALLEN benachrichtigungs_einstellungen-Zeilen des
-- Nutzers (alle familie_id) auf false — DIESELBE Tabelle/Spalten, die der Nutzer
-- im Profil manuell umschaltet (keine zweite Datenquelle). Aufruf ausschließlich
-- durch die Edge Function `abmelden` per service_role.
--
-- Sicherheit: Der Spaltenname kommt NIE aus dem Token ins SQL — der Typ wird gegen
-- eine feste Whitelist geprüft und auf STATISCHE Spaltennamen gemappt (CASE).
-- ============================================================================

-- 1) Spalten absichern (falls einzelne Migrationen noch nicht eingespielt sind).
ALTER TABLE public.benachrichtigungs_einstellungen
  ADD COLUMN IF NOT EXISTS email_geburtstage                   boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS email_gedenktage                    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS email_ungelesene_nachrichten        boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS email_ungelesene_benachrichtigungen boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS email_woechentlicher_digest         boolean NOT NULL DEFAULT true;

-- 2) Optionales Audit-Log (welcher Nutzer hat wann welchen Typ abbestellt).
--    RLS AN, KEINE Policies -> kein Client-Zugriff; nur service_role/SECURITY DEFINER schreibt.
CREATE TABLE IF NOT EXISTS public.abmelde_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid,
  typ         text NOT NULL,
  quelle      text,                              -- 'email' (GET-Klick) | 'oneclick' (RFC 8058 POST)
  erstellt_am timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.abmelde_log ENABLE ROW LEVEL SECURITY;

-- 3) RPC: Abmeldung anwenden. SECURITY DEFINER; nur service_role darf ausführen.
CREATE OR REPLACE FUNCTION public.abmelden_anwenden(
  p_user uuid, p_typ text, p_quelle text DEFAULT 'email')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_typ text := lower(btrim(coalesce(p_typ, '')));
BEGIN
  IF p_user IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'kein_user'); END IF;

  -- WHITELIST: Einzel-Spalten + zwei Gruppen (anlaesse/ungelesen) + alle.
  IF v_typ NOT IN (
        'email_geburtstage', 'email_gedenktage',
        'email_ungelesene_nachrichten', 'email_ungelesene_benachrichtigungen',
        'email_woechentlicher_digest',
        'anlaesse',   -- = geburtstage + gedenktage (anlaesse-erinnerung deckt beide ab)
        'ungelesen',  -- = ungelesene_nachrichten + ungelesene_benachrichtigungen
        'alle') THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'ungueltiger_typ');
  END IF;

  -- (a) Je Familie des Nutzers eine Zeile sicherstellen (Default = an). Sonst liefe das Abmelden
  --     bei „noch nie im Profil gespeichert" ins Leere (der Versand nimmt bool_or(...) = true an).
  INSERT INTO public.benachrichtigungs_einstellungen (familie_id, user_id)
  SELECT DISTINCT m.familie_id, p_user
    FROM public.mitgliedschaften m
   WHERE m.user_id = p_user AND m.familie_id IS NOT NULL
  ON CONFLICT (familie_id, user_id) DO NOTHING;

  -- (b) Zielspalte(n) in ALLEN Zeilen des Nutzers auf false (Spaltennamen STATISCH; idempotent).
  UPDATE public.benachrichtigungs_einstellungen SET
    email_geburtstage = CASE
      WHEN v_typ IN ('email_geburtstage', 'anlaesse', 'alle') THEN false ELSE email_geburtstage END,
    email_gedenktage = CASE
      WHEN v_typ IN ('email_gedenktage', 'anlaesse', 'alle') THEN false ELSE email_gedenktage END,
    email_ungelesene_nachrichten = CASE
      WHEN v_typ IN ('email_ungelesene_nachrichten', 'ungelesen', 'alle') THEN false ELSE email_ungelesene_nachrichten END,
    email_ungelesene_benachrichtigungen = CASE
      WHEN v_typ IN ('email_ungelesene_benachrichtigungen', 'ungelesen', 'alle') THEN false ELSE email_ungelesene_benachrichtigungen END,
    email_woechentlicher_digest = CASE
      WHEN v_typ IN ('email_woechentlicher_digest', 'alle') THEN false ELSE email_woechentlicher_digest END,
    updated_at = now()
  WHERE user_id = p_user;

  INSERT INTO public.abmelde_log (user_id, typ, quelle)
  VALUES (p_user, v_typ, coalesce(nullif(btrim(p_quelle), ''), 'email'));

  RETURN jsonb_build_object('ok', true, 'typ', v_typ);
END $$;

-- Nur service_role (Edge Function) darf abmelden_anwenden aufrufen — nie anon/authenticated.
REVOKE ALL ON FUNCTION public.abmelden_anwenden(uuid, text, text) FROM public;
REVOKE ALL ON FUNCTION public.abmelden_anwenden(uuid, text, text) FROM anon;
REVOKE ALL ON FUNCTION public.abmelden_anwenden(uuid, text, text) FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.abmelden_anwenden(uuid, text, text) TO service_role;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_abmelden.sql ausgeführt — abmelden_anwenden(uuid,text,text) + abmelde_log' AS status;
