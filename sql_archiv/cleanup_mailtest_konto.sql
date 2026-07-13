-- ============================================================================
-- EINMAL-CLEANUP: Wegwerf-Testkonto "ZZTestmail" (Mail-Zustelltest) entfernen
-- ----------------------------------------------------------------------------
-- Löscht NUR das eine Testkonto milan_vidovic89+mailtest@hotmail.com samt seiner
-- Familie/Baum/Person/Mitgliedschaft und dem Auth-User. FK-sichere Reihenfolge
-- (Kinder vor Eltern). Im Supabase SQL-Editor ausführen. NICHT Teil des Neuaufbaus.
--
-- Scope streng über die bekannte familie_id + E-Mail -> trifft nichts anderes.
-- ============================================================================

DO $$
DECLARE
  v_fam  uuid := '3519116c-60fd-47b9-91cb-f8ed65d01db7';   -- Familie "ZZTestmail"
  v_mail text := 'milan_vidovic89+mailtest@hotmail.com';
  v_user uuid;
BEGIN
  SELECT id INTO v_user FROM auth.users WHERE lower(email) = lower(v_mail);

  -- Beziehungen der Personen dieser Familie
  DELETE FROM public.beziehungen b
   WHERE b.person_a IN (SELECT id FROM public.personen WHERE familie_id = v_fam)
      OR b.person_b IN (SELECT id FROM public.personen WHERE familie_id = v_fam);

  -- Personen, Mitgliedschaften, Bäume, Registrierungsanfragen, dann Familie
  DELETE FROM public.personen        WHERE familie_id = v_fam;
  DELETE FROM public.mitgliedschaften WHERE familie_id = v_fam;
  DELETE FROM public.stammbaeume     WHERE familie_id = v_fam;
  DELETE FROM public.registrierungs_anfragen WHERE familie_id = v_fam;
  DELETE FROM public.familien        WHERE id = v_fam;

  -- Auth-User zuletzt (falls vorhanden) — vorher evtl. profile-Zeile lösen (FK)
  IF v_user IS NOT NULL THEN
    DELETE FROM public.profile WHERE user_id = v_user;
    DELETE FROM auth.users WHERE id = v_user;
  END IF;

  RAISE NOTICE 'Testkonto ZZTestmail entfernt (familie=%, user=%)', v_fam, v_user;
END $$;

SELECT 'cleanup_mailtest_konto.sql ausgeführt' AS status;
