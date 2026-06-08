-- =====================================================
-- Mitglied umhängen: trivopetrovic89@gmail.com
--   Vidović : Admin  -> Mitglied (sieht den Baum weiterhin, KEINE Admin-Rechte)
--   Petrović:        -> Admin
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- mitgliedschaften: (user_id, familie_id, rolle, aktiv), UNIQUE(user_id, familie_id).
-- Owner-Rollen werden bewusst NICHT automatisch geändert.
-- =====================================================

-- ---------- 1) VORSCHAU (ändert nichts) — bitte zuerst prüfen ----------
-- a) der User
SELECT id, email FROM auth.users WHERE lower(email) = lower('trivopetrovic89@gmail.com');

-- b) seine aktuellen Mitgliedschaften
SELECT f.name AS familie, m.rolle, m.aktiv, m.familie_id
FROM public.mitgliedschaften m
JOIN public.familien f ON f.id = m.familie_id
JOIN auth.users u      ON u.id = m.user_id
WHERE lower(u.email) = lower('trivopetrovic89@gmail.com')
ORDER BY f.name;

-- c) Kandidaten-Familien (genaue Namen/IDs kontrollieren — v.a. ob "Petrović" eindeutig ist)
SELECT id, name, verbund_id FROM public.familien
WHERE name ILIKE 'Vidovi%' OR name ILIKE 'Petrovi%'
ORDER BY name;

-- ---------- 2) AKTION (idempotent) ----------
DO $$
DECLARE
  v_user uuid;
  v_vid  uuid;          -- Vidović = die Familie, in der er aktuell Admin ist
  v_pet  uuid;          -- Petrović
  v_pet_anzahl int;
BEGIN
  SELECT id INTO v_user FROM auth.users WHERE lower(email) = lower('trivopetrovic89@gmail.com');
  IF v_user IS NULL THEN RAISE EXCEPTION 'User trivopetrovic89@gmail.com nicht gefunden.'; END IF;

  -- Vidović eindeutig über SEINE Admin-Mitgliedschaft bestimmen (kein Namens-Kollisionsrisiko).
  SELECT m.familie_id INTO v_vid
  FROM public.mitgliedschaften m
  JOIN public.familien f ON f.id = m.familie_id
  WHERE m.user_id = v_user AND m.rolle = 'familien_admin' AND f.name ILIKE 'Vidovi%'
  LIMIT 1;
  IF v_vid IS NULL THEN
    RAISE EXCEPTION 'Keine Admin-Mitgliedschaft "Vidović" für diesen User gefunden — bitte Vorschau (b) prüfen.';
  END IF;

  -- Petrović über den Namen; bei Mehrdeutigkeit abbrechen (dann v_pet manuell auf die ID aus Vorschau (c) setzen).
  SELECT count(*) INTO v_pet_anzahl FROM public.familien WHERE name ILIKE 'Petrovi%';
  IF v_pet_anzahl = 0 THEN RAISE EXCEPTION 'Familie Petrović nicht gefunden.'; END IF;
  IF v_pet_anzahl > 1 THEN
    RAISE EXCEPTION 'Mehrere Familien "Petrovi%%" gefunden (%) — bitte in diesem Block v_pet manuell auf die richtige familie_id aus Vorschau (c) setzen.', v_pet_anzahl;
  END IF;
  SELECT id INTO v_pet FROM public.familien WHERE name ILIKE 'Petrovi%' LIMIT 1;

  -- Schutz: Owner nicht automatisch herabstufen.
  IF EXISTS (SELECT 1 FROM public.mitgliedschaften
             WHERE user_id = v_user AND familie_id = v_vid AND rolle = 'familien_owner') THEN
    RAISE EXCEPTION 'User ist OWNER von Vidović — Downgrade nicht automatisch (Owner-Regel).';
  END IF;

  -- 1) Vidović: Admin -> Mitglied (aktiv bleibt -> sieht den Baum weiterhin)
  UPDATE public.mitgliedschaften
     SET rolle = 'familien_mitglied', aktiv = true
   WHERE user_id = v_user AND familie_id = v_vid;

  -- 2) Petrović: Admin (anlegen ODER bestehende Mitgliedschaft hochstufen; Owner bleibt Owner)
  INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv)
  VALUES (v_user, v_pet, 'familien_admin', true)
  ON CONFLICT (user_id, familie_id) DO UPDATE
     SET rolle = CASE WHEN mitgliedschaften.rolle = 'familien_owner'
                      THEN 'familien_owner' ELSE 'familien_admin' END,
         aktiv = true;

  RAISE NOTICE 'OK: % ist jetzt Mitglied (Lesezugriff) von Vidović und Admin von Petrović.',
    'trivopetrovic89@gmail.com';
END $$;

-- ---------- 3) KONTROLLE (sollte Vidović=familien_mitglied, Petrović=familien_admin zeigen) ----------
SELECT f.name AS familie, m.rolle, m.aktiv
FROM public.mitgliedschaften m
JOIN public.familien f ON f.id = m.familie_id
JOIN auth.users u      ON u.id = m.user_id
WHERE lower(u.email) = lower('trivopetrovic89@gmail.com')
ORDER BY f.name;
