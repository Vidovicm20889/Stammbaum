-- ===============================================================
-- DIAGNOSE (NUR LESEN, ändert NICHTS) — Konsistenz-Check
-- Erwartung (Regel "eine Familie pro Baum", ab v10.1):
--   Anzahl unterschiedlicher Nachnamen  ==  Anzahl Stammbäume  ==  Anzahl Familien
-- Ausführen in: Supabase -> SQL Editor. Jeder Block liefert eigene Zeilen.
--
-- Hinweise zur Interpretation:
--  * Nachnamen werden über merge_norm() normalisiert (diakritik-/groß-klein-unempfindlich),
--    damit "Begović" und "Begovic" NICHT doppelt zählen.
--  * "Nachname eines Baums" = der NAME des Stammbaums (stammbaeume.name). Personen-Nachnamen
--    eignen sich NICHT als Zähler, weil eingeheiratete/gespiegelte Personen fremde Nachnamen
--    in einen Baum tragen (1 Baum hätte sonst mehrere Nachnamen).
--  * Es werden NUR aktive Bäume gezählt (coalesce(aktiv,true)).
-- ===============================================================


-- ===============================================================
-- BLOCK 1 — HEADLINE: die drei Zahlen nebeneinander + OK/NICHT-OK
-- ===============================================================
WITH
baeume AS (
  SELECT s.id, s.name, s.familie_id
  FROM public.stammbaeume s
  WHERE coalesce(s.aktiv, true)
),
zahlen AS (
  SELECT
    (SELECT count(DISTINCT public.merge_norm(b.name)) FROM baeume b) AS distinct_nachnamen,
    (SELECT count(*)                                   FROM baeume b) AS anzahl_baeume,
    (SELECT count(*)                                   FROM public.familien f) AS anzahl_familien
)
SELECT
  distinct_nachnamen,
  anzahl_baeume,
  anzahl_familien,
  CASE
    WHEN distinct_nachnamen = anzahl_baeume AND anzahl_baeume = anzahl_familien
      THEN '✅ OK — 1:1:1'
    ELSE '❌ MISMATCH — siehe Block 2–5'
  END AS status
FROM zahlen;


-- ===============================================================
-- BLOCK 2 — FAMILIE ↔ BAUM 1:1: Familien mit ungleich 1 (aktivem) Baum
--   >1  = Familie hält mehrere Bäume (verstößt gegen "1 Familie pro Baum")
--    0  = Familie ohne aktiven Baum (verwaist / leer)
-- ===============================================================
SELECT f.id AS familie_id, f.name AS familie, f.verbund_id,
       count(s.id) AS aktive_baeume,
       coalesce(string_agg(s.name, ', ' ORDER BY s.name), '—') AS baum_namen
FROM public.familien f
LEFT JOIN public.stammbaeume s
       ON s.familie_id = f.id AND coalesce(s.aktiv, true)
GROUP BY f.id, f.name, f.verbund_id
HAVING count(s.id) <> 1
ORDER BY aktive_baeume DESC, f.name;


-- ===============================================================
-- BLOCK 3 — NACHNAME (= BAUMNAME) ↔ BAUM 1:1:
--   Normalisierte Baum-Namen, die mehr als 1 aktiven Baum haben (doppelte Linie)
-- ===============================================================
SELECT public.merge_norm(s.name) AS nachname_norm,
       count(*) AS anzahl_baeume,
       string_agg(s.name || ' (id=' || s.id || ', fam=' || s.familie_id || ')', ' | '
                  ORDER BY s.name) AS baeume
FROM public.stammbaeume s
WHERE coalesce(s.aktiv, true)
GROUP BY public.merge_norm(s.name)
HAVING count(*) > 1
ORDER BY anzahl_baeume DESC, nachname_norm;


-- ===============================================================
-- BLOCK 4 — VOLLE ÜBERSICHT: jeder aktive Baum mit Familie + Verbund
--   (zum Querlesen, welche Baum/Familie-Paare existieren)
-- ===============================================================
SELECT s.id AS stammbaum_id, s.name AS baum,
       public.merge_norm(s.name) AS nachname_norm,
       f.id AS familie_id, f.name AS familie, f.verbund_id,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
FROM public.stammbaeume s
LEFT JOIN public.familien f ON f.id = s.familie_id
WHERE coalesce(s.aktiv, true)
ORDER BY f.verbund_id NULLS FIRST, public.merge_norm(s.name);


-- ===============================================================
-- BLOCK 5 — GEGENPROBE auf PERSONEN-NACHNAMEN:
--   Welche normalisierten Personen-Nachnamen haben KEINEN gleichnamigen Baum?
--   (Kandidaten für "fehlt ein eigener Stammbaum/Familie" — eingeheiratete Linien)
--   identitaet_id-Dubletten werden über DISTINCT auf (norm, identitaet_id) entschärft.
-- ===============================================================
WITH personen_namen AS (
  SELECT DISTINCT
         public.merge_norm(pe.nachname) AS nachname_norm,
         coalesce(pe.identitaet_id::text, pe.id::text) AS ident
  FROM public.personen pe
  WHERE pe.nachname IS NOT NULL AND btrim(pe.nachname) <> ''
),
baum_namen AS (
  SELECT DISTINCT public.merge_norm(s.name) AS nachname_norm
  FROM public.stammbaeume s
  WHERE coalesce(s.aktiv, true)
)
SELECT pn.nachname_norm,
       count(*) AS anzahl_personen,
       CASE WHEN bn.nachname_norm IS NULL
            THEN '⚠️ kein gleichnamiger Baum'
            ELSE '✅ Baum vorhanden' END AS status
FROM personen_namen pn
LEFT JOIN baum_namen bn ON bn.nachname_norm = pn.nachname_norm
GROUP BY pn.nachname_norm, bn.nachname_norm
ORDER BY (bn.nachname_norm IS NULL) DESC, anzahl_personen DESC, pn.nachname_norm;
