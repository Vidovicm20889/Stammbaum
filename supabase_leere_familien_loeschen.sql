-- =====================================================
-- LEERE FAMILIEN (OHNE STAMMBAUM) LÖSCHEN — Aufräumen
-- Ausführen in: Supabase -> SQL-Editor. STRUKTURELLE PRODUKTIV-MIGRATION.
--
-- Entfernt Familien, die KEINEN Stammbaum und KEINE Personen haben (Reste/Test-
-- Einträge). Nutzer-Konten bleiben erhalten (Entscheidung: verwaiste Konten NICHT
-- löschen) — nur die leere Familie + ihre Mitgliedschaften + offenen Registrierungs-/
-- Zugriffsanfragen werden FK-sicher entfernt.
--
-- SICHERHEITS-GUARDS (eine Familie wird NUR gelöscht, wenn ALLE zutreffen):
--   * kein Stammbaum (NOT EXISTS stammbaeume)
--   * 0 Personen (sonst = anderes Problem -> stammbaum_bereinigung_diagnose nutzen,
--     NICHT löschen)
--   * KEINE super_admin-Mitgliedschaft (Haupt-/Betriebs-Konto nie löschen, CLAUDE.md)
--
-- Reihenfolge: TEIL 0 (Vorschau) -> TEIL 1 (Backup) -> TEIL 2 (Löschen) -> TEIL 3.
-- Idempotent: nach dem Lauf sind keine solchen Familien mehr da -> No-op.
-- =====================================================


-- ===============================================================
-- TEIL 0 — VORSCHAU (nichts wird geändert)
-- a) Diese Familien WERDEN gelöscht
SELECT f.name AS familie, f.land, f.stadt, f.gemeinde,
       (SELECT count(*) FROM public.mitgliedschaften m WHERE m.familie_id = f.id) AS mitglieder,
       (SELECT string_agg(u.email || ' (' || m.rolle || ')', ', ')
          FROM public.mitgliedschaften m JOIN auth.users u ON u.id = m.user_id
         WHERE m.familie_id = f.id) AS mitglied_details,
       (SELECT count(*) FROM public.registrierungs_anfragen r WHERE r.familie_id = f.id) AS offene_anfragen
FROM public.familien f
WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
  AND (SELECT count(*) FROM public.personen p WHERE p.familie_id = f.id) = 0
  AND NOT EXISTS (SELECT 1 FROM public.mitgliedschaften m
                   WHERE m.familie_id = f.id AND m.rolle = 'super_admin')
ORDER BY f.name;

-- b) Leere Familien, die ÜBERSPRUNGEN werden (mit Grund) — zur Kontrolle
SELECT f.name AS familie,
       CASE
         WHEN EXISTS (SELECT 1 FROM public.mitgliedschaften m
                       WHERE m.familie_id = f.id AND m.rolle = 'super_admin')
              THEN 'hat super_admin -> geschützt'
         WHEN (SELECT count(*) FROM public.personen p WHERE p.familie_id = f.id) > 0
              THEN 'hat Personen -> Bereinigungs-Tool nutzen'
         ELSE 'ok'
       END AS grund
FROM public.familien f
WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
  AND (
        EXISTS (SELECT 1 FROM public.mitgliedschaften m
                 WHERE m.familie_id = f.id AND m.rolle = 'super_admin')
        OR (SELECT count(*) FROM public.personen p WHERE p.familie_id = f.id) > 0
      )
ORDER BY f.name;


-- ===============================================================
-- TEIL 1 — BACKUP (vor dem Löschen ausführen)
-- Volle Zeilenkopien der zu löschenden Familien + abhängiger Zeilen, falls
-- manuell wiederhergestellt werden muss.
-- ===============================================================
DROP TABLE IF EXISTS public.bak_leerfam_familien;
DROP TABLE IF EXISTS public.bak_leerfam_mitgliedschaften;
DROP TABLE IF EXISTS public.bak_leerfam_anfragen;

CREATE TABLE public.bak_leerfam_familien AS
  SELECT f.* FROM public.familien f
  WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
    AND (SELECT count(*) FROM public.personen p WHERE p.familie_id = f.id) = 0
    AND NOT EXISTS (SELECT 1 FROM public.mitgliedschaften m
                     WHERE m.familie_id = f.id AND m.rolle = 'super_admin');

CREATE TABLE public.bak_leerfam_mitgliedschaften AS
  SELECT m.* FROM public.mitgliedschaften m
  WHERE m.familie_id IN (SELECT id FROM public.bak_leerfam_familien);

CREATE TABLE public.bak_leerfam_anfragen AS
  SELECT r.* FROM public.registrierungs_anfragen r
  WHERE r.familie_id IN (SELECT id FROM public.bak_leerfam_familien);

SELECT 'Backup angelegt' AS status,
       (SELECT count(*) FROM public.bak_leerfam_familien)         AS familien,
       (SELECT count(*) FROM public.bak_leerfam_mitgliedschaften) AS mitgliedschaften,
       (SELECT count(*) FROM public.bak_leerfam_anfragen)         AS anfragen;


-- ===============================================================
-- TEIL 2 — LÖSCHEN
-- ===============================================================
DO $$
DECLARE
  r       record;
  v_anz   int := 0;
BEGIN
  FOR r IN
    SELECT f.id, f.name FROM public.familien f
    WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
      AND (SELECT count(*) FROM public.personen p WHERE p.familie_id = f.id) = 0
      AND NOT EXISTS (SELECT 1 FROM public.mitgliedschaften m
                       WHERE m.familie_id = f.id AND m.rolle = 'super_admin')
  LOOP
    -- 1) Offene Registrierungs-/Zugriffsanfragen (FK auf familien -> zuerst weg)
    DELETE FROM public.registrierungs_anfragen WHERE familie_id = r.id;

    -- 2) Defensive: evtl. verwaiste Beziehungen dieser Familie (sollte 0 sein)
    DELETE FROM public.beziehungen WHERE familie_id = r.id;

    -- 3) Mitgliedschaften der leeren Familie (Konten/auth.users BLEIBEN bestehen)
    DELETE FROM public.mitgliedschaften WHERE familie_id = r.id;

    -- 4) Audit-Eintrag (familien_audit.familie_id hat KEINEN FK -> nach Löschung ok)
    INSERT INTO public.familien_audit (familie_id, aktion, geaendert_von, alte_werte, neue_werte)
    VALUES (r.id, 'leere_familie_geloescht', auth.uid(),
            jsonb_build_object('familie_name', r.name, 'grund', 'kein Stammbaum, 0 Personen'),
            jsonb_build_object('geloescht', true));

    -- 5) Familie selbst
    DELETE FROM public.familien WHERE id = r.id;

    v_anz := v_anz + 1;
    RAISE NOTICE 'Leere Familie "%" (%) gelöscht.', r.name, r.id;
  END LOOP;

  RAISE NOTICE 'Fertig: % leere Familie(n) gelöscht (verwaiste Konten behalten).', v_anz;
END $$;


-- ===============================================================
-- TEIL 3 — KONTROLLE (sollte keine löschbaren leeren Familien mehr zeigen)
-- ===============================================================
SELECT f.name AS verbleibende_leere_familie
FROM public.familien f
WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
ORDER BY f.name;
-- (Falls hier noch etwas steht: entweder geschützt — super_admin — oder hat Personen,
--  siehe TEIL 0 b.)


-- ===============================================================
-- TEIL 4 — AUFRÄUMEN der Backup-Tabellen (optional, wenn alles passt)
-- ===============================================================
-- DROP TABLE IF EXISTS public.bak_leerfam_familien;
-- DROP TABLE IF EXISTS public.bak_leerfam_mitgliedschaften;
-- DROP TABLE IF EXISTS public.bak_leerfam_anfragen;
