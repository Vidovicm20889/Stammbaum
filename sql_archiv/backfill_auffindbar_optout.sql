-- =====================================================
-- EINMALIGER BACKFILL: Opt-in -> Opt-out für die verbundübergreifende Auffindbarkeit (v13.9)
-- NUR EINMAL ausführen (NICHT Teil des idempotenten Neuaufbaus -> liegt bewusst in sql_archiv).
--
-- Hintergrund: In der Opt-in-Ära war profile.auffindbar_extern für ALLE Konten false
-- (alter Default). Beim Umstieg auf Opt-out (Default true) sollen die BESTEHENDEN Konten
-- ebenfalls auffindbar werden. Da bis jetzt niemand bewusst "false" gewählt hat, ist das
-- pauschale Setzen auf true hier korrekt.
--
-- WICHTIG: NICHT erneut ausführen, sobald Nutzer angefangen haben, sich aktiv zu verstecken
-- (sonst würden deren bewusste Opt-outs wieder auf true gesetzt). Der idempotente
-- supabase_auffindbarkeit.sql setzt nur den Spalten-DEFAULT, NICHT die Bestandszeilen.
-- =====================================================

UPDATE public.profile
SET auffindbar_extern = true
WHERE auffindbar_extern = false;

SELECT count(*) AS jetzt_auffindbar
FROM public.profile
WHERE auffindbar_extern = true;
