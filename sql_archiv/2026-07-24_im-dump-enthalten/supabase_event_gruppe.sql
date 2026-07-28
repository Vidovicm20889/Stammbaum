-- =====================================================
-- GRUPPEN-KALENDER — ein Event kann optional einer CHAT-GRUPPE zugeordnet werden;
-- deren Mitglieder sehen es zusätzlich (auch wenn es eingeschränkt ist).
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- SETZT supabase_event_eingeladene_user.sql (darf_event_sehen) + supabase_chat.sql
-- (chats/chat_teilnehmer/ist_chat_teilnehmer) VORAUS.
--
-- BEWUSST: KEINE neue Gruppen-Entität — eine chats(typ='gruppe') IST die Usergruppe,
-- chat_teilnehmer sind die Kalender-Mitglieder (Variante A, vom Nutzer gewählt).
-- WICHTIG: erweitert die ZENTRALE Sichtbarkeits-RPC darf_event_sehen additiv (nur LESEN).
-- VOR Ausführung Daten-Backup/Tag empfohlen (zentrale Funktion).
-- =====================================================

-- 1) Event -> optionale Chat-Gruppe -------------------------------------------
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS chat_id uuid REFERENCES public.chats(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS events_chat_idx ON public.events(chat_id);


-- 2) darf_event_sehen ADDITIV erweitern: Gruppen-Mitglieder dürfen sehen ------
--    Original-Logik unverändert + ODER (chat_id gesetzt UND ich bin Chat-Teilnehmer).
CREATE OR REPLACE FUNCTION public.darf_event_sehen(p_event_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.events e
    WHERE e.id = p_event_id
      AND (
        public.ist_super_admin()
        OR (e.chat_id IS NOT NULL AND public.ist_chat_teilnehmer(e.chat_id))
        OR (
          public.sieht_familie(e.familie_id)
          AND (
            NOT e.sichtbar_eingeschraenkt
            OR public.kann_familie_bearbeiten(e.familie_id)
            OR EXISTS (
              SELECT 1 FROM public.event_eingeladene ee
               WHERE ee.event_id = e.id AND ee.user_id = auth.uid()
            )
          )
        )
      )
  );
$$;
GRANT EXECUTE ON FUNCTION public.darf_event_sehen(uuid) TO authenticated;


-- 3) Meine Chat-Gruppen (für die Kalender-Auswahl im Event-Editor) ------------
CREATE OR REPLACE FUNCTION public.meine_gruppen_kalender()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name)
           ORDER BY c.name), '[]'::jsonb)
    FROM public.chats c
   WHERE c.typ = 'gruppe' AND public.ist_chat_teilnehmer(c.id);
$$;
GRANT EXECUTE ON FUNCTION public.meine_gruppen_kalender() TO authenticated;


-- 4) Event einem Gruppen-Kalender zuordnen / lösen ----------------------------
--    Nur Bearbeiter der Event-Familie; bei gesetzter Gruppe muss der Aufrufer
--    Mitglied der Gruppe sein (sonst könnte er fremde Events einer Gruppe unterschieben).
CREATE OR REPLACE FUNCTION public.event_kalender_setzen(p_event uuid, p_chat_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  IF p_chat_id IS NOT NULL THEN
    IF NOT public.ist_chat_teilnehmer(p_chat_id) THEN RAISE EXCEPTION 'Keine Gruppen-Mitgliedschaft.'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.chats WHERE id = p_chat_id AND typ = 'gruppe') THEN
      RAISE EXCEPTION 'Keine Gruppe.'; END IF;
  END IF;
  UPDATE public.events SET chat_id = p_chat_id WHERE id = p_event;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.event_kalender_setzen(uuid, uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'OK: events.chat_id + darf_event_sehen(Gruppen) + meine_gruppen_kalender + event_kalender_setzen angelegt' AS status;
