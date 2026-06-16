-- =====================================================
-- „AN DIESEM TAG" — FAMILIEN-ERINNERUNGEN aus VORHANDENEN Daten (Facebook-Memories-Prinzip)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_beitraege.sql ausführen (nutzt mein_verbund + Tabelle beitraege).
--
-- KEIN neues Datenmodell — nur eine SECURITY-DEFINER-RPC, die Ereignisse liefert, deren
-- TAG+MONAT dem heutigen Datum entsprechen (über beliebige Jahre): Geburtstage, Gedenktage,
-- Hochzeitstage, sowie „vor N Jahren"-Fotos und -Beiträge. Jeweils mit „jahre" = N.
--
-- DATENSCHUTZ / ISOLATION: streng VERBUND-INTERN. Die RPC liefert NUR an Mitglieder des
-- Verbunds (Tor ist_in_verbund) und NUR Daten dieses einen Verbunds. Die Cross-Verbund-
-- Minderjährigen-/Opt-in-Regel (Discovery, supabase_auffindbarkeit.sql) gilt hier bewusst
-- NICHT — innerhalb der eigenen Familie sind Geburtstage lebender (auch minderjähriger)
-- Angehöriger genau der Sinn der Funktion. KEIN baum_freigaben-/Cross-Verbund-Pfad.
--
-- Voraussetzungen: supabase_verbund.sql, supabase_reaktionen_kommentare.sql (ist_in_verbund),
--   supabase_beitraege.sql (mein_verbund, beitraege), supabase_personen_fotos.sql,
--   supabase_profile.sql, supabase_multitree_phase5.sql (personen/beziehungen/familien).
-- Datumswerte: stammbaum_daten ISO 'YYYY-MM-DD' (Freitext-Altwerte werden übersprungen);
--   personen_fotos.aufnahme_datum (date), beitraege.erstellt_am (timestamptz).
-- =====================================================

CREATE OR REPLACE FUNCTION public.erinnerungen_heute(p_verbund uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_verb  uuid := coalesce(p_verbund, public.mein_verbund());
  v_today text := to_char(current_date, 'MM-DD');
  v_year  int  := extract(year from current_date)::int;
  v_items jsonb;
BEGIN
  IF v_verb IS NULL OR NOT public.ist_in_verbund(v_verb) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung', 'items', '[]'::jsonb);
  END IF;

  WITH
  -- Kanonische Personen des Verbunds (identitaet_id-Zwillinge entdoppelt, Platzhalter raus)
  pers AS (
    SELECT DISTINCT ON (coalesce(pe.identitaet_id::text, pe.id::text))
           pe.id, pe.externe_id, pe.stammbaum_daten AS sd,
           btrim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) AS name
      FROM public.personen pe
      JOIN public.familien f ON f.id = pe.familie_id
     WHERE f.verbund_id = v_verb
       AND coalesce(pe.stammbaum_daten->>'platzhalter','') <> 'true'
     ORDER BY coalesce(pe.identitaet_id::text, pe.id::text), pe.id
  ),
  -- Geburtstage (gleicher Tag+Monat, beliebiges Jahr; jahre>0)
  geburt AS (
    SELECT jsonb_build_object(
             'kategorie','geburtstag','ref_typ','person','ref_ext',p.externe_id,
             'name', p.name, 'datum', p.sd->>'birth_date',
             'jahre', v_year - left(p.sd->>'birth_date',4)::int) AS o
      FROM pers p
     WHERE p.sd->>'birth_date' ~ '^\d{4}-\d{2}-\d{2}$'
       AND substring(p.sd->>'birth_date' from 6 for 5) = v_today
       AND v_year - left(p.sd->>'birth_date',4)::int > 0
  ),
  -- Gedenktage (Sterbedatum gleicher Tag+Monat)
  gedenk AS (
    SELECT jsonb_build_object(
             'kategorie','gedenktag','ref_typ','person','ref_ext',p.externe_id,
             'name', p.name, 'datum', p.sd->>'death_date',
             'jahre', v_year - left(p.sd->>'death_date',4)::int) AS o
      FROM pers p
     WHERE (lower(coalesce(p.sd->>'deceased','')) = 'true' OR coalesce(btrim(p.sd->>'death_date'),'') <> '')
       AND p.sd->>'death_date' ~ '^\d{4}-\d{2}-\d{2}$'
       AND substring(p.sd->>'death_date' from 6 for 5) = v_today
       AND v_year - left(p.sd->>'death_date',4)::int > 0
  ),
  -- Hochzeitstage: Datum liegt auf der PERSON (standesamt ODER kirchlich); Paar via ehepartner
  -- entdoppelt (least/greatest der beiden Personen-IDs).
  hochzeit_roh AS (
    SELECT p.id, p.externe_id, p.name,
           coalesce(nullif(btrim(p.sd->>'hochzeit_standesamt'),''), nullif(btrim(p.sd->>'hochzeit_kirchlich'),'')) AS hd
      FROM pers p
  ),
  hochzeit AS (
    SELECT DISTINCT ON (least(h.id, coalesce(part.id, h.id)), greatest(h.id, coalesce(part.id, h.id)))
           jsonb_build_object(
             'kategorie','hochzeit','ref_typ','person','ref_ext',h.externe_id,
             'name', h.name || coalesce(' & ' || part.name, ''),
             'datum', h.hd, 'jahre', v_year - left(h.hd,4)::int) AS o
      FROM hochzeit_roh h
      LEFT JOIN public.beziehungen bz ON bz.typ='ehepartner' AND (bz.person_a = h.id OR bz.person_b = h.id)
      LEFT JOIN pers part ON part.id = CASE WHEN bz.person_a = h.id THEN bz.person_b ELSE bz.person_a END
     WHERE h.hd ~ '^\d{4}-\d{2}-\d{2}$'
       AND substring(h.hd from 6 for 5) = v_today
       AND v_year - left(h.hd,4)::int > 0
     ORDER BY least(h.id, coalesce(part.id, h.id)), greatest(h.id, coalesce(part.id, h.id)), h.id
  ),
  -- „Vor N Jahren"-Fotos (Aufnahmedatum gleicher Tag+Monat) -> öffnet die Personenkarte
  foto AS (
    SELECT jsonb_build_object(
             'kategorie','foto','ref_typ','person','ref_ext',pe.externe_id,
             'name', btrim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')),
             'titel', ff.beschriftung, 'bild_pfad', ff.storage_pfad,
             'datum', ff.aufnahme_datum::text,
             'jahre', v_year - extract(year from ff.aufnahme_datum)::int) AS o
      FROM public.personen_fotos ff
      JOIN public.familien f  ON f.id = ff.familie_id
      JOIN public.personen pe ON pe.id = ff.person_id
     WHERE f.verbund_id = v_verb
       AND ff.aufnahme_datum IS NOT NULL
       AND to_char(ff.aufnahme_datum,'MM-DD') = v_today
       AND v_year - extract(year from ff.aufnahme_datum)::int > 0
  ),
  -- „Vor N Jahren"-Beiträge (Beitragsdatum gleicher Tag+Monat) -> öffnet den Feed
  beitrag AS (
    SELECT jsonb_build_object(
             'kategorie','beitrag','ref_typ','beitrag','ref_id',b.id,
             'name', COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)),''), u.email),
             'titel', left(coalesce(b.text,''), 80), 'bild_url', b.bild_url,
             'datum', b.erstellt_am::date::text,
             'jahre', v_year - extract(year from b.erstellt_am)::int) AS o
      FROM public.beitraege b
      LEFT JOIN auth.users u     ON u.id = b.autor
      LEFT JOIN public.profile pr ON pr.user_id = b.autor
     WHERE b.verbund_id = v_verb AND b.geloescht = false
       AND to_char(b.erstellt_am,'MM-DD') = v_today
       AND v_year - extract(year from b.erstellt_am)::int > 0
  ),
  alle AS (
    SELECT o FROM geburt
    UNION ALL SELECT o FROM gedenk
    UNION ALL SELECT o FROM hochzeit
    UNION ALL SELECT o FROM foto
    UNION ALL SELECT o FROM beitrag
  )
  SELECT coalesce(jsonb_agg(o ORDER BY (o->>'jahre')::int DESC), '[]'::jsonb) INTO v_items FROM alle;

  RETURN jsonb_build_object('ok', true, 'items', v_items);
END $$;

GRANT EXECUTE ON FUNCTION public.erinnerungen_heute(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_erinnerungen_heute.sql ausgeführt — RPC erinnerungen_heute (Geburtstag/Gedenktag/Hochzeit/Foto/Beitrag, verbund-intern)' AS status;
