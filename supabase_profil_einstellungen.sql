-- =====================================================
-- PROFIL: generische UI-Einstellungen (kontogebunden, geräteübergreifend)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- ZWECK: UI-Präferenzen, die dem NUTZER folgen sollen (nicht nur browser-lokal in localStorage):
--   * standard_baum       -> zuletzt als Standard gesetzter Start-Stammbaum
--   * ansicht             -> gespeicherte Baum-Ansicht (standard/kreis/voll/zweig + Parameter)
--   * letzter_baum        -> zuletzt geöffneter Baum (Reload-/Geräte-Wiederherstellung)
--   * mp_snooze           -> "Meine Person"-Hinweis für 24 h weggeklickt (Zeitstempel)
--   * baum_hilfe_gesehen  -> Baum-Hilfe-Hinweis einmalig gesehen
-- als EINE generische jsonb-Spalte -> erweiterbar OHNE weitere Schema-Änderungen.
--
-- Das Frontend spiegelt diese Werte beim Login in die bestehenden localStorage-Keys (schneller
-- lokaler Cache) und schreibt Änderungen in BEIDE. profile.einstellungen ist die Quelle der
-- Wahrheit; ohne Login bleibt reines localStorage. RLS: nur die EIGENE Profilzeile (unverändert).
--
-- KEIN Karten-Sync-Aufwand: der Trigger profile_sync_to_personen ignoriert Nicht-Karten-Felder
-- (nur vorname/nachname/... lösen einen Karten-Sync aus) -> einstellungen-Writes sind billig.
-- =====================================================

ALTER TABLE public.profile
  ADD COLUMN IF NOT EXISTS einstellungen jsonb NOT NULL DEFAULT '{}'::jsonb;

NOTIFY pgrst, 'reload schema';

SELECT 'OK: profile.einstellungen (jsonb) angelegt' AS status;
