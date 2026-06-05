-- =====================================================
-- DIAGNOSE: Warum zeigt "Desa/Desanka" in 2 Bäumen unterschiedliche Daten?
-- Ausführen in: Supabase -> SQL Editor. NUR LESEN (keine Änderung).
--
-- Liefert pro Desa/Desanka-Karte: Baum, identitaet_id und alle relevanten
-- Felder. Auswertung:
--   * identitaet_id bei beiden Karten GLEICH (und nicht NULL)  -> sie SIND
--     verknüpft. Wenn die Felder trotzdem abweichen -> echter Sync-Bug.
--   * identitaet_id NULL oder UNTERSCHIEDLICH -> Karten sind NICHT verknüpft,
--     der Trigger kann gar nicht synchronisieren -> einmalig verknüpfen nötig.
-- Außerdem: existiert der Trigger ident_sync + die Funktion überhaupt?
-- =====================================================
SELECT jsonb_pretty(jsonb_build_object(
  'desa_karten', (SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) FROM (
     SELECT pe.id,
            s.name                              AS baum,
            pe.identitaet_id,
            trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS spalten_name,
            pe.stammbaum_daten->>'name'         AS d_name,
            pe.stammbaum_daten->>'given'        AS d_given,
            pe.stammbaum_daten->>'surname'      AS d_surname,
            pe.stammbaum_daten->>'ehename'      AS d_maedchenname,
            pe.stammbaum_daten->>'birth_date'   AS d_geboren,
            pe.stammbaum_daten->>'birth_place'  AS d_geburtsort
     FROM public.personen pe
     LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
     WHERE pe.vorname ILIKE 'Des%'                -- fängt Desa UND Desanka
        OR pe.stammbaum_daten->>'given' ILIKE 'Des%'
        OR pe.nachname ILIKE 'Pisarev%'
        OR pe.nachname ILIKE 'Begov%'
     ORDER BY s.name
     ) t),
  'trigger_vorhanden',  (SELECT count(*) FROM pg_trigger WHERE tgname = 'ident_sync'),
  'funktion_vorhanden', (SELECT count(*) FROM pg_proc    WHERE proname = 'trg_ident_sync')
)) AS ergebnis;
