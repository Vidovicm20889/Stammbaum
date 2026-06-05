-- =====================================================
-- VOLL-RESTORE auf den Pre-Merge-Stand (aus bak_merge_*)
-- Ausführen in: Supabase -> SQL Editor (komplett markieren -> Run).
-- Macht ALLE fehlerhaften Merges rückgängig: gelöschte Karten (u. a. Gordana in
-- Vidović/Pisarević) kommen zurück, doppelte Vater-Kante verschwindet.
--
-- SICHER: 1) Snapshot des AKTUELLEN Stands (bak_pre_restore_*) als Rückweg.
--         2) Restore in EINER Transaktion (bei Fehler -> automatischer Rollback).
--         3) Personen werden nur ergänzt/aktualisiert (nie gelöscht) -> keine FK-Brüche
--            (event_teilnehmer/Konten bleiben gültig). Beziehungen werden ersetzt.
-- HINWEIS: familien.verbund_id wird NICHT verändert (kein Backup davon) -> die Bäume
--          bleiben wie aktuell im selben Verbund sichtbar. Das ist unkritisch.
-- =====================================================

-- 0) Sicherheits-Snapshot des AKTUELLEN Stands (falls wir doch zurück wollen)
DROP TABLE IF EXISTS public.bak_pre_restore_personen;
DROP TABLE IF EXISTS public.bak_pre_restore_beziehungen;
CREATE TABLE public.bak_pre_restore_personen    AS SELECT * FROM public.personen;
CREATE TABLE public.bak_pre_restore_beziehungen AS SELECT * FROM public.beziehungen;

BEGIN;

-- 1) Beziehungen leeren (kein eingehender FK auf beziehungen)
DELETE FROM public.beziehungen;

-- 2) Im Backup vorhandene, aktuell FEHLENDE Personen wieder einspielen (die gemergten Karten)
INSERT INTO public.personen
SELECT * FROM public.bak_merge_personen b
WHERE NOT EXISTS (SELECT 1 FROM public.personen p WHERE p.id = b.id);

-- 3) Noch vorhandene (überlebende) Personen auf den Backup-Stand zurücksetzen
UPDATE public.personen p SET
  familie_id      = b.familie_id,
  stammbaum_id    = b.stammbaum_id,
  externe_id      = b.externe_id,
  vorname         = b.vorname,
  nachname        = b.nachname,
  geburtsdatum    = b.geburtsdatum,
  sterbedatum     = b.sterbedatum,
  geschlecht      = b.geschlecht,
  notizen         = b.notizen,
  stammbaum_daten = b.stammbaum_daten,
  user_id         = b.user_id,
  pos_x           = b.pos_x,
  pos_y           = b.pos_y
FROM public.bak_merge_personen b
WHERE p.id = b.id;

-- 4) Beziehungen aus dem Backup wieder einspielen
INSERT INTO public.beziehungen SELECT * FROM public.bak_merge_beziehungen;

COMMIT;

-- 5) Kontrolle (sollte 242 / 387 ergeben)
SELECT (SELECT count(*) FROM public.personen)    AS personen_jetzt,
       (SELECT count(*) FROM public.beziehungen) AS beziehungen_jetzt;

-- 6) Kontrolle Gordana: jetzt wieder als Karte in Vidović/Pisarević vorhanden?
SELECT trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS person,
       s.name AS baum
FROM public.personen pe
LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
WHERE pe.vorname ILIKE 'Gord%'
ORDER BY baum;
