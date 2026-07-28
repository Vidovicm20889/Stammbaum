-- ============================================================================
-- Board-Modus — freie Kartenpositionen (docs/board-modus.md, P2)
-- ----------------------------------------------------------------------------
-- Ein GEMEINSAMES Board pro Baum (kein Pro-Nutzer-Layout): je personen-Zeile (= eine
-- Karte in genau einem Baum) EINE Position. PK = person_id, ON DELETE CASCADE haelt die
-- referenzielle Integritaet (Karte/Baum geloescht -> Position weg, keine Waisen).
--   * Lesen: Baum-Berechtigte (auch Leser) -> Board statisch sichtbar (RLS-SELECT).
--   * Schreiben: NUR ueber SECURITY-DEFINER-RPC karte_board_pos_setzen mit expliziter
--     Rechtepruefung (owner/familien_admin/super_admin). Kein direkter Client-Write.
-- Idempotent. Im Supabase SQL-Editor ausfuehren.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.board_layout (
  person_id    uuid PRIMARY KEY REFERENCES public.personen(id)    ON DELETE CASCADE,
  stammbaum_id uuid NOT NULL    REFERENCES public.stammbaeume(id) ON DELETE CASCADE,
  x            numeric NOT NULL,
  y            numeric NOT NULL,
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS board_layout_baum_idx ON public.board_layout(stammbaum_id);

ALTER TABLE public.board_layout ENABLE ROW LEVEL SECURITY;

-- SELECT: wer den Baum sehen darf, sieht auch das Board (rekursionsfrei: Subquery auf
-- personen, NICHT auf board_layout selbst).
DROP POLICY IF EXISTS board_layout_select ON public.board_layout;
CREATE POLICY board_layout_select ON public.board_layout FOR SELECT USING (
  public.ist_super_admin()
  OR public.sieht_familie((SELECT p.familie_id FROM public.personen p WHERE p.id = board_layout.person_id))
);
-- KEINE INSERT/UPDATE/DELETE-Policy -> Client kann nicht direkt schreiben (nur die RPC unten,
-- die als SECURITY DEFINER die RLS umgeht und selbst die Rechte prueft).

CREATE OR REPLACE FUNCTION public.karte_board_pos_setzen(p_person uuid, p_x numeric, p_y numeric)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_familie uuid;
  v_baum    uuid;
BEGIN
  SELECT familie_id, stammbaum_id INTO v_familie, v_baum
    FROM public.personen WHERE id = p_person AND geloescht_am IS NULL;
  IF v_familie IS NULL THEN
    RAISE EXCEPTION 'board_person_unbekannt';
  END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_familie)) THEN
    RAISE EXCEPTION 'board_kein_recht';
  END IF;
  INSERT INTO public.board_layout(person_id, stammbaum_id, x, y, updated_at)
  VALUES (p_person, v_baum, p_x, p_y, now())
  ON CONFLICT (person_id) DO UPDATE
    SET x = EXCLUDED.x, y = EXCLUDED.y, stammbaum_id = EXCLUDED.stammbaum_id, updated_at = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.karte_board_pos_setzen(uuid, numeric, numeric) TO authenticated;

-- „Als Baum ordnen" (Phase 4): alle freien Positionen eines Baums verwerfen -> Board startet
-- wieder aus der Blutlinien-Anordnung (boardBerechnePositionen). Rechteprüfung wie beim Schreiben.
CREATE OR REPLACE FUNCTION public.board_layout_reset(p_stammbaum uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam uuid;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_stammbaum;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'board_baum_unbekannt'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'board_kein_recht';
  END IF;
  DELETE FROM public.board_layout WHERE stammbaum_id = p_stammbaum;
END;
$$;
GRANT EXECUTE ON FUNCTION public.board_layout_reset(uuid) TO authenticated;

-- Phase 3 (Echtzeit): board_layout in die Supabase-Realtime-Publikation aufnehmen, damit
-- Positionsänderungen anderer Bearbeiter live gespiegelt werden (RLS-SELECT gilt weiterhin ->
-- nur Baum-Berechtigte erhalten die Events). Idempotent.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'board_layout')
  THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.board_layout;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

SELECT 'board_layout + karte_board_pos_setzen + board_layout_reset + Realtime angelegt (Board-Modus)' AS status;
