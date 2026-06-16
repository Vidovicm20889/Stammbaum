-- DIAGNOSE (JSON-Ausgabe): warum erscheint "Bastian" nicht in der Discovery?
-- Eine Zeile JSON je Treffer-Karte. Im Supabase SQL-Editor ausführen.
WITH params AS (
  SELECT 'bastian'::text AS q, 'milan_vidovic89@hotmail.com'::text AS email
),
caller AS (
  SELECT u.id AS uid FROM auth.users u, params p WHERE lower(u.email) = lower(p.email)
),
caller_verbuende AS (
  SELECT DISTINCT fm.verbund_id
  FROM public.mitgliedschaften m
  JOIN public.familien fm ON fm.id = m.familie_id
  JOIN caller c ON c.uid = m.user_id
)
SELECT jsonb_pretty(jsonb_build_object(
  'person_id',            pe.id,
  'name',                 btrim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')),
  'familie',              f.name,
  'verbund_id',           f.verbund_id,
  'tor1_fremder_verbund', (f.verbund_id NOT IN (SELECT verbund_id FROM caller_verbuende)),
  'ist_verstorben',       (lower(coalesce(pe.stammbaum_daten->>'deceased','')) = 'true'
                            OR coalesce(btrim(pe.stammbaum_daten->>'death_date'),'') <> ''),
  'birth_date',           pe.stammbaum_daten->>'birth_date',
  'alter_jahre',          public._alter_jahre(nullif(btrim(pe.stammbaum_daten->>'birth_date'),'')),
  'hat_konto',            (pe.user_id IS NOT NULL),
  'user_id',              pe.user_id,
  'opt_in_auffindbar',    pr.auffindbar_extern,
  'avatar_sichtbarkeit',  pr.avatar_sichtbarkeit,
  'baum_discovery_verstorbene', s.einstellungen->>'discovery_verstorbene',
  'karte_ausgeblendet',   pe.stammbaum_daten->>'nicht_auffindbar',
  'platzhalter',          coalesce(pe.stammbaum_daten->>'platzhalter',''),
  'rpc_entdeckbar',       public._person_entdeckbar(pe.id)
)) AS diagnose_json
FROM public.personen pe
JOIN public.familien f      ON f.id = pe.familie_id
JOIN public.stammbaeume s   ON s.id = pe.stammbaum_id
LEFT JOIN public.profile pr ON pr.user_id = pe.user_id
CROSS JOIN params p
WHERE public.merge_norm(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) LIKE '%' || public.merge_norm(p.q) || '%'
ORDER BY f.name, pe.vorname;
