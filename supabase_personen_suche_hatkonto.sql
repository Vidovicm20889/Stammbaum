-- ============================================================================
-- personen_suche + hat_konto — für die vereinte Personensuche (Nav-Feld)
-- ----------------------------------------------------------------------------
-- Erweitert die bestehende personen_suche() um eine Spalte `hat_konto` (bool), damit die
-- Trefferliste im Verbund unterscheiden kann: Person MIT verknüpftem Konto (personen.user_id
-- gesetzt) vs. reine Namenskarte OHNE Konto. Alles andere unverändert.
--
-- Rückgabetyp ändert sich (neue Spalte) -> CREATE OR REPLACE reicht NICHT, daher DROP + CREATE.
-- Idempotent (IF EXISTS). Im Supabase SQL-Editor ausführen. Ersetzt die Definition aus
-- supabase_personen_suche_verbinden.sql (gleiche Signatur + Logik, nur hat_konto ergänzt).
-- ============================================================================

DROP FUNCTION IF EXISTS public.personen_suche(text, text, text, int, int);

CREATE FUNCTION public.personen_suche(
  p_vorname text DEFAULT NULL, p_nachname text DEFAULT NULL, p_geburt text DEFAULT NULL,
  p_limit int DEFAULT 30, p_offset int DEFAULT 0)
RETURNS TABLE(
  id uuid, name text, given text, surname text,
  birth_date text, death_date text,
  baum text, baum_id uuid, familie_id uuid, identitaet_id uuid,
  eltern text, partner text, hat_konto boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
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
    (pe.user_id IS NOT NULL) AS hat_konto
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  CROSS JOIN n
  WHERE pe.geloescht_am IS NULL
    AND (public.ist_super_admin() OR public.sieht_familie(pe.familie_id))
    AND (n.vn IS NOT NULL OR n.nn IS NOT NULL OR n.bd IS NOT NULL)
    AND (n.vn IS NULL OR public.merge_norm(pe.vorname)  LIKE n.vn || '%')
    AND (n.nn IS NULL OR public.merge_norm(pe.nachname) LIKE n.nn || '%')
    AND (n.bd IS NULL OR coalesce(pe.stammbaum_daten->>'birth_date','') ILIKE '%'||n.bd||'%')
  ORDER BY pe.nachname, pe.vorname
  LIMIT greatest(1, least(coalesce(p_limit,30), 100))
  OFFSET greatest(0, coalesce(p_offset,0));
$$;
GRANT EXECUTE ON FUNCTION public.personen_suche(text, text, text, int, int) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'personen_suche um hat_konto erweitert' AS status;
