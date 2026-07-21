-- ============================================================================
-- SCRUM-9 — „Im Baum anzeigen" (erzwungene Sichtbarkeit) ENTFERNEN
-- ----------------------------------------------------------------------------
-- Gegenstück zu supabase_baum_sichtbarkeit.sql (liegt jetzt in sql_archiv/).
-- Die Funktion entfällt zusammen mit den beiden Karten-Leisten unter dem Baum:
-- der Tabla-Modus zeigt ohnehin ALLE Karten des Baums, damit war der Render-Override
-- „diese Karte erzwungen einblenden" gegenstandslos.
--
-- ⚠️ DEPLOY-REIHENFOLGE: ERST das Frontend ausrollen, DANN dieses Skript ausführen.
--    Umgekehrt würde eine noch laufende alte Frontend-Version beim Laden auf
--    baum_sichtbarkeit bzw. karte_sichtbar_setzen zugreifen und Fehler werfen.
--
-- ⚠️ DATENVERLUST: Bereits gesetzte „Im Baum anzeigen"-Einträge gehen verloren.
--    Fachlich ohne Folge (die Funktion entfällt). Wer sie sichern will, zieht VORHER:
--      SELECT * FROM public.baum_sichtbarkeit;
--
-- Idempotent (mehrfaches Ausführen wirft keinen Fehler).
-- FK-sichere Reihenfolge: RPC -> Policies -> Tabelle.
-- Im Supabase SQL-Editor ausführen (keine CLI — Citrix-Firewall).
-- ============================================================================

-- 1) RPC zuerst: sie referenziert die Tabelle. Beide Signaturen abdecken (DEFAULT-Parameter).
DROP FUNCTION IF EXISTS public.karte_sichtbar_setzen(uuid, boolean);
DROP FUNCTION IF EXISTS public.karte_sichtbar_setzen(uuid);

-- 2) Policies vor der Tabelle (DROP TABLE nähme sie zwar mit, aber explizit ist nachvollziehbar
--    und bleibt idempotent, falls die Tabelle bereits weg ist).
DROP POLICY IF EXISTS "bs_select" ON public.baum_sichtbarkeit;
DROP POLICY IF EXISTS "bs_write"  ON public.baum_sichtbarkeit;

-- 3) Tabelle. Kein CASCADE nötig: auf baum_sichtbarkeit zeigt nichts — ihre FKs gehen
--    ausgehend auf stammbaeume/personen/familien/auth.users, nicht umgekehrt.
DROP TABLE IF EXISTS public.baum_sichtbarkeit;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_baum_sichtbarkeit_entfernen.sql ausgeführt — RPC, Policies und Tabelle entfernt' AS status;
