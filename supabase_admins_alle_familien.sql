-- =====================================================
-- VIDOVIĆ-ADMINS AUF ALLE FAMILIEN/STAMMBÄUME BERECHTIGEN
-- Ausführen in: Supabase -> SQL Editor.
--
-- Idee: Die Admins der Haupt-Familie (die mit den meisten Personen = der
-- große Vidović-Stammbaum) bekommen in JEDER Familie eine familien_admin-
-- Mitgliedschaft. Dadurch können sie alle Stammbäume sehen und bearbeiten
-- (Mitgliederverwaltung, Personen, Baum löschen ...).
--
-- Rechte liegen in public.mitgliedschaften (NICHT in familien). Die familien-
-- Zeilen existieren schon; wir verknüpfen nur die Admins mit allen Familien.
--
-- SICHER: idempotent (ON CONFLICT DO NOTHING) – mehrfaches Ausführen schadet nicht.
-- =====================================================

-- ---------------------------------------------------------------
-- SCHRITT 0 — VORSCHAU: erst ansehen, WER auf WIE VIELE Familien
-- berechtigt wird. Nichts wird hier geändert.
-- ---------------------------------------------------------------
WITH haupt AS (
  SELECT familie_id FROM public.personen
  GROUP BY familie_id ORDER BY count(*) DESC LIMIT 1
),
admins AS (
  SELECT DISTINCT m.user_id
  FROM public.mitgliedschaften m
  JOIN haupt h ON h.familie_id = m.familie_id
  WHERE m.rolle IN ('super_admin','familien_admin') AND m.aktiv
)
SELECT u.email AS admin_email,
       (SELECT count(*) FROM public.familien)                       AS familien_gesamt,
       (SELECT count(*) FROM public.mitgliedschaften mm
          WHERE mm.user_id = a.user_id)                             AS bisherige_mitgliedschaften
FROM admins a JOIN auth.users u ON u.id = a.user_id
ORDER BY u.email;

-- ---------------------------------------------------------------
-- SCHRITT 1 — DURCHFÜHREN: jeden dieser Admins als familien_admin
-- in JEDE Familie eintragen (vorhandene Einträge bleiben unberührt).
-- ---------------------------------------------------------------
WITH haupt AS (
  SELECT familie_id FROM public.personen
  GROUP BY familie_id ORDER BY count(*) DESC LIMIT 1
),
admins AS (
  SELECT DISTINCT m.user_id
  FROM public.mitgliedschaften m
  JOIN haupt h ON h.familie_id = m.familie_id
  WHERE m.rolle IN ('super_admin','familien_admin') AND m.aktiv
)
INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv)
SELECT a.user_id, f.id, 'familien_admin', true
FROM admins a
CROSS JOIN public.familien f
ON CONFLICT (user_id, familie_id) DO NOTHING;

-- ---------------------------------------------------------------
-- SCHRITT 2 — KONTROLLE: pro Admin die Anzahl Familien, in denen
-- er jetzt Admin ist (sollte = Anzahl aller Familien sein).
-- ---------------------------------------------------------------
SELECT u.email,
       count(*) FILTER (WHERE m.rolle IN ('super_admin','familien_admin') AND m.aktiv) AS admin_in_familien,
       (SELECT count(*) FROM public.familien) AS familien_gesamt
FROM public.mitgliedschaften m
JOIN auth.users u ON u.id = m.user_id
GROUP BY u.email
ORDER BY admin_in_familien DESC, u.email;
