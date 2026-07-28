-- =====================================================
-- BLUTLINIEN-RECHTE (Phase 1: Fundament + Auto-Recompute)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Idee: Ein Konto wird mit EINER Person im Baum verknüpft (personen.user_id).
-- Daraus wird die direkte Blutlinie (Vorfahren + Nachkommen, väterlich UND
-- mütterlich) berechnet; die dabei berührten FAMILIEN (= Nachnamen-Bäume)
-- bekommen automatisch rolle=familien_admin. Streng VERBUND-INTERN (keine
-- fremden Konten). OWNER und MANUELL gesetzte Rollen werden NIE überschrieben.
--
-- Voraussetzungen: personen(id, familie_id, user_id?), beziehungen(person_a,
--   person_b, typ='elternteil' mit a=Elternteil/b=Kind), familien(id, verbund_id),
--   mitgliedschaften(user_id, familie_id, rolle, aktiv), ist_super_admin(),
--   kann_familie_bearbeiten(p_familie_id).
-- =====================================================

-- 1) Verknüpfung Konto <-> Person + Auto-Flag für Rollen
ALTER TABLE public.personen        ADD COLUMN IF NOT EXISTS user_id uuid;
CREATE INDEX IF NOT EXISTS personen_user_id_idx ON public.personen(user_id);
-- auto=true  -> von der Blutlinien-Logik vergeben (darf neu berechnet/entzogen werden)
-- auto=false -> manuell/aus Anfrage gesetzt ODER Owner -> NIE automatisch ändern
ALTER TABLE public.mitgliedschaften ADD COLUMN IF NOT EXISTS auto boolean NOT NULL DEFAULT false;

-- 2) Blutlinie -> berührte Familien (verbund-intern). Vorfahren (rauf) + Nachkommen (runter)
--    über 'elternteil'-Kanten; KEINE Ehepartner-Kanten (Schwieger-Familien bleiben außen vor).
CREATE OR REPLACE FUNCTION public.blutlinie_familien(p_person uuid)
RETURNS TABLE(familie_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_fam uuid; v_verbund uuid;
BEGIN
  SELECT pe.familie_id INTO v_fam FROM public.personen pe WHERE pe.id = p_person AND pe.geloescht_am IS NULL;
  IF v_fam IS NULL THEN RETURN; END IF;
  SELECT f.verbund_id INTO v_verbund FROM public.familien f WHERE f.id = v_fam;

  RETURN QUERY
  WITH RECURSIVE vorfahren AS (
    SELECT p_person AS pid
    UNION
    SELECT b.person_a FROM public.beziehungen b
      JOIN vorfahren v ON b.person_b = v.pid
     WHERE b.typ = 'elternteil' AND b.geloescht_am IS NULL
  ),
  nachkommen AS (
    SELECT p_person AS pid
    UNION
    SELECT b.person_b FROM public.beziehungen b
      JOIN nachkommen n ON b.person_a = n.pid
     WHERE b.typ = 'elternteil' AND b.geloescht_am IS NULL
  ),
  blut AS (SELECT pid FROM vorfahren UNION SELECT pid FROM nachkommen)
  SELECT DISTINCT pe.familie_id
  FROM blut bl
  JOIN public.personen pe ON pe.id = bl.pid AND pe.geloescht_am IS NULL
  JOIN public.familien  f  ON f.id  = pe.familie_id
  WHERE pe.familie_id = v_fam                                  -- Anker-Familie immer dabei
     OR (v_verbund IS NOT NULL AND f.verbund_id = v_verbund);  -- sonst NUR eigener Verbund
END $$;
GRANT EXECUTE ON FUNCTION public.blutlinie_familien(uuid) TO authenticated;

-- 3) Rechte eines Users neu berechnen (intern; von Verknüpfung/Trigger/Anfrage aufgerufen).
--    Nur ERGÄNZEN: Blutlinie-Familien -> auto-admin; Owner & manuelle Rollen bleiben unberührt;
--    veraltete AUTO-Rollen (Familie nicht mehr in Blutlinie) werden entfernt.
CREATE OR REPLACE FUNCTION public.rechte_neu_berechnen(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fams uuid[]; f uuid; v_rolle text; v_auto boolean;
BEGIN
  IF p_user IS NULL THEN RETURN; END IF;

  -- Vereinigung der Blutlinien aller mit dem Konto verknüpften Personen
  SELECT array_agg(DISTINCT bf) INTO v_fams
  FROM public.personen pe
  CROSS JOIN LATERAL public.blutlinie_familien(pe.id) bf
  WHERE pe.user_id = p_user;
  v_fams := COALESCE(v_fams, '{}');

  -- Blutlinie-Familien -> familien_admin (auto), aber Owner/Manuell schützen
  FOREACH f IN ARRAY v_fams LOOP
    SELECT m.rolle, m.auto INTO v_rolle, v_auto
    FROM public.mitgliedschaften m WHERE m.user_id = p_user AND m.familie_id = f;
    IF NOT FOUND THEN
      INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv, auto)
      VALUES (p_user, f, 'familien_admin', true, true);
    ELSIF v_rolle = 'familien_owner' THEN
      CONTINUE;                                  -- Owner nie anfassen
    ELSIF v_auto IS NOT TRUE THEN
      CONTINUE;                                  -- manuell gesetzt -> respektieren
    ELSE
      UPDATE public.mitgliedschaften
         SET rolle = 'familien_admin', aktiv = true
       WHERE user_id = p_user AND familie_id = f AND rolle <> 'familien_admin';
    END IF;
  END LOOP;

  -- Veraltete AUTO-Admin-Rollen entfernen (Familie nicht mehr in der Blutlinie).
  -- (Lesezugriff auf andere Verbund-Familien bleibt über die Verbund-Sichtbarkeit bestehen.)
  DELETE FROM public.mitgliedschaften
   WHERE user_id = p_user AND auto = true AND NOT (familie_id = ANY(v_fams));
END $$;
-- absichtlich KEIN GRANT an authenticated: nur intern (Definer-Kontext) aufrufbar.

-- 4) Konto mit Person verknüpfen (Admin der Familie ODER Super-Admin) -> löst Recompute aus
CREATE OR REPLACE FUNCTION public.person_user_verknuepfen(p_person uuid, p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_alt uuid;
BEGIN
  SELECT pe.familie_id INTO v_fam FROM public.personen pe WHERE pe.id = p_person AND pe.geloescht_am IS NULL;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Person nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam))
    THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;

  -- bisherige Verknüpfung dieses Kontos lösen (ein Konto = eine Person)
  SELECT id INTO v_alt FROM public.personen WHERE user_id = p_user AND id <> p_person LIMIT 1;
  IF v_alt IS NOT NULL THEN UPDATE public.personen SET user_id = NULL WHERE id = v_alt; END IF;

  UPDATE public.personen SET user_id = p_user WHERE id = p_person;
  PERFORM public.rechte_neu_berechnen(p_user);
END $$;
GRANT EXECUTE ON FUNCTION public.person_user_verknuepfen(uuid, uuid) TO authenticated;

-- 5) Auto-Recompute bei Baumänderungen: alle verknüpften Konten im betroffenen Verbund neu rechnen.
CREATE OR REPLACE FUNCTION public.rechte_neu_berechnen_verbund(p_familie uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verbund uuid; v_user uuid;
BEGIN
  IF p_familie IS NULL THEN RETURN; END IF;
  SELECT verbund_id INTO v_verbund FROM public.familien WHERE id = p_familie;

  FOR v_user IN
    SELECT DISTINCT pe.user_id
    FROM public.personen pe
    JOIN public.familien f ON f.id = pe.familie_id
    WHERE pe.user_id IS NOT NULL
      AND ( (v_verbund IS NOT NULL AND f.verbund_id = v_verbund) OR pe.familie_id = p_familie )
  LOOP
    PERFORM public.rechte_neu_berechnen(v_user);
  END LOOP;
END $$;

-- Trigger-Funktion: bei beziehungen/personen-Änderung den betroffenen Verbund neu rechnen.
-- Guard: läuft nur, wenn es überhaupt verknüpfte Konten gibt (während Bulk-Migration = no-op).
CREATE OR REPLACE FUNCTION public.trg_blutlinie_recompute()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.personen WHERE user_id IS NOT NULL) THEN
    RETURN NULL;                                   -- keine Verknüpfungen -> nichts zu tun
  END IF;
  IF TG_TABLE_NAME = 'beziehungen' THEN
    SELECT familie_id INTO v_fam FROM public.personen
     WHERE id = COALESCE(NEW.person_b, OLD.person_b, NEW.person_a, OLD.person_a) LIMIT 1;
  ELSE  -- personen
    v_fam := COALESCE(NEW.familie_id, OLD.familie_id);
  END IF;
  PERFORM public.rechte_neu_berechnen_verbund(v_fam);
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS blutlinie_beziehungen ON public.beziehungen;
CREATE TRIGGER blutlinie_beziehungen
  AFTER INSERT OR UPDATE OR DELETE ON public.beziehungen
  FOR EACH ROW EXECUTE FUNCTION public.trg_blutlinie_recompute();

-- personen: nur bei relevanten Änderungen (Nachname in stammbaum_daten, familie/stammbaum, Verknüpfung)
DROP TRIGGER IF EXISTS blutlinie_personen ON public.personen;
CREATE TRIGGER blutlinie_personen
  AFTER UPDATE OF nachname, familie_id, stammbaum_id, stammbaum_daten, user_id ON public.personen
  FOR EACH ROW EXECUTE FUNCTION public.trg_blutlinie_recompute();

NOTIFY pgrst, 'reload schema';
SELECT 'Blutlinien-Rechte: Schema + RPCs + Trigger angelegt' AS status;

-- =====================================================
-- TEST (nichts wird dauerhaft verändert, außer du rufst person_user_verknuepfen auf)
-- =====================================================
-- A) Eine bekannte Person finden (z.B. der spätere Konto-Inhaber):
-- SELECT id, vorname, nachname, familie_id FROM public.personen
--   WHERE lower(nachname) = lower('Vidović') LIMIT 20;
--
-- B) Blutlinie-FAMILIEN dieser Person prüfen (sollte z.B. Vidović + Knežević enthalten):
-- SELECT f.name, bf.familie_id
--   FROM public.blutlinie_familien('<PERSON-UUID>') bf
--   JOIN public.familien f ON f.id = bf.familie_id;
--
-- C) Wenn B stimmt: Konto verknüpfen (löst Auto-Admin-Vergabe aus):
-- SELECT public.person_user_verknuepfen('<PERSON-UUID>',
--          (SELECT id FROM auth.users WHERE lower(email)=lower('user@example.com')));
--
-- D) Kontrolle der vergebenen Rollen:
-- SELECT f.name AS familie, m.rolle, m.auto
--   FROM public.mitgliedschaften m JOIN public.familien f ON f.id=m.familie_id
--   WHERE m.user_id = (SELECT id FROM auth.users WHERE lower(email)=lower('user@example.com'))
--   ORDER BY m.auto, f.name;
-- =====================================================
