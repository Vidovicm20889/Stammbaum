-- =====================================================
-- JEDEN STAMMBAUM IN EINE EIGENE FAMILIE AUFTEILEN
-- + milan.vidovic90 als familien_owner aller Familien AUSSER Vidović
-- Ausführen in: Supabase -> SQL Editor.
--
-- WICHTIG: strukturelle Datenmigration. Vorher am besten einen DB-Snapshot/Backup
-- machen (Supabase -> Database -> Backups). Idempotent: bei erneutem Lauf werden
-- bereits ausgelagerte Bäume nicht noch einmal verarbeitet.
--
-- ENTSCHEIDUNG: gemeinsamer Verbund bleibt erhalten (baumübergreifende
-- Ehepartner bleiben sichtbar). Vidović bleibt unter der bisherigen Hauptfamilie.
-- =====================================================

-- ---------------------------------------------------------------
-- VORSCHAU (nichts wird geändert): welche Bäume werden ausgelagert?
-- ---------------------------------------------------------------
SELECT s.name AS stammbaum,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
FROM public.stammbaeume s
WHERE s.familie_id = '55abc7a5-8b21-46d8-83ff-e9baa6ddee96'
  AND s.id <> '55cb81eb-1c28-49b0-8769-91d166b8ad89'   -- Vidović-Baum bleibt
ORDER BY s.name;

-- ---------------------------------------------------------------
-- DURCHFÜHREN
-- ---------------------------------------------------------------
DO $$
DECLARE
  v_main_familie uuid := '55abc7a5-8b21-46d8-83ff-e9baa6ddee96';  -- bisherige Sammel-Familie
  v_vidovic_tree uuid := '55cb81eb-1c28-49b0-8769-91d166b8ad89';  -- Vidović bleibt hier
  v_verbund uuid;
  v_milan   uuid;
  r record;
  v_new_fam uuid;
BEGIN
  SELECT verbund_id INTO v_verbund FROM public.familien WHERE id = v_main_familie;
  SELECT id INTO v_milan FROM auth.users WHERE lower(email) = 'milan.vidovic90@gmail.com';
  IF v_verbund IS NULL THEN RAISE EXCEPTION 'Hauptfamilie 55abc... nicht gefunden.'; END IF;
  IF v_milan   IS NULL THEN RAISE EXCEPTION 'milan.vidovic90@gmail.com nicht gefunden.'; END IF;

  FOR r IN
    SELECT id, name FROM public.stammbaeume
    WHERE familie_id = v_main_familie AND id <> v_vidovic_tree
    ORDER BY name
  LOOP
    -- 1) eigene Familie für diesen Baum (gleicher Verbund -> bleibt verknüpft)
    INSERT INTO public.familien (name, verbund_id) VALUES (r.name, v_verbund)
    RETURNING id INTO v_new_fam;

    -- 2) Beziehungen der Personen dieses Baums umhängen (auch baumübergreifende)
    UPDATE public.beziehungen b SET familie_id = v_new_fam
    WHERE b.person_a IN (SELECT id FROM public.personen WHERE stammbaum_id = r.id)
       OR b.person_b IN (SELECT id FROM public.personen WHERE stammbaum_id = r.id);

    -- 3) Personen umhängen
    UPDATE public.personen SET familie_id = v_new_fam WHERE stammbaum_id = r.id;

    -- 4) Stammbaum umhängen
    UPDATE public.stammbaeume SET familie_id = v_new_fam WHERE id = r.id;

    -- 5) milan.vidovic90 als Eigentümer dieser Familie
    INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv)
    VALUES (v_milan, v_new_fam, 'familien_owner', true)
    ON CONFLICT (user_id, familie_id) DO UPDATE SET rolle = 'familien_owner', aktiv = true;
  END LOOP;

  -- 6) Testeric (eigene Familie) ebenfalls auf Owner setzen
  UPDATE public.mitgliedschaften m SET rolle = 'familien_owner', aktiv = true
  WHERE m.user_id = v_milan
    AND m.familie_id IN (SELECT id FROM public.familien WHERE name ILIKE '%testeric%');
END $$;

-- ---------------------------------------------------------------
-- KONTROLLE
-- ---------------------------------------------------------------
-- a) jede Familie mit ihrem Baum + Personenzahl
SELECT f.name AS familie, s.name AS stammbaum,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
FROM public.familien f
JOIN public.stammbaeume s ON s.familie_id = f.id
ORDER BY f.name;

-- b) Owner-Mitgliedschaften von milan.vidovic90 (sollte alle außer Vidović sein)
SELECT u.email, f.name AS familie, m.rolle, m.aktiv
FROM public.mitgliedschaften m
JOIN auth.users u ON u.id = m.user_id
JOIN public.familien f ON f.id = m.familie_id
WHERE lower(u.email) = 'milan.vidovic90@gmail.com'
ORDER BY f.name;
