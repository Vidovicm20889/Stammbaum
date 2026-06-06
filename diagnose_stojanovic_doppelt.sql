-- ===============================================================
-- DIAGNOSE (NUR LESEN, ändert NICHTS) — zwei Bäume namens "Stojanović"
-- Klärt: dieselbe Linie (→ mergen) oder zwei echte Familien (→ umbenennen)?
-- ===============================================================

-- 1) Die beiden Bäume + Familie/Verbund/Owner/Personenzahl nebeneinander
SELECT s.id AS stammbaum_id, s.name AS baum, coalesce(s.aktiv,true) AS aktiv,
       f.id AS familie_id, f.name AS familie, f.verbund_id,
       (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen,
       (SELECT u.email FROM public.mitgliedschaften m
          JOIN auth.users u ON u.id = m.user_id
         WHERE m.familie_id = f.id AND m.rolle = 'familien_owner' AND m.aktiv
         LIMIT 1) AS owner_email
FROM public.stammbaeume s
LEFT JOIN public.familien f ON f.id = s.familie_id
WHERE public.merge_norm(s.name) = public.merge_norm('Stojanović')
ORDER BY personen DESC;

-- 2) Personen in BEIDEN Bäumen (zum Vergleich, wer wo liegt + identitaet_id-Brücken)
SELECT s.name AS baum, s.id AS stammbaum_id,
       pe.vorname, pe.nachname, pe.identitaet_id, pe.user_id
FROM public.personen pe
JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
WHERE public.merge_norm(s.name) = public.merge_norm('Stojanović')
ORDER BY s.name, pe.nachname, pe.vorname;

-- 3) Teilen sich die beiden Bäume Personen über identitaet_id? (gleiche reale Person)
--    Treffer = es ist dieselbe Linie/Verbund (starker Hinweis auf "mergen")
SELECT a.identitaet_id,
       a.vorname || ' ' || a.nachname AS person,
       sa.name AS baum_a, sb.name AS baum_b
FROM public.personen a
JOIN public.personen b
  ON b.identitaet_id = a.identitaet_id AND b.stammbaum_id <> a.stammbaum_id
JOIN public.stammbaeume sa ON sa.id = a.stammbaum_id
JOIN public.stammbaeume sb ON sb.id = b.stammbaum_id
WHERE a.identitaet_id IS NOT NULL
  AND public.merge_norm(sa.name) = public.merge_norm('Stojanović')
  AND public.merge_norm(sb.name) = public.merge_norm('Stojanović')
ORDER BY person;
