-- Sind Gordanas Karten verknüpft (gleiche identitaet_id) + ist der Sync-Trigger da? (nur lesen)
SELECT jsonb_pretty(jsonb_build_object(
  'gordana_karten', (SELECT coalesce(jsonb_agg(t),'[]'::jsonb) FROM (
     SELECT pe.id,
            trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS person,
            s.name AS baum,
            pe.identitaet_id,
            pe.stammbaum_daten->>'beruf'       AS beruf,
            pe.stammbaum_daten->>'birth_place' AS geburtsort,
            pe.stammbaum_daten->>'geburtsland' AS geburtsland,
            pe.stammbaum_daten->>'birth_date'  AS geboren
     FROM public.personen pe
     LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
     WHERE pe.vorname ILIKE 'Gord%'
     ORDER BY baum) t),
  'trigger_vorhanden', (SELECT count(*) FROM pg_trigger WHERE tgname = 'ident_sync'),
  'funktion_aktuell', (SELECT count(*) FROM pg_proc WHERE proname = 'trg_ident_sync')
)) AS ergebnis;
