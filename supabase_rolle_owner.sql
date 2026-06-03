-- =====================================================
-- NEUE ROLLE: familien_owner
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier, Run).
--
-- familien_owner = Eigentümer einer Familie/eines Stammbaums (der Ersteller).
--   * hat ALLE Rechte eines familien_admin
--   * EXKLUSIV: darf den Stammbaum löschen
--   * kann NICHT über normale Rollenänderung vergeben/entfernt werden
--   * ein familien_admin darf einen Owner weder ändern, deaktivieren noch entfernen
--
-- Voraussetzung: ist_super_admin(), get_meine_rolle() existieren (mitglieder_komplett).
-- =====================================================

-- 1) Rolle in der CHECK-Constraint erlauben (jede vorhandene rolle-Constraint
--    ersetzen, egal wie sie heißt)
DO $$
DECLARE c record;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.mitgliedschaften'::regclass AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%rolle%'
  LOOP
    EXECUTE format('ALTER TABLE public.mitgliedschaften DROP CONSTRAINT %I', c.conname);
  END LOOP;
  ALTER TABLE public.mitgliedschaften ADD CONSTRAINT mitgliedschaften_rolle_check
    CHECK (rolle IN ('super_admin','familien_owner','familien_admin','familien_mitglied'));
END $$;

-- 2) Bearbeiten-Recht: owner zählt wie admin (verbundweit)
CREATE OR REPLACE FUNCTION public.kann_familie_bearbeiten(p_familie_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT public.ist_super_admin() OR EXISTS (
    SELECT 1 FROM public.mitgliedschaften m
    JOIN public.familien fm ON fm.id = m.familie_id
    WHERE m.user_id = auth.uid()
      AND m.rolle IN ('familien_admin','familien_owner') AND m.aktiv
      AND fm.verbund_id = (SELECT verbund_id FROM public.familien WHERE id = p_familie_id)
  );
$$;

-- 3) Mitglieder-Liste: owner verwaltet seine Familie ebenfalls
DROP FUNCTION IF EXISTS public.mitglieder_verwaltbar();
CREATE OR REPLACE FUNCTION public.mitglieder_verwaltbar()
RETURNS TABLE (
  mitgliedschaft_id uuid, user_id uuid, email text, name text,
  rolle text, familie_id uuid, familie_name text, aktiv boolean
)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT m.id, m.user_id, u.email,
    trim(coalesce(ra.vorname,'') || ' ' || coalesce(ra.nachname,'')) AS name,
    m.rolle, m.familie_id, f.name, m.aktiv
  FROM public.mitgliedschaften m
  JOIN auth.users u       ON u.id = m.user_id
  JOIN public.familien f   ON f.id = m.familie_id
  LEFT JOIN LATERAL (
    SELECT vorname, nachname FROM public.registrierungs_anfragen r
    WHERE lower(r.email) = lower(u.email) ORDER BY r.created_at DESC LIMIT 1
  ) ra ON true
  WHERE public.ist_super_admin()
     OR m.familie_id IN (
       SELECT familie_id FROM public.mitgliedschaften
       WHERE user_id = auth.uid() AND rolle IN ('familien_admin','familien_owner') AND aktiv
     )
  ORDER BY f.name, (NOT m.aktiv), u.email;
$$;
GRANT EXECUTE ON FUNCTION public.mitglieder_verwaltbar() TO authenticated;

-- 4) Schreib-RPCs: owner darf verwalten, ist aber selbst geschützt
--    (Helfer: ist der Aufrufer berechtigt, diese Familie zu verwalten?)
--    -> super_admin ODER owner/admin der Familie.

-- aktiv setzen
CREATE OR REPLACE FUNCTION public.mitglied_aktiv_setzen(p_mid uuid, p_aktiv boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_rolle text;
BEGIN
  SELECT familie_id, rolle INTO v_fam, v_rolle FROM public.mitgliedschaften WHERE id = p_mid;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Mitglied nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.get_meine_rolle(v_fam) IN ('familien_admin','familien_owner')) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  -- Owner und super_admin sind vor Nicht-Super-Admins geschützt
  IF v_rolle IN ('super_admin','familien_owner') AND NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  UPDATE public.mitgliedschaften SET aktiv = p_aktiv WHERE id = p_mid;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.mitglied_aktiv_setzen(uuid, boolean) TO authenticated;

-- Rolle setzen — nur mitglied/admin; owner kann NICHT vergeben/entfernt werden
CREATE OR REPLACE FUNCTION public.mitglied_rolle_setzen(p_mid uuid, p_rolle text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_rolle text;
BEGIN
  IF p_rolle NOT IN ('familien_mitglied','familien_admin') THEN
    RAISE EXCEPTION 'Unzulässige Rolle.';   -- familien_owner/super_admin nicht über GUI
  END IF;
  SELECT familie_id, rolle INTO v_fam, v_rolle FROM public.mitgliedschaften WHERE id = p_mid;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Mitglied nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.get_meine_rolle(v_fam) IN ('familien_admin','familien_owner')) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  -- Bestehende owner/super_admin-Zeilen sind unveränderlich (außer per SQL)
  IF v_rolle IN ('super_admin','familien_owner') THEN
    RAISE EXCEPTION 'Diese Rolle kann nicht geändert werden.';
  END IF;
  UPDATE public.mitgliedschaften SET rolle = p_rolle WHERE id = p_mid;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.mitglied_rolle_setzen(uuid, text) TO authenticated;

-- Mitglied entfernen (owner geschützt; sonst wie gehabt inkl. auth.users-Löschung)
CREATE OR REPLACE FUNCTION public.mitglied_entfernen(p_mid uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_rolle text; v_user uuid; v_email text;
BEGIN
  SELECT familie_id, rolle, user_id INTO v_fam, v_rolle, v_user
    FROM public.mitgliedschaften WHERE id = p_mid;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Mitglied nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.get_meine_rolle(v_fam) IN ('familien_admin','familien_owner')) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  IF v_rolle IN ('super_admin','familien_owner') AND NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  IF public.ist_super_admin() THEN
    DELETE FROM public.mitgliedschaften WHERE user_id = v_user;
  ELSE
    DELETE FROM public.mitgliedschaften WHERE id = p_mid;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.mitgliedschaften WHERE user_id = v_user) THEN
    SELECT email INTO v_email FROM auth.users WHERE id = v_user;
    IF v_email IS NOT NULL THEN
      DELETE FROM public.registrierungs_anfragen WHERE lower(email) = lower(v_email);
    END IF;
    DELETE FROM auth.users WHERE id = v_user;
  END IF;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.mitglied_entfernen(uuid) TO authenticated;

-- 5) Stammbaum löschen — EXKLUSIV für familien_owner (oder super_admin / Betrieb)
CREATE OR REPLACE FUNCTION public.stammbaum_loeschen(p_tree uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_count integer;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.get_meine_rolle(v_fam) = 'familien_owner') THEN
    RAISE EXCEPTION 'Nur der Eigentümer (familien_owner) darf den Stammbaum löschen.';
  END IF;

  DELETE FROM public.beziehungen b
  WHERE b.person_a IN (SELECT id FROM public.personen WHERE stammbaum_id = p_tree)
     OR b.person_b IN (SELECT id FROM public.personen WHERE stammbaum_id = p_tree);

  WITH del AS (DELETE FROM public.personen WHERE stammbaum_id = p_tree RETURNING 1)
  SELECT count(*) INTO v_count FROM del;

  DELETE FROM public.stammbaeume WHERE id = p_tree;
  RETURN v_count;
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_loeschen(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------
-- 6) OPTIONAL — bestehende Selbst-Anleger zu Owner machen.
-- Heuristik: in jeder Familie, die NICHT die Haupt-Vidović-Familie ist
-- (= nicht die mit den meisten Personen) und genau EINEN familien_admin hat,
-- wird dieser zum familien_owner. Bei Bedarf einkommentieren und ausführen.
-- ---------------------------------------------------------------
-- WITH haupt AS (
--   SELECT familie_id FROM public.personen GROUP BY familie_id ORDER BY count(*) DESC LIMIT 1
-- ),
-- kand AS (
--   SELECT m.familie_id, min(m.id) AS mid, count(*) AS n
--   FROM public.mitgliedschaften m
--   WHERE m.rolle = 'familien_admin' AND m.aktiv
--     AND m.familie_id NOT IN (SELECT familie_id FROM haupt)
--   GROUP BY m.familie_id
--   HAVING count(*) = 1
-- )
-- UPDATE public.mitgliedschaften x SET rolle = 'familien_owner'
-- FROM kand WHERE x.id = kand.mid;

SELECT 'familien_owner-Rolle eingerichtet' AS status;
