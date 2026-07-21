-- =====================================================
-- OPTION B — SCHRITT 2a: PLAN (READ-ONLY Vorschau). KOMPLETT ausführbar, KEIN Risiko.
-- =====================================================
-- Ändert KEINE Personen/Beziehungen. Baut nur zwei Hilfstabellen
--   * migration_personen_map     (kanonische Person je identitaet_id-Gruppe)
--   * migration_feld_konflikte   (Felder, die zwischen Zwillingen abweichen)
-- und gibt die Plan-Zahlen aus. Erst danach folgt (separat) die destruktive Migration.
--
-- Kanonische Wahl (freigegeben): (1) Konto verknüpft (user_id) > (2) vollständigste
-- stammbaum_daten > (3) kleinste externe_id. NUR AKTIVE (geloescht_am IS NULL).
-- =====================================================

CREATE TABLE IF NOT EXISTS public.migration_personen_map (
  alt_id         uuid PRIMARY KEY,
  kanonische_id  uuid NOT NULL,
  identitaet_id  uuid NOT NULL,
  ts             timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.migration_feld_konflikte (
  identitaet_id  uuid NOT NULL,
  feld           text NOT NULL,
  werte          jsonb NOT NULL,
  ts             timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (identitaet_id, feld)
);

TRUNCATE public.migration_personen_map;
TRUNCATE public.migration_feld_konflikte;

-- Mapping: je AKTIVER identitaet_id-Gruppe die kanonische Person; alle aktiven Mitglieder eingetragen.
INSERT INTO public.migration_personen_map (alt_id, kanonische_id, identitaet_id)
SELECT p.id, k.kanon, p.identitaet_id
FROM public.personen p
JOIN (
  SELECT DISTINCT ON (identitaet_id) identitaet_id, id AS kanon
  FROM public.personen
  WHERE identitaet_id IS NOT NULL AND geloescht_am IS NULL
  ORDER BY identitaet_id,
    (user_id IS NOT NULL) DESC,
    (SELECT count(*) FROM jsonb_each_text(coalesce(stammbaum_daten, '{}'::jsonb)) e WHERE e.value <> '') DESC,
    externe_id ASC
) k ON k.identitaet_id = p.identitaet_id
WHERE p.identitaet_id IS NOT NULL AND p.geloescht_am IS NULL;

-- Feld-Konflikte: je Gruppe Felder mit >1 verschiedenem nicht-leerem Wert (NICHT still überschreiben).
INSERT INTO public.migration_feld_konflikte (identitaet_id, feld, werte)
SELECT identitaet_id, key, jsonb_agg(DISTINCT val ORDER BY val)
FROM (
  SELECT p.identitaet_id, e.key, e.value AS val
  FROM public.personen p, jsonb_each_text(coalesce(p.stammbaum_daten, '{}'::jsonb)) e
  WHERE p.identitaet_id IS NOT NULL AND p.geloescht_am IS NULL AND e.value <> ''
    AND e.key IN ('given','surname','birth_date','death_date','sex','ehename',
                  'birth_place','death_place','geburtsland','beschreibung')
) s
GROUP BY identitaet_id, key
HAVING count(DISTINCT val) > 1
ON CONFLICT (identitaet_id, feld) DO UPDATE SET werte = EXCLUDED.werte;

-- ===== PLAN-ZAHLEN =====
SELECT
  (SELECT count(*) FROM public.personen WHERE identitaet_id IS NOT NULL AND geloescht_am IS NULL) AS aktive_zwillingskarten,
  (SELECT count(DISTINCT identitaet_id) FROM public.migration_personen_map)                       AS gruppen,
  (SELECT count(*) FROM public.migration_personen_map WHERE alt_id <> kanonische_id)              AS zu_loeschende_karten,
  (SELECT count(*) FROM public.migration_feld_konflikte)                                          AS feld_konflikte;

-- ===== KONFLIKTE im Detail (zum Klären mit Claude) =====
SELECT * FROM public.migration_feld_konflikte ORDER BY identitaet_id, feld;
