-- =====================================================
-- PERSON IN BESTEHENDEN NACHNAMEN-BAUM EINORDNEN (Phase 1b/2)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Wenn beim abweichenden Nachnamen bereits ein gleichnamiger Baum existiert und der Admin
-- „dort einordnen" wählt, wird die Person als GLEICHE Person (identitaet_id) in den Zielbaum
-- GESPIEGELT — vorerst OHNE Beziehungen (lose Karte). Der Nutzer verknüpft sie anschließend
-- über den Lose-Karten-Hinweis manuell (bzw. die Auto-Verknüpfung schlägt eine Kante vor).
--
-- Sicherheit: nur Admin/Owner beider Familien (oder Super-Admin), beide im selben Verbund.
-- Idempotent: existiert im Zielbaum bereits eine Karte derselben identitaet_id -> keine zweite.
--
-- ROLLBACK: die gespiegelte lose Karte ist eine normale personen-Zeile -> über den Papierkorb
-- bzw. person_papierkorb entfernbar (identitätsbewusst).
-- =====================================================

CREATE OR REPLACE FUNCTION public.stammbaum_person_einordnen(p_person uuid, p_zielbaum uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_src_fam   uuid;
  v_ident     uuid;
  v_ziel_fam  uuid;
  v_verb_src  uuid;
  v_verb_ziel uuid;
  v_rec       record;
  v_new       uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'nicht_angemeldet'; END IF;
  IF p_person IS NULL OR p_zielbaum IS NULL THEN RAISE EXCEPTION 'ein_ungueltige_auswahl'; END IF;

  SELECT pe.familie_id, pe.identitaet_id INTO v_src_fam, v_ident
    FROM public.personen pe WHERE pe.id = p_person AND pe.geloescht_am IS NULL;
  IF v_src_fam IS NULL THEN RAISE EXCEPTION 'ein_person_fehlt'; END IF;

  SELECT s.familie_id INTO v_ziel_fam FROM public.stammbaeume s WHERE s.id = p_zielbaum;
  IF v_ziel_fam IS NULL THEN RAISE EXCEPTION 'ein_zielbaum_fehlt'; END IF;

  -- Rechte an BEIDEN Familien
  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_src_fam) AND public.kann_familie_bearbeiten(v_ziel_fam))) THEN
    RAISE EXCEPTION 'ein_keine_berechtigung';
  END IF;

  -- Beide im selben Verbund (Isolation wahren)
  SELECT verbund_id INTO v_verb_src  FROM public.familien WHERE id = v_src_fam;
  SELECT verbund_id INTO v_verb_ziel FROM public.familien WHERE id = v_ziel_fam;
  IF coalesce(v_verb_src::text,'') <> coalesce(v_verb_ziel::text,'') THEN
    RAISE EXCEPTION 'ein_fremder_verbund';
  END IF;

  -- identitaet_id sicherstellen (gemeinsame Identität für den Spiegel)
  IF v_ident IS NULL THEN
    v_ident := gen_random_uuid();
    UPDATE public.personen SET identitaet_id = v_ident WHERE id = p_person;
  END IF;

  -- Schon eine Karte dieser Identität im Zielbaum? -> idempotent, nichts tun
  SELECT id INTO v_new FROM public.personen
   WHERE stammbaum_id = p_zielbaum AND identitaet_id = v_ident AND geloescht_am IS NULL
   LIMIT 1;
  IF v_new IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'schon_da', true, 'person_id', v_new, 'zielbaum', p_zielbaum);
  END IF;

  -- Spiegelkarte anlegen (lose, ohne Beziehungen)
  SELECT * INTO v_rec FROM public.personen WHERE id = p_person;
  INSERT INTO public.personen
    (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum, stammbaum_daten, identitaet_id)
  VALUES
    (v_ziel_fam, p_zielbaum,
     'I' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(replace(v_rec.id::text,'-',''),1,8),
     v_rec.vorname, v_rec.nachname, NULL,
     coalesce(v_rec.stammbaum_daten, '{}'::jsonb) || jsonb_build_object('lose_zuordnen', true),
     v_ident)
  RETURNING id INTO v_new;

  RETURN jsonb_build_object('ok', true, 'schon_da', false, 'person_id', v_new, 'zielbaum', p_zielbaum);
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_person_einordnen(uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Person einordnen (lose Spiegelung in Zielbaum): stammbaum_person_einordnen(p_person, p_zielbaum)' AS status;
