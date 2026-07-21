-- ============================================================================
-- Board — Linien-Wegpunkte (Phase 4): manuell verschiebbarer Knickpunkt je Eltern->Kind-Linie,
-- PRO BAUM (gemeinsam für alle, wie board_layout). „Zurücksetzen" (board_linie_reset) stellt den
-- automatischen Verlauf wieder her. Keyed über (stammbaum_id, von_person, nach_person).
--   * Lesen: Baum-Berechtigte (RLS-SELECT über personen.familie_id).
--   * Schreiben: NUR über SECURITY-DEFINER-RPC mit Rechteprüfung (kann_familie_bearbeiten).
-- Idempotent. Im Supabase SQL-Editor ausführen.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.board_linie (
  stammbaum_id uuid NOT NULL REFERENCES public.stammbaeume(id) ON DELETE CASCADE,
  von_person   uuid NOT NULL REFERENCES public.personen(id)    ON DELETE CASCADE,
  nach_person  uuid NOT NULL REFERENCES public.personen(id)    ON DELETE CASCADE,
  wx           numeric NOT NULL,
  wy           numeric NOT NULL,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (stammbaum_id, von_person, nach_person)
);
CREATE INDEX IF NOT EXISTS board_linie_baum_idx ON public.board_linie(stammbaum_id);

ALTER TABLE public.board_linie ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS board_linie_select ON public.board_linie;
CREATE POLICY board_linie_select ON public.board_linie FOR SELECT USING (
  public.ist_super_admin()
  OR public.sieht_familie((SELECT p.familie_id FROM public.personen p WHERE p.id = board_linie.von_person))
);

CREATE OR REPLACE FUNCTION public.board_linie_setzen(p_baum uuid, p_von uuid, p_nach uuid, p_x numeric, p_y numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.personen WHERE id = p_von AND geloescht_am IS NULL;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'linie_person_unbekannt'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN RAISE EXCEPTION 'board_kein_recht'; END IF;
  INSERT INTO public.board_linie (stammbaum_id, von_person, nach_person, wx, wy, updated_at)
  VALUES (p_baum, p_von, p_nach, p_x, p_y, now())
  ON CONFLICT (stammbaum_id, von_person, nach_person) DO UPDATE SET wx = EXCLUDED.wx, wy = EXCLUDED.wy, updated_at = now();
END; $$;
GRANT EXECUTE ON FUNCTION public.board_linie_setzen(uuid, uuid, uuid, numeric, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.board_linie_reset(p_baum uuid, p_von uuid, p_nach uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.personen WHERE id = p_von;
  IF v_fam IS NULL OR NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN RAISE EXCEPTION 'board_kein_recht'; END IF;
  DELETE FROM public.board_linie WHERE stammbaum_id = p_baum AND von_person = p_von AND nach_person = p_nach;
END; $$;
GRANT EXECUTE ON FUNCTION public.board_linie_reset(uuid, uuid, uuid) TO authenticated;

-- Realtime (Live-Sync der Wegpunkte)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='board_linie')
  THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.board_linie; END IF;
END $$;

NOTIFY pgrst, 'reload schema';
SELECT 'board_linie + board_linie_setzen/reset + Realtime angelegt (Linien-Wegpunkte)' AS status;
