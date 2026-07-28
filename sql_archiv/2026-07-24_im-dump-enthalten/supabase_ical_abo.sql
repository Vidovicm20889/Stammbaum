-- =====================================================
-- iCAL-ABO — abonnierbarer Kalender-Feed (webcal). Phone/Desktop-Kalender ziehen
-- die Familien-Events automatisch. Ausführen in: Supabase -> SQL Editor. Idempotent.
-- SETZT das Event-System + supabase_profile.sql VORAUS.
--
-- Sicherheit: pro Konto ein zufälliges Token (profile.ical_token). Der Feed (Edge Function
-- ical-feed) ruft ical_feed(p_token) mit SERVICE-ROLE auf -> liefert NUR Events, die der
-- Token-Inhaber sehen darf (konservativ: nicht-eingeschränkte Events seines Verbunds +
-- Events, zu denen er eingeladen ist / die er angelegt hat). KEIN Leak eingeschränkter Events.
-- =====================================================

-- 1) Pro-Konto-Token ----------------------------------------------------------
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS ical_token uuid;

-- 2) Eigenes Token holen/erzeugen (für den Abo-Link im Frontend) --------------
CREATE OR REPLACE FUNCTION public.ical_token_get()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tok uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet.'; END IF;
  INSERT INTO public.profile (user_id, ical_token)
  VALUES (auth.uid(), gen_random_uuid())
  ON CONFLICT (user_id) DO UPDATE
     SET ical_token = coalesce(profile.ical_token, gen_random_uuid())
  RETURNING ical_token INTO v_tok;
  RETURN v_tok::text;
END $$;
GRANT EXECUTE ON FUNCTION public.ical_token_get() TO authenticated;

-- 3) Token zurücksetzen (alten Abo-Link entwerten) ----------------------------
CREATE OR REPLACE FUNCTION public.ical_token_reset()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tok uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet.'; END IF;
  UPDATE public.profile SET ical_token = gen_random_uuid()
   WHERE user_id = auth.uid() RETURNING ical_token INTO v_tok;
  IF v_tok IS NULL THEN RETURN public.ical_token_get(); END IF;
  RETURN v_tok::text;
END $$;
GRANT EXECUTE ON FUNCTION public.ical_token_reset() TO authenticated;

-- 4) Feed je Token (NUR Service-Role; von der Edge Function aufgerufen) --------
CREATE OR REPLACE FUNCTION public.ical_feed(p_token uuid)
RETURNS TABLE(id uuid, titel text, beschreibung text, datum text, ort text,
              uhrzeit text, ende_uhrzeit text, zeitzone text, kalender_seq int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_uid uuid;
BEGIN
  SELECT user_id INTO v_uid FROM public.profile WHERE ical_token = p_token;
  IF v_uid IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT e.id, e.titel, e.beschreibung, e.datum, e.ort,
         e.uhrzeit, e.ende_uhrzeit, e.zeitzone, e.kalender_seq
    FROM public.events e
    JOIN public.familien f ON f.id = e.familie_id
   WHERE f.verbund_id IN (
           SELECT DISTINCT f2.verbund_id FROM public.mitgliedschaften m
             JOIN public.familien f2 ON f2.id = m.familie_id
            WHERE m.user_id = v_uid)
     AND (
       NOT e.sichtbar_eingeschraenkt
       OR e.ersteller = v_uid
       OR EXISTS (SELECT 1 FROM public.event_eingeladene ee
                   WHERE ee.event_id = e.id AND ee.user_id = v_uid)
     )
     AND e.datum ~ '^\d{4}-\d{2}-\d{2}';   -- nur datierte Events in den Feed
END $$;
REVOKE ALL ON FUNCTION public.ical_feed(uuid) FROM public, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.ical_feed(uuid) TO service_role;


NOTIFY pgrst, 'reload schema';
SELECT 'OK: profile.ical_token + ical_token_get/reset + ical_feed (service_role) angelegt' AS status;
