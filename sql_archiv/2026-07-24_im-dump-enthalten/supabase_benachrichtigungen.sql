-- =====================================================
-- BENACHRICHTIGUNGEN (Phase 2) — allgemeines In-App-System + Event-Einladungen
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- Idempotent.
--
-- Hintergrund: „Obavještenja" ist bewusst NUR für Admin-Zugangsanfragen
-- (registrierungs_anfragen, RPC-gelesen, Polling). Für NUTZER-Benachrichtigungen
-- (z. B. Event-Einladungen im Profilbereich) gibt es bisher nichts -> diese Datei
-- legt eine allgemeine, NUTZER-EIGENE Benachrichtigungstabelle an.
--
-- Sichtbarkeit: jeder Nutzer sieht/ändert AUSSCHLIESSLICH seine EIGENEN Zeilen
-- (auth.uid() = user_id) -> echte RLS, rekursionsfrei (kein Subquery auf sich selbst).
-- Erzeugt werden Benachrichtigungen nur über SECURITY-DEFINER-RPCs (kein INSERT für
-- normale Nutzer) -> niemand kann Fremd-Benachrichtigungen fälschen.
--
-- Delta-Regel (vom User bestätigt): Beim Speichern der Event-Teilnehmer erhält NUR
-- die NEU hinzugefügte Person eine Benachrichtigung (nicht erneut die bestehenden).
--
-- Voraussetzungen: supabase_events.sql, supabase_event_eingeladene.sql,
--   supabase_verbund.sql (kann_familie_bearbeiten/ist_super_admin),
--   supabase_gleiche_person.sql (personen.identitaet_id), supabase_profile.sql (profile).
-- =====================================================


-- 1) Tabelle ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.benachrichtigungen (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  typ        text NOT NULL DEFAULT 'event_einladung',
  titel      text NOT NULL,
  text       text,
  event_id   uuid REFERENCES public.events(id) ON DELETE CASCADE,   -- Direktlink (optional)
  gelesen    boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS benachrichtigungen_user_idx
  ON public.benachrichtigungen(user_id, created_at DESC);


-- 2) RLS: nur die EIGENEN Zeilen ----------------------------------------------
ALTER TABLE public.benachrichtigungen ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "benachr_select_own" ON public.benachrichtigungen;
DROP POLICY IF EXISTS "benachr_update_own" ON public.benachrichtigungen;
DROP POLICY IF EXISTS "benachr_delete_own" ON public.benachrichtigungen;

-- Lesen: eigene
CREATE POLICY "benachr_select_own" ON public.benachrichtigungen
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
-- Ändern (gelesen-Flag): eigene
CREATE POLICY "benachr_update_own" ON public.benachrichtigungen
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
-- Löschen: eigene
CREATE POLICY "benachr_delete_own" ON public.benachrichtigungen
  FOR DELETE TO authenticated USING (auth.uid() = user_id);
-- KEIN INSERT-Policy -> normale Nutzer können NICHT einfügen; nur die
-- SECURITY-DEFINER-RPC unten erzeugt Benachrichtigungen.


-- 3) Event-Einladung: Benachrichtigungen anlegen + E-Mail-Empfänger liefern ----
--    Wird vom Frontend NACH event_eingeladene_setzen mit dem `neu`-Array
--    (neu hinzugefügte person_ids) aufgerufen. Legt je verknüpftem Konto (≠ aufrufender
--    Nutzer) eine In-App-Benachrichtigung an und gibt die E-Mail-Empfänger zurück,
--    damit das Frontend die Resend-Edge-Function aufrufen kann.
--    Berücksichtigt Identitätsgruppen (Spiegelkarten via identitaet_id).
CREATE OR REPLACE FUNCTION public.event_einladung_benachrichtige(
  p_event uuid, p_person_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_titel text; v_empf jsonb;
BEGIN
  IF p_person_ids IS NULL OR array_length(p_person_ids,1) IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'empfaenger', '[]'::jsonb);
  END IF;
  SELECT familie_id, titel INTO v_fam, v_titel FROM public.events WHERE id = p_event;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Event nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  -- Zielkonten: verknüpfte Konten der neu hinzugefügten Personen (inkl. Spiegelkarten),
  -- ohne den aufrufenden Nutzer selbst.
  CREATE TEMP TABLE _ziel ON COMMIT DROP AS
    SELECT DISTINCT pu.user_id
      FROM unnest(p_person_ids) AS inp(pid)
      JOIN public.personen pi ON pi.id = inp.pid
      JOIN public.personen pu
        ON (pu.id = pi.id OR (pi.identitaet_id IS NOT NULL AND pu.identitaet_id = pi.identitaet_id))
     WHERE pu.user_id IS NOT NULL AND pu.user_id <> auth.uid();

  -- In-App-Benachrichtigung je Zielkonto
  INSERT INTO public.benachrichtigungen (user_id, typ, titel, text, event_id)
  SELECT z.user_id, 'event_einladung', v_titel, NULL, p_event FROM _ziel z;

  -- E-Mail-Empfänger (Adresse + bester Anzeigename) für die Edge Function
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'user_id', z.user_id,
           'email',   u.email,
           'name',    trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')),
           'sprache', coalesce(pr.sprache, 'de')
         )), '[]'::jsonb)
    INTO v_empf
    FROM _ziel z
    JOIN auth.users u ON u.id = z.user_id
    LEFT JOIN public.profile pr ON pr.user_id = z.user_id
   WHERE u.email IS NOT NULL;

  RETURN jsonb_build_object('ok', true, 'titel', v_titel, 'empfaenger', v_empf);
END $$;
GRANT EXECUTE ON FUNCTION public.event_einladung_benachrichtige(uuid, uuid[]) TO authenticated;


-- 4) Komfort-RPC: alle eigenen als gelesen markieren --------------------------
CREATE OR REPLACE FUNCTION public.benachrichtigungen_alle_gelesen()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.benachrichtigungen SET gelesen = true
   WHERE user_id = auth.uid() AND gelesen = false;
$$;
GRANT EXECUTE ON FUNCTION public.benachrichtigungen_alle_gelesen() TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'Phase 2 OK: benachrichtigungen (RLS own) + event_einladung_benachrichtige + alle_gelesen' AS status;
