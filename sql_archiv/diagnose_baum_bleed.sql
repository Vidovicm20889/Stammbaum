-- =====================================================
-- DIAGNOSE (NUR LESEN — ändert NICHTS): systemische Baum-„Bleed"-Quellen aufdecken
-- Ausführen in: Supabase -> SQL Editor. Jede Abfrage EINZELN markieren + ausführen
-- (der Editor zeigt nur das Ergebnis der letzten Abfrage).
--
-- Hintergrund: Ein Baum zeigt eine FREMDE Familie (z. B. „Tadić" zeigt Jovanović), wenn eine Person
-- über eine ROHE baumübergreifende Kante (elternteil/ehepartner, OHNE identitaet_id-Spiegel) mit
-- einem anderen Baum verbunden ist. Der globale Renderer wandert dann über diese Kante hinüber.
-- =====================================================


-- ============ A) ROHE baumübergreifende ELTERNTEIL-Kanten als JSON (Hauptursache für Bleed) ============
-- Kind in Baum X, Elternteil in Baum Y, KEINE identitaet_id-Spiegelung dazwischen. Ergebnis = EINE
-- Zelle mit dem kompletten JSON-Array (bequem kopierbar).
SELECT json_agg(t) AS bleed_json FROM (
  SELECT
    s_kind.name  || coalesce(' ('||s_kind.zusatz ||')','') AS kind_baum,
    k.vorname || ' ' || k.nachname                          AS kind,
    e.vorname || ' ' || e.nachname                          AS elternteil,
    s_elt.name  || coalesce(' ('||s_elt.zusatz  ||')','')   AS eltern_baum,
    k.identitaet_id                                         AS kind_ident,
    e.identitaet_id                                         AS eltern_ident
  FROM public.beziehungen b
  JOIN public.personen  e ON e.id = b.person_a AND e.geloescht_am IS NULL   -- person_a = Elternteil
  JOIN public.personen  k ON k.id = b.person_b AND k.geloescht_am IS NULL   -- person_b = Kind
  JOIN public.stammbaeume s_elt  ON s_elt.id  = e.stammbaum_id
  JOIN public.stammbaeume s_kind ON s_kind.id = k.stammbaum_id
  WHERE b.typ = 'elternteil' AND b.geloescht_am IS NULL
    AND e.stammbaum_id <> k.stammbaum_id                                    -- verschiedene Bäume
    AND coalesce(e.identitaet_id::text,'x') <> coalesce(k.identitaet_id::text,'y')
  ORDER BY kind_baum, kind
) t;
-- (Ergebnis = EINE Zelle „bleed_json". B/C unten sind auskommentiert -> stören nicht.)


-- ============ B) Welche NACHNAMEN stecken je Baum? (deckt mislabelte/gemischte Bäume auf) ============
-- Zeigt „Tadić-Baum enthält Jovanović" direkt: pro Baum die vorkommenden Nachnamen + Anzahl.
-- SELECT s.name || coalesce(' ('||s.zusatz||')','') AS baum,
--        coalesce(nullif(btrim(pe.nachname),''),'(leer)') AS nachname,
--        count(*) AS anzahl
-- FROM public.stammbaeume s
-- JOIN public.personen pe ON pe.stammbaum_id = s.id AND pe.geloescht_am IS NULL
-- GROUP BY 1, 2
-- ORDER BY baum, anzahl DESC;


-- ============ C) ROHE baumübergreifende EHEPARTNER-Kanten (Partner-Bleed, meist harmlos = Blatt) ============
-- SELECT s_a.name || coalesce(' ('||s_a.zusatz||')','') AS baum_a,
--        a.vorname||' '||a.nachname AS person_a, '⇔' AS ehe,
--        c.vorname||' '||c.nachname AS person_b,
--        s_c.name || coalesce(' ('||s_c.zusatz||')','') AS baum_b
-- FROM public.beziehungen b
-- JOIN public.personen a ON a.id = b.person_a AND a.geloescht_am IS NULL
-- JOIN public.personen c ON c.id = b.person_b AND c.geloescht_am IS NULL
-- JOIN public.stammbaeume s_a ON s_a.id = a.stammbaum_id
-- JOIN public.stammbaeume s_c ON s_c.id = c.stammbaum_id
-- WHERE b.typ = 'ehepartner' AND b.geloescht_am IS NULL
--   AND a.stammbaum_id <> c.stammbaum_id
-- ORDER BY baum_a;
