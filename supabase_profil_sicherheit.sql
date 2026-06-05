-- =====================================================
-- PROFIL — SICHERHEITSBEREICH (Phase 2)
-- Letzter Login / Letzte Passwortänderung / Aktive Sitzungen + "andere abmelden".
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent: mehrfach ausführbar.
--
-- Bewusst über SECURITY-DEFINER-RPCs (KEINE Edge Function nötig): auth.users/auth.sessions
-- sind weder per RLS-SELECT noch vom Client lesbar. Eine DEFINER-Funktion (Owner = postgres)
-- liest sie und gibt AUSSCHLIESSLICH die Daten des Aufrufers zurück (Filter auth.uid()).
-- Stack-konform (CLAUDE.md: Schreib-/Lese-Logik bevorzugt als SECURITY-DEFINER-RPC).
--
-- Hinweis "Letzte Passwortänderung": Supabase/GoTrue hat dafür KEIN natives Feld. Wir tracken
-- es selbst in profile.pw_geaendert_am (Frontend setzt es nach erfolgreichem updateUser).
-- =====================================================


-- 1) profile: Zeitpunkt der letzten (in-App) Passwortänderung -----------------
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS pw_geaendert_am timestamptz;


-- 2) Sicherheits-Infos des eingeloggten Nutzers (NUR eigene Daten) ------------
CREATE OR REPLACE FUNCTION public.meine_sicherheit_info()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_cur     uuid;
  v_last    timestamptz;
  v_created timestamptz;
  v_pw      timestamptz;
  v_sess    jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'nicht_angemeldet');
  END IF;

  -- aktuelle Session aus dem JWT (markiert "diese Sitzung")
  BEGIN
    v_cur := (auth.jwt() ->> 'session_id')::uuid;
  EXCEPTION WHEN others THEN v_cur := NULL;
  END;

  SELECT u.last_sign_in_at, u.created_at
    INTO v_last, v_created
    FROM auth.users u WHERE u.id = v_uid;

  SELECT p.pw_geaendert_am INTO v_pw
    FROM public.profile p WHERE p.user_id = v_uid;

  -- aktive Sitzungen (jüngste zuerst)
  SELECT coalesce(jsonb_agg(t.s ORDER BY t.letzte DESC), '[]'::jsonb)
    INTO v_sess
    FROM (
      SELECT jsonb_build_object(
               'id',       se.id,
               'erstellt', se.created_at,
               'letzte',   coalesce(se.refreshed_at, se.updated_at, se.created_at),
               'geraet',   se.user_agent,
               'ip',       host(se.ip),
               'aktuell',  (se.id = v_cur)
             ) AS s,
             coalesce(se.refreshed_at, se.updated_at, se.created_at) AS letzte
        FROM auth.sessions se
       WHERE se.user_id = v_uid
    ) t;

  RETURN jsonb_build_object(
    'ok',              true,
    'letzter_login',   v_last,
    'registriert',     v_created,
    'pw_geaendert',    v_pw,
    'sitzungen',       v_sess,
    'aktuelle_bekannt', (v_cur IS NOT NULL)
  );
END $$;


-- 3) Alle ANDEREN Sitzungen abmelden (aktuelle bleibt) ------------------------
--    Löscht die übrigen auth.sessions-Zeilen -> deren Refresh-Token wird ungültig.
CREATE OR REPLACE FUNCTION public.andere_sitzungen_abmelden()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_cur uuid;
  v_n   int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'nicht_angemeldet');
  END IF;

  BEGIN
    v_cur := (auth.jwt() ->> 'session_id')::uuid;
  EXCEPTION WHEN others THEN v_cur := NULL;
  END;

  -- Ohne bekannte aktuelle Session NICHT löschen (sonst würde man sich selbst ausloggen).
  IF v_cur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'aktuelle_unbekannt');
  END IF;

  WITH del AS (
    DELETE FROM auth.sessions se
     WHERE se.user_id = v_uid AND se.id <> v_cur
    RETURNING se.id
  )
  SELECT count(*) INTO v_n FROM del;

  RETURN jsonb_build_object('ok', true, 'abgemeldet', v_n);
END $$;


-- 4) Rechte: nur eingeloggte Nutzer dürfen die (auf sich selbst beschränkten) RPCs nutzen
GRANT EXECUTE ON FUNCTION public.meine_sicherheit_info()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.andere_sitzungen_abmelden()  TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Profil-Sicherheit (Phase 2) angelegt: meine_sicherheit_info(), andere_sitzungen_abmelden()' AS status;
