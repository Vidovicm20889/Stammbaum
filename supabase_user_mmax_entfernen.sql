-- =====================================================
-- USER KOMPLETT ENTFERNEN: mmax89996@gmail.com
-- Entfernt Konto + Mitgliedschaften (inkl. Blutlinien-Admin) + Anfragen,
-- löst die Blutlinien-Verknüpfung (personen.user_id) und löscht die FÜR
-- DIESES KONTO angelegten Personen-Karten samt deren Beziehungen.
-- Ausführen in: Supabase -> SQL Editor. ZUERST Preview (1), dann Löschen (2).
--
-- ⚠️ SICHERHEIT: Eine ECHTE Stammbaum-Person (Vorfahre/Nachkomme anderer) wird
--    NICHT gelöscht, nur entkoppelt — sonst zerbricht der Baum für andere.
--    Nur Personen mit angelegt_aus in ('zugangsanfrage','stammbaum-anlegen')
--    gelten als „eigene Karten" und werden gelöscht. Preview (1d) zeigt, was da ist.
-- =====================================================

-- ---------- 1) PREVIEW (ändert nichts) ----------
-- a) Konto
SELECT id, email, created_at FROM auth.users WHERE lower(email) = lower('mmax89996@gmail.com');

-- b) Mitgliedschaften (Rollen, auto=Blutlinie?)
SELECT f.name AS familie, m.rolle, m.aktiv, m.auto, m.familie_id
FROM public.mitgliedschaften m
JOIN public.familien f ON f.id = m.familie_id
JOIN auth.users u      ON u.id = m.user_id
WHERE lower(u.email) = lower('mmax89996@gmail.com')
ORDER BY f.name;

-- c) Zugangsanfragen
SELECT id, status, rolle, familie_id, created_at
FROM public.registrierungs_anfragen WHERE lower(email) = lower('mmax89996@gmail.com');

-- d) Verknüpfte Personen-KARTEN: ist das eine eigene Karte (angelegt_aus) oder eine
--    echte Baum-Person? + wie viele Beziehungen hängen dran (= Risiko beim Löschen)?
SELECT pe.id, trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS person,
       f.name AS familie,
       pe.stammbaum_daten->>'angelegt_aus' AS angelegt_aus,
       (SELECT count(*) FROM public.beziehungen b WHERE b.person_a = pe.id OR b.person_b = pe.id) AS beziehungen,
       CASE WHEN coalesce(pe.stammbaum_daten->>'angelegt_aus','') IN ('zugangsanfrage','stammbaum-anlegen')
            THEN 'wird GELÖSCHT' ELSE 'wird nur ENTKOPPELT (echte Person)' END AS aktion
FROM public.personen pe
JOIN auth.users u ON u.id = pe.user_id
LEFT JOIN public.familien f ON f.id = pe.familie_id
WHERE lower(u.email) = lower('mmax89996@gmail.com');

-- ---------- 2) LÖSCHEN (idempotent) ----------
DO $$
DECLARE v_user uuid; v_email text := 'mmax89996@gmail.com'; v_self uuid[];
BEGIN
  SELECT id INTO v_user FROM auth.users WHERE lower(email) = lower(v_email);
  IF v_user IS NULL THEN RAISE NOTICE 'User % nicht gefunden — nichts zu tun.', v_email; RETURN; END IF;

  -- „Eigene" Karten dieses Kontos (für die Anfrage/Selbst-Anlegen erzeugt)
  SELECT array_agg(id) INTO v_self
  FROM public.personen
  WHERE user_id = v_user
    AND coalesce(stammbaum_daten->>'angelegt_aus','') IN ('zugangsanfrage','stammbaum-anlegen');
  v_self := coalesce(v_self, '{}');

  -- a) Beziehungen dieser eigenen Karten entfernen, dann die Karten selbst
  IF array_length(v_self,1) IS NOT NULL THEN
    DELETE FROM public.beziehungen
     WHERE person_a = ANY(v_self) OR person_b = ANY(v_self);
    DELETE FROM public.personen WHERE id = ANY(v_self);
  END IF;

  -- b) Restliche Verknüpfungen lösen (echte Baum-Personen bleiben erhalten)
  UPDATE public.personen SET user_id = NULL WHERE user_id = v_user;

  -- c) Mitgliedschaften (inkl. Blutlinien-Admin) + Anfragen
  DELETE FROM public.mitgliedschaften WHERE user_id = v_user;
  DELETE FROM public.registrierungs_anfragen WHERE lower(email) = lower(v_email);

  -- d) (optional) Protokoll-Einträge anonymisieren, falls dieses Konto je entschieden hat
  BEGIN
    UPDATE public.anfrage_log SET entschieden_von = NULL WHERE entschieden_von = v_user;
  EXCEPTION WHEN undefined_table THEN NULL; END;

  -- e) Auth-Konto zuletzt (identities/sessions per FK-CASCADE)
  DELETE FROM auth.users WHERE id = v_user;

  RAISE NOTICE 'User % entfernt (eigene Karten: %).', v_email, coalesce(array_length(v_self,1),0);
END $$;

-- ---------- 3) KONTROLLE (sollte 0 / leer sein) ----------
SELECT count(*) AS konto_noch_da FROM auth.users WHERE lower(email) = lower('mmax89996@gmail.com');
SELECT count(*) AS mitgliedschaften_rest
FROM public.mitgliedschaften m JOIN auth.users u ON u.id = m.user_id
WHERE lower(u.email) = lower('mmax89996@gmail.com');

-- =====================================================
-- WILLST DU WIRKLICH ALLE verknüpften Personen löschen (auch echte Baum-Personen)?
-- Dann VOR dem DO-Block in (2a) die angelegt_aus-Bedingung weglassen, d.h. v_self =
--   SELECT array_agg(id) FROM public.personen WHERE user_id = v_user;
-- ⚠️ Nur tun, wenn die Preview (1d) zeigt, dass es KEINE echten Vorfahren/Nachkommen
--    anderer sind — sonst gehen Beziehungen anderer Personen verloren.
-- =====================================================
