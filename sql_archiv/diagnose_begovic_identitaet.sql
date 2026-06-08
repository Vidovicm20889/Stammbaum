-- =====================================================
-- DIAGNOSE (NUR LESEN) — identitaet_id der Begović-Linien-Karten
-- Ausführen in: Supabase -> SQL-Editor -> Run. Ändert NICHTS.
-- Zweck: Sind die Doppelkarten (Mirsad ×2, Mirsada ×2, Gordana ×3) echte
-- identitaet_id-Zwillinge (Spiegel) oder unverknüpfte Duplikate? Ergebnis hier
-- zurückgeben, dann gebe ich den Mirror-Schritt (supabase_zweig_begovic.sql) frei.
-- =====================================================
SELECT coalesce(jsonb_agg(t ORDER BY t.nachname, t.vorname, t.baum), '[]') AS begovic_identitaet
FROM (
  SELECT pe.vorname, pe.nachname, s.name AS baum, pe.id, pe.identitaet_id
  FROM public.personen pe
  LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  WHERE pe.id IN (
    '7d12816e-cd27-40a3-a710-c717edf5a3e1', -- Desanka (Pisarević)
    '3ef5b6e0-d805-400d-8592-cb98755a8889', -- Halid (Pisarević)
    '7c57001a-0337-4bb4-b9ae-9dcf2cc7ab49', -- Mićo Vidović
    'd1a986b5-c57e-433a-a177-f3bfe5830dc0', -- Mirsad (Vidović)
    '45e879e7-e14a-460b-824d-a3c1451b2841', -- Mirsad (Pisarević)
    'd488b914-4ae7-4329-93c0-7ee7535ffcd3', -- Mirsada (Pisarević)
    '75e898fb-e483-4dee-ba50-a60d1b3485a3', -- Mirsada (Stojanović)
    'd6dc86d0-a129-4d05-945a-66f18fc0c927', -- Gordana (Vidović)
    'bab6cec0-080b-453b-a4ec-7308fca30e3f', -- Gordana (Pisarević)
    '4ceaf37c-52e6-441b-a712-2a43c9ff005d', -- Gordana (Dujković)
    '9dff56df-3e42-4dfb-a1ef-7b976d5ee4c5'  -- Đoja Pisarević
  )
) t;
