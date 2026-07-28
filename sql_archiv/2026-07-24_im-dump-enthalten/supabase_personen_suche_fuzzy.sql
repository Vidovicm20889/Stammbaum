-- ============================================================================
-- personen_suche — TOLERANTE (Fuzzy-)Suche per pg_trgm
-- ----------------------------------------------------------------------------
-- PROBLEM: Das serbische Lateinalphabet kennt kein Y/W/X/Q. Fremde Namen behalten
-- diese Buchstaben, die Anzeige-Transliteration (nm()/srLat2Cyr) laesst sie stehen
-- -> Misch-Schrift wie "Цyрило" fuer den gespeicherten Namen "Cyrilo". Das lateinische
-- 'y' (U+0079) ist ein Homoglyph des kyrillischen 'у' (U+0443) -> der Nutzer liest
-- "Curilo" und tippt das -> exakte Praefix-Suche findet nichts (cyrilo <> curilo).
--
-- LOESUNG: personen_suche matcht zusaetzlich UNSCHARF ueber Trigramm-Aehnlichkeit.
--   * Praefix-Match bleibt unveraendert (schnell, praezise, bisheriges Verhalten).
--   * ZUSAETZLICH Treffer, wenn similarity(merge_norm(feld), query) >= 0.35.
--     similarity('cyrilo','curilo') = 0.400 -> Fall geloest.
--     Gegenprobe: 'vidovic' vs 'petrovic' = 0.214 -> KEIN Fehltreffer.
--   * Fuzzy erst ab Query-Laenge >= 4 (bei 2-3 Zeichen waere Trigramm-Aehnlichkeit
--     reines Rauschen; die Praefix-Suche deckt kurze Eingaben ohnehin ab).
--   * Sortierung: exakte Praefix-Treffer ZUERST, dann nach Aehnlichkeit, dann Name.
--   * NEUE Spalte `unscharf` (bool): true = Zeile hat NUR ueber Aehnlichkeit gematcht.
--     Das Frontend trennt damit "Treffer" von "Moegliche Treffer".
--
-- WICHTIG — die Suche darf NICHT einen ganzen Namen ("Milan Vidovic") in EIN Feld schicken:
-- dann matcht 'milan' unscharf gegen "milan vidovic" (0.429) und JEDER Milan/Vidovic kommt mit,
-- bei Gleichstand sogar vor dem echten Treffer. Das Frontend SPLITTET mehrwortige Eingaben
-- daher in Vor-/Nachname (sucheSplitVarianten) -> exakter AND-Praefix-Treffer gewinnt.
--
-- Signatur unveraendert; RUECKGABETYP erweitert (+`unscharf`) -> DROP + CREATE noetig und
-- Frontend-Deploy gehoert dazu. Ersetzt supabase_personen_suche_hatkonto.sql (idempotent).
--
-- search_path = public, extensions: pg_trgm liegt auf Supabase i. d. R. im Schema
-- `extensions`, bei lokaler Installation in `public`. Beide Faelle funktionieren; ein
-- nicht existierendes Schema im search_path wird von Postgres still ignoriert.
--
-- KEIN GIN-Index: der OR-Zweig (LIKE ... OR similarity(...)) waere ohnehin nicht
-- index-nutzbar, und die RLS-Praedikate (sieht_familie) erzwingen bereits einen
-- Zeilen-Scan. Bei der Datenmenge dieser App (alle Personen werden im Client komplett
-- im Speicher gehalten) ist das unkritisch. Bei Wachstum: hier nachruesten.
--
-- Im Supabase SQL-Editor ausfuehren. NACH supabase_personen_suche_hatkonto.sql.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP FUNCTION IF EXISTS public.personen_suche(text, text, text, int, int);

CREATE FUNCTION public.personen_suche(
  p_vorname text DEFAULT NULL, p_nachname text DEFAULT NULL, p_geburt text DEFAULT NULL,
  p_limit int DEFAULT 30, p_offset int DEFAULT 0)
RETURNS TABLE(
  id uuid, name text, given text, surname text,
  birth_date text, death_date text,
  baum text, baum_id uuid, familie_id uuid, identitaet_id uuid,
  eltern text, partner text, hat_konto boolean, unscharf boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, extensions AS $$
  WITH n AS (
    SELECT nullif(public.merge_norm(p_vorname),'')  AS vn,
           nullif(public.merge_norm(p_nachname),'') AS nn,
           nullif(trim(coalesce(p_geburt,'')),'')   AS bd
  )
  SELECT pe.id,
    trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS name,
    pe.vorname AS given, pe.nachname AS surname,
    nullif(trim(coalesce(pe.stammbaum_daten->>'birth_date','')),'') AS birth_date,
    nullif(trim(coalesce(pe.stammbaum_daten->>'death_date','')),'') AS death_date,
    s.name AS baum, pe.stammbaum_id AS baum_id, pe.familie_id, pe.identitaet_id,
    (SELECT string_agg(DISTINCT trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')), ', ')
       FROM public.beziehungen b JOIN public.personen po ON po.id = b.person_a
       WHERE b.typ='elternteil' AND b.person_b = pe.id
         AND b.geloescht_am IS NULL AND po.geloescht_am IS NULL) AS eltern,
    (SELECT string_agg(DISTINCT trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')), ', ')
       FROM public.beziehungen b
       JOIN public.personen po ON po.id = CASE WHEN b.person_a = pe.id THEN b.person_b ELSE b.person_a END
       WHERE b.typ='ehepartner' AND b.geloescht_am IS NULL AND (b.person_a = pe.id OR b.person_b = pe.id)
         AND b.geloescht_am IS NULL AND po.geloescht_am IS NULL) AS partner,
    (pe.user_id IS NOT NULL) AS hat_konto,
    -- unscharf = die Zeile hat NUR ueber Trigramm-Aehnlichkeit gematcht (kein Praefix-Treffer).
    -- Das Frontend zeigt solche Zeilen getrennt unter "Moegliche Treffer" an.
    (NOT ((n.vn IS NULL OR public.merge_norm(pe.vorname)  LIKE n.vn || '%')
      AND (n.nn IS NULL OR public.merge_norm(pe.nachname) LIKE n.nn || '%'))) AS unscharf
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  CROSS JOIN n
  WHERE pe.geloescht_am IS NULL
    AND (public.ist_super_admin() OR public.sieht_familie(pe.familie_id))
    AND (n.vn IS NOT NULL OR n.nn IS NOT NULL OR n.bd IS NOT NULL)
    -- Vorname: Praefix ODER (ab 4 Zeichen) trigramm-aehnlich
    AND (n.vn IS NULL
         OR public.merge_norm(pe.vorname) LIKE n.vn || '%'
         OR (length(n.vn) >= 4 AND similarity(public.merge_norm(pe.vorname), n.vn) >= 0.35))
    -- Nachname: analog
    AND (n.nn IS NULL
         OR public.merge_norm(pe.nachname) LIKE n.nn || '%'
         OR (length(n.nn) >= 4 AND similarity(public.merge_norm(pe.nachname), n.nn) >= 0.35))
    AND (n.bd IS NULL OR coalesce(pe.stammbaum_daten->>'birth_date','') ILIKE '%'||n.bd||'%')
  ORDER BY
    -- 1) exakte Praefix-Treffer zuerst, unscharfe danach
    (CASE WHEN (n.vn IS NULL OR public.merge_norm(pe.vorname)  LIKE n.vn || '%')
            AND (n.nn IS NULL OR public.merge_norm(pe.nachname) LIKE n.nn || '%')
          THEN 0 ELSE 1 END),
    -- 2) innerhalb der unscharfen Treffer: aehnlichste zuerst
    (CASE WHEN n.vn IS NOT NULL THEN similarity(public.merge_norm(pe.vorname),  n.vn) ELSE 0 END
   + CASE WHEN n.nn IS NOT NULL THEN similarity(public.merge_norm(pe.nachname), n.nn) ELSE 0 END) DESC,
    pe.nachname, pe.vorname
  LIMIT greatest(1, least(coalesce(p_limit,30), 100))
  OFFSET greatest(0, coalesce(p_offset,0));
$$;
GRANT EXECUTE ON FUNCTION public.personen_suche(text, text, text, int, int) TO authenticated;

NOTIFY pgrst, 'reload schema';

SELECT 'personen_suche: tolerante Trigramm-Suche aktiv (pg_trgm, Schwelle 0.35 ab 4 Zeichen)' AS status;
