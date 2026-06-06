-- =====================================================
-- REPARATUR — Zorana wieder in BEIDEN Bäumen sichtbar (Knežević + Simić)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT (mehrfach ausführbar, ungefährlich).
--
-- Ausgangslage (per Diagnose bestätigt): Es existiert nur noch EINE Zorana-Karte
-- im Simić-Baum (a71487ed…). Ihre Original-Kanten (Eltern Nada/Milan Knežević,
-- Ehe mit Milanko) wurden durch einen MERGE auf diese Simić-Karte umgehängt; die
-- ursprüngliche Knežević-Karte wurde dabei gelöscht. -> Im Knežević-Baum verschwindet
-- Zorana, weil ihre Karte in einem anderen Baum liegt und kein Zwilling sie brückt.
--
-- Fix: Knežević-Spiegelkarte neu anlegen (gleiche identitaet_id = echter Zwilling,
-- Biografie hält Trigger ident_sync synchron) + korrekte Kanten IM Knežević-Baum
-- (Eltern + Ehe mit Milanko_Knežević) + die falschen Kreuz-Kanten auf die Simić-Karte
-- entfernen. Danach: App neu laden -> Zorana in beiden Bäumen.
-- =====================================================

DO $$
DECLARE
  v_kn_fam     uuid := '8496292a-710c-4b26-8135-bfb34ba4ed8e';  -- Familie Knežević
  v_kn_tree    uuid := '862bafc9-adcb-493a-9a6b-bf14ea4d940e';  -- Stammbaum Knežević
  v_zor_si     uuid := 'a71487ed-2f6f-480e-8b74-572aed7d9bac';  -- Zorana (Simić, bleibt)
  v_milan      uuid := 'a293fdaa-c6ec-4dac-874a-d909c4de8603';  -- Milan Knežević
  v_nada       uuid := '8c2f3006-9b75-4770-abd6-4e03b1bfd915';  -- Nada  Knežević
  v_milanko_kn uuid := '04f4430c-ab6d-48c7-b4fd-9e498524ba4c';  -- Milanko (Knežević)
  v_ident      uuid;
  v_sd         jsonb;
  v_vn         text;
  v_nn         text;
  v_new        uuid;
BEGIN
  -- Quelle (Simić-Zorana) lesen
  SELECT identitaet_id, stammbaum_daten, vorname, nachname
    INTO v_ident, v_sd, v_vn, v_nn
    FROM public.personen WHERE id = v_zor_si;
  IF v_vn IS NULL THEN RAISE EXCEPTION 'Simić-Zorana (%) nicht gefunden — IDs prüfen.', v_zor_si; END IF;

  -- identitaet_id sicherstellen (sollte acc861fe… sein)
  IF v_ident IS NULL THEN
    v_ident := gen_random_uuid();
    UPDATE public.personen SET identitaet_id = v_ident WHERE id = v_zor_si;
  END IF;

  -- 1) Knežević-Spiegelkarte (Idempotenz: nur, wenn noch keine Zorana-Zwillingskarte im Baum)
  SELECT id INTO v_new
    FROM public.personen
   WHERE stammbaum_id = v_kn_tree AND identitaet_id = v_ident
   LIMIT 1;

  IF v_new IS NULL THEN
    INSERT INTO public.personen
      (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum,
       stammbaum_daten, identitaet_id)
    VALUES
      (v_kn_fam, v_kn_tree,
       'I' || (extract(epoch from clock_timestamp())*1000)::bigint || '_repairz',
       v_vn, v_nn, NULL, v_sd, v_ident)
    RETURNING id INTO v_new;
  END IF;

  -- 2) Eltern-Kanten IM Knežević-Baum (idempotent)
  INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
  SELECT v_kn_fam, v_milan, v_new, 'elternteil'
   WHERE NOT EXISTS (SELECT 1 FROM public.beziehungen
                      WHERE typ='elternteil' AND person_a=v_milan AND person_b=v_new);

  INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
  SELECT v_kn_fam, v_nada, v_new, 'elternteil'
   WHERE NOT EXISTS (SELECT 1 FROM public.beziehungen
                      WHERE typ='elternteil' AND person_a=v_nada AND person_b=v_new);

  -- 3) Ehe-Kante IM Knežević-Baum: Zorana_Kn ↔ Milanko_Kn (idempotent, beide Richtungen)
  INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
  SELECT v_kn_fam, v_new, v_milanko_kn, 'ehepartner'
   WHERE NOT EXISTS (SELECT 1 FROM public.beziehungen
                      WHERE typ='ehepartner'
                        AND ((person_a=v_new AND person_b=v_milanko_kn)
                          OR (person_a=v_milanko_kn AND person_b=v_new)));

  -- 4) Falsche Kreuz-Baum-Kanten auf die Simić-Karte entfernen
  --    a) Eltern (Knežević) -> Simić-Zorana
  DELETE FROM public.beziehungen
   WHERE typ='elternteil' AND person_b=v_zor_si AND person_a IN (v_milan, v_nada);
  --    b) Ehe Simić-Zorana ↔ Milanko_Knežević (gehört in den Knežević-Baum, s. Schritt 3)
  DELETE FROM public.beziehungen
   WHERE typ='ehepartner'
     AND ((person_a=v_zor_si AND person_b=v_milanko_kn)
       OR (person_a=v_milanko_kn AND person_b=v_zor_si));

  RAISE NOTICE 'Repair ok: Knežević-Zorana = %, identitaet_id = %', v_new, v_ident;
END $$;

-- Kontrolle: jetzt sollte Zorana je EINMAL pro Baum stehen, mit GLEICHER identitaet_id
SELECT pe.id, s.name AS baum, pe.vorname, pe.nachname, pe.identitaet_id
FROM public.personen pe
JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
WHERE pe.vorname ILIKE 'zorana%'
ORDER BY s.name;
