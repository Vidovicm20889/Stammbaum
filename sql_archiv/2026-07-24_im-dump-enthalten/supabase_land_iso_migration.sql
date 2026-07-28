-- =====================================================
-- LÄNDER -> ISO-CODES (Migration + Helfer)
-- Ausführen in: Supabase -> SQL Editor. Idempotent (mehrfach ausführbar).
--
-- Hintergrund: Das Frontend nutzt jetzt eine zentrale Länder-Komponente
-- (CountrySelector) und speichert ISO-3166-1-alpha-2-Codes (z. B. BA, DE, RS).
-- Diese Migration wandelt bestehende Länder-KLARTEXTE in Codes um:
--   * familien.land            (matching-kritisch: familie_finden_exakt)
--   * personen.stammbaum_daten -> geburtsland, wohnort_land
--   * registrierungs_anfragen.geburtsland (falls vorhanden)
-- Unbekannte/historische Werte (z. B. „Jugoslawien") bleiben unverändert als
-- Freitext erhalten (kein Datenverlust); das Frontend zeigt sie weiter an.
--
-- Voraussetzung: public.merge_norm(text) (ć č š ž đ -> c c s z d, lower, trim).
-- =====================================================

-- merge_norm idempotent absichern
CREATE OR REPLACE FUNCTION public.merge_norm(p_txt text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT translate(lower(trim(coalesce(p_txt,''))), 'ćčšžđ', 'ccszd');
$$;

-- Klartext (irgendeine Sprache) ODER bereits-Code -> ISO-Code; sonst unverändert.
CREATE OR REPLACE FUNCTION public.land_zu_iso(p text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  WITH map(name, code) AS (VALUES
    ('Bosnien und Herzegowina','BA'),('Bosna i Hercegovina','BA'),('Босна и Херцеговина','BA'),('Bosnia and Herzegovina','BA'),('Bosnia & Herzegovina','BA'),
    ('Kroatien','HR'),('Hrvatska','HR'),('Хрватска','HR'),('Croatia','HR'),
    ('Serbien','RS'),('Srbija','RS'),('Србија','RS'),('Serbia','RS'),
    ('Slowenien','SI'),('Slovenija','SI'),('Словенија','SI'),('Slovenia','SI'),
    ('Montenegro','ME'),('Crna Gora','ME'),('Црна Гора','ME'),
    ('Nordmazedonien','MK'),('Sjeverna Makedonija','MK'),('Severna Makedonija','MK'),('Северна Македонија','MK'),('North Macedonia','MK'),('Makedonija','MK'),
    ('Kosovo','XK'),('Косово','XK'),
    ('Deutschland','DE'),('Njemačka','DE'),('Nemačka','DE'),('Немачка','DE'),('Germany','DE'),
    ('Österreich','AT'),('Austrija','AT'),('Аустрија','AT'),('Austria','AT'),
    ('Schweiz','CH'),('Švicarska','CH'),('Švajcarska','CH'),('Швајцарска','CH'),('Switzerland','CH'),
    ('Italien','IT'),('Italija','IT'),('Италија','IT'),('Italy','IT'),
    ('Frankreich','FR'),('Francuska','FR'),('Француска','FR'),('France','FR'),
    ('Schweden','SE'),('Švedska','SE'),('Шведска','SE'),('Sweden','SE'),
    ('Niederlande','NL'),('Nizozemska','NL'),('Holandija','NL'),('Холандија','NL'),('Netherlands','NL'),
    ('Belgien','BE'),('Belgija','BE'),('Белгија','BE'),('Belgium','BE'),
    ('Vereinigtes Königreich','GB'),('Ujedinjeno Kraljevstvo','GB'),('Уједињено Краљевство','GB'),('United Kingdom','GB'),('Velika Britanija','GB'),
    ('Vereinigte Staaten','US'),('Sjedinjene Države','US'),('Сједињене Државе','US'),('United States','US'),('SAD','US'),('USA','US'),
    ('Kanada','CA'),('Канада','CA'),('Canada','CA'),
    ('Australien','AU'),('Australija','AU'),('Аустралија','AU'),('Australia','AU')
  )
  SELECT CASE
    WHEN nullif(trim(coalesce(p,'')),'') IS NULL THEN p
    WHEN upper(trim(p)) IN ('BA','HR','RS','SI','ME','MK','XK','DE','AT','CH','IT','FR','SE','NL','BE','GB','US','CA','AU')
         AND trim(p) ~ '^[A-Za-z]{2}$' THEN upper(trim(p))
    ELSE coalesce((SELECT m.code FROM map m WHERE public.merge_norm(m.name) = public.merge_norm(p) LIMIT 1), p)
  END;
$$;

-- 1) familien.land
UPDATE public.familien
   SET land = public.land_zu_iso(land)
 WHERE land IS NOT NULL AND land <> public.land_zu_iso(land);

-- 2) personen.stammbaum_daten -> geburtsland / wohnort_land (nur vorhandene Keys)
UPDATE public.personen
   SET stammbaum_daten = jsonb_set(stammbaum_daten, '{geburtsland}',
         to_jsonb(public.land_zu_iso(stammbaum_daten->>'geburtsland')), false)
 WHERE stammbaum_daten ? 'geburtsland'
   AND coalesce(stammbaum_daten->>'geburtsland','') <> public.land_zu_iso(stammbaum_daten->>'geburtsland');

UPDATE public.personen
   SET stammbaum_daten = jsonb_set(stammbaum_daten, '{wohnort_land}',
         to_jsonb(public.land_zu_iso(stammbaum_daten->>'wohnort_land')), false)
 WHERE stammbaum_daten ? 'wohnort_land'
   AND coalesce(stammbaum_daten->>'wohnort_land','') <> public.land_zu_iso(stammbaum_daten->>'wohnort_land');

-- 3) registrierungs_anfragen.geburtsland (falls Spalte existiert)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema='public' AND table_name='registrierungs_anfragen' AND column_name='geburtsland') THEN
    UPDATE public.registrierungs_anfragen
       SET geburtsland = public.land_zu_iso(geburtsland)
     WHERE geburtsland IS NOT NULL AND geburtsland <> public.land_zu_iso(geburtsland);
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
SELECT 'Land->ISO-Migration ausgeführt: land_zu_iso + familien.land + personen(geburtsland/wohnort_land) + anfragen' AS status;
