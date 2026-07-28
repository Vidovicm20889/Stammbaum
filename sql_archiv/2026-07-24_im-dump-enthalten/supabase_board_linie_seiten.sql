-- ============================================================================
-- Board — Linien-ANKER (Endpunkt-Seiten) je Verbindung. Erweitert supabase_board_linie.sql.
-- ----------------------------------------------------------------------------
-- Bisher speicherte board_linie nur einen Knick-WEGPUNKT (wx,wy). Neu: pro Linie kann für BEIDE
-- Endpunkte die Kartenseite festgelegt werden, an der die Linie andockt:
--   'l' = links, 'r' = rechts, 't' = oben, 'b' = unten. NULL = automatisch (zur Gegenkarte zeigend).
-- Damit lässt sich z. B. „rechte Seite Karte A -> linke Seite Karte B" fest einstellen.
--
-- wx/wy werden NULLABLE: eine Linie kann nur Anker haben (ohne Knickpunkt) und umgekehrt.
-- Zurücksetzen bleibt board_linie_reset (löscht die Zeile = Anker UND Wegpunkt).
-- Idempotent. Im Supabase SQL-Editor ausführen (NACH supabase_board_linie.sql).
-- ============================================================================

-- 1) Spalten + Constraint
ALTER TABLE public.board_linie ADD COLUMN IF NOT EXISTS von_seite  text;
ALTER TABLE public.board_linie ADD COLUMN IF NOT EXISTS nach_seite text;

-- wx/wy dürfen jetzt leer sein (Anker-only-Zeilen)
ALTER TABLE public.board_linie ALTER COLUMN wx DROP NOT NULL;
ALTER TABLE public.board_linie ALTER COLUMN wy DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'board_linie_seiten_chk') THEN
    ALTER TABLE public.board_linie ADD CONSTRAINT board_linie_seiten_chk CHECK (
      (von_seite  IS NULL OR von_seite  IN ('l','r','t','b')) AND
      (nach_seite IS NULL OR nach_seite IN ('l','r','t','b'))
    );
  END IF;
END $$;

-- 2) RPC: Anker setzen (ohne den Wegpunkt anzufassen). Rechte wie board_linie_setzen.
CREATE OR REPLACE FUNCTION public.board_linie_seiten_setzen(
  p_baum uuid, p_von uuid, p_nach uuid, p_von_seite text, p_nach_seite text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  IF p_von_seite  IS NOT NULL AND p_von_seite  NOT IN ('l','r','t','b') THEN RAISE EXCEPTION 'linie_seite_ungueltig'; END IF;
  IF p_nach_seite IS NOT NULL AND p_nach_seite NOT IN ('l','r','t','b') THEN RAISE EXCEPTION 'linie_seite_ungueltig'; END IF;

  SELECT familie_id INTO v_fam FROM public.personen WHERE id = p_von AND geloescht_am IS NULL;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'linie_person_unbekannt'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN RAISE EXCEPTION 'board_kein_recht'; END IF;

  INSERT INTO public.board_linie (stammbaum_id, von_person, nach_person, von_seite, nach_seite, updated_at)
  VALUES (p_baum, p_von, p_nach, p_von_seite, p_nach_seite, now())
  ON CONFLICT (stammbaum_id, von_person, nach_person)
  DO UPDATE SET von_seite = EXCLUDED.von_seite, nach_seite = EXCLUDED.nach_seite, updated_at = now();
END; $$;
GRANT EXECUTE ON FUNCTION public.board_linie_seiten_setzen(uuid, uuid, uuid, text, text) TO authenticated;

-- 3) board_linie_setzen (Wegpunkt) neu: darf die Anker NICHT überschreiben.
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

NOTIFY pgrst, 'reload schema';
SELECT 'board_linie: von_seite/nach_seite + board_linie_seiten_setzen angelegt (Endpunkt-Anker)' AS status;
