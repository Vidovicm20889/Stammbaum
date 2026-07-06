-- =====================================================
-- KOCHBUCH-BEWERTUNGEN (Sterne 1–5, GLOBAL / stammbaum- & verbundübergreifend)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- ZWECK: Nutzer bewerten die statischen Kochbuch-Rezepte (rezepte_pool.js, `REZEPT_POOL`,
-- je Rezept eine stabile `id` wie 'sarma') mit 1–5 Sternen. Angezeigt wird der GLOBALE
-- Durchschnitt + Anzahl über ALLE Nutzer (alle Stammbäume/Verbünde) — das Kochbuch ist
-- ohnehin globaler, öffentlicher Read-only-Inhalt.
--
-- BEWUSSTE AUSNAHME zur „strikt verbund-gebunden"-Regel (CLAUDE.md): Dies ist die EINZIGE
-- globale Datenart. Zulässig, weil KEINE Personen-/Familiendaten die Verbund-Grenze
-- überschreiten — nur ein anonymer Aggregatwert (Ø + Anzahl) auf globalem Inhalt. Individuelle
-- Bewertungen sind NICHT direkt lesbar (RLS ohne Policies); Zugriff nur über die RPCs unten,
-- die ausschließlich Aggregat + die EIGENE Bewertung zurückgeben.
-- =====================================================

CREATE TABLE IF NOT EXISTS public.kochbuch_bewertungen (
  rezept_key      text     NOT NULL,                 -- REZEPT_POOL.id (statischer Schlüssel)
  user_id         uuid     NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sterne          smallint NOT NULL CHECK (sterne BETWEEN 1 AND 5),
  erstellt_am     timestamptz NOT NULL DEFAULT now(),
  aktualisiert_am timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (rezept_key, user_id)                  -- 1 Bewertung je Nutzer je Rezept
);
CREATE INDEX IF NOT EXISTS kochbuch_bew_key_idx ON public.kochbuch_bewertungen (rezept_key);

-- RLS an, ABER OHNE Policies für 'authenticated' -> kein direkter Client-Zugriff.
-- Alles über die SECURITY-DEFINER-RPCs unten (geben nur Aggregat + eigene Bewertung zurück).
ALTER TABLE public.kochbuch_bewertungen ENABLE ROW LEVEL SECURITY;

-- Bewerten (Upsert der EIGENEN Bewertung) ------------------------------------
CREATE OR REPLACE FUNCTION public.kochbuch_bewerten(p_key text, p_sterne int)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_key text; v_avg numeric; v_anz int;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'fehler', 'nicht_eingeloggt'); END IF;
  v_key := left(trim(coalesce(p_key, '')), 80);
  IF v_key = '' THEN RETURN jsonb_build_object('ok', false, 'fehler', 'kein_key'); END IF;
  IF p_sterne IS NULL OR p_sterne < 1 OR p_sterne > 5 THEN
    RETURN jsonb_build_object('ok', false, 'fehler', 'ungueltig'); END IF;

  INSERT INTO public.kochbuch_bewertungen (rezept_key, user_id, sterne)
  VALUES (v_key, v_me, p_sterne)
  ON CONFLICT (rezept_key, user_id) DO UPDATE SET sterne = excluded.sterne, aktualisiert_am = now();

  SELECT round(avg(sterne), 2), count(*) INTO v_avg, v_anz
    FROM public.kochbuch_bewertungen WHERE rezept_key = v_key;
  RETURN jsonb_build_object('ok', true, 'avg', v_avg, 'anzahl', v_anz, 'meine', p_sterne);
END $$;
GRANT EXECUTE ON FUNCTION public.kochbuch_bewerten(text, int) TO authenticated;

-- Aggregate holen (Ø + Anzahl + eigene Bewertung) je Rezept-Key ---------------
-- p_keys = NULL -> alle bewerteten Rezepte. Rückgabe: { "<key>": {avg,anzahl,meine}, … }.
CREATE OR REPLACE FUNCTION public.kochbuch_bewertungen_holen(p_keys text[] DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_me uuid := auth.uid(); v_out jsonb;
BEGIN
  SELECT coalesce(jsonb_object_agg(k.rezept_key, jsonb_build_object(
           'avg', k.avg, 'anzahl', k.anzahl, 'meine', k.meine)), '{}'::jsonb)
    INTO v_out
    FROM (
      SELECT b.rezept_key,
             round(avg(b.sterne), 2)                        AS avg,
             count(*)                                       AS anzahl,
             max(b.sterne) FILTER (WHERE b.user_id = v_me)  AS meine
        FROM public.kochbuch_bewertungen b
       WHERE p_keys IS NULL OR b.rezept_key = ANY(p_keys)
       GROUP BY b.rezept_key
    ) k;
  RETURN coalesce(v_out, '{}'::jsonb);
END $$;
GRANT EXECUTE ON FUNCTION public.kochbuch_bewertungen_holen(text[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'OK: kochbuch_bewertungen + RPCs (kochbuch_bewerten / kochbuch_bewertungen_holen) angelegt' AS status;
