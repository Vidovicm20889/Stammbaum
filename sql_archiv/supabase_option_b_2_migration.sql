-- =====================================================
-- OPTION B — SCHRITT 2: MIGRATION (Zwillinge zusammenführen / identitaet_id auflösen)
-- =====================================================
-- ⚠️⚠️ ENTWURF — IRREVERSIBLE DATENÄNDERUNG. NICHT blind ausführen. ⚠️⚠️
-- Reihenfolge: Renderer verifiziert → frischer Backup-Snapshot + Restore-Dry-Run →
--   supabase_option_b_1_schema.sql → DIESES File im DRY-RUN (Abschnitt B endet auf ROLLBACK) →
--   Feld-Konflikt-Report (migration_feld_konflikte) MIT DIR klären → erst dann Abschnitt B mit
--   COMMIT scharf → danach supabase_papierkorb.sql ERNEUT (RLS-Filter) ausführen.
--
-- ZIEL: je identitaet_id-Gruppe EINE kanonische Person; alle Verweise der übrigen (aktiven)
-- Zwillinge darauf umhängen (REPOINT VOR DELETE!), Beziehungen deduplizieren, Selbstbezüge/Zyklen
-- bereinigen, dann die nicht-kanonischen AKTIVEN Zwillinge löschen. identitaet_id bleibt als
-- historische Spalte (eine reale Person je Identität → faktisch ungenutzt).
--
-- PAPIERKORB-BEWUSST (supabase_papierkorb.sql ist LIVE): Es werden NUR AKTIVE Zeilen
-- (geloescht_am IS NULL) zusammengeführt/gelöscht. Soft-gelöschte Zwillinge + deren Kanten
-- bleiben unangetastet im Papierkorb (30-Tage-Restore bleibt heil); sie werden vom regulären
-- papierkorb_purge entfernt.
--
-- KANONISCHE WAHL (freigegeben): (1) Konto verknüpft (user_id) > (2) vollständigste
-- stammbaum_daten > (3) kleinste externe_id.
--
-- VERLUSTFREIHEIT: auf Zeilen-/Verweis-/Beziehungs-Ebene verlustfrei. NICHT verlustfrei auf
-- FELD-Ebene bei Konflikten (eine Variante gewinnt; die anderen stehen in migration_feld_konflikte
-- + im Backup-Snapshot) und bei pos_x/pos_y (kanonische behält eine Position).
-- =====================================================


-- #####################################################
-- ABSCHNITT A — PLAN AUFBAUEN (sicher, KEINE Personendaten-Änderung). Beliebig oft ausführbar.
-- #####################################################

-- Mapping-/Konflikt-Tabellen (persistent, für Nachvollzug/Rollback-Hilfe).
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

-- Frisch aufbauen (idempotent).
TRUNCATE public.migration_personen_map;
TRUNCATE public.migration_feld_konflikte;

-- Kanonische Person je identitaet_id-Gruppe (nur AKTIVE), Mapping ALLER aktiven Gruppen-Mitglieder.
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

-- PLAN-AUSGABE: vor dem scharfen Lauf prüfen.
SELECT
  (SELECT count(*) FROM public.personen WHERE identitaet_id IS NOT NULL AND geloescht_am IS NULL) AS aktive_zwillingskarten,
  (SELECT count(DISTINCT identitaet_id) FROM public.migration_personen_map)                       AS gruppen,
  (SELECT count(*) FROM public.migration_personen_map WHERE alt_id <> kanonische_id)              AS zu_loeschende_karten,
  (SELECT count(*) FROM public.migration_feld_konflikte)                                          AS feld_konflikte;

-- 👉 Konflikte ansehen:  SELECT * FROM public.migration_feld_konflikte ORDER BY identitaet_id, feld;
-- Erwartung Personen-Rückgang (aktiv) == zu_loeschende_karten. Erst weiter, wenn Konflikte geklärt.


-- #####################################################
-- ABSCHNITT B — DESTRUKTIV. Standardmäßig DRY-RUN (endet auf ROLLBACK).
--   Für den SCHARFEN Lauf: das letzte ROLLBACK durch COMMIT ersetzen.
-- #####################################################
BEGIN;

-- Vorher-Zähler (in Notice, zum Vergleich mit Nachher).
DO $$
DECLARE vp bigint; vb bigint;
BEGIN
  SELECT count(*) INTO vp FROM public.personen   WHERE geloescht_am IS NULL;
  SELECT count(*) INTO vb FROM public.beziehungen WHERE geloescht_am IS NULL;
  RAISE NOTICE 'VORHER aktiv: personen=%, beziehungen=%', vp, vb;
END $$;

-- B0) Hilfs-Set der zu löschenden (nicht-kanonischen) aktiven Zwillinge.
CREATE TEMP TABLE _zu_loeschen ON COMMIT DROP AS
  SELECT alt_id, kanonische_id FROM public.migration_personen_map WHERE alt_id <> kanonische_id;

-- B1) UNIQUE-Kollisionen VOR dem Repoint GENERISCH auflösen (keine Tabellennamen hartkodiert):
--     Für JEDE UNIQUE/PK-Constraint, die eine personen-FK-Spalte enthält, die nicht-kanonische
--     Kind-Zeile löschen, wenn sie nach dem Umhängen ein Duplikat einer bereits auf die kanonische
--     Person zeigenden Zeile wäre. Deckt foto_personen(foto_id,person_id),
--     personen_geschichten(person_id,sprache), event_*(event_id,person_id), … automatisch ab.
DO $$
DECLARE r record; match_cond text;
BEGIN
  FOR r IN
    SELECT t.relname AS tbl, fkcol.attname AS fkcol,
           array_remove(array_agg(DISTINCT uatt.attname), fkcol.attname) AS other_cols
    FROM pg_constraint fk
    JOIN pg_class t        ON t.oid = fk.conrelid
    JOIN pg_namespace n    ON n.oid = t.relnamespace AND n.nspname = 'public'
    JOIN pg_attribute fkcol ON fkcol.attrelid = fk.conrelid AND fkcol.attnum = fk.conkey[1]
    JOIN pg_constraint con ON con.conrelid = fk.conrelid AND con.contype IN ('u','p')
    JOIN LATERAL unnest(con.conkey) uk(attnum) ON true
    JOIN pg_attribute uatt ON uatt.attrelid = con.conrelid AND uatt.attnum = uk.attnum
    WHERE fk.contype = 'f'
      AND fk.confrelid = 'public.personen'::regclass
      AND array_length(fk.conkey, 1) = 1
      AND fkcol.attnum = ANY (con.conkey)     -- die UNIQUE/PK enthält die FK-Spalte
    GROUP BY t.relname, fkcol.attname, con.conname
  LOOP
    SELECT string_agg(format('x.%I IS NOT DISTINCT FROM y.%I', c, c), ' AND ')
      INTO match_cond FROM unnest(r.other_cols) c;
    EXECUTE format(
      'DELETE FROM public.%I x USING _zu_loeschen z WHERE x.%I = z.alt_id '
      'AND EXISTS (SELECT 1 FROM public.%I y WHERE y.%I = z.kanonische_id%s)',
      r.tbl, r.fkcol, r.tbl, r.fkcol,
      CASE WHEN coalesce(match_cond,'') = '' THEN '' ELSE ' AND ' || match_cond END);
  END LOOP;
END $$;

-- B1b) personen_fotos „1 Hauptbild je Person" ist ein PARTIELLER UNIQUE-INDEX (nicht in
--      pg_constraint) → separat behandeln: alt-Hauptbild degradieren, wenn kanon schon eins hat.
DO $$
BEGIN
  IF to_regclass('public.personen_fotos') IS NOT NULL THEN
    UPDATE public.personen_fotos x SET ist_hauptbild = false
      FROM _zu_loeschen z
     WHERE x.person_id = z.alt_id AND x.ist_hauptbild = true
       AND EXISTS (SELECT 1 FROM public.personen_fotos y
                    WHERE y.person_id = z.kanonische_id AND y.ist_hauptbild = true);
  END IF;
END $$;

-- B2) GENERISCHES FK-Repoint: ALLE FK-Spalten, die auf personen(id) zeigen, automatisch umhängen
--     (deckt personen_fotos/-dokumente/-geschichten, person_aufnahmen, foto_personen, beitraege.ref_person,
--      benachrichtigungen.ref_person, familien_fragen.person_id/geloest_person, kontakt_anfragen.ziel_person_id,
--      gedenk_eintraege, event_*, beziehungen.person_a/person_b, …). Robust gegen vergessene Tabellen.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT tc.table_name, kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
    JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = 'public'
      AND ccu.table_name = 'personen' AND ccu.column_name = 'id'
  LOOP
    EXECUTE format(
      'UPDATE public.%I t SET %I = z.kanonische_id FROM _zu_loeschen z WHERE t.%I = z.alt_id',
      r.table_name, r.column_name, r.column_name);
  END LOOP;
END $$;

-- B3) POLYMORPHE Verweise (KEIN FK → vom generischen Repoint NICHT erfasst):
--     reaktionen/kommentare (ziel_typ='person', ziel_id), aktivitaeten (ref_id bei person-Typen).
--     reaktionen hat UNIQUE(ziel_typ,ziel_id,user_id) → kollidierende Zeile des nicht-kanonischen
--     Zwillings zuerst löschen, dann umhängen.
DO $$
BEGIN
  IF to_regclass('public.reaktionen') IS NOT NULL THEN
    DELETE FROM public.reaktionen x USING _zu_loeschen z          -- UNIQUE(ziel_typ,ziel_id,user_id)
     WHERE x.ziel_typ='person' AND x.ziel_id=z.alt_id
       AND EXISTS (SELECT 1 FROM public.reaktionen y
                    WHERE y.ziel_typ='person' AND y.ziel_id=z.kanonische_id AND y.user_id=x.user_id);
    UPDATE public.reaktionen x SET ziel_id=z.kanonische_id
      FROM _zu_loeschen z WHERE x.ziel_typ='person' AND x.ziel_id=z.alt_id;
  END IF;
  IF to_regclass('public.kommentare') IS NOT NULL THEN
    UPDATE public.kommentare x SET ziel_id=z.kanonische_id
      FROM _zu_loeschen z WHERE x.ziel_typ='person' AND x.ziel_id=z.alt_id;
  END IF;
  IF to_regclass('public.aktivitaeten') IS NOT NULL THEN
    DELETE FROM public.aktivitaeten x USING _zu_loeschen z        -- UNIQUE(typ,ref_id) → Kollision vorab
     WHERE x.typ='person_neu' AND x.ref_id=z.alt_id
       AND EXISTS (SELECT 1 FROM public.aktivitaeten y WHERE y.typ='person_neu' AND y.ref_id=z.kanonische_id);
    UPDATE public.aktivitaeten x SET ref_id=z.kanonische_id
      FROM _zu_loeschen z WHERE x.typ='person_neu' AND x.ref_id=z.alt_id;
  END IF;
END $$;

-- B4) BEZIEHUNGEN bereinigen (nach dem Repoint von person_a/person_b):
--   (a) Selbstbezüge entfernen (durch Merge entstanden: person_a = person_b).
DELETE FROM public.beziehungen WHERE person_a = person_b;
--   (b) ehepartner richtungsnormalisieren (sortiertes Paar), damit Dedup A↔B = B↔A greift.
UPDATE public.beziehungen SET person_a = person_b, person_b = person_a
 WHERE typ = 'ehepartner' AND person_a > person_b;
--   (c) Doppelkanten zusammenführen: pro (person_a, person_b, typ) nur die ALTESTE behalten
--       (nur AKTIVE; Papierkorb-Kanten bleiben unberührt). ctid = physischer Zeilenzeiger.
DELETE FROM public.beziehungen a
 USING public.beziehungen b
 WHERE a.geloescht_am IS NULL AND b.geloescht_am IS NULL
   AND a.person_a = b.person_a AND a.person_b = b.person_b AND a.typ = b.typ
   AND a.ctid > b.ctid;

-- B5) Nicht-kanonische AKTIVE Zwillinge löschen. CASCADE ist jetzt ungefährlich, weil alle
--     Verweise umgehängt sind (B1–B4). Soft-gelöschte Zwillinge bleiben (Papierkorb).
DELETE FROM public.personen p USING _zu_loeschen z WHERE p.id = z.alt_id;

-- B6) NACHHER-VERIFIKATION als SICHTBARES Ergebnis-Grid (VOR dem ROLLBACK).
--     ERWARTUNG: personen_nachher ≈ vorher − 113 ; verwaiste_kanten = 0.
SELECT
  (SELECT count(*) FROM public.personen   WHERE geloescht_am IS NULL) AS personen_nachher,
  (SELECT count(*) FROM public.beziehungen WHERE geloescht_am IS NULL) AS beziehungen_nachher,
  (SELECT count(*) FROM public.beziehungen b
     WHERE NOT EXISTS (SELECT 1 FROM public.personen pa WHERE pa.id = b.person_a)
        OR NOT EXISTS (SELECT 1 FROM public.personen pb WHERE pb.id = b.person_b)) AS verwaiste_kanten;

-- Restliche identitaet_id-Werte gehören jetzt eindeutigen Personen (historisch, ungenutzt) — bleiben.

-- 👉 DRY-RUN: ROLLBACK (nichts wird geschrieben). Für den SCHARFEN Lauf: ROLLBACK -> COMMIT.
ROLLBACK;
-- COMMIT;

NOTIFY pgrst, 'reload schema';
