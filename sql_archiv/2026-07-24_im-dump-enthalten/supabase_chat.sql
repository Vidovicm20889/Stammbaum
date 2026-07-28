-- =====================================================
-- CHAT (1:1 + Gruppen) — verbundweit (familien.verbund_id)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
-- Idempotent (mehrfaches Ausführen schadet nicht).
--
-- GELTUNGSBEREICH (CLAUDE.md): Ein Chat gehört zu genau EINEM verbund_id.
-- Chat-fähig sind nur Nutzer, die mit dem Aufrufer mindestens einen verbund_id
-- teilen (alle verknüpften Stammbäume desselben Verbunds). AUSNAHME (Nutzerwunsch,
-- siehe CLAUDE.md): super_admin nimmt IM CHAT voll teil (sicht-/anschreibbar wie ein
-- normaler Verbund-Nutzer), bleibt aber in allen anderen GUI-Bereichen unsichtbar und
-- kann fremde Chats NICHT lesen (SELECT ist strikt teilnehmer-gebunden).
--
-- TRANSPORT: Supabase Realtime (wie Baumdaten) — chat_nachrichten + chat_teilnehmer
-- haben echte RLS-SELECT-Policies und liegen in der Publication supabase_realtime.
--
-- Voraussetzungen: supabase_verbund.sql (verbund_id, sieht_familie/kann_familie_bearbeiten),
-- supabase_mitglieder_komplett.sql (ist_super_admin), supabase_profile.sql (profile).
-- =====================================================

-- =====================================================
-- 1) TABELLEN
-- =====================================================

CREATE TABLE IF NOT EXISTS public.chats (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id   uuid NOT NULL,
  typ          text NOT NULL CHECK (typ IN ('direkt', 'gruppe')),
  name         text,                       -- nur Gruppen
  direkt_key   text,                       -- Dedupe-Schlüssel für 1:1 (sortiertes Paar + verbund)
  erstellt_von uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  erstellt_am  timestamptz NOT NULL DEFAULT now()
);
-- Genau EIN 1:1-Chat je User-Paar je Verbund (verhindert Duplikate)
CREATE UNIQUE INDEX IF NOT EXISTS chats_direkt_key_uidx
  ON public.chats (direkt_key) WHERE direkt_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS chats_verbund_idx ON public.chats (verbund_id);

CREATE TABLE IF NOT EXISTS public.chat_teilnehmer (
  chat_id           uuid NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id           uuid NOT NULL REFERENCES auth.users(id)   ON DELETE CASCADE,
  ist_gruppen_admin boolean NOT NULL DEFAULT false,
  beigetreten_am    timestamptz NOT NULL DEFAULT now(),
  zuletzt_gelesen_am timestamptz,
  PRIMARY KEY (chat_id, user_id)
);
CREATE INDEX IF NOT EXISTS chat_teilnehmer_user_idx ON public.chat_teilnehmer (user_id);

CREATE TABLE IF NOT EXISTS public.chat_nachrichten (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id      uuid NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  absender_id  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  text         text,
  erstellt_am  timestamptz NOT NULL DEFAULT now(),
  bearbeitet_am timestamptz,
  geloescht    boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS chat_nachrichten_chat_zeit_idx
  ON public.chat_nachrichten (chat_id, erstellt_am);

ALTER TABLE public.chats           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_teilnehmer ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_nachrichten ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 2) HELFER (SECURITY DEFINER -> rekursionsfrei in den Policies)
-- =====================================================

-- Ist der eingeloggte Nutzer Teilnehmer dieses Chats?
-- DEFINER -> die Abfrage auf chat_teilnehmer löst die RLS-Policy NICHT erneut aus.
CREATE OR REPLACE FUNCTION public.ist_chat_teilnehmer(p_chat uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_teilnehmer t
    WHERE t.chat_id = p_chat AND t.user_id = auth.uid()
  );
$$;

-- Ist der eingeloggte Nutzer Gruppen-Admin dieses Chats?
CREATE OR REPLACE FUNCTION public.ist_chat_gruppen_admin(p_chat uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_teilnehmer t
    WHERE t.chat_id = p_chat AND t.user_id = auth.uid() AND t.ist_gruppen_admin
  );
$$;

-- Teilt p_user mindestens einen verbund_id mit dem eingeloggten Nutzer?
CREATE OR REPLACE FUNCTION public.teilt_verbund(p_user uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.mitgliedschaften m1
    JOIN public.familien f1 ON f1.id = m1.familie_id
    JOIN public.familien f2 ON f2.verbund_id = f1.verbund_id
    JOIN public.mitgliedschaften m2 ON m2.familie_id = f2.id
    WHERE m1.user_id = auth.uid()
      AND m2.user_id = p_user
  );
$$;

-- Ist p_user ein super_admin? (Helfer bleibt erhalten; im Chat AKTUELL ungenutzt,
-- seit super_admin voll teilnimmt — nützlich für evtl. spätere Rollen-Logik.)
CREATE OR REPLACE FUNCTION public.ist_super_admin_user(p_user uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mitgliedschaften m
    WHERE m.user_id = p_user AND m.rolle = 'super_admin' AND m.aktiv
  );
$$;

-- Darf der eingeloggte Nutzer diesen Chat verwalten (Teilnehmer entfernen,
-- Gruppen-Admin setzen)? -> Gruppen-Admin ODER owner/admin im Verbund des Chats.
CREATE OR REPLACE FUNCTION public.darf_chat_verwalten(p_chat uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT public.ist_chat_gruppen_admin(p_chat)
      OR EXISTS (
        SELECT 1
        FROM public.chats c
        JOIN public.familien f      ON f.verbund_id = c.verbund_id
        JOIN public.mitgliedschaften m ON m.familie_id = f.id
        WHERE c.id = p_chat
          AND m.user_id = auth.uid()
          AND m.rolle IN ('familien_owner', 'familien_admin')
          AND m.aktiv
      );
$$;

-- =====================================================
-- 3) RLS-POLICIES  (Schreiben läuft sonst über SECURITY-DEFINER-RPCs)
-- =====================================================

-- CHATS: nur Teilnehmer sehen den Chat. (Anlegen/Ändern nur über RPC.)
DROP POLICY IF EXISTS "chats_select" ON public.chats;
CREATE POLICY "chats_select" ON public.chats FOR SELECT
  USING ( public.ist_chat_teilnehmer(id) );

-- CHAT_TEILNEHMER: Teilnehmer sehen die Teilnehmerliste ihrer Chats
-- (echte RLS-SELECT-Policy -> Realtime liefert diese Zeilen aus).
DROP POLICY IF EXISTS "chat_teilnehmer_select" ON public.chat_teilnehmer;
CREATE POLICY "chat_teilnehmer_select" ON public.chat_teilnehmer FOR SELECT
  USING ( public.ist_chat_teilnehmer(chat_id) );

-- CHAT_NACHRICHTEN
-- SELECT: nur Teilnehmer (echte RLS-SELECT-Policy -> Realtime liefert sie aus).
DROP POLICY IF EXISTS "chat_nachrichten_select" ON public.chat_nachrichten;
CREATE POLICY "chat_nachrichten_select" ON public.chat_nachrichten FOR SELECT
  USING ( public.ist_chat_teilnehmer(chat_id) );

-- INSERT: nur Teilnehmer, nur als eigener Absender. (Senden läuft i. d. R. über
-- die RPC chat_nachricht_senden; diese Policy erlaubt zusätzlich den direkten Pfad.)
DROP POLICY IF EXISTS "chat_nachrichten_insert" ON public.chat_nachrichten;
CREATE POLICY "chat_nachrichten_insert" ON public.chat_nachrichten FOR INSERT
  WITH CHECK ( absender_id = auth.uid() AND public.ist_chat_teilnehmer(chat_id) );

-- UPDATE: nur der Absender (Bearbeiten / Soft-Delete via geloescht=true). Die
-- WITH-CHECK auf ist_chat_teilnehmer(chat_id) verhindert, dass eine eigene Nachricht
-- per chat_id-Update in einen fremden Chat „verschoben"/eingeschleust wird.
DROP POLICY IF EXISTS "chat_nachrichten_update" ON public.chat_nachrichten;
CREATE POLICY "chat_nachrichten_update" ON public.chat_nachrichten FOR UPDATE
  USING ( absender_id = auth.uid() )
  WITH CHECK ( absender_id = auth.uid() AND public.ist_chat_teilnehmer(chat_id) );

-- (KEINE DELETE-Policy: Nachrichten werden NICHT hart gelöscht -> geloescht=true.)

-- =====================================================
-- 4) RPCs  (SECURITY DEFINER, geben nur erlaubte Daten zurück)
-- =====================================================

-- 4a) Chat-fähige Nutzer des Verbunds (für „Neuer Chat").
--     Schließt NUR den Aufrufer selbst aus (super_admin nimmt im Chat teil — Nutzerwunsch).
--     Anzeigename/Avatar aus profile (fremde profile-Zeilen sind per RLS nicht direkt
--     lesbar -> DEFINER).
DROP FUNCTION IF EXISTS public.verbund_nutzer();
CREATE OR REPLACE FUNCTION public.verbund_nutzer()
RETURNS TABLE(
  user_id     uuid,
  anzeigename text,
  avatar_url  text,
  familie_name text,
  baum_namen  text
)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  WITH meine_verbuende AS (
    SELECT DISTINCT f.verbund_id
    FROM public.mitgliedschaften m
    JOIN public.familien f ON f.id = m.familie_id
    WHERE m.user_id = auth.uid()
  ),
  kandidaten AS (
    SELECT DISTINCT m.user_id, f.id AS familie_id, f.name AS familie_name
    FROM public.mitgliedschaften m
    JOIN public.familien f ON f.id = m.familie_id
    JOIN meine_verbuende mv ON mv.verbund_id = f.verbund_id
    WHERE m.aktiv
      AND m.user_id <> auth.uid()
      -- super_admin NIMMT im Chat voll teil (Nutzerwunsch, Ausnahme zur GUI-Unsichtbarkeit,
      -- siehe CLAUDE.md) -> NICHT mehr ausschließen.
  ),
  -- pro Nutzer EINE Familie (alphabetisch erste) als Kontext
  pro_user AS (
    SELECT DISTINCT ON (k.user_id) k.user_id, k.familie_id, k.familie_name
    FROM kandidaten k
    ORDER BY k.user_id, k.familie_name
  )
  SELECT
    pu.user_id,
    COALESCE(
      NULLIF(btrim(concat_ws(' ', p.vorname, p.nachname)), ''),
      initcap(replace(replace(replace(split_part(u.email, '@', 1), '.', ' '), '_', ' '), '-', ' ')),
      u.email
    ) AS anzeigename,
    CASE WHEN COALESCE(p.avatar_sichtbarkeit, 'verbund') <> 'privat'
         THEN COALESCE(p.avatar_thumb_url, p.avatar_url) END AS avatar_url,
    pu.familie_name,
    (SELECT string_agg(DISTINCT s.name, ', ' ORDER BY s.name)
       FROM public.stammbaeume s WHERE s.familie_id = pu.familie_id) AS baum_namen
  FROM pro_user pu
  JOIN auth.users u ON u.id = pu.user_id
  LEFT JOIN public.profile p ON p.user_id = pu.user_id
  ORDER BY anzeigename;
$$;
GRANT EXECUTE ON FUNCTION public.verbund_nutzer() TO authenticated;

-- 4b) 1:1-Chat finden oder anlegen (idempotent, keine Duplikate).
DROP FUNCTION IF EXISTS public.direkt_chat_finden_oder_anlegen(uuid);
CREATE OR REPLACE FUNCTION public.direkt_chat_finden_oder_anlegen(p_user2 uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_key  text;
  v_chat uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Nicht eingeloggt.'; END IF;
  IF p_user2 IS NULL OR p_user2 = v_me THEN RAISE EXCEPTION 'Ungültiger Gesprächspartner.'; END IF;
  -- (super_admin als Gegenüber bewusst NICHT mehr geblockt — nimmt im Chat voll teil.)
  IF NOT public.teilt_verbund(p_user2) THEN
    RAISE EXCEPTION 'Kein gemeinsamer Verbund.';
  END IF;

  -- gemeinsamen Verbund bestimmen (stabil: kleinste gemeinsame verbund_id).
  -- HINWEIS: uuid hat KEIN min()-Aggregat in Postgres -> ORDER BY + LIMIT 1 statt MIN().
  SELECT f1.verbund_id INTO v_verb
  FROM public.mitgliedschaften m1
  JOIN public.familien f1 ON f1.id = m1.familie_id
  JOIN public.familien f2 ON f2.verbund_id = f1.verbund_id
  JOIN public.mitgliedschaften m2 ON m2.familie_id = f2.id
  WHERE m1.user_id = v_me AND m2.user_id = p_user2
  ORDER BY f1.verbund_id
  LIMIT 1;

  IF v_verb IS NULL THEN RAISE EXCEPTION 'Kein gemeinsamer Verbund.'; END IF;

  v_key := LEAST(v_me::text, p_user2::text) || '|' ||
           GREATEST(v_me::text, p_user2::text) || '|' || v_verb::text;

  SELECT id INTO v_chat FROM public.chats WHERE direkt_key = v_key;
  IF v_chat IS NOT NULL THEN RETURN v_chat; END IF;

  -- ON CONFLICT muss die WHERE-Bedingung des PARTIELLEN Unique-Index
  -- (chats_direkt_key_uidx ... WHERE direkt_key IS NOT NULL) mitführen, sonst
  -- findet Postgres keinen passenden Index und wirft eine Exception.
  INSERT INTO public.chats (verbund_id, typ, direkt_key, erstellt_von)
  VALUES (v_verb, 'direkt', v_key, v_me)
  ON CONFLICT (direkt_key) WHERE direkt_key IS NOT NULL DO NOTHING
  RETURNING id INTO v_chat;

  IF v_chat IS NULL THEN  -- Race: jemand anders hat ihn parallel angelegt
    SELECT id INTO v_chat FROM public.chats WHERE direkt_key = v_key;
  END IF;

  INSERT INTO public.chat_teilnehmer (chat_id, user_id, beigetreten_am)
  VALUES (v_chat, v_me, now()), (v_chat, p_user2, now())
  ON CONFLICT (chat_id, user_id) DO NOTHING;

  RETURN v_chat;
END $$;
GRANT EXECUTE ON FUNCTION public.direkt_chat_finden_oder_anlegen(uuid) TO authenticated;

-- 4c) Gruppenchat anlegen. Ersteller = Gruppen-Admin. Alle p_user_ids müssen
--     denselben Verbund mit dem Ersteller teilen (super_admin darf dabei sein).
DROP FUNCTION IF EXISTS public.gruppen_chat_anlegen(text, uuid[]);
CREATE OR REPLACE FUNCTION public.gruppen_chat_anlegen(p_name text, p_user_ids uuid[])
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_uid  uuid;
  v_chat uuid;
  v_anz  int;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Nicht eingeloggt.'; END IF;
  IF p_name IS NULL OR btrim(p_name) = '' THEN RAISE EXCEPTION 'Gruppenname fehlt.'; END IF;
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'Keine Teilnehmer gewählt.';
  END IF;

  -- gemeinsamen Verbund finden, dem der Ersteller UND alle gewählten Nutzer angehören:
  -- ein Verbund des Aufrufers, in dem genauso viele der gewählten (Nicht-Selbst-)Nutzer
  -- Mitglied sind wie gewählt wurden.
  SELECT f.verbund_id INTO v_verb
  FROM public.mitgliedschaften m
  JOIN public.familien f ON f.id = m.familie_id
  WHERE m.user_id = v_me
    AND (SELECT count(DISTINCT u) FROM unnest(p_user_ids) AS u WHERE u <> v_me)
      = (SELECT count(DISTINCT mm.user_id)
           FROM public.mitgliedschaften mm
           JOIN public.familien ff ON ff.id = mm.familie_id
          WHERE ff.verbund_id = f.verbund_id
            AND mm.user_id = ANY(p_user_ids)
            AND mm.user_id <> v_me)
  GROUP BY f.verbund_id
  ORDER BY f.verbund_id
  LIMIT 1;

  IF v_verb IS NULL THEN
    RAISE EXCEPTION 'Alle Teilnehmer müssen denselben Verbund teilen.';
  END IF;

  INSERT INTO public.chats (verbund_id, typ, name, erstellt_von)
  VALUES (v_verb, 'gruppe', btrim(p_name), v_me)
  RETURNING id INTO v_chat;

  INSERT INTO public.chat_teilnehmer (chat_id, user_id, ist_gruppen_admin, beigetreten_am)
  VALUES (v_chat, v_me, true, now());

  FOREACH v_uid IN ARRAY p_user_ids LOOP
    IF v_uid <> v_me THEN   -- super_admin darf als normaler Teilnehmer dabei sein
      INSERT INTO public.chat_teilnehmer (chat_id, user_id, ist_gruppen_admin, beigetreten_am)
      VALUES (v_chat, v_uid, false, now())
      ON CONFLICT (chat_id, user_id) DO NOTHING;
    END IF;
  END LOOP;

  RETURN v_chat;
END $$;
GRANT EXECUTE ON FUNCTION public.gruppen_chat_anlegen(text, uuid[]) TO authenticated;

-- 4d) Nachricht senden (Teilnehmer-Prüfung), gibt die Zeile zurück.
DROP FUNCTION IF EXISTS public.chat_nachricht_senden(uuid, text);
CREATE OR REPLACE FUNCTION public.chat_nachricht_senden(p_chat uuid, p_text text)
RETURNS public.chat_nachrichten
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me  uuid := auth.uid();
  v_row public.chat_nachrichten;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Nicht eingeloggt.'; END IF;
  IF NOT public.ist_chat_teilnehmer(p_chat) THEN
    RAISE EXCEPTION 'Kein Teilnehmer dieses Chats.';
  END IF;
  IF p_text IS NULL OR btrim(p_text) = '' THEN RAISE EXCEPTION 'Leere Nachricht.'; END IF;

  INSERT INTO public.chat_nachrichten (chat_id, absender_id, text)
  VALUES (p_chat, v_me, btrim(p_text))
  RETURNING * INTO v_row;

  UPDATE public.chat_teilnehmer
     SET zuletzt_gelesen_am = now()
   WHERE chat_id = p_chat AND user_id = v_me;

  RETURN v_row;
END $$;
GRANT EXECUTE ON FUNCTION public.chat_nachricht_senden(uuid, text) TO authenticated;

-- 4e) Chat als gelesen markieren (eigene zuletzt_gelesen_am).
DROP FUNCTION IF EXISTS public.chat_gelesen(uuid);
CREATE OR REPLACE FUNCTION public.chat_gelesen(p_chat uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.ist_chat_teilnehmer(p_chat) THEN RETURN; END IF;
  UPDATE public.chat_teilnehmer
     SET zuletzt_gelesen_am = now()
   WHERE chat_id = p_chat AND user_id = auth.uid();
END $$;
GRANT EXECUTE ON FUNCTION public.chat_gelesen(uuid) TO authenticated;

-- 4f) Teilnehmer entfernen. Erlaubt: man selbst (Gruppe verlassen) ODER
--     Verwalter (Gruppen-Admin / owner/admin im Verbund).
DROP FUNCTION IF EXISTS public.chat_teilnehmer_entfernen(uuid, uuid);
CREATE OR REPLACE FUNCTION public.chat_teilnehmer_entfernen(p_chat uuid, p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_user <> auth.uid() AND NOT public.darf_chat_verwalten(p_chat) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  DELETE FROM public.chat_teilnehmer WHERE chat_id = p_chat AND user_id = p_user;
  -- Verwaiste Gruppe ohne Teilnehmer aufräumen (referenzielle Konsistenz).
  DELETE FROM public.chats c
   WHERE c.id = p_chat
     AND NOT EXISTS (SELECT 1 FROM public.chat_teilnehmer t WHERE t.chat_id = c.id);
END $$;
GRANT EXECUTE ON FUNCTION public.chat_teilnehmer_entfernen(uuid, uuid) TO authenticated;

-- 4g) Gruppen-Admin setzen/entziehen (nur Verwalter).
DROP FUNCTION IF EXISTS public.chat_gruppen_admin_setzen(uuid, uuid, boolean);
CREATE OR REPLACE FUNCTION public.chat_gruppen_admin_setzen(p_chat uuid, p_user uuid, p_wert boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.darf_chat_verwalten(p_chat) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  UPDATE public.chat_teilnehmer SET ist_gruppen_admin = p_wert
   WHERE chat_id = p_chat AND user_id = p_user;
END $$;
GRANT EXECUTE ON FUNCTION public.chat_gruppen_admin_setzen(uuid, uuid, boolean) TO authenticated;

-- =====================================================
-- 5) REALTIME-PUBLICATION (wie Baumdaten)
--    chat_nachrichten + chat_teilnehmer live ausliefern.
-- =====================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

DO $$
DECLARE
  t text;
  tabellen text[] := ARRAY['chat_nachrichten', 'chat_teilnehmer'];
BEGIN
  FOREACH t IN ARRAY tabellen LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
      RAISE NOTICE 'Realtime aktiviert für public.%', t;
    ELSE
      RAISE NOTICE 'public.% bereits in Publication supabase_realtime', t;
    END IF;
  END LOOP;
END $$;

-- Vollständige alte Zeile bei UPDATE/DELETE mitsenden (für DELETE-Erkennung im Client).
ALTER TABLE public.chat_nachrichten REPLICA IDENTITY FULL;
ALTER TABLE public.chat_teilnehmer  REPLICA IDENTITY FULL;

-- PostgREST-Schema neu laden, damit die neuen RPCs sofort verfügbar sind.
NOTIFY pgrst, 'reload schema';

SELECT 'supabase_chat.sql ausgeführt — Chat (1:1 + Gruppen, verbundweit) eingerichtet' AS status;
