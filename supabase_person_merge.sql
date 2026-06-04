-- =====================================================
-- PERSON-MERGE (Dubletten zusammenführen) — wiederverwendbares Primitiv
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- person_zusammenfuehren(p_behalten, p_dublette):
--   hängt ALLE Referenzen der Dublette auf die bleibende Person um
--   (beziehungen, event_teilnehmer, Konto-Verknüpfung) und löscht dann nur die
--   redundante Kopie. KEIN Verlust von Beziehungen/Konten/Events/Medien
--   (Event-Medien hängen am Event, nicht an der Person).
-- Rechte: super_admin ODER Admin/Owner BEIDER betroffener Familien.
-- =====================================================

CREATE OR REPLACE FUNCTION public.person_zusammenfuehren(p_behalten uuid, p_dublette uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam_b uuid; v_fam_d uuid; v_user_b uuid; v_user_d uuid; v_sd_b jsonb; v_sd_d jsonb;
BEGIN
  IF p_behalten IS NULL OR p_dublette IS NULL OR p_behalten = p_dublette THEN RETURN; END IF;
  SELECT familie_id, user_id, stammbaum_daten INTO v_fam_b, v_user_b, v_sd_b FROM public.personen WHERE id = p_behalten;
  SELECT familie_id, user_id, stammbaum_daten INTO v_fam_d, v_user_d, v_sd_d FROM public.personen WHERE id = p_dublette;
  IF v_fam_b IS NULL OR v_fam_d IS NULL THEN RAISE EXCEPTION 'Person(en) nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_fam_b) AND public.kann_familie_bearbeiten(v_fam_d)))
    THEN RAISE EXCEPTION 'Keine Berechtigung (Admin/Owner beider Familien nötig).'; END IF;

  -- 1) Beziehungen der Dublette auf die bleibende Person umhängen
  UPDATE public.beziehungen SET person_a = p_behalten WHERE person_a = p_dublette;
  UPDATE public.beziehungen SET person_b = p_behalten WHERE person_b = p_dublette;
  -- Self-Edges (a=b) entfernen
  DELETE FROM public.beziehungen WHERE person_a = person_b;
  -- exakte Duplikat-Kanten entfernen (gleiche a,b,typ)
  DELETE FROM public.beziehungen b USING public.beziehungen b2
   WHERE b.ctid > b2.ctid AND b.person_a = b2.person_a AND b.person_b = b2.person_b AND b.typ = b2.typ;
  -- gespiegelte Ehepartner-Duplikate (a,b) vs (b,a) entfernen
  DELETE FROM public.beziehungen b USING public.beziehungen b2
   WHERE b.ctid > b2.ctid AND b.typ = 'ehepartner' AND b2.typ = 'ehepartner'
     AND b.person_a = b2.person_b AND b.person_b = b2.person_a;

  -- 2) Event-Teilnehmer umhängen (falls Tabelle existiert)
  BEGIN
    UPDATE public.event_teilnehmer SET person_id = p_behalten WHERE person_id = p_dublette;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  -- 3) Konto-Verknüpfung übernehmen, falls nur die Dublette ein Konto hatte
  IF v_user_d IS NOT NULL AND v_user_b IS NULL THEN
    UPDATE public.personen SET user_id = v_user_d WHERE id = p_behalten;
  END IF;

  -- 4) Fehlende Felder der bleibenden Karte aus der Dublette auffüllen (nicht überschreiben)
  UPDATE public.personen
     SET stammbaum_daten = coalesce(v_sd_d,'{}'::jsonb) || coalesce(v_sd_b,'{}'::jsonb)
   WHERE id = p_behalten;

  -- 5) redundante Kopie löschen
  DELETE FROM public.personen WHERE id = p_dublette;
END $$;
GRANT EXECUTE ON FUNCTION public.person_zusammenfuehren(uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'person_zusammenfuehren(behalten, dublette) angelegt' AS status;
