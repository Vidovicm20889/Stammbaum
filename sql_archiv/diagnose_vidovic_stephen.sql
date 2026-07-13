-- =====================================================
-- DIAGNOSE (NUR LESEN — ändert NICHTS): warum zeigt „Vidović (Stephen)" den ganzen Vidović-Baum?
-- Ausführen in: Supabase -> SQL Editor.
--
-- Zwischenstand:
--   Abschnitt A ergab: die (Stephen)-Person „Cyrilo Stephen - Vidović" hat
--   identitaet_id = NULL, karten = 0  => KEINE Identitäts-Brücke.
--   => Nächster Verdacht: Cyrilo hat BEZIEHUNGEN (Kanten) zu Personen des großen Vidović-Baums.
--      Der Renderer baut EIN globales Diagramm; die Blutlinien-Eingrenzung geht über den NAMEN
--      („vidovic"), nicht über die Baum-ID -> solche Kanten ziehen die ganze Linie herein.
--
-- WICHTIG: Der Supabase-SQL-Editor zeigt nur das Ergebnis der LETZTEN Abfrage.
--          Darum unten die EINE aktive Kern-Abfrage (Abschnitt D). Einfach ausführen.
-- =====================================================


-- ============ D) KERN: Cyrilos Beziehungen + Baum der Gegenperson — DIESE AUSFÜHREN ============
-- Jede Zeile = eine Kante von/zu Cyrilo. Spalte „anderer_baum" zeigt, in welchem Baum die
-- verbundene Person liegt.
--   Zeigen Zeilen auf „Vidović" (der 72er-Baum)  => das ist die Brücke, die alles hereinzieht.
--   0 Zeilen                                       => Cyrilo ist wirklich lose; dann melden,
--                                                     ich schaue den Ansichts-/Wurzel-Pfad an.
SELECT b.typ,
       CASE WHEN b.person_a = pe.id THEN 'Cyrilo → …' ELSE '… → Cyrilo' END AS richtung,
       o.vorname || ' ' || o.nachname                        AS gegenperson,
       o.nachname                                            AS gegen_nachname,
       so.name || coalesce(' ('||so.zusatz||')','')          AS gegen_baum
FROM public.personen pe
JOIN public.stammbaeume s  ON s.id = pe.stammbaum_id AND s.zusatz ILIKE '%Stephen%'
JOIN public.beziehungen b  ON (b.person_a = pe.id OR b.person_b = pe.id) AND b.geloescht_am IS NULL
JOIN public.personen o     ON o.id = CASE WHEN b.person_a = pe.id THEN b.person_b ELSE b.person_a END
                            AND o.geloescht_am IS NULL
JOIN public.stammbaeume so ON so.id = o.stammbaum_id
WHERE pe.geloescht_am IS NULL
ORDER BY gegen_baum, b.typ;


-- ============ (Referenz) A) — schon ausgeführt: identitaet_id = NULL, karten = 0 ============
-- SELECT pe.vorname || ' ' || pe.nachname AS person, pe.identitaet_id,
--   (SELECT count(*) FROM public.personen p2
--      WHERE p2.identitaet_id = pe.identitaet_id AND pe.identitaet_id IS NOT NULL AND p2.geloescht_am IS NULL) AS karten,
--   (SELECT count(*) FROM public.beziehungen b
--      WHERE b.geloescht_am IS NULL AND (b.person_a = pe.id OR b.person_b = pe.id)) AS eigene_kanten
-- FROM public.personen pe
-- JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
-- WHERE pe.geloescht_am IS NULL AND s.zusatz ILIKE '%Stephen%';
