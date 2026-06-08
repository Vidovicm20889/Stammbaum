-- =====================================================
-- EINEN STAMMBAUM IN EINE EIGENE FAMILIE AUSLAGERN
-- Konkreter Fall: der Baum „Stojanović" hängt aktuell an der Familie „Knežević“.
-- Ziel: Stojanović wird eine EIGENE Familie (eigener Owner/Verwaltung), bleibt aber
-- im GLEICHEN VERBUND wie Knežević → eingeheiratete Personen / baumübergreifende
-- Verknüpfungen (identitaet_id) und Heiratsdarstellung bleiben sichtbar.
-- Owner der neuen Familie = derselbe wie bei Knežević (auto=false, geschützt).
--
-- Ausführen in: Supabase -> SQL Editor. STRUKTURELLE PRODUKTIV-MIGRATION.
-- Reihenfolge:
--   1) TEIL 0 (Vorschau) ausführen  -> Stammbaum-UUID kopieren
--   2) TEIL 1 (Backup) ausführen    -> Sicherungsnetz
--   3) In TEIL 2 die UUID eintragen -> ausführen
--   4) TEIL 3 (Kontrolle) ausführen
-- Idempotent: liegt der Baum bereits allein in seiner Familie, passiert NICHTS.
-- =====================================================


-- ===============================================================
-- TEIL 0 — VORSCHAU (nichts wird geändert)
-- Findet den Stojanović-Baum, seine aktuelle Familie, Personenzahl und den
-- aktuellen Owner. Die ausgegebene stammbaum_id in TEIL 2 eintragen.
-- (ILIKE deckt Latein „Stojanović" ab; bei kyrillischem Namen den Filter
--  anpassen oder die Zeile ohne WHERE laufen lassen und manuell suchen.)
-- ===============================================================
SELECT
  s.id            AS stammbaum_id,        -- <<< diese UUID in TEIL 2 eintragen
  s.name          AS stammbaum,
  f.id            AS aktuelle_familie_id,
  f.name          AS aktuelle_familie,
  f.verbund_id,
  (SELECT count(*) FROM public.stammbaeume x WHERE x.familie_id = f.id) AS baeume_in_familie,
  (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id)  AS personen,
  (SELECT string_agg(u.email, ', ')
     FROM public.mitgliedschaften m
     JOIN auth.users u ON u.id = m.user_id
    WHERE m.familie_id = f.id AND m.rolle = 'familien_owner' AND m.aktiv) AS owner_email
FROM public.stammbaeume s
JOIN public.familien f ON f.id = s.familie_id
WHERE s.name ILIKE '%stojanovi%'
ORDER BY s.name;


-- ===============================================================
-- TEIL 1 — BACKUP (vor der Migration ausführen)
-- ===============================================================
DROP TABLE IF EXISTS public.bak_stoj_stammbaeume;
DROP TABLE IF EXISTS public.bak_stoj_personen;
DROP TABLE IF EXISTS public.bak_stoj_beziehungen;
DROP TABLE IF EXISTS public.bak_stoj_familien_ids;
DROP TABLE IF EXISTS public.bak_stoj_mitglied_ids;

CREATE TABLE public.bak_stoj_stammbaeume  AS SELECT id, familie_id FROM public.stammbaeume;
CREATE TABLE public.bak_stoj_personen     AS SELECT id, familie_id FROM public.personen;
CREATE TABLE public.bak_stoj_beziehungen  AS SELECT id, familie_id FROM public.beziehungen;
CREATE TABLE public.bak_stoj_familien_ids AS SELECT id FROM public.familien;
CREATE TABLE public.bak_stoj_mitglied_ids AS SELECT id FROM public.mitgliedschaften;

SELECT 'Backup angelegt' AS status,
       (SELECT count(*) FROM public.bak_stoj_stammbaeume)  AS stammbaeume,
       (SELECT count(*) FROM public.bak_stoj_personen)     AS personen,
       (SELECT count(*) FROM public.bak_stoj_beziehungen)  AS beziehungen;


-- ===============================================================
-- TEIL 2 — DURCHFÜHREN  (UUID aus TEIL 0 unten eintragen!)
-- ===============================================================
DO $$
DECLARE
  v_tree     uuid := 'HIER-STOJANOVIC-STAMMBAUM-UUID-EINTRAGEN';  -- <<< aus TEIL 0
  v_alt_fam  uuid;
  v_tree_name text;
  v_verbund  uuid;
  v_new_fam  uuid;
  v_anz_baeume int;
  v_owner_n  int;
BEGIN
  -- 1) Baum + aktuelle Familie ermitteln
  SELECT s.familie_id, s.name INTO v_alt_fam, v_tree_name
  FROM public.stammbaeume s WHERE s.id = v_tree;
  IF v_alt_fam IS NULL THEN
    RAISE EXCEPTION 'Stammbaum % nicht gefunden — UUID aus TEIL 0 prüfen.', v_tree;
  END IF;

  -- 2) Idempotenz-/Sicherheitscheck: liegt der Baum bereits ALLEIN in seiner Familie,
  --    gibt es nichts auszulagern (z. B. zweiter Lauf).
  SELECT count(*) INTO v_anz_baeume FROM public.stammbaeume WHERE familie_id = v_alt_fam;
  IF v_anz_baeume <= 1 THEN
    RAISE NOTICE 'Baum "%" liegt bereits allein in seiner Familie (%). Nichts zu tun.',
      v_tree_name, v_alt_fam;
    RETURN;
  END IF;

  SELECT verbund_id INTO v_verbund FROM public.familien WHERE id = v_alt_fam;

  -- 3) Neue Familie (Name = Baumname), GLEICHER Verbund -> bleibt sichtbar verknüpft.
  --    Ort/Land best-effort von der alten Familie übernehmen (in „Podešavanje porodice"
  --    bei Bedarf anpassen — wichtig fürs Zugriffsanfragen-Matching).
  INSERT INTO public.familien (name, verbund_id, land, stadt, gemeinde)
  SELECT v_tree_name, v_verbund, f.land, f.stadt, f.gemeinde
  FROM public.familien f WHERE f.id = v_alt_fam
  RETURNING id INTO v_new_fam;

  -- 4) Beziehungen der Personen dieses Baums umhängen (auch baumübergreifende Kanten)
  UPDATE public.beziehungen b SET familie_id = v_new_fam
  WHERE b.person_a IN (SELECT id FROM public.personen WHERE stammbaum_id = v_tree)
     OR b.person_b IN (SELECT id FROM public.personen WHERE stammbaum_id = v_tree);

  -- 5) Personen umhängen (löst Blutlinien-Recompute aus — gewollt, verbund-intern/additiv)
  UPDATE public.personen SET familie_id = v_new_fam WHERE stammbaum_id = v_tree;

  -- 6) Stammbaum umhängen
  UPDATE public.stammbaeume SET familie_id = v_new_fam WHERE id = v_tree;

  -- 7) Owner der alten Familie als Owner der neuen Familie übernehmen (auto=false = geschützt)
  INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv, auto)
  SELECT m.user_id, v_new_fam, 'familien_owner', true, false
  FROM public.mitgliedschaften m
  WHERE m.familie_id = v_alt_fam AND m.rolle = 'familien_owner' AND m.aktiv
  ON CONFLICT (user_id, familie_id)
  DO UPDATE SET rolle = 'familien_owner', aktiv = true, auto = false;
  GET DIAGNOSTICS v_owner_n = ROW_COUNT;

  RAISE NOTICE 'Fertig: Baum "%" ausgelagert in neue Familie % (Verbund %). Owner kopiert: %.',
    v_tree_name, v_new_fam, v_verbund, v_owner_n;
  IF v_owner_n = 0 THEN
    RAISE NOTICE 'HINWEIS: Die alte Familie hatte keinen aktiven familien_owner — die neue '
      'Familie hat vorerst KEINEN Owner. Owner/Admin danach über die GUI vergeben.';
  END IF;
END $$;


-- ===============================================================
-- TEIL 3 — KONTROLLE
-- ===============================================================
-- a) Stojanović sollte jetzt eine eigene Familie mit genau diesem Baum sein
SELECT f.name AS familie, f.verbund_id, s.name AS stammbaum,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
FROM public.familien f
JOIN public.stammbaeume s ON s.familie_id = f.id
WHERE f.name ILIKE '%stojanovi%' OR f.name ILIKE '%knezevi%' OR f.name ILIKE '%kneževi%'
ORDER BY f.name;

-- b) Owner der neuen/alten Familie
SELECT f.name AS familie, u.email AS owner, m.rolle, m.aktiv, m.auto
FROM public.mitgliedschaften m
JOIN public.familien f ON f.id = m.familie_id
JOIN auth.users u ON u.id = m.user_id
WHERE (f.name ILIKE '%stojanovi%' OR f.name ILIKE '%knezevi%' OR f.name ILIKE '%kneževi%')
  AND m.rolle = 'familien_owner'
ORDER BY f.name;


-- ===============================================================
-- TEIL 4 — ROLLBACK (nur bei Bedarf; Block einkommentieren und ausführen)
-- Stellt familie_id-Zuordnungen wieder her und entfernt neu angelegte Familie/
-- Mitgliedschaften. Voraussetzung: TEIL 1 (Backup) wurde vor der Migration gefahren.
-- ===============================================================
-- DO $$
-- BEGIN
--   UPDATE public.stammbaeume s SET familie_id = b.familie_id
--   FROM public.bak_stoj_stammbaeume b WHERE b.id = s.id AND s.familie_id <> b.familie_id;
--
--   UPDATE public.personen p SET familie_id = b.familie_id
--   FROM public.bak_stoj_personen b WHERE b.id = p.id AND p.familie_id <> b.familie_id;
--
--   UPDATE public.beziehungen z SET familie_id = b.familie_id
--   FROM public.bak_stoj_beziehungen b WHERE b.id = z.id AND z.familie_id <> b.familie_id;
--
--   DELETE FROM public.mitgliedschaften m
--   WHERE m.id NOT IN (SELECT id FROM public.bak_stoj_mitglied_ids);
--
--   DELETE FROM public.familien f
--   WHERE f.id NOT IN (SELECT id FROM public.bak_stoj_familien_ids);
-- END $$;
-- SELECT 'Rollback ausgeführt' AS status;
