-- =====================================================
-- GLEICHE PERSON ÜBER BÄUME (logische Verknüpfung, beide Karten behalten)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Voraussetzung: supabase_merge_gui.sql (merge_fill), supabase_verbund.sql
--   (ist_super_admin, kann_familie_bearbeiten).
--
-- Idee: Eine reale Person, die in mehreren Bäumen vorkommt (z. B. eingeheiratete
-- Frau = Tochter im einen, Ehefrau im anderen Baum), bekommt in JEDEM Baum ihre
-- eigene Karte. Diese Karten werden über eine gemeinsame identitaet_id als
-- DIESELBE Person markiert. KEINE Karte wird gelöscht -> sie bleibt überall sichtbar.
-- =====================================================

-- 1) Gruppen-Spalte: gleiche identitaet_id = dieselbe reale Person
ALTER TABLE public.personen ADD COLUMN IF NOT EXISTS identitaet_id uuid;
CREATE INDEX IF NOT EXISTS personen_identitaet_idx ON public.personen(identitaet_id);


-- 2) Zwei Karten als gleiche Person verknüpfen (beide bleiben erhalten)
--    - legt beide (und ihre evtl. bestehenden Gruppen) in EINE identitaet_id
--    - vereinheitlicht die Biografie: fehlende Felder gegenseitig auffüllen
--      (merge_fill = vorhandene Werte bleiben, KEINE Namen werden überschrieben)
--    - verbindet die Verbünde (Navigation/Sichtbarkeit zwischen den Bäumen)
-- Rechte: super_admin ODER Admin/Owner BEIDER Familien.
CREATE OR REPLACE FUNCTION public.personen_verknuepfen(p_a uuid, p_b uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fa uuid; v_fb uuid; v_ia uuid; v_ib uuid; v_grp uuid;
  v_sa jsonb; v_sb jsonb; v_va uuid; v_vb uuid;
BEGIN
  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN RAISE EXCEPTION 'Ungültige Auswahl.'; END IF;
  SELECT familie_id, identitaet_id, stammbaum_daten INTO v_fa, v_ia, v_sa FROM public.personen WHERE id = p_a;
  SELECT familie_id, identitaet_id, stammbaum_daten INTO v_fb, v_ib, v_sb FROM public.personen WHERE id = p_b;
  IF v_fa IS NULL OR v_fb IS NULL THEN RAISE EXCEPTION 'Person(en) nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_fa) AND public.kann_familie_bearbeiten(v_fb)))
    THEN RAISE EXCEPTION 'Keine Berechtigung (Admin/Owner beider Familien nötig).'; END IF;

  -- Gruppen-id bestimmen (bestehende Gruppe weiterverwenden, sonst neu)
  v_grp := coalesce(v_ia, v_ib, gen_random_uuid());

  -- Beide Karten + alle Mitglieder ihrer bisherigen Gruppen in die gemeinsame Gruppe
  UPDATE public.personen SET identitaet_id = v_grp
   WHERE id IN (p_a, p_b)
      OR (v_ia IS NOT NULL AND identitaet_id = v_ia)
      OR (v_ib IS NOT NULL AND identitaet_id = v_ib);

  -- Biografie vereinheitlichen: jede Karte behält ihre Werte, ergänzt fehlende
  -- aus der anderen (Namen bleiben dadurch unangetastet, da beide Namen gesetzt sind).
  UPDATE public.personen SET stammbaum_daten = public.merge_fill(coalesce(v_sa,'{}'::jsonb), coalesce(v_sb,'{}'::jsonb)) WHERE id = p_a;
  UPDATE public.personen SET stammbaum_daten = public.merge_fill(coalesce(v_sb,'{}'::jsonb), coalesce(v_sa,'{}'::jsonb)) WHERE id = p_b;

  -- Verbünde zusammenlegen (Bäume bleiben getrennt, werden aber gegenseitig sichtbar)
  IF v_fa <> v_fb THEN
    SELECT verbund_id INTO v_va FROM public.familien WHERE id = v_fa;
    SELECT verbund_id INTO v_vb FROM public.familien WHERE id = v_fb;
    IF v_va IS NOT NULL AND v_vb IS NOT NULL AND v_va <> v_vb THEN
      UPDATE public.familien SET verbund_id = v_va WHERE verbund_id = v_vb;
    END IF;
  END IF;

  RETURN v_grp;
END $$;
GRANT EXECUTE ON FUNCTION public.personen_verknuepfen(uuid, uuid) TO authenticated;


-- 3) Verknüpfung einer Karte wieder lösen (Korrektur). Karte bleibt, identitaet_id -> NULL.
CREATE OR REPLACE FUNCTION public.personen_identitaet_aufheben(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_f uuid;
BEGIN
  SELECT familie_id INTO v_f FROM public.personen WHERE id = p_id;
  IF v_f IS NULL THEN RAISE EXCEPTION 'Person nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_f)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  UPDATE public.personen SET identitaet_id = NULL WHERE id = p_id;
END $$;
GRANT EXECUTE ON FUNCTION public.personen_identitaet_aufheben(uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'Gleiche-Person-Verknüpfung angelegt: personen.identitaet_id + personen_verknuepfen / personen_identitaet_aufheben' AS status;
