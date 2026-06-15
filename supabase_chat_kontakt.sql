-- =====================================================
-- CHAT-ERGÄNZUNG: verbundübergreifende Kontakt-Chats (Stufe 2)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
-- NACH supabase_chat.sql UND supabase_kontakt_anfragen.sql ausführen.
--
-- ZWECK: Ein per kontakt_verbindungen genehmigtes Konto-Paar darf 1:1 chatten, AUCH wenn es
-- KEINEN gemeinsamen Verbund hat. Der bestehende Verbund-Chat bleibt unverändert; diese Datei
-- erweitert NUR die Anlage-RPC und erlaubt verbund-lose Direkt-Chats.
--
-- WARUM verbund_id nullable: chats.verbund_id wird nur für die "Neuer Chat"-Liste (verbund_nutzer)
-- und den Direkt-Dedupe-Key genutzt. Die Chat-RLS ist rein TEILNEHMER-basiert
-- (ist_chat_teilnehmer) -> ein verbund-loser Kontakt-Chat ist sicher (nur die 2 Beteiligten
-- sehen ihn). Kontakt-Partner werden NICHT über verbund_nutzer(), sondern über meine_kontakte()
-- gelistet -> der Verbund-Chat-Flow ändert sich nicht.
-- =====================================================

-- 1) verbund_id darf für Kontakt-Chats NULL sein.
ALTER TABLE public.chats ALTER COLUMN verbund_id DROP NOT NULL;


-- 2) 1:1-Chat finden/anlegen — Verbund ODER genehmigte Kontakt-Verbindung.
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

  IF public.teilt_verbund(p_user2) THEN
    -- ----- bestehender Verbund-Pfad (unverändert) -----
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

  ELSIF public.darf_chatten(p_user2) THEN
    -- ----- verbundübergreifender Kontakt-Chat (genehmigte Verbindung) -----
    v_verb := NULL;
    v_key  := 'kontakt|' || LEAST(v_me::text, p_user2::text) || '|' || GREATEST(v_me::text, p_user2::text);

  ELSE
    RAISE EXCEPTION 'Kein gemeinsamer Verbund und keine Kontakt-Verbindung.';
  END IF;

  SELECT id INTO v_chat FROM public.chats WHERE direkt_key = v_key;
  IF v_chat IS NOT NULL THEN RETURN v_chat; END IF;

  INSERT INTO public.chats (verbund_id, typ, direkt_key, erstellt_von)
  VALUES (v_verb, 'direkt', v_key, v_me)
  ON CONFLICT (direkt_key) WHERE direkt_key IS NOT NULL DO NOTHING
  RETURNING id INTO v_chat;

  IF v_chat IS NULL THEN  -- Race: parallel angelegt
    SELECT id INTO v_chat FROM public.chats WHERE direkt_key = v_key;
  END IF;

  INSERT INTO public.chat_teilnehmer (chat_id, user_id, beigetreten_am)
  VALUES (v_chat, v_me, now()), (v_chat, p_user2, now())
  ON CONFLICT (chat_id, user_id) DO NOTHING;

  RETURN v_chat;
END $$;
GRANT EXECUTE ON FUNCTION public.direkt_chat_finden_oder_anlegen(uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_chat_kontakt.sql ausgeführt — verbundübergreifende Kontakt-Chats (verbund_id nullable, darf_chatten)' AS status;
