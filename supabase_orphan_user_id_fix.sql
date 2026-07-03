-- =====================================================
-- FIX: Verwaiste personen.user_id (gelöschtes Auth-Konto) blockiert den Verbund
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- SYMPTOM (aus der Browser-Konsole): Karte verknüpfen / Person bearbeiten schlägt fehl mit
--   code 23503 "insert or update on table \"mitgliedschaften\" violates foreign key constraint
--   \"mitgliedschaften_user_id_fkey\"  Key (user_id)=(<UUID>) is not present in table users".
--
-- URSACHE: Ein Auth-Konto wurde gelöscht (z. B. direkt im Dashboard), OHNE personen.user_id
-- freizugeben -> eine Karte zeigt auf eine nicht mehr existierende UUID ("Geist"). Der Trigger
-- rechte_neu_berechnen_verbund() iteriert bei JEDER Karten-/Personenänderung über ALLE user_id
-- im Verbund und will auch dem Geist eine familien_admin-Mitgliedschaft geben -> FK-Verletzung
-- -> die GANZE Aktion (und damit jede Karten-/Personen-Änderung im Verbund) bricht ab.
--
-- Diese Datei behebt drei Dinge:
--   1) Bestehende Geister aufräumen (personen.user_id -> NULL; verwaiste Mitgliedschaften weg).
--   2) Recompute robust machen: nicht-existierende Konten werden übersprungen (defense in depth).
--   3) Künftige Geister verhindern: FK personen.user_id -> auth.users ON DELETE SET NULL
--      (Konto-Löschung — auch im Dashboard — gibt die Karte automatisch frei).
--
-- Voraussetzung: supabase_blutlinie_rechte.sql wurde bereits ausgeführt.
-- =====================================================

-- 1) BESTEHENDE GEISTER AUFRÄUMEN ---------------------------------------------
-- a) Karten, die auf ein nicht mehr existierendes Konto zeigen -> Verknüpfung lösen
--    (die Karte selbst BLEIBT im Baum erhalten).
UPDATE public.personen pe SET user_id = NULL
 WHERE pe.user_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = pe.user_id);

-- b) Verwaiste Mitgliedschaften (Konto existiert nicht mehr) entfernen.
DELETE FROM public.mitgliedschaften m
 WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = m.user_id);


-- 2) RECOMPUTE ROBUST GEGEN GEISTER (defense in depth) ------------------------
-- 2a) rechte_neu_berechnen: für nicht existierende Konten sofort aussteigen
--     (verhindert den FK-Fehler beim INSERT in mitgliedschaften).
CREATE OR REPLACE FUNCTION public.rechte_neu_berechnen(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fams uuid[]; f uuid; v_rolle text; v_auto boolean;
BEGIN
  IF p_user IS NULL THEN RETURN; END IF;
  -- Robustheit: verwaiste (gelöschte) Konten ignorieren -> sonst FK-Verletzung.
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user) THEN RETURN; END IF;

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
  DELETE FROM public.mitgliedschaften
   WHERE user_id = p_user AND auto = true AND NOT (familie_id = ANY(v_fams));
END $$;

-- 2b) rechte_neu_berechnen_verbund: nur EXISTIERENDE Konten in die Schleife
--     (ein einzelner Geist darf nicht den ganzen Verbund lahmlegen).
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
      AND EXISTS (SELECT 1 FROM auth.users u WHERE u.id = pe.user_id)   -- Geister überspringen
      AND ( (v_verbund IS NOT NULL AND f.verbund_id = v_verbund) OR pe.familie_id = p_familie )
  LOOP
    PERFORM public.rechte_neu_berechnen(v_user);
  END LOOP;
END $$;


-- 3) KÜNFTIGE GEISTER VERHINDERN (FK mit ON DELETE SET NULL) ------------------
-- Wird ein Auth-Konto gelöscht (auch DIREKT im Dashboard), setzt Postgres alle
-- personen.user_id automatisch auf NULL -> Karte bleibt, Verknüpfung fällt weg,
-- kein Geist mehr. (Schritt 1 hat alle Bestands-Geister entfernt -> FK-Anlage klappt.)
-- Kein UNIQUE (bewusst, siehe CLAUDE.md) — nur die referenzielle Integrität.
ALTER TABLE public.personen DROP CONSTRAINT IF EXISTS personen_user_id_fkey;
ALTER TABLE public.personen ADD CONSTRAINT personen_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


NOTIFY pgrst, 'reload schema';

-- KONTROLLE (sollte 0 sein):
SELECT count(*) AS verwaiste_karten
  FROM public.personen pe
 WHERE pe.user_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = pe.user_id);

SELECT 'OK: Geister entfernt, Recompute gehärtet, FK personen.user_id -> auth.users (ON DELETE SET NULL) gesetzt' AS status;
