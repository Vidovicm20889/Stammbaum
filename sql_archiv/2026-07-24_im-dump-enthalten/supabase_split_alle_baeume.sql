-- =====================================================
-- JEDEN STAMMBAUM IN EINE EIGENE FAMILIE (Generalisierung von supabase_split_stojanovic.sql)
-- Ziel (Nutzerwunsch „eine Familie pro Baum"): Familien, die MEHRERE aktive
-- Stammbäume enthalten, werden so aufgeteilt, dass am Ende jede Familie genau
-- EINEN Baum hat. Pro Familie bleibt EIN „Keeper"-Baum in der bestehenden Familie
-- (so bleiben Owner/Mitglieder/Einstellungen dieser Familie erhalten), alle übrigen
-- Bäume wandern in jeweils eine NEUE, eigene Familie.
--
-- Keeper-Auswahl je Familie (in dieser Reihenfolge):
--   1) der Baum, dessen Name = Familienname (Namensvetter, diakritik-insensitiv)
--   2) sonst der Baum mit den MEISTEN Personen
--   3) sonst der mit der kleinsten id (deterministisch)
--
-- ENTSCHEIDUNG (wie bei Stojanović): neue Familie = GLEICHER Verbund (baum-
-- übergreifende Ehepartner/Sichtbarkeit bleiben), Owner = Owner der Ausgangsfamilie
-- (auto=false, geschützt). Ort/Land best-effort übernommen.
--
-- Ausführen in: Supabase -> SQL-Editor. STRUKTURELLE PRODUKTIV-MIGRATION.
-- Reihenfolge: TEIL 0 (Vorschau) -> TEIL 1 (Backup) -> TEIL 2 (Durchführen) -> TEIL 3.
-- Idempotent: hat eine Familie nur noch 1 aktiven Baum, passiert NICHTS.
-- =====================================================


-- ===============================================================
-- TEIL 0 — VORSCHAU (nichts wird geändert)
-- Zeigt alle Familien mit MEHREREN aktiven Bäumen und markiert je Baum, ob er
-- bleibt (KEEPER) oder ausgelagert wird (-> neue Familie).
-- ===============================================================
WITH fam_multi AS (
  SELECT s.familie_id
  FROM public.stammbaeume s
  WHERE coalesce(s.aktiv, true)
  GROUP BY s.familie_id
  HAVING count(*) > 1
),
keeper AS (
  SELECT DISTINCT ON (s.familie_id) s.familie_id, s.id AS keeper_id
  FROM public.stammbaeume s
  JOIN public.familien f ON f.id = s.familie_id
  WHERE coalesce(s.aktiv, true) AND s.familie_id IN (SELECT familie_id FROM fam_multi)
  ORDER BY s.familie_id,
           (public.merge_norm(s.name) = public.merge_norm(f.name)) DESC,
           (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) DESC,
           s.id
)
SELECT f.name AS familie, f.verbund_id, s.id AS stammbaum_id, s.name AS stammbaum,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen,
       CASE WHEN s.id = k.keeper_id THEN 'BLEIBT (Keeper)' ELSE '-> neue Familie' END AS aktion
FROM public.stammbaeume s
JOIN public.familien f ON f.id = s.familie_id
JOIN keeper k ON k.familie_id = s.familie_id
WHERE coalesce(s.aktiv, true) AND s.familie_id IN (SELECT familie_id FROM fam_multi)
ORDER BY f.name, aktion DESC, s.name;


-- ===============================================================
-- TEIL 1 — BACKUP (vor der Migration ausführen)
-- ===============================================================
DROP TABLE IF EXISTS public.bak_splitall_stammbaeume;
DROP TABLE IF EXISTS public.bak_splitall_personen;
DROP TABLE IF EXISTS public.bak_splitall_beziehungen;
DROP TABLE IF EXISTS public.bak_splitall_familien_ids;
DROP TABLE IF EXISTS public.bak_splitall_mitglied_ids;

CREATE TABLE public.bak_splitall_stammbaeume  AS SELECT id, familie_id FROM public.stammbaeume;
CREATE TABLE public.bak_splitall_personen     AS SELECT id, familie_id FROM public.personen;
CREATE TABLE public.bak_splitall_beziehungen  AS SELECT id, familie_id FROM public.beziehungen;
CREATE TABLE public.bak_splitall_familien_ids AS SELECT id FROM public.familien;
CREATE TABLE public.bak_splitall_mitglied_ids AS SELECT id FROM public.mitgliedschaften;

SELECT 'Backup angelegt' AS status,
       (SELECT count(*) FROM public.bak_splitall_stammbaeume) AS stammbaeume,
       (SELECT count(*) FROM public.bak_splitall_personen)    AS personen,
       (SELECT count(*) FROM public.bak_splitall_beziehungen) AS beziehungen;


-- ===============================================================
-- TEIL 2 — DURCHFÜHREN (kein Parameter nötig — wirkt auf alle Multi-Baum-Familien)
-- ===============================================================
DO $$
DECLARE
  r         record;
  v_new_fam uuid;
  v_owner   uuid;
  v_anz     int := 0;
BEGIN
  FOR r IN
    SELECT s.id AS tree_id, s.name AS tree_name, s.familie_id AS alt_fam,
           f.verbund_id, f.land, f.stadt, f.gemeinde
    FROM public.stammbaeume s
    JOIN public.familien f ON f.id = s.familie_id
    WHERE coalesce(s.aktiv, true)
      -- nur Familien mit mehr als 1 aktivem Baum
      AND (SELECT count(*) FROM public.stammbaeume s2
             WHERE s2.familie_id = s.familie_id AND coalesce(s2.aktiv, true)) > 1
      -- dieser Baum ist NICHT der Keeper seiner Familie
      AND s.id <> (
        SELECT k.id FROM public.stammbaeume k
        WHERE k.familie_id = s.familie_id AND coalesce(k.aktiv, true)
        ORDER BY (public.merge_norm(k.name) = public.merge_norm(f.name)) DESC,
                 (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = k.id) DESC,
                 k.id
        LIMIT 1
      )
  LOOP
    -- 1) Owner der Ausgangsfamilie ermitteln
    SELECT m.user_id INTO v_owner
      FROM public.mitgliedschaften m
     WHERE m.familie_id = r.alt_fam AND m.rolle = 'familien_owner' AND m.aktiv
     ORDER BY m.aktiv DESC LIMIT 1;

    -- 2) Neue Familie (Name = Baumname, gleicher Verbund, Ort best-effort)
    INSERT INTO public.familien (name, verbund_id, land, stadt, gemeinde)
    VALUES (r.tree_name, r.verbund_id, r.land, r.stadt, r.gemeinde)
    RETURNING id INTO v_new_fam;

    -- 3) Owner übernehmen (nur falls die alte Familie einen hatte), auto=false
    IF v_owner IS NOT NULL THEN
      INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv, auto)
      VALUES (v_owner, v_new_fam, 'familien_owner', true, false)
      ON CONFLICT (user_id, familie_id)
      DO UPDATE SET rolle = 'familien_owner', aktiv = true, auto = false;
    END IF;

    -- 4) Beziehungen der Personen dieses Baums umhängen (auch baumübergreifende)
    UPDATE public.beziehungen b SET familie_id = v_new_fam
    WHERE b.person_a IN (SELECT id FROM public.personen WHERE stammbaum_id = r.tree_id)
       OR b.person_b IN (SELECT id FROM public.personen WHERE stammbaum_id = r.tree_id);

    -- 5) Personen umhängen
    UPDATE public.personen SET familie_id = v_new_fam WHERE stammbaum_id = r.tree_id;

    -- 6) Stammbaum umhängen
    UPDATE public.stammbaeume SET familie_id = v_new_fam WHERE id = r.tree_id;

    v_anz := v_anz + 1;
    RAISE NOTICE 'Baum "%" (%) -> neue Familie % (Owner: %).',
      r.tree_name, r.tree_id, v_new_fam, coalesce(v_owner::text, 'KEINER');
  END LOOP;

  RAISE NOTICE 'Fertig: % Baum/Bäume in eigene Familien ausgelagert.', v_anz;
END $$;


-- ===============================================================
-- TEIL 3 — KONTROLLE
-- ===============================================================
-- a) Jede Familie sollte jetzt genau 1 aktiven Baum haben
SELECT f.name AS familie, count(*) FILTER (WHERE coalesce(s.aktiv, true)) AS aktive_baeume,
       string_agg(s.name, ', ') AS baeume
FROM public.familien f
JOIN public.stammbaeume s ON s.familie_id = f.id
GROUP BY f.name
ORDER BY aktive_baeume DESC, f.name;

-- b) Familien, die WEITERHIN mehrere aktive Bäume haben (sollte leer sein)
SELECT f.name AS familie, count(*) AS aktive_baeume
FROM public.familien f
JOIN public.stammbaeume s ON s.familie_id = f.id AND coalesce(s.aktiv, true)
GROUP BY f.name
HAVING count(*) > 1
ORDER BY f.name;


-- ===============================================================
-- TEIL 4 — ROLLBACK (nur bei Bedarf; Block einkommentieren und ausführen)
-- Setzt familie_id-Zuordnungen zurück und entfernt neu angelegte Familien/
-- Mitgliedschaften. Voraussetzung: TEIL 1 (Backup) lief vor der Migration.
-- ===============================================================
-- DO $$
-- BEGIN
--   UPDATE public.stammbaeume s SET familie_id = b.familie_id
--   FROM public.bak_splitall_stammbaeume b WHERE b.id = s.id AND s.familie_id <> b.familie_id;
--
--   UPDATE public.personen p SET familie_id = b.familie_id
--   FROM public.bak_splitall_personen b WHERE b.id = p.id AND p.familie_id <> b.familie_id;
--
--   UPDATE public.beziehungen z SET familie_id = b.familie_id
--   FROM public.bak_splitall_beziehungen b WHERE b.id = z.id AND z.familie_id <> b.familie_id;
--
--   DELETE FROM public.mitgliedschaften m
--   WHERE m.id NOT IN (SELECT id FROM public.bak_splitall_mitglied_ids);
--
--   DELETE FROM public.familien f
--   WHERE f.id NOT IN (SELECT id FROM public.bak_splitall_familien_ids);
-- END $$;
-- SELECT 'Rollback ausgeführt' AS status;
