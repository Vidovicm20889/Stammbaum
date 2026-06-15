-- =====================================================
-- AUFFINDBARKEIT / VERBUNDÜBERGREIFENDE DISCOVERY (Stufe 1 von 3)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT (mehrfach ausführbar).
--
-- TEIL DES FEATURES "verbundübergreifende Personensuche + Kontaktanfragen" (Instagram-Prinzip).
-- Diese Datei deckt NUR Stufe 1 ab (ENTDECKEN). Kontakt (Stufe 2) und Baumzugriff (Stufe 3)
-- liegen in supabase_kontakt_anfragen.sql / supabase_baum_freigaben_rls.sql.
--
-- SICHERHEITSKRITISCH: Dies ist EINE der genau ZWEI Stellen, an denen die verbund_id-Isolation
-- bewusst und kontrolliert durchbrochen wird. Der Bruch ist VOLLSTÄNDIG in der RPC
-- personen_entdecken() gekapselt — die RLS-SELECT-Policy auf personen bleibt UNVERÄNDERT.
-- Die RPC gibt verbundübergreifend AUSSCHLIESSLICH vier Minimalfelder zurück:
--   { person_id, name, familienname, avatar_url }
-- KEINE Daten, KEINE Beziehungen, KEINE Bäume, KEINE Geburts-/Sterbedaten.
--
-- DATENSCHUTZ-REGEL (vom Betreiber bestätigt):
--   Eine Karte erscheint verbundübergreifend NUR, wenn:
--   1) ihr verbund_id NICHT zu den eigenen Verbünden gehört (eigener Verbund -> normale Suche),
--   2) sie NICHT (lebend-)minderjährig ist (HARTES Tor),
--   3) UND ( VERSTORBEN  und Baum nicht opt-out und Karte nicht einzeln ausgeblendet )
--      ODER ( LEBEND und BEWEISBAR volljährig (ISO-Geburtsdatum, Alter>=18)
--             und Konto-Opt-in profile.auffindbar_extern=true auf der via user_id verknüpften Karte ).
--   - Lebend + Alter NICHT berechenbar (Datum fehlt/Freitext) -> AUSGESCHLOSSEN (Volljährigkeit
--     nicht beweisbar). Dokumentierte Folge: erwachsene Lebende ohne ISO-Geburtsdatum sind erst
--     auffindbar, wenn ein Datum gepflegt ist.
--   - INTERPRETATION (dokumentiert): Der Minderjährigen-Schutz gilt für LEBENDE Personen
--     (heute lebende Kinder). Eine vor langer Zeit jung verstorbene Person ist kein "lebender
--     Minderjähriger" und fällt unter die Verstorbenen-Regel. Bei Bedarf hier verschärfbar.
--   - Avatar erscheint nur bei NEUER Sichtbarkeits-Stufe 'oeffentlich' (lebende Konten) bzw.
--     als Karten-Foto bei verstorbenen Karten (Teil der Verstorbenen-Freigabe).
--
-- STEUERUNG:
--   - LEBENDE: profile.auffindbar_extern (Default false = striktes Opt-in; nur das Konto selbst).
--   - VERSTORBENE: Default auffindbar; Admin-Opt-out je Baum
--     (stammbaeume.einstellungen->>'discovery_verstorbene' = 'false') ODER je Karte
--     (stammbaum_daten->>'nicht_auffindbar' = 'true').
--
-- Voraussetzungen: supabase_verbund.sql (verbund_id, sieht_familie, ist_super_admin),
--   supabase_profile.sql (profile, avatar_sichtbarkeit), supabase_merge_gui.sql (merge_norm),
--   supabase_multitree_phase5.sql / supabase_familie_einstellungen.sql (stammbaeume.einstellungen).
-- =====================================================


-- =====================================================
-- 1) SCHEMA-ERWEITERUNGEN
-- =====================================================

-- 1a) Konto-Opt-in für lebende Personen (nur das Konto selbst steuert es). Default false.
ALTER TABLE public.profile
  ADD COLUMN IF NOT EXISTS auffindbar_extern boolean NOT NULL DEFAULT false;

-- 1b) Neue Avatar-Sichtbarkeits-Stufe 'oeffentlich' (für die verbundübergreifende Discovery).
--     Die alte CHECK-Constraint (verbund/familie/privat) wird ersetzt.
ALTER TABLE public.profile DROP CONSTRAINT IF EXISTS profile_avatar_sichtbarkeit_check;
ALTER TABLE public.profile
  ADD CONSTRAINT profile_avatar_sichtbarkeit_check
  CHECK (avatar_sichtbarkeit IN ('verbund', 'familie', 'privat', 'oeffentlich'));


-- =====================================================
-- 2) HELFER: Alter aus ISO-Datum (STABLE — age() bezieht sich auf das aktuelle Datum)
--    Liefert NULL, wenn das Datum nicht als ISO YYYY-MM-DD parsebar ist (CASE -> kein Cast,
--    daher kein 22008-Fehler bei Freitext-Altwerten).
-- =====================================================
CREATE OR REPLACE FUNCTION public._alter_jahre(p_iso text)
RETURNS int LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT CASE
    WHEN p_iso ~ '^\d{4}-\d{2}-\d{2}$'
    THEN extract(year from age(p_iso::date))::int
  END;
$$;


-- =====================================================
-- 3) EIGNUNGS-HELFER: Ist EINE Karte für den AUFRUFER verbundübergreifend entdeckbar?
--    EINZIGE QUELLE DER WAHRHEIT für die Discovery-Regel — wird von personen_entdecken()
--    UND von kontakt_anfrage_stellen() (Stufe 2) genutzt, damit niemand per RPC eine NICHT
--    entdeckbare (lebende/minderjährige/nicht-opt-in) Person kontaktieren kann.
--    DEFINER, da fremde personen/profile/stammbaeume-Zeilen per RLS nicht direkt lesbar sind.
-- =====================================================
CREATE OR REPLACE FUNCTION public._person_entdeckbar(p_person uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.personen pe
    JOIN public.familien f    ON f.id = pe.familie_id
    JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
    LEFT JOIN public.profile pr ON pr.user_id = pe.user_id
    WHERE pe.id = p_person
      -- (1) FREMDER Verbund (eigener Verbund läuft über die normale personen_suche).
      --     verbund_id ist NOT NULL -> kein NULL-Problem mit NOT IN.
      AND f.verbund_id NOT IN (
        SELECT fm.verbund_id
        FROM public.mitgliedschaften m
        JOIN public.familien fm ON fm.id = m.familie_id
        WHERE m.user_id = auth.uid()
      )
      -- Platzhalter-Karten nie auffindbar
      AND coalesce(pe.stammbaum_daten->>'platzhalter','') <> 'true'
      -- (2)+(3) Auffindbarkeits-Regel
      AND (
        CASE
          -- VERSTORBEN -> Default auffindbar, sofern Baum nicht opt-out und Karte nicht ausgeblendet
          WHEN ( lower(coalesce(pe.stammbaum_daten->>'deceased','')) = 'true'
                 OR coalesce(btrim(pe.stammbaum_daten->>'death_date'),'') <> '' )
            THEN coalesce(s.einstellungen->>'discovery_verstorbene','true') <> 'false'
                 AND coalesce(pe.stammbaum_daten->>'nicht_auffindbar','') <> 'true'
          -- LEBEND -> nur BEWEISBAR volljährig (ISO-Datum, Alter>=18) UND Konto-Opt-in.
          --          Alter nicht berechenbar -> -1 -> ausgeschlossen (Minderjährigen-Schutz).
          ELSE coalesce(public._alter_jahre(nullif(btrim(pe.stammbaum_daten->>'birth_date'),'')), -1) >= 18
               AND pe.user_id IS NOT NULL
               AND coalesce(pr.auffindbar_extern, false) = true
        END
      )
  );
$$;


-- =====================================================
-- 4) DISCOVERY-RPC (SECURITY DEFINER — kontrollierter, gekapselter Isolations-Bruch)
--    Gibt verbundübergreifend NUR { person_id, name, familienname, avatar_url } zurück.
-- =====================================================
DROP FUNCTION IF EXISTS public.personen_entdecken(text, int);
CREATE OR REPLACE FUNCTION public.personen_entdecken(p_query text, p_limit int DEFAULT 30)
RETURNS TABLE(
  person_id    uuid,
  name         text,
  familienname text,
  avatar_url   text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH q AS (
    SELECT nullif(public.merge_norm(p_query), '') AS qn
  )
  SELECT
    pe.id AS person_id,
    nullif(btrim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')), '') AS name,
    f.name AS familienname,
    CASE
      -- Lebendes Konto: Avatar nur bei ausdrücklicher Stufe 'oeffentlich'
      WHEN pe.user_id IS NOT NULL AND pr.avatar_sichtbarkeit = 'oeffentlich'
        THEN coalesce(pr.avatar_thumb_url, pr.avatar_url)
      -- Verstorbene Karte (kein Konto): Karten-Foto im Rahmen der Verstorbenen-Freigabe
      WHEN (lower(coalesce(pe.stammbaum_daten->>'deceased','')) = 'true'
            OR coalesce(btrim(pe.stammbaum_daten->>'death_date'),'') <> '')
        THEN nullif(coalesce(pe.stammbaum_daten->>'foto',
                             pe.stammbaum_daten->>'avatar',
                             pe.stammbaum_daten->>'bild'), '')
      ELSE NULL
    END AS avatar_url
  FROM public.personen pe
  JOIN public.familien f      ON f.id = pe.familie_id
  LEFT JOIN public.profile pr ON pr.user_id = pe.user_id
  CROSS JOIN q
  WHERE q.qn IS NOT NULL
    AND length(q.qn) >= 2
    -- Namens-Match (Präfix je Feld ODER Teilstring über den ganzen Namen)
    AND (
         public.merge_norm(coalesce(pe.vorname,''))  LIKE q.qn || '%'
      OR public.merge_norm(coalesce(pe.nachname,'')) LIKE q.qn || '%'
      OR public.merge_norm(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) LIKE '%' || q.qn || '%'
    )
    -- Datenschutz-/Eignungsregel (fremder Verbund + lebend/minderjährig/opt-in) zentral im Helfer
    AND public._person_entdeckbar(pe.id)
  ORDER BY pe.nachname, pe.vorname
  LIMIT greatest(1, least(coalesce(p_limit, 30), 50));
$$;
GRANT EXECUTE ON FUNCTION public.personen_entdecken(text, int) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_auffindbarkeit.sql ausgeführt — profile.auffindbar_extern + Avatar-Stufe oeffentlich + personen_entdecken (Discovery, 4 Minimalfelder)' AS status;
