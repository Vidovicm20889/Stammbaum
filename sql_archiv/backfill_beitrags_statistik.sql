-- =====================================================
-- EINMALIGER BACKFILL: historische Beiträge -> beitrags_statistik (sanfte Gamification, v13.9)
-- NUR EINMAL ausführen (NICHT Teil des idempotenten Neuaufbaus -> liegt bewusst in sql_archiv).
-- Voraussetzung: supabase_beitrags_statistik.sql wurde bereits ausgeführt (Tabelle + Trigger).
--
-- WARUM ÜBERHAUPT NÖTIG: Die Trigger zählen ab Deployment NUR NEUE Inserts (vorwärts). Bestehende
-- Personen/Fotos/Geschichten wurden nie gezählt -> ohne Backfill bleiben die Profile-Zähler 0.
--
-- ====== EHRLICHE GRENZE DER ZUORDNUNG (bitte lesen) ======
-- KEINE der Quelltabellen speichert einen "Ersteller":
--   * personen.user_id = das VERKNÜPFTE Konto (die Person selbst), NICHT der Erfasser.
--   * personen_fotos / personen_geschichten: gar keine Uploader-/Autor-Spalte.
-- Eine EXAKTE Rückverteilung auf den jeweiligen Erfasser ist daher unmöglich.
-- HEURISTIK (bewusst, generös, da Gamification ohne Wettbewerb/Rangliste):
--   Alle bestehenden Inhalte einer Familie werden dem FAMILIEN-OWNER gutgeschrieben
--   (mitgliedschaften.rolle = 'familien_owner') — der den Baum i. d. R. angelegt hat.
--   Familien OHNE Owner werden übersprungen (nicht zuordenbar).
--
-- ENTDOPPLUNG (analog der Trigger-Logik):
--   * Platzhalter-Personen ("Unbekannt"-Eltern) zählen NICHT.
--   * identitaet_id-Spiegelkarten zählen nur EINMAL (die Karte mit der kleinsten id gewinnt;
--     ihr familie_id/Owner bekommt die Gutschrift).
--   * Geschichten werden je (reale Person, Sprache) nur EINMAL gezählt (Spiegel über
--     geschichte_ident_sync ausgeklammert). Hinweis: die beim Geschichten-Backfill aus
--     `beschreibung` geseedete de-Geschichte zählt mit (kein Flag, um sie zu unterscheiden).
--
-- ====== WICHTIG: NICHT ZWEIMAL AUSFÜHREN ======
-- Das Skript ADDIERT (DO UPDATE += ...). Direkt NACH dem Deployment ausführen, BEVOR neue Inhalte
-- angelegt werden. Bei erneutem Lauf würden die Zähler doppelt hochgesetzt; bei verzögertem Lauf
-- könnten einzelne, bereits vorwärts gezählte Neu-Inserts geringfügig doppelt erscheinen.
-- =====================================================

WITH
-- Echte Personen (kein Platzhalter), je identitaet_id-Gruppe nur EINE Karte (kleinste id):
personen_dedupe AS (
  SELECT DISTINCT ON (coalesce(p.identitaet_id::text, p.id::text))
         p.id, p.familie_id
  FROM public.personen p
  WHERE coalesce(p.stammbaum_daten->>'platzhalter','') <> 'true'
  ORDER BY coalesce(p.identitaet_id::text, p.id::text), p.id
),
-- Geschichten je (reale Person, Sprache) nur EINMAL (Spiegel entdoppelt):
gesch_dedupe AS (
  SELECT DISTINCT ON (coalesce(pp.identitaet_id::text, g.person_id::text), g.sprache)
         g.id, g.familie_id
  FROM public.personen_geschichten g
  JOIN public.personen pp ON pp.id = g.person_id
  ORDER BY coalesce(pp.identitaet_id::text, g.person_id::text), g.sprache, g.id
),
-- Zählungen je Familie:
person_cnt AS (SELECT familie_id, count(*) AS n FROM personen_dedupe       GROUP BY familie_id),
foto_cnt   AS (SELECT familie_id, count(*) AS n FROM public.personen_fotos GROUP BY familie_id),
gesch_cnt  AS (SELECT familie_id, count(*) AS n FROM gesch_dedupe          GROUP BY familie_id),
-- Familie -> Verbund + Owner (genau ein Owner je Familie; aktive Mitgliedschaft bevorzugt):
fam AS (
  SELECT f.id AS familie_id, f.verbund_id,
         (SELECT m.user_id FROM public.mitgliedschaften m
            WHERE m.familie_id = f.id AND m.rolle = 'familien_owner'
            ORDER BY (m.aktiv IS TRUE) DESC, m.user_id
            LIMIT 1) AS owner_id
  FROM public.familien f
),
-- Pro Familie die drei Zähler an Verbund + Owner hängen:
je_familie AS (
  SELECT fam.verbund_id, fam.owner_id,
         coalesce(pc.n, 0) AS pa, coalesce(fc.n, 0) AS fo, coalesce(gc.n, 0) AS ge
  FROM fam
  LEFT JOIN person_cnt pc ON pc.familie_id = fam.familie_id
  LEFT JOIN foto_cnt   fc ON fc.familie_id = fam.familie_id
  LEFT JOIN gesch_cnt  gc ON gc.familie_id = fam.familie_id
  WHERE fam.owner_id IS NOT NULL AND fam.verbund_id IS NOT NULL
),
-- Über alle Familien des Owners im selben Verbund aufsummieren:
agg AS (
  SELECT verbund_id, owner_id AS user_id,
         sum(pa)::int AS personen_angelegt,
         sum(fo)::int AS fotos_hinzugefuegt,
         sum(ge)::int AS geschichten_geschrieben
  FROM je_familie
  GROUP BY verbund_id, owner_id
)
INSERT INTO public.beitrags_statistik
  (verbund_id, user_id, personen_angelegt, fotos_hinzugefuegt, geschichten_geschrieben)
SELECT verbund_id, user_id, personen_angelegt, fotos_hinzugefuegt, geschichten_geschrieben
FROM agg
WHERE personen_angelegt > 0 OR fotos_hinzugefuegt > 0 OR geschichten_geschrieben > 0
ON CONFLICT (verbund_id, user_id) DO UPDATE SET
  personen_angelegt       = public.beitrags_statistik.personen_angelegt       + EXCLUDED.personen_angelegt,
  fotos_hinzugefuegt      = public.beitrags_statistik.fotos_hinzugefuegt      + EXCLUDED.fotos_hinzugefuegt,
  geschichten_geschrieben = public.beitrags_statistik.geschichten_geschrieben + EXCLUDED.geschichten_geschrieben,
  aktualisiert_am         = now();

-- Kontrolle: was wurde gutgeschrieben?
SELECT count(*) AS konten_mit_beitraegen,
       coalesce(sum(personen_angelegt), 0)       AS summe_personen,
       coalesce(sum(fotos_hinzugefuegt), 0)      AS summe_fotos,
       coalesce(sum(geschichten_geschrieben), 0) AS summe_geschichten
FROM public.beitrags_statistik;
