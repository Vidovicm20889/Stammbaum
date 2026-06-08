-- =====================================================
-- VOLL-RESTORE v2 — mit Baum-Remapping (gelöschte Backup-Bäume -> heutige ids)
-- Ausführen in: Supabase -> SQL Editor (komplett markieren -> Run).
--
-- Remapping (alte, gelöschte Baum-id  ->  heutiger Baum + dessen Familie):
--   43cf707a… (alt Pisarević) -> Baum ddf1b02a… , Familie d7b0a657…
--   5ec4dd7c… (alt Dujković)  -> Baum e7b1f4a7… , Familie 4e1e75d6…
--
-- SICHER: Snapshot des aktuellen Stands (bak_pre_restore_*) + Transaktion (Rollback bei Fehler).
-- Personen werden nur ergänzt/aktualisiert (nie gelöscht); Beziehungen werden ersetzt.
-- =====================================================

-- 0) Sicherheits-Snapshot des AKTUELLEN Stands (Rückweg)
DROP TABLE IF EXISTS public.bak_pre_restore_personen;
DROP TABLE IF EXISTS public.bak_pre_restore_beziehungen;
CREATE TABLE public.bak_pre_restore_personen    AS SELECT * FROM public.personen;
CREATE TABLE public.bak_pre_restore_beziehungen AS SELECT * FROM public.beziehungen;

BEGIN;

-- 1) Korrigierte Kopie des Personen-Backups (gelöschte Baum-ids umbiegen)
CREATE TEMP TABLE bak_fix ON COMMIT DROP AS SELECT * FROM public.bak_merge_personen;
UPDATE bak_fix SET stammbaum_id = 'ddf1b02a-b01c-4a7f-9267-0a9ff9659d42',
                   familie_id   = 'd7b0a657-6233-4d0e-8c31-68c0125a8f9d'
 WHERE stammbaum_id = '43cf707a-d360-4849-b881-9f5f19232bf1';
UPDATE bak_fix SET stammbaum_id = 'e7b1f4a7-5d8e-4247-a620-b7cc07c680fc',
                   familie_id   = '4e1e75d6-1fbf-4131-acda-94519f3d2334'
 WHERE stammbaum_id = '5ec4dd7c-5e36-441b-8de4-767c48b54d20';

-- 2) Beziehungen leeren (kein eingehender FK auf beziehungen)
DELETE FROM public.beziehungen;

-- 3) Im Backup vorhandene, aktuell FEHLENDE Personen wieder einspielen (die gemergten Karten)
INSERT INTO public.personen
SELECT * FROM bak_fix b
WHERE NOT EXISTS (SELECT 1 FROM public.personen p WHERE p.id = b.id);

-- 4) Noch vorhandene (überlebende) Personen auf den Backup-Stand zurücksetzen
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
FROM bak_fix b
WHERE p.id = b.id;

-- 5) Beziehungen aus dem Backup wieder einspielen.
--    (Beziehungen, die nur die zwei gelöschten Bäume betrafen, hängen über familie_id —
--     die Familien existieren weiterhin, daher FK-sicher.)
INSERT INTO public.beziehungen SELECT * FROM public.bak_merge_beziehungen;

COMMIT;

-- 6) Kontrolle (sollte 242 / 387 ergeben)
SELECT (SELECT count(*) FROM public.personen)    AS personen_jetzt,
       (SELECT count(*) FROM public.beziehungen) AS beziehungen_jetzt;

-- 7) Kontrolle Gordana: wieder in mehreren Bäumen?
SELECT trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS person, s.name AS baum
FROM public.personen pe
LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
WHERE pe.vorname ILIKE 'Gord%'
ORDER BY baum;
