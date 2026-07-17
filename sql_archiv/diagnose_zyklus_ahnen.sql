-- ============================================================================
-- DIAGNOSE: Zyklus in der Ahnenkette („jemand ist sein eigener Vorfahr")
-- ----------------------------------------------------------------------------
-- WARUM: Der Graph-Renderer (graphRaenge) vergibt Generationen, indem er Kinder immer eine Ebene
-- unter die Eltern schiebt. Existiert ein KREIS (A ist Vorfahr von B und B wieder von A), gibt es
-- keine gültige Generationen-Reihenfolge -> die Schleife läuft in ihr Iterations-Limit, Personen
-- landen in völlig falschen Ebenen und „wer gehört wem" ist im Baum nicht mehr erkennbar.
-- Beobachtet im Baum „Scicluna": Ränge 65–67 bei nur 7 echten Reihen = klassische Zyklus-Signatur.
--
-- Dieses Skript ist REINE DIAGNOSE (nur SELECT) — es ändert nichts.
-- Einmal-/Vorfall-Skript -> gehört nicht zum Neuaufbau.
--
-- beziehungen: typ='elternteil' -> person_a = ELTERNTEIL, person_b = KIND.
-- ============================================================================

-- 1) Zyklen finden: Eltern->Kind-Ketten verfolgen, bis eine Person erneut in ihrer eigenen Kette auftaucht.
WITH RECURSIVE pfad AS (
  SELECT b.person_a AS start,
         b.person_b AS aktuell,
         ARRAY[b.person_a, b.person_b] AS kette,
         (b.person_a = b.person_b) AS zyklus
    FROM public.beziehungen b
   WHERE b.typ = 'elternteil' AND b.geloescht_am IS NULL
  UNION ALL
  SELECT p.start,
         b.person_b,
         p.kette || b.person_b,
         b.person_b = ANY(p.kette)
    FROM pfad p
    JOIN public.beziehungen b
      ON b.person_a = p.aktuell AND b.typ = 'elternteil' AND b.geloescht_am IS NULL
   WHERE NOT p.zyklus
     AND array_length(p.kette, 1) < 40          -- Sicherheitsnetz gegen Endlos-Rekursion
)
SELECT DISTINCT
       array_length(k.kette, 1) AS kettenlaenge,
       (SELECT string_agg(trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) ||
                          ' [' || coalesce(s.name,'?') || ']', '  ->  ' ORDER BY o.ord)
          FROM unnest(k.kette) WITH ORDINALITY AS o(pid, ord)
          JOIN public.personen pe ON pe.id = o.pid
          LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id) AS kreis
  FROM pfad k
 WHERE k.zyklus
 ORDER BY 1
 LIMIT 20;

-- 2) Falls (1) zu langsam/leer ist: die verdächtigen Kanten EINES Baums direkt ansehen.
--    Baum-ID unten eintragen (z. B. die von „Scicluna" aus dem Nav-Dropdown).
-- SELECT b.id AS beziehung_id, b.typ,
--        trim(coalesce(pa.vorname,'')||' '||coalesce(pa.nachname,'')) AS elternteil,
--        trim(coalesce(pb.vorname,'')||' '||coalesce(pb.nachname,'')) AS kind
--   FROM public.beziehungen b
--   JOIN public.personen pa ON pa.id = b.person_a
--   JOIN public.personen pb ON pb.id = b.person_b
--  WHERE b.typ = 'elternteil' AND b.geloescht_am IS NULL
--    AND (pa.stammbaum_id = '<BAUM_ID>' OR pb.stammbaum_id = '<BAUM_ID>')
--  ORDER BY elternteil, kind;

-- 3) IST EIN KREIS GEFUNDEN? -> Die FALSCHE Kante in der App lösen (Detailkarte -> Verwandten-Chip -> ✕
--    bzw. ⇄ „Beziehung ändern"). Danach stimmen Generationen und Layout wieder.
--    Bewusst KEIN automatisches DELETE hier: welche der Kanten die falsche ist, kann nur ein Mensch
--    entscheiden (sonst löscht man evtl. die richtige Abstammung).
