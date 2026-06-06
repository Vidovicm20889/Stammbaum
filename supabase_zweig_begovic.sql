-- =====================================================
-- EINMALIGER ZWEIGBAUM "Begović" aus bestehender Heirat (Halid Begović ⚭ Desanka, née Pisarević)
-- Ausführen in: Supabase -> SQL-Editor. IDEMPOTENT (zweiter Lauf macht NICHTS).
--
-- HINTERGRUND:
-- Die Begović-Personen (Halid + Nachkommen) leben aktuell NUR als Zweig im
-- Pisarević-Baum. Es gibt KEINEN eigenen "Begović"-Stammbaum -> er fehlt deshalb im
-- Baum-Dropdown (das listet nur stammbaeume-Zeilen). Der reguläre Auto-Zweigbaum
-- (RPC stammbaum_zweig_aus_heirat) feuert nur beim *Anlegen* eines Partners mit neuem
-- Nachnamen + Bestätigung; für ein bereits bestehendes Paar gibt es keinen UI-Pfad, und
-- die RPC selbst braucht auth.uid() (im SQL-Editor NULL). Diese Datei repliziert daher
-- die GETESTETE Mirror-Logik der RPC als einmalige Migration OHNE auth-Abhängigkeit.
--
-- VERHALTEN (identisch zur RPC, CLAUDE.md "Auto-Zweigbaum bei Heirat", v10.1):
--   * Personen werden NICHT verschoben, sondern als GLEICHE Person über
--     personen.identitaet_id in den neuen Baum GESPIEGELT (beide Karten bleiben sichtbar,
--     Trigger ident_sync hält die Biografie synchron).
--   * Gespiegelt werden: Wurzel = Halid Begović + seine Nachkommen (rekursiv, nur im
--     Quellbaum) + die Ehepartner aller gesammelten Personen (also auch Desanka und ggf.
--     Schwiegerkinder/Enkel). Beziehungen werden NUR zwischen gespiegelten Karten neu
--     aufgebaut (keine verwaisten Zeilen).
--   * Neuer Baum + NEUE, EIGENE Familie im GLEICHEN Verbund (verbund-RLS = sichtbar
--     verknüpft). Owner der neuen Familie = Owner der Pisarević-Familie (auto=false).
--
-- Reihenfolge: TEIL 0 (Vorschau) -> TEIL 1 (Backup) -> TEIL 2 (Durchführen) -> TEIL 3.
-- Voraussetzungen (bereits vorhanden): merge_norm(text), Trigger ident_sync,
--   personen.identitaet_id, familien.verbund_id.
-- =====================================================


-- ===============================================================
-- TEIL 0 — VORSCHAU (ändert NICHTS): wer ist Wurzel/Partner und wer würde gespiegelt?
-- ===============================================================
WITH RECURSIVE wurzel AS (
  SELECT pe.id, pe.stammbaum_id AS src, pe.familie_id AS fam
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id AND coalesce(s.aktiv, true)
  WHERE public.merge_norm(pe.vorname) = public.merge_norm('Halid')
    AND public.merge_norm(pe.nachname) = public.merge_norm('Begović')
),
nach(pid) AS (
  SELECT id FROM wurzel
  UNION
  SELECT b.person_b
    FROM public.beziehungen b
    JOIN nach n ON b.person_a = n.pid
    JOIN public.personen pe ON pe.id = b.person_b
   WHERE b.typ = 'elternteil' AND pe.stammbaum_id = (SELECT src FROM wurzel)
),
gesammelt AS (
  SELECT pid FROM nach
  UNION
  SELECT CASE WHEN b.person_a IN (SELECT pid FROM nach) THEN b.person_b ELSE b.person_a END
    FROM public.beziehungen b
   WHERE b.typ = 'ehepartner'
     AND (b.person_a IN (SELECT pid FROM nach) OR b.person_b IN (SELECT pid FROM nach))
)
SELECT pe.vorname, pe.nachname, s.name AS aktueller_baum, pe.identitaet_id,
       CASE WHEN pe.id IN (SELECT id FROM wurzel) THEN 'WURZEL (neuer Baum)' ELSE 'wird gespiegelt' END AS rolle
FROM public.personen pe
LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
WHERE pe.id IN (SELECT pid FROM gesammelt)
  AND pe.stammbaum_id = (SELECT src FROM wurzel)
ORDER BY rolle DESC, pe.nachname, pe.vorname;


-- ===============================================================
-- TEIL 1 — BACKUP (vor der Migration ausführen)
-- ===============================================================
DROP TABLE IF EXISTS public.bak_zweig_begovic_personen;
DROP TABLE IF EXISTS public.bak_zweig_begovic_beziehungen;
DROP TABLE IF EXISTS public.bak_zweig_begovic_familien_ids;
DROP TABLE IF EXISTS public.bak_zweig_begovic_stammbaeume_ids;
DROP TABLE IF EXISTS public.bak_zweig_begovic_mitglied_ids;

CREATE TABLE public.bak_zweig_begovic_personen        AS SELECT id, identitaet_id FROM public.personen;
CREATE TABLE public.bak_zweig_begovic_beziehungen     AS SELECT id FROM public.beziehungen;
CREATE TABLE public.bak_zweig_begovic_familien_ids     AS SELECT id FROM public.familien;
CREATE TABLE public.bak_zweig_begovic_stammbaeume_ids  AS SELECT id FROM public.stammbaeume;
CREATE TABLE public.bak_zweig_begovic_mitglied_ids     AS SELECT id FROM public.mitgliedschaften;

SELECT 'Backup angelegt' AS status;


-- ===============================================================
-- TEIL 2 — DURCHFÜHREN
-- ===============================================================
DO $$
DECLARE
  v_wurzel  uuid;
  v_partner uuid;
  v_src     uuid;
  v_fam     uuid;
  v_verbund uuid;
  v_name    text := 'Begović';
  v_owner   uuid;
  v_new_fam uuid;
  v_tree    uuid;
  v_rec     record;
  v_mir     uuid;
  v_n       int;
  v_anz_w   int;
  v_anz_p   int;
BEGIN
  -- 1) Wurzel (Halid Begović) eindeutig in einem aktiven Baum finden
  SELECT count(*) INTO v_anz_w
    FROM public.personen pe
    JOIN public.stammbaeume s ON s.id = pe.stammbaum_id AND coalesce(s.aktiv, true)
   WHERE public.merge_norm(pe.vorname)  = public.merge_norm('Halid')
     AND public.merge_norm(pe.nachname) = public.merge_norm('Begović');
  IF v_anz_w = 0 THEN RAISE EXCEPTION 'Halid Begović nicht gefunden — Namen/aktiv prüfen.'; END IF;
  IF v_anz_w > 1 THEN RAISE EXCEPTION 'Halid Begović mehrfach gefunden (%) — bitte UUID hart setzen.', v_anz_w; END IF;

  SELECT pe.id, pe.stammbaum_id, pe.familie_id
    INTO v_wurzel, v_src, v_fam
    FROM public.personen pe
    JOIN public.stammbaeume s ON s.id = pe.stammbaum_id AND coalesce(s.aktiv, true)
   WHERE public.merge_norm(pe.vorname)  = public.merge_norm('Halid')
     AND public.merge_norm(pe.nachname) = public.merge_norm('Begović');

  -- 2) Ehepartner (Desanka) eindeutig im selben Baum finden
  SELECT count(*) INTO v_anz_p
    FROM public.beziehungen b
    JOIN public.personen pe ON pe.id = CASE WHEN b.person_a = v_wurzel THEN b.person_b ELSE b.person_a END
   WHERE b.typ = 'ehepartner' AND (b.person_a = v_wurzel OR b.person_b = v_wurzel)
     AND pe.stammbaum_id = v_src;
  IF v_anz_p = 0 THEN RAISE EXCEPTION 'Kein Ehepartner von Halid im Quellbaum — Beziehung prüfen.'; END IF;
  IF v_anz_p > 1 THEN RAISE EXCEPTION 'Mehrere Ehepartner von Halid (%) — bitte Partner-UUID hart setzen.', v_anz_p; END IF;

  SELECT CASE WHEN b.person_a = v_wurzel THEN b.person_b ELSE b.person_a END
    INTO v_partner
    FROM public.beziehungen b
    JOIN public.personen pe ON pe.id = CASE WHEN b.person_a = v_wurzel THEN b.person_b ELSE b.person_a END
   WHERE b.typ = 'ehepartner' AND (b.person_a = v_wurzel OR b.person_b = v_wurzel)
     AND pe.stammbaum_id = v_src
   LIMIT 1;

  -- 3) Verbund + Idempotenz: existiert im Verbund schon ein aktiver "Begović"-Baum? -> Abbruch
  SELECT f.verbund_id INTO v_verbund FROM public.familien f WHERE f.id = v_fam;
  IF EXISTS (
    SELECT 1 FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
     WHERE coalesce(s.aktiv, true)
       AND public.merge_norm(s.name) = public.merge_norm(v_name)
       AND ((v_verbund IS NOT NULL AND f.verbund_id = v_verbund) OR f.id = v_fam)
  ) THEN
    RAISE NOTICE 'Begović-Baum existiert im Verbund bereits — nichts zu tun (idempotent).';
    RETURN;
  END IF;

  -- 4) Zu spiegelnde Quell-Personen sammeln (Wurzel + Nachkommen + Ehepartner; nur Quellbaum)
  CREATE TEMP TABLE _bz_src ON COMMIT DROP AS
  WITH RECURSIVE nach(pid) AS (
    SELECT v_wurzel
    UNION
    SELECT b.person_b
      FROM public.beziehungen b
      JOIN nach n ON b.person_a = n.pid
      JOIN public.personen pe ON pe.id = b.person_b
     WHERE b.typ = 'elternteil' AND pe.stammbaum_id = v_src
  )
  SELECT DISTINCT x.pid
    FROM (
      SELECT pid FROM nach
      UNION ALL SELECT v_partner
      UNION ALL
      SELECT CASE WHEN b.person_a IN (SELECT pid FROM nach) THEN b.person_b ELSE b.person_a END
        FROM public.beziehungen b
       WHERE b.typ = 'ehepartner'
         AND (b.person_a IN (SELECT pid FROM nach) OR b.person_b IN (SELECT pid FROM nach))
    ) x
    JOIN public.personen pe ON pe.id = x.pid
   WHERE x.pid IS NOT NULL AND pe.stammbaum_id = v_src;

  -- Jede gesammelte Karte braucht eine identitaet_id (gemeinsame Identität mit Spiegel)
  UPDATE public.personen
     SET identitaet_id = gen_random_uuid()
   WHERE id IN (SELECT pid FROM _bz_src) AND identitaet_id IS NULL;

  -- 5) Owner der Pisarević-Familie ermitteln (Fallback: Quellbaum-Owner/Ersteller)
  SELECT m.user_id INTO v_owner
    FROM public.mitgliedschaften m
   WHERE m.familie_id = v_fam AND m.rolle = 'familien_owner' AND m.aktiv
   ORDER BY m.aktiv DESC LIMIT 1;
  IF v_owner IS NULL THEN
    SELECT coalesce(s.owner_id, s.ersteller_id) INTO v_owner
      FROM public.stammbaeume s WHERE s.id = v_src;
  END IF;

  -- 6) Neue, EIGENE Familie (Name=Begović, gleicher Verbund, Ort best-effort)
  INSERT INTO public.familien (name, verbund_id, land, stadt, gemeinde)
  SELECT v_name, v_verbund, f.land, f.stadt, f.gemeinde
    FROM public.familien f WHERE f.id = v_fam
  RETURNING id INTO v_new_fam;

  IF v_owner IS NOT NULL THEN
    INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv, auto)
    VALUES (v_owner, v_new_fam, 'familien_owner', true, false)
    ON CONFLICT (user_id, familie_id)
    DO UPDATE SET rolle = 'familien_owner', aktiv = true, auto = false;
  END IF;

  -- 7) Stammbaum in der neuen Familie anlegen
  INSERT INTO public.stammbaeume (familie_id, name, ersteller_id, owner_id, aktiv)
  VALUES (v_new_fam, v_name, v_owner, v_owner, true)
  RETURNING id INTO v_tree;

  -- 8) Spiegelkarten anlegen (Biografie übernehmen, identitaet teilen)
  CREATE TEMP TABLE _bz_map (src uuid, mir uuid) ON COMMIT DROP;
  FOR v_rec IN
    SELECT pe.* FROM public.personen pe JOIN _bz_src z ON z.pid = pe.id
  LOOP
    INSERT INTO public.personen
      (familie_id, stammbaum_id, externe_id, vorname, nachname, geburtsdatum,
       stammbaum_daten, identitaet_id)
    VALUES
      (v_new_fam, v_tree,
       'I' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(replace(v_rec.id::text,'-',''),1,8),
       v_rec.vorname, v_rec.nachname, NULL,
       v_rec.stammbaum_daten, v_rec.identitaet_id)
    RETURNING id INTO v_mir;
    INSERT INTO _bz_map (src, mir) VALUES (v_rec.id, v_mir);
  END LOOP;

  -- 9) Beziehungen zwischen den Spiegelkarten neu aufbauen (nur wenn BEIDE Enden gespiegelt)
  INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
  SELECT v_new_fam, ma.mir, mb.mir, b.typ
    FROM public.beziehungen b
    JOIN _bz_map ma ON ma.src = b.person_a
    JOIN _bz_map mb ON mb.src = b.person_b;

  -- 10) Wurzelperson des neuen Baums setzen (Halid)
  UPDATE public.stammbaeume
     SET wurzel_person_id = (SELECT mir FROM _bz_map WHERE src = v_wurzel)
   WHERE id = v_tree;

  SELECT count(*) INTO v_n FROM _bz_map;
  RAISE NOTICE 'Begović-Baum % (Familie %) angelegt: % Karten gespiegelt (Wurzel Halid=%).',
    v_tree, v_new_fam, v_n, v_wurzel;
END $$;


-- ===============================================================
-- TEIL 3 — KONTROLLE
-- ===============================================================
-- a) Der neue Baum + Personenzahl
SELECT s.id, s.name AS baum, f.name AS familie, f.verbund_id,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
WHERE public.merge_norm(s.name) = public.merge_norm('Begović');

-- b) Personen mit Spiegel (gleiche identitaet_id) — jede Person je einmal pro Baum
SELECT pe.vorname, pe.nachname, s.name AS baum, pe.identitaet_id
FROM public.personen pe
JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
WHERE pe.identitaet_id IN (
  SELECT p2.identitaet_id FROM public.personen p2
  JOIN public.stammbaeume s2 ON s2.id = p2.stammbaum_id
  WHERE public.merge_norm(s2.name) = public.merge_norm('Begović') AND p2.identitaet_id IS NOT NULL
)
ORDER BY pe.identitaet_id, s.name;


-- ===============================================================
-- TEIL 4 — ROLLBACK (nur bei Bedarf; Block einkommentieren und ausführen)
-- Entfernt den neu angelegten Begović-Baum samt Spiegelkarten/Beziehungen/Familie/
-- Mitgliedschaft. Die Original-Karten im Pisarević-Baum bleiben unangetastet.
-- ===============================================================
-- DO $$
-- DECLARE v_tree uuid; v_fam uuid;
-- BEGIN
--   SELECT s.id, s.familie_id INTO v_tree, v_fam
--     FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
--    WHERE public.merge_norm(s.name) = public.merge_norm('Begović')
--      AND s.familie_id NOT IN (SELECT id FROM public.bak_zweig_begovic_familien_ids)
--    LIMIT 1;
--   IF v_tree IS NULL THEN RAISE NOTICE 'Kein neu angelegter Begović-Baum gefunden.'; RETURN; END IF;
--   DELETE FROM public.beziehungen WHERE familie_id = v_fam;
--   DELETE FROM public.personen    WHERE stammbaum_id = v_tree;
--   DELETE FROM public.stammbaeume WHERE id = v_tree;
--   DELETE FROM public.mitgliedschaften WHERE familie_id = v_fam
--     AND id NOT IN (SELECT id FROM public.bak_zweig_begovic_mitglied_ids);
--   DELETE FROM public.familien WHERE id = v_fam
--     AND id NOT IN (SELECT id FROM public.bak_zweig_begovic_familien_ids);
--   RAISE NOTICE 'Rollback ok: Begović-Baum % entfernt.', v_tree;
-- END $$;
