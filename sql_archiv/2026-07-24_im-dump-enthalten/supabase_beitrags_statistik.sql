-- =====================================================
-- BEITRAGS-STATISTIK — sanfte Gamification (Feature „Vervollständigung & Gamification")
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_reaktionen_kommentare.sql / supabase_beitraege.sql ausführen
--   (liefern die Helfer ist_in_verbund / mein_verbund / darf_verbund_moderieren).
--
-- KONZEPT: EINE schlanke Tabelle `beitrags_statistik` zählt je (verbund_id, user_id), wie viele
-- Personen / Fotos / Geschichten ein Konto beigetragen hat. Fortgeschrieben per DB-TRIGGER an den
-- Schreibstellen (robust, deckt auch RPC-Pfade ab) — NICHT per Live-Aggregation. STRIKT
-- VERBUND-GEBUNDEN (CLAUDE.md Social-Regel): SELECT nur für Mitglieder des verbund_id.
--
-- ANTI-SPAM / KORREKTHEIT (analog supabase_aktivitaeten.sql):
--  * Nur echte Nutzer-Aktion: gezählt wird NUR, wenn auth.uid() gesetzt ist. Bulk-/Import-/
--    Backfill-Schreibvorgänge über service_role (auth.uid() IS NULL) zählen NICHT.
--  * Platzhalter-Personen ("Unbekannt"-Eltern) werden NICHT gezählt.
--  * identitaet_id-Spiegelkarten (zweite+ Karte derselben realen Person) werden NICHT gezählt
--    (nur die erste). Geschichten-Spiegelung (geschichte_ident_sync) wird über pg_trigger_depth()
--    ausgeklammert, damit ein Schreiben nur EINMAL zählt.
--
-- Abzeichen werden NICHT in der DB gespeichert — das Frontend leitet sie aus den Zählern ab
-- (wenige, geschmackvolle Schwellen). KEINE Rangliste: die Beitragenden-Liste ist alphabetisch.
--
-- Voraussetzungen: supabase_verbund.sql, supabase_profile.sql, supabase_multitree_phase5.sql,
--   supabase_personen_fotos.sql, supabase_personen_geschichten.sql,
--   supabase_reaktionen_kommentare.sql (ist_in_verbund), supabase_beitraege.sql (mein_verbund).
-- =====================================================


-- =====================================================
-- 1) TABELLE (eine Zeile je Konto je Verbund)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.beitrags_statistik (
  verbund_id              uuid NOT NULL,
  user_id                 uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  personen_angelegt       int  NOT NULL DEFAULT 0,
  fotos_hinzugefuegt      int  NOT NULL DEFAULT 0,
  geschichten_geschrieben int  NOT NULL DEFAULT 0,
  aktualisiert_am         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (verbund_id, user_id)
);
CREATE INDEX IF NOT EXISTS beitrags_statistik_verbund_idx ON public.beitrags_statistik (verbund_id);

ALTER TABLE public.beitrags_statistik ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "beitrags_statistik_select" ON public.beitrags_statistik;
CREATE POLICY "beitrags_statistik_select" ON public.beitrags_statistik FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );
-- (Schreiben ausschließlich über die SECURITY-DEFINER-Trigger unten — keine INSERT/UPDATE-Policy.)


-- =====================================================
-- 2) HELFER: Zähler +1 (whitelisted Feldname gegen SQL-Injection)
-- =====================================================
CREATE OR REPLACE FUNCTION public._stat_inc(p_verbund uuid, p_feld text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_verbund IS NULL OR auth.uid() IS NULL THEN RETURN; END IF;
  IF p_feld NOT IN ('personen_angelegt','fotos_hinzugefuegt','geschichten_geschrieben') THEN RETURN; END IF;
  INSERT INTO public.beitrags_statistik (verbund_id, user_id)
  VALUES (p_verbund, auth.uid())
  ON CONFLICT (verbund_id, user_id) DO NOTHING;
  EXECUTE format(
    'UPDATE public.beitrags_statistik SET %1$I = %1$I + 1, aktualisiert_am = now() WHERE verbund_id = $1 AND user_id = $2',
    p_feld
  ) USING p_verbund, auth.uid();
END $$;


-- =====================================================
-- 3) TRIGGER je Schreibstelle (AFTER INSERT). Nur bei echter Nutzer-Aktion.
-- =====================================================

-- 3a) Person angelegt (kein Platzhalter, keine identitaet_id-Spiegelkarte)
CREATE OR REPLACE FUNCTION public.stat_trg_person() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF coalesce(NEW.stammbaum_daten->>'platzhalter','') = 'true' THEN RETURN NEW; END IF;
  IF NEW.identitaet_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personen WHERE identitaet_id = NEW.identitaet_id AND id <> NEW.id)
  THEN RETURN NEW; END IF;   -- Spiegelkarte -> nur die erste zählt
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
  PERFORM public._stat_inc(v_verb, 'personen_angelegt');
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS stat_person_neu ON public.personen;
CREATE TRIGGER stat_person_neu AFTER INSERT ON public.personen
  FOR EACH ROW EXECUTE FUNCTION public.stat_trg_person();

-- 3b) Foto hinzugefügt (Fotos hängen an EINER Karte -> keine Spiegel-Entdopplung nötig)
CREATE OR REPLACE FUNCTION public.stat_trg_foto() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
  PERFORM public._stat_inc(v_verb, 'fotos_hinzugefuegt');
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS stat_foto_neu ON public.personen_fotos;
CREATE TRIGGER stat_foto_neu AFTER INSERT ON public.personen_fotos
  FOR EACH ROW EXECUTE FUNCTION public.stat_trg_foto();

-- 3c) Geschichte geschrieben. pg_trigger_depth() > 1 = Spiegelung (geschichte_ident_sync) -> NICHT
--     mitzählen, sonst zählt ein Schreiben mehrfach (eine Zeile je Zwillingskarte).
CREATE OR REPLACE FUNCTION public.stat_trg_geschichte() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF pg_trigger_depth() > 1 THEN RETURN NEW; END IF;   -- Spiegel-INSERT überspringen
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
  PERFORM public._stat_inc(v_verb, 'geschichten_geschrieben');
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS stat_geschichte_neu ON public.personen_geschichten;
CREATE TRIGGER stat_geschichte_neu AFTER INSERT ON public.personen_geschichten
  FOR EACH ROW EXECUTE FUNCTION public.stat_trg_geschichte();


-- =====================================================
-- 4) RPC: eigene Statistik + Beitragende des eigenen Verbunds (alphabetisch, KEINE Rangliste)
-- =====================================================
CREATE OR REPLACE FUNCTION public.beitrags_statistik_holen()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_verb  uuid;
  v_meine jsonb;
  v_liste jsonb;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;

  -- Eigene Summen über ALLE Verbünde, in denen ich beigetragen habe:
  SELECT jsonb_build_object(
           'personen_angelegt',       coalesce(sum(personen_angelegt), 0),
           'fotos_hinzugefuegt',      coalesce(sum(fotos_hinzugefuegt), 0),
           'geschichten_geschrieben', coalesce(sum(geschichten_geschrieben), 0))
    INTO v_meine
    FROM public.beitrags_statistik WHERE user_id = v_me;

  v_verb := public.mein_verbund();

  -- Beitragende des eigenen Verbunds (NUR mit ≥1 Beitrag), alphabetisch sortiert:
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'user_id', s.user_id,
           'ich',     (s.user_id = v_me),
           'name',    COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''),
                               initcap(replace(replace(replace(split_part(u.email,'@',1),'.',' '),'_',' '),'-',' ')),
                               u.email),
           'avatar',  CASE WHEN COALESCE(pr.avatar_sichtbarkeit,'verbund') <> 'privat'
                           THEN COALESCE(pr.avatar_thumb_url, pr.avatar_url) END,
           'personen_angelegt',       s.personen_angelegt,
           'fotos_hinzugefuegt',      s.fotos_hinzugefuegt,
           'geschichten_geschrieben', s.geschichten_geschrieben
         ) ORDER BY lower(COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''), u.email))),
         '[]'::jsonb)
    INTO v_liste
    FROM public.beitrags_statistik s
    LEFT JOIN auth.users u      ON u.id = s.user_id
    LEFT JOIN public.profile pr ON pr.user_id = s.user_id
   WHERE s.verbund_id = v_verb
     AND (s.personen_angelegt > 0 OR s.fotos_hinzugefuegt > 0 OR s.geschichten_geschrieben > 0);

  RETURN jsonb_build_object('ok', true, 'meine', v_meine, 'beitragende', v_liste);
END $$;
GRANT EXECUTE ON FUNCTION public.beitrags_statistik_holen() TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_beitrags_statistik.sql ausgeführt — beitrags_statistik (verbund-RLS) + Trigger (person/foto/geschichte) + beitrags_statistik_holen' AS status;
