-- =====================================================
-- DIAGNOSE: Warum erscheint "Bastian" NICHT in der verbundübergreifenden Suche?
-- Einmal-/Diagnose-Skript (gehört NICHT zum Neuaufbau). Im Supabase SQL-Editor ausführen.
-- Passe den Suchbegriff (:q) und deine Login-E-Mail (:email) unten an.
-- Zeigt je Treffer-Karte, welches Discovery-Tor scheitert (TRUE = erfüllt = OK).
-- =====================================================

WITH params AS (
  SELECT
    'bastian'::text                              AS q,        -- Suchbegriff (klein, ohne Diakritika ok)
    'milan_vidovic89@hotmail.com'::text          AS email     -- DEIN Login (= Aufrufer)
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
SELECT
  pe.id                                                        AS person_id,
  btrim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) AS name,
  f.name                                                       AS familie,
  f.verbund_id,
  -- TOR 1: fremder Verbund?  (TRUE = OK / fremd; FALSE = eigener Verbund -> ausgeblendet)
  (f.verbund_id NOT IN (SELECT verbund_id FROM caller_verbuende)) AS tor1_fremder_verbund,
  -- Status der Karte
  (lower(coalesce(pe.stammbaum_daten->>'deceased','')) = 'true'
     OR coalesce(btrim(pe.stammbaum_daten->>'death_date'),'') <> '') AS ist_verstorben,
  pe.stammbaum_daten->>'birth_date'                           AS birth_date,
  public._alter_jahre(nullif(btrim(pe.stammbaum_daten->>'birth_date'),'')) AS alter_jahre,
  (pe.user_id IS NOT NULL)                                    AS hat_konto,
  pr.auffindbar_extern                                        AS opt_in_auffindbar,
  s.einstellungen->>'discovery_verstorbene'                   AS baum_discovery_verstorbene,
  pe.stammbaum_daten->>'nicht_auffindbar'                     AS karte_ausgeblendet,
  coalesce(pe.stammbaum_daten->>'platzhalter','')             AS platzhalter,
  -- ENDERGEBNIS: liefert die echte RPC-Eignung (nutzt auth.uid() -> hier ggf. NULL,
  -- daher nur als Referenz; die Spalten oben sind die verlässliche Erklärung):
  public._person_entdeckbar(pe.id)                            AS rpc_entdeckbar
FROM public.personen pe
JOIN public.familien f      ON f.id = pe.familie_id
JOIN public.stammbaeume s   ON s.id = pe.stammbaum_id
LEFT JOIN public.profile pr ON pr.user_id = pe.user_id
CROSS JOIN params p
WHERE public.merge_norm(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) LIKE '%' || public.merge_norm(p.q) || '%'
ORDER BY f.name, name;
