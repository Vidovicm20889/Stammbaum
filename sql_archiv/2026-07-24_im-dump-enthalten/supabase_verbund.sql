-- =====================================================
-- VERBUND — kontenübergreifende Sichtbarkeit/Bearbeitung über Heirats-Verknüpfung
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
--
-- Idee: Jede familie (Konto) gehört zu einem "Verbund". Konten im selben Verbund
-- sehen sich; andere Verbünde sind fremd (unsichtbar). Eine Heirat über Konten
-- hinweg legt die Konten in denselben Verbund (familien_verbinden).
--
-- WICHTIG: Für ein einzelnes Konto ist das Verhalten IDENTISCH zu vorher
-- (jeder Verbund enthält genau seine eine familie). Erst ab 2 verbundenen
-- Konten greift die kontenübergreifende Sicht.
--
-- ROLLBACK: einfach supabase_rls_setup.sql (+ stammbaeume-Policies aus
-- supabase_multitree_phase5.sql) erneut ausführen.
-- =====================================================

-- 1) verbund_id an familien (Backfill: jede familie ihr eigener Verbund)
ALTER TABLE public.familien ADD COLUMN IF NOT EXISTS verbund_id uuid;
UPDATE public.familien SET verbund_id = gen_random_uuid() WHERE verbund_id IS NULL;
ALTER TABLE public.familien ALTER COLUMN verbund_id SET DEFAULT gen_random_uuid();
ALTER TABLE public.familien ALTER COLUMN verbund_id SET NOT NULL;


-- 2) Helper-Funktionen (SECURITY DEFINER -> keine Rekursion)

-- Darf der eingeloggte User die Daten dieser familie SEHEN?
-- (eine seiner Mitgliedschafts-Familien teilt den Verbund mit p_familie_id)
CREATE OR REPLACE FUNCTION public.sieht_familie(p_familie_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.mitgliedschaften m
    JOIN public.familien fm ON fm.id = m.familie_id
    WHERE m.user_id = auth.uid()
      AND fm.verbund_id = (SELECT verbund_id FROM public.familien WHERE id = p_familie_id)
  );
$$;

-- Darf der eingeloggte User die Daten dieser familie BEARBEITEN?
-- (Super-Admin; oder Familien-Admin in einem Konto desselben Verbunds)
CREATE OR REPLACE FUNCTION public.kann_familie_bearbeiten(p_familie_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT public.ist_super_admin() OR EXISTS (
    SELECT 1
    FROM public.mitgliedschaften m
    JOIN public.familien fm ON fm.id = m.familie_id
    WHERE m.user_id = auth.uid()
      AND m.rolle = 'familien_admin'
      AND fm.verbund_id = (SELECT verbund_id FROM public.familien WHERE id = p_familie_id)
  );
$$;


-- 3) Policies auf verbund-basiert umstellen

-- PERSONEN
DROP POLICY IF EXISTS "personen_select" ON public.personen;
DROP POLICY IF EXISTS "personen_insert" ON public.personen;
DROP POLICY IF EXISTS "personen_update" ON public.personen;
DROP POLICY IF EXISTS "personen_delete" ON public.personen;
CREATE POLICY "personen_select" ON public.personen FOR SELECT
  USING ( public.ist_super_admin() OR public.sieht_familie(familie_id) );
CREATE POLICY "personen_insert" ON public.personen FOR INSERT
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "personen_update" ON public.personen FOR UPDATE
  USING ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "personen_delete" ON public.personen FOR DELETE
  USING ( public.kann_familie_bearbeiten(familie_id) );

-- BEZIEHUNGEN
DROP POLICY IF EXISTS "beziehungen_select" ON public.beziehungen;
DROP POLICY IF EXISTS "beziehungen_insert" ON public.beziehungen;
DROP POLICY IF EXISTS "beziehungen_update" ON public.beziehungen;
DROP POLICY IF EXISTS "beziehungen_delete" ON public.beziehungen;
CREATE POLICY "beziehungen_select" ON public.beziehungen FOR SELECT
  USING ( public.ist_super_admin() OR public.sieht_familie(familie_id) );
CREATE POLICY "beziehungen_insert" ON public.beziehungen FOR INSERT
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "beziehungen_update" ON public.beziehungen FOR UPDATE
  USING ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "beziehungen_delete" ON public.beziehungen FOR DELETE
  USING ( public.kann_familie_bearbeiten(familie_id) );

-- STAMMBAEUME
DROP POLICY IF EXISTS "stammbaeume_select" ON public.stammbaeume;
DROP POLICY IF EXISTS "stammbaeume_insert" ON public.stammbaeume;
DROP POLICY IF EXISTS "stammbaeume_update" ON public.stammbaeume;
DROP POLICY IF EXISTS "stammbaeume_delete" ON public.stammbaeume;
CREATE POLICY "stammbaeume_select" ON public.stammbaeume FOR SELECT
  USING ( public.ist_super_admin() OR public.sieht_familie(familie_id) );
CREATE POLICY "stammbaeume_insert" ON public.stammbaeume FOR INSERT
  WITH CHECK ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "stammbaeume_update" ON public.stammbaeume FOR UPDATE
  USING ( public.kann_familie_bearbeiten(familie_id) );
CREATE POLICY "stammbaeume_delete" ON public.stammbaeume FOR DELETE
  USING ( public.ist_super_admin() );

-- FAMILIEN (Namen verbundener Konten sichtbar)
DROP POLICY IF EXISTS "familien_select" ON public.familien;
CREATE POLICY "familien_select" ON public.familien FOR SELECT
  USING ( public.ist_super_admin() OR public.sieht_familie(id) );


-- 4) Zwei Konten verbinden (z. B. bei Heirat über Konten hinweg).
--    Legt familie B (und alle in B's Verbund) in den Verbund von familie A.
--    Nur Super-Admin.
CREATE OR REPLACE FUNCTION public.familien_verbinden(p_a uuid, p_b uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_a uuid; v_b uuid;
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'Nur Super-Admin darf Konten verbinden.'; END IF;
  SELECT verbund_id INTO v_a FROM public.familien WHERE id = p_a;
  SELECT verbund_id INTO v_b FROM public.familien WHERE id = p_b;
  IF v_a IS NULL OR v_b IS NULL THEN RAISE EXCEPTION 'familie nicht gefunden.'; END IF;
  UPDATE public.familien SET verbund_id = v_a WHERE verbund_id = v_b;
END $$;
GRANT EXECUTE ON FUNCTION public.familien_verbinden(uuid, uuid) TO authenticated;


-- 4b) AUTOMATIK: Bei Heirat (ehepartner) über Konten hinweg die Verbünde
--     automatisch zusammenlegen. Trigger auf beziehungen.
CREATE OR REPLACE FUNCTION public.trg_beziehung_verbund()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_a uuid; v_b uuid;
BEGIN
  IF NEW.typ = 'ehepartner' THEN
    SELECT f.verbund_id INTO v_a FROM public.personen p
      JOIN public.familien f ON f.id = p.familie_id WHERE p.id = NEW.person_a;
    SELECT f.verbund_id INTO v_b FROM public.personen p
      JOIN public.familien f ON f.id = p.familie_id WHERE p.id = NEW.person_b;
    IF v_a IS NOT NULL AND v_b IS NOT NULL AND v_a <> v_b THEN
      UPDATE public.familien SET verbund_id = v_a WHERE verbund_id = v_b;
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS beziehung_verbund_merge ON public.beziehungen;
CREATE TRIGGER beziehung_verbund_merge
AFTER INSERT OR UPDATE OF typ, person_a, person_b ON public.beziehungen
FOR EACH ROW EXECUTE FUNCTION public.trg_beziehung_verbund();


-- 5) Kontrolle
SELECT name, verbund_id FROM public.familien ORDER BY name;
