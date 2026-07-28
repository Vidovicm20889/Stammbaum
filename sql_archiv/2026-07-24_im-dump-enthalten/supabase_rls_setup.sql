-- =====================================================
-- STAMMBAUM: Row Level Security Setup
-- Ausführen in: Supabase → SQL Editor
-- =====================================================


-- =====================================================
-- SCHRITT 1: Helper-Funktionen (SECURITY DEFINER = umgeht RLS, kein Recursion-Problem)
-- =====================================================

-- Gibt die Rolle des eingeloggten Users für eine bestimmte Familie zurück
CREATE OR REPLACE FUNCTION public.get_meine_rolle(p_familie_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT rolle FROM public.mitgliedschaften
  WHERE user_id = auth.uid() AND familie_id = p_familie_id
  LIMIT 1;
$$;

-- Prüft ob der eingeloggte User Super Admin ist (in irgendeiner Familie)
CREATE OR REPLACE FUNCTION public.ist_super_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid() AND rolle = 'super_admin'
  );
$$;


-- =====================================================
-- SCHRITT 2: RLS aktivieren (auf allen Tabellen)
-- =====================================================

ALTER TABLE public.familien         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personen         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.beziehungen      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mitgliedschaften ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lizenzen         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rollen_anfragen  ENABLE ROW LEVEL SECURITY;


-- =====================================================
-- SCHRITT 3: Policies für FAMILIEN
-- =====================================================

-- Lesen: Super Admin sieht alle; andere nur ihre eigene Familie
CREATE POLICY "familien_select" ON public.familien
FOR SELECT USING (
  ist_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid() AND familie_id = familien.id
  )
);

-- Erstellen: Nur Super Admin darf neue Familien anlegen
CREATE POLICY "familien_insert" ON public.familien
FOR INSERT WITH CHECK (ist_super_admin());

-- Bearbeiten: Super Admin oder Familien-Admin der jeweiligen Familie
CREATE POLICY "familien_update" ON public.familien
FOR UPDATE USING (
  ist_super_admin()
  OR get_meine_rolle(id) = 'familien_admin'
);

-- Löschen: Nur Super Admin
CREATE POLICY "familien_delete" ON public.familien
FOR DELETE USING (ist_super_admin());


-- =====================================================
-- SCHRITT 4: Policies für PERSONEN
-- =====================================================

-- Lesen: Super Admin alle; andere nur eigene Familie
CREATE POLICY "personen_select" ON public.personen
FOR SELECT USING (
  ist_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid() AND familie_id = personen.familie_id
  )
);

-- Erstellen: Super Admin oder Familien-Admin
CREATE POLICY "personen_insert" ON public.personen
FOR INSERT WITH CHECK (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

-- Bearbeiten: Super Admin oder Familien-Admin
CREATE POLICY "personen_update" ON public.personen
FOR UPDATE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

-- Löschen: Super Admin oder Familien-Admin
CREATE POLICY "personen_delete" ON public.personen
FOR DELETE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);


-- =====================================================
-- SCHRITT 5: Policies für BEZIEHUNGEN
-- =====================================================

CREATE POLICY "beziehungen_select" ON public.beziehungen
FOR SELECT USING (
  ist_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid() AND familie_id = beziehungen.familie_id
  )
);

CREATE POLICY "beziehungen_insert" ON public.beziehungen
FOR INSERT WITH CHECK (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

CREATE POLICY "beziehungen_update" ON public.beziehungen
FOR UPDATE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

CREATE POLICY "beziehungen_delete" ON public.beziehungen
FOR DELETE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);


-- =====================================================
-- SCHRITT 6: Policies für MITGLIEDSCHAFTEN
-- =====================================================

-- Lesen: Super Admin alle; User sieht eigene; Familien-Admin sieht seine Familie
CREATE POLICY "mitgliedschaften_select" ON public.mitgliedschaften
FOR SELECT USING (
  ist_super_admin()
  OR user_id = auth.uid()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

-- Erstellen: Super Admin oder Familien-Admin (für Genehmigungen)
CREATE POLICY "mitgliedschaften_insert" ON public.mitgliedschaften
FOR INSERT WITH CHECK (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

-- Bearbeiten: Super Admin oder Familien-Admin
CREATE POLICY "mitgliedschaften_update" ON public.mitgliedschaften
FOR UPDATE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

-- Löschen: Super Admin oder Familien-Admin
CREATE POLICY "mitgliedschaften_delete" ON public.mitgliedschaften
FOR DELETE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);


-- =====================================================
-- SCHRITT 7: Policies für ROLLEN_ANFRAGEN
-- =====================================================

-- Lesen: Super Admin alle; Familien-Admin seine Familie; User eigene Anfragen
CREATE POLICY "rollen_anfragen_select" ON public.rollen_anfragen
FOR SELECT USING (
  ist_super_admin()
  OR user_id = auth.uid()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

-- Erstellen: Jeder eingeloggte User darf eine Anfrage für sich stellen
CREATE POLICY "rollen_anfragen_insert" ON public.rollen_anfragen
FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL
  AND user_id = auth.uid()
);

-- Bearbeiten (genehmigen/ablehnen): Super Admin oder Familien-Admin
CREATE POLICY "rollen_anfragen_update" ON public.rollen_anfragen
FOR UPDATE USING (
  ist_super_admin()
  OR get_meine_rolle(familie_id) = 'familien_admin'
);

-- Löschen: Nur Super Admin
CREATE POLICY "rollen_anfragen_delete" ON public.rollen_anfragen
FOR DELETE USING (ist_super_admin());


-- =====================================================
-- SCHRITT 8: Policies für LIZENZEN
-- =====================================================

-- Lesen: Super Admin alle; Mitglieder sehen ihre Familien-Lizenz
CREATE POLICY "lizenzen_select" ON public.lizenzen
FOR SELECT USING (
  ist_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.mitgliedschaften
    WHERE user_id = auth.uid() AND familie_id = lizenzen.familie_id
  )
);

-- Erstellen/Bearbeiten/Löschen: Nur Super Admin (später Stripe-Webhook)
CREATE POLICY "lizenzen_insert"  ON public.lizenzen FOR INSERT WITH CHECK (ist_super_admin());
CREATE POLICY "lizenzen_update"  ON public.lizenzen FOR UPDATE USING (ist_super_admin());
CREATE POLICY "lizenzen_delete"  ON public.lizenzen FOR DELETE USING (ist_super_admin());


-- =====================================================
-- SCHRITT 9: Dich selbst als Super Admin eintragen
-- (Nur ausführen NACHDEM du dich via Supabase Auth registriert hast)
-- Ersetze die UUIDs mit deinen echten Werten!
-- =====================================================

/*
INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle)
VALUES (
  'DEINE-USER-ID-AUS-AUTH.USERS',   -- Supabase → Authentication → Users → deine ID
  'DEINE-FAMILIE-ID-AUS-FAMILIEN',  -- Supabase → Table Editor → familien → deine ID
  'super_admin'
);
*/
