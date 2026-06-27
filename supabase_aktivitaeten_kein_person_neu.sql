-- =====================================================
-- FEED/„ZID": neue Personen NICHT mehr in den Aktivitäten-Stream schreiben
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_aktivitaeten.sql ausführen.
--
-- HINTERGRUND: supabase_aktivitaeten.sql legt bei jeder echten Nutzer-Anlage einer Person
-- (Trigger akt_person_neu auf public.personen) eine Aktivität vom Typ 'person_neu' an, die im
-- Familien-Feed/Zid erscheint. Nutzerwunsch: das soll NICHT passieren.
--
-- ÄNDERUNG:
--   1) Trigger + Triggerfunktion für 'person_neu' entfernen -> künftig KEINE Aktivität bei
--      Personenanlage. Alle übrigen Aktivitätstypen (foto/geschichte/event/beitrag) bleiben
--      unverändert.
--   2) Bereits vorhandene 'person_neu'-Aktivitäten löschen, damit der Zid auch rückwirkend
--      sauber ist.
--
-- HINWEIS: Der CHECK-Wert 'person_neu' und der person_neu-Zweig in aktivitaeten_holen bleiben
-- bestehen (harmlos, da keine solchen Zeilen mehr entstehen) — so bleibt die Änderung minimal
-- und leicht reversibel (Trigger aus supabase_aktivitaeten.sql erneut ausführen).
-- =====================================================

-- 1) Trigger + Funktion entfernen
DROP TRIGGER IF EXISTS akt_person_neu ON public.personen;
DROP FUNCTION IF EXISTS public.akt_trg_person();

-- 2) Bestehende person_neu-Aktivitäten aus dem Feed räumen
DELETE FROM public.aktivitaeten WHERE typ = 'person_neu';

SELECT 'supabase_aktivitaeten_kein_person_neu.sql ausgeführt — Trigger akt_person_neu entfernt, vorhandene person_neu-Aktivitäten gelöscht' AS status;
