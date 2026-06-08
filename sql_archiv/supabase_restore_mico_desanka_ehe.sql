-- =====================================================
-- NACHKORREKTUR: Desanka war ZWEIMAL verheiratet — Halid UND Mićo.
-- Ausführen in: Supabase -> SQL-Editor. IDEMPOTENT.
--
-- supabase_fix_begovic_eltern.sql hatte die Ehe Mićo ⚭ Desanka als Artefakt entfernt.
-- Bestätigung des Nutzers: Mićo Vidović ist ein ECHTER (zweiter) Ehemann von Desanka.
-- -> Ehe-Kante Mićo ⚭ Desanka wiederherstellen (Halid ⚭ Desanka bleibt bestehen).
--    Die falschen ELTERN-Kanten (Mićo -> Mirsad) bleiben ENTFERNT (Vater = Halid).
--
-- Voraussetzung: Backup-Tabelle public.bak_fix_begovic_beziehungen aus Schritt 1.
-- (Fallback: direkter Insert per UUID, falls Backup fehlt.)
-- =====================================================

DO $$
DECLARE
  v_mico    uuid := '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49'; -- Mićo Vidović
  v_desanka uuid := '7d12816e-cd27-40a3-a710-c717edf5a3e1'; -- Desanka (Pisarević)
  v_fam     uuid;
  v_n       int := 0;
BEGIN
  -- Schon vorhanden? -> nichts tun (idempotent)
  IF EXISTS (
    SELECT 1 FROM public.beziehungen
     WHERE typ='ehepartner'
       AND ((person_a=v_mico AND person_b=v_desanka) OR (person_a=v_desanka AND person_b=v_mico))
  ) THEN
    RAISE NOTICE 'Mićo ⚭ Desanka existiert bereits — nichts zu tun.';
    RETURN;
  END IF;

  -- 1) Bevorzugt: aus dem Backup zurückspielen (nur die Ehe-Kante, NICHT die Eltern-Kanten)
  IF to_regclass('public.bak_fix_begovic_beziehungen') IS NOT NULL THEN
    INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
    SELECT b.familie_id, b.person_a, b.person_b, b.typ
      FROM public.bak_fix_begovic_beziehungen b
     WHERE b.typ='ehepartner'
       AND ((b.person_a=v_mico AND b.person_b=v_desanka) OR (b.person_a=v_desanka AND b.person_b=v_mico));
    GET DIAGNOSTICS v_n = ROW_COUNT;
  END IF;

  -- 2) Fallback: Backup fehlte/leer -> Kante direkt anlegen (familie_id von Desanka)
  IF v_n = 0 THEN
    SELECT familie_id INTO v_fam FROM public.personen WHERE id = v_desanka;
    INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
    VALUES (v_fam, v_mico, v_desanka, 'ehepartner');
    v_n := 1;
  END IF;

  RAISE NOTICE 'Mićo ⚭ Desanka wiederhergestellt (% Kante). Halid ⚭ Desanka bleibt. Mićo→Mirsad bleibt entfernt.', v_n;
END $$;


-- ---------- KONTROLLE: Desanka sollte jetzt ZWEI Ehepartner haben (Halid + Mićo) ----------
SELECT p.vorname||' '||p.nachname AS person, sp.name AS person_baum,
       q.vorname||' '||q.nachname AS ehepartner, sq.name AS partner_baum
FROM public.beziehungen b
JOIN public.personen p ON p.id = b.person_a
JOIN public.personen q ON q.id = b.person_b
LEFT JOIN public.stammbaeume sp ON sp.id = p.stammbaum_id
LEFT JOIN public.stammbaeume sq ON sq.id = q.stammbaum_id
WHERE b.typ='ehepartner'
  AND (b.person_a='7d12816e-cd27-40a3-a710-c717edf5a3e1'
    OR b.person_b='7d12816e-cd27-40a3-a710-c717edf5a3e1')
ORDER BY ehepartner;
