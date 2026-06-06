-- =====================================================
-- DATENKORREKTUR Begović-Linie (VOR supabase_zweig_begovic.sql ausführen!)
-- Ausführen in: Supabase -> SQL-Editor. IDEMPOTENT (zweiter Lauf macht nichts mehr).
--
-- BESTÄTIGTER SACHVERHALT (vom Nutzer):
--   * Das echte Paar ist HALID Begović ⚭ DESANKA (née Pisarević). Die Ehe-Kante FEHLT
--     in den Daten -> wird ergänzt.
--   * Die Ehe-Kante Mićo Vidović ⚭ Desanka ist FALSCH (Mirror-Artefakt) -> wird entfernt.
--   * Mirsad Begović hat fälschlich DREI Eltern (Halid + Desanka + Mićo Vidović). Echter
--     Vater = Halid -> Mićo Vidović wird als Elternteil von Mirsad entfernt (alle Karten).
--
-- Halid (3ef5b6e0…) und Desanka (7d12816e…) liegen im Pisarević-Baum (gleiche Familie).
-- Mirsad existiert als zwei Karten (Vidović d1a986b5…, Pisarević 45e879e7…); BEIDE behalten
-- Halid + Desanka als Eltern (diese Kanten existieren bereits) — nur Mićo wird gelöst.
-- =====================================================


-- ===============================================================
-- TEIL 0 — VORSCHAU (ändert NICHTS)
-- ===============================================================
-- a) Die FALSCHEN Kanten, die entfernt werden
SELECT 'WIRD ENTFERNT' AS aktion, b.typ,
       a.vorname||' '||a.nachname AS person_a, c.vorname||' '||c.nachname AS person_b,
       sa.name AS baum_a, sc.name AS baum_b
FROM public.beziehungen b
JOIN public.personen a ON a.id = b.person_a
JOIN public.personen c ON c.id = b.person_b
LEFT JOIN public.stammbaeume sa ON sa.id = a.stammbaum_id
LEFT JOIN public.stammbaeume sc ON sc.id = c.stammbaum_id
WHERE
  -- Ehe Mićo ⚭ Desanka (beide Richtungen)
  ( b.typ='ehepartner'
    AND ((b.person_a='7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49' AND b.person_b='7d12816e-cd27-40a3-a710-c717edf5a3e1')
      OR (b.person_a='7d12816e-cd27-40a3-a710-c717edf5a3e1' AND b.person_b='7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49')) )
  OR
  -- Mićo als Elternteil von (irgendeiner) Mirsad-Begović-Karte
  ( b.typ='elternteil' AND b.person_a='7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49'
    AND b.person_b IN (SELECT id FROM public.personen
                        WHERE public.merge_norm(vorname)=public.merge_norm('Mirsad')
                          AND public.merge_norm(nachname)=public.merge_norm('Begović')) );

-- b) Fehlt die Ehe Halid ⚭ Desanka? (true = wird ergänzt)
SELECT NOT EXISTS (
  SELECT 1 FROM public.beziehungen
   WHERE typ='ehepartner'
     AND ((person_a='3ef5b6e0-d805-400d-8592-cb98755a8889' AND person_b='7d12816e-cd27-40a3-a710-c717edf5a3e1')
       OR (person_a='7d12816e-cd27-40a3-a710-c717edf5a3e1' AND person_b='3ef5b6e0-d805-400d-8592-cb98755a8889'))
) AS halid_desanka_ehe_fehlt;


-- ===============================================================
-- TEIL 1 — BACKUP der zu löschenden Kanten (für Rollback)
-- ===============================================================
DROP TABLE IF EXISTS public.bak_fix_begovic_beziehungen;
CREATE TABLE public.bak_fix_begovic_beziehungen AS
SELECT b.* FROM public.beziehungen b
WHERE
  ( b.typ='ehepartner'
    AND ((b.person_a='7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49' AND b.person_b='7d12816e-cd27-40a3-a710-c717edf5a3e1')
      OR (b.person_a='7d12816e-cd27-40a3-a710-c717edf5a3e1' AND b.person_b='7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49')) )
  OR
  ( b.typ='elternteil' AND b.person_a='7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49'
    AND b.person_b IN (SELECT id FROM public.personen
                        WHERE public.merge_norm(vorname)=public.merge_norm('Mirsad')
                          AND public.merge_norm(nachname)=public.merge_norm('Begović')) );

SELECT 'Backup: ' || count(*) || ' zu löschende Kante(n) gesichert' AS status
FROM public.bak_fix_begovic_beziehungen;


-- ===============================================================
-- TEIL 2 — DURCHFÜHREN
-- ===============================================================
DO $$
DECLARE
  v_halid   uuid := '3ef5b6e0-d805-400d-8592-cb98755a8889';
  v_desanka uuid := '7d12816e-cd27-40a3-a710-c717edf5a3e1';
  v_mico    uuid := '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49';
  v_fam     uuid;
  v_del_ehe int;
  v_del_elt int;
  v_add     int := 0;
BEGIN
  -- Plausibilität: existieren Halid & Desanka noch?
  SELECT familie_id INTO v_fam FROM public.personen WHERE id = v_halid;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Halid (%) nicht gefunden — IDs prüfen.', v_halid; END IF;

  -- 1) Falsche Ehe Mićo ⚭ Desanka entfernen (beide Richtungen)
  DELETE FROM public.beziehungen
   WHERE typ='ehepartner'
     AND ((person_a=v_mico AND person_b=v_desanka) OR (person_a=v_desanka AND person_b=v_mico));
  GET DIAGNOSTICS v_del_ehe = ROW_COUNT;

  -- 2) Mićo als Elternteil JEDER Mirsad-Begović-Karte entfernen
  DELETE FROM public.beziehungen
   WHERE typ='elternteil' AND person_a=v_mico
     AND person_b IN (SELECT id FROM public.personen
                       WHERE public.merge_norm(vorname)=public.merge_norm('Mirsad')
                         AND public.merge_norm(nachname)=public.merge_norm('Begović'));
  GET DIAGNOSTICS v_del_elt = ROW_COUNT;

  -- 3) Echte Ehe Halid ⚭ Desanka ergänzen (idempotent, gleiche Familie)
  IF NOT EXISTS (
    SELECT 1 FROM public.beziehungen
     WHERE typ='ehepartner'
       AND ((person_a=v_halid AND person_b=v_desanka) OR (person_a=v_desanka AND person_b=v_halid))
  ) THEN
    INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
    VALUES (v_fam, v_halid, v_desanka, 'ehepartner');
    v_add := 1;
  END IF;

  RAISE NOTICE 'Fix Begović: % falsche Ehe-Kante(n), % falsche Eltern-Kante(n) entfernt; % Halid⚭Desanka ergänzt.',
    v_del_ehe, v_del_elt, v_add;
END $$;


-- ===============================================================
-- TEIL 3 — KONTROLLE
-- ===============================================================
-- a) Eltern von Mirsad Begović (sollte nur noch Halid + Desanka sein, je Karte)
SELECT mk.vorname||' '||mk.nachname AS mirsad, smk.name AS mirsad_baum,
       el.vorname||' '||el.nachname AS elternteil, sel.name AS elternteil_baum
FROM public.beziehungen b
JOIN public.personen mk ON mk.id = b.person_b
JOIN public.personen el ON el.id = b.person_a
LEFT JOIN public.stammbaeume smk ON smk.id = mk.stammbaum_id
LEFT JOIN public.stammbaeume sel ON sel.id = el.stammbaum_id
WHERE b.typ='elternteil'
  AND public.merge_norm(mk.vorname)=public.merge_norm('Mirsad')
  AND public.merge_norm(mk.nachname)=public.merge_norm('Begović')
ORDER BY mirsad_baum, elternteil;

-- b) Ehepartner von Halid und von Desanka
SELECT p.vorname||' '||p.nachname AS person,
       q.vorname||' '||q.nachname AS ehepartner
FROM public.beziehungen b
JOIN public.personen p ON p.id = b.person_a
JOIN public.personen q ON q.id = b.person_b
WHERE b.typ='ehepartner'
  AND (b.person_a IN ('3ef5b6e0-d805-400d-8592-cb98755a8889','7d12816e-cd27-40a3-a710-c717edf5a3e1')
    OR b.person_b IN ('3ef5b6e0-d805-400d-8592-cb98755a8889','7d12816e-cd27-40a3-a710-c717edf5a3e1'));


-- ===============================================================
-- TEIL 4 — ROLLBACK (nur bei Bedarf; Block einkommentieren)
-- Stellt die gelöschten Kanten wieder her und entfernt die ergänzte Halid⚭Desanka-Ehe.
-- ===============================================================
-- INSERT INTO public.beziehungen
--   SELECT * FROM public.bak_fix_begovic_beziehungen b
--   WHERE NOT EXISTS (SELECT 1 FROM public.beziehungen z WHERE z.id = b.id);
-- DELETE FROM public.beziehungen
--  WHERE typ='ehepartner'
--    AND ((person_a='3ef5b6e0-d805-400d-8592-cb98755a8889' AND person_b='7d12816e-cd27-40a3-a710-c717edf5a3e1')
--      OR (person_a='7d12816e-cd27-40a3-a710-c717edf5a3e1' AND person_b='3ef5b6e0-d805-400d-8592-cb98755a8889'));
-- SELECT 'Rollback ausgeführt' AS status;
