-- =====================================================
-- EINZELNE SPIEGELKARTE IN DEN PAPIERKORB (nicht identitätsbewusst)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT (CREATE OR REPLACE).
--
-- HINTERGRUND: person_papierkorb löscht IDENTITÄTSBEWUSST (alle identitaet_id-Zwillinge). Für die
-- „Verschieben → Zielbaum hat schon einen Zwilling"-Konsolidierung braucht man aber das Gegenteil:
-- NUR die eine überflüssige Spiegelkarte (im Quellbaum) entfernen, der Zwilling im Zielbaum bleibt.
-- Direktes client-seitiges Setzen von geloescht_am ist durch die RESTRICTIVE SELECT-Policy
-- „personen_softdelete_restrict" gesperrt (das UPDATE...RETURNING re-liest die nun gelöschte Zeile
-- und verletzt die Policy). Diese SECURITY-DEFINER-RPC läuft als Owner (BYPASSRLS) und umgeht das —
-- wie person_papierkorb, nur eben single-card.
--
-- SICHERHEIT:
--   • Rechte: Bearbeiter (kann_familie_bearbeiten) der Familie der Karte (bzw. Super-Admin).
--   • Es MUSS ein aktiver identitaet_id-Zwilling bestehen bleiben (sonst Abbruch „kein_zwilling") →
--     die Funktion kann NIE die letzte/einzige Karte einer Person löschen (dafür person_papierkorb).
--   • Soft-Delete (Papierkorb): Karte + ihre Kanten teilen EINEN loesch_batch → gemeinsam über den
--     bestehenden Papierkorb wiederherstellbar. Zwillinge werden NICHT angefasst.
--
-- Voraussetzungen: supabase_papierkorb.sql (geloescht_am/geloescht_von/loesch_batch + Policies) und
-- supabase_verbund.sql (kann_familie_bearbeiten/ist_super_admin).
-- =====================================================

CREATE OR REPLACE FUNCTION public.person_karte_papierkorb(p_person uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_fam   uuid;
  v_ident uuid;
  v_twins int;
  v_batch uuid := gen_random_uuid();
  v_nb    int;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;

  SELECT familie_id, identitaet_id INTO v_fam, v_ident
    FROM public.personen WHERE id = p_person AND geloescht_am IS NULL;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;

  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  -- Nur eine REDUNDANTE Spiegelkarte entfernen: es MUSS ein aktiver Zwilling bleiben.
  IF v_ident IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'kein_zwilling'); END IF;
  SELECT count(*) INTO v_twins
    FROM public.personen
   WHERE identitaet_id = v_ident AND id <> p_person AND geloescht_am IS NULL;
  IF v_twins < 1 THEN RETURN jsonb_build_object('ok', false, 'grund', 'kein_zwilling'); END IF;

  -- Kanten NUR dieser Karte soft-löschen (gleicher Batch -> zusammen wiederherstellbar).
  WITH upd AS (
    UPDATE public.beziehungen
       SET geloescht_am = now(), geloescht_von = v_me, loesch_batch = v_batch
     WHERE geloescht_am IS NULL AND (person_a = p_person OR person_b = p_person)
    RETURNING 1
  ) SELECT count(*) INTO v_nb FROM upd;

  -- Nur DIESE eine Karte soft-löschen (Zwillinge bleiben unangetastet).
  UPDATE public.personen
     SET geloescht_am = now(), geloescht_von = v_me, loesch_batch = v_batch
   WHERE id = p_person AND geloescht_am IS NULL;

  RETURN jsonb_build_object('ok', true, 'batch', v_batch, 'beziehungen', v_nb);
END $$;
GRANT EXECUTE ON FUNCTION public.person_karte_papierkorb(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'person_karte_papierkorb(p_person) angelegt: einzelne Spiegelkarte in den Papierkorb (Zwilling bleibt).' AS status;
