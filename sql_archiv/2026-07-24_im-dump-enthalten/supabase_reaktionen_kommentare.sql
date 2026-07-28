-- =====================================================
-- REAKTIONEN & KOMMENTARE — wiederverwendbares, POLYMORPHES Engagement-System
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT (mehrfach ausführbar).
--
-- BASIS-PRIMITIV der sozialen Schicht (Foto/Geschichte/Beitrag/Person/Event reagieren+kommentieren).
-- STRIKT VERBUND-GEBUNDEN (CLAUDE.md Social-Regel): Reaktionen/Kommentare sind NIE
-- verbundübergreifend sichtbar; sie erben die Lese-Grenze ihres Zielobjekts über den denormalisiert
-- mitgeführten verbund_id (KEIN polymorpher Join in der Policy -> rekursionsfreie, einfache RLS).
--
-- SICHERHEIT:
--   * SELECT: nur Mitglieder des verbund_id (Helfer ist_in_verbund). KEIN baum_freigaben-Pfad
--     (Baumzugriff ist read-only-Stammbaum, KEINE Social-Teilnahme) -> Isolation gewahrt.
--   * Schreiben ausschließlich über SECURITY-DEFINER-RPCs (kein direktes INSERT/UPDATE/DELETE):
--     verbund_id wird serverseitig aus dem Zielobjekt abgeleitet -> nicht fälschbar.
--   * Kommentar bearbeiten/löschen (geloescht=true, KEIN hartes DELETE): nur Autor;
--     Moderation (löschen) zusätzlich für familien_owner/familien_admin im Verbund + super_admin.
--
-- TRANSPORT: Supabase Realtime (wie Baumdaten/Chat) — beide Tabellen haben echte RLS-SELECT-
-- Policies und liegen in der Publication supabase_realtime.
--
-- Voraussetzungen: supabase_verbund.sql (verbund_id, mitgliedschaften, ist_super_admin),
--   supabase_profile.sql (profile), supabase_multitree_phase5.sql (personen/stammbaeume),
--   supabase_personen_fotos.sql / supabase_personen_geschichten.sql / supabase_events.sql
--   (Zieltabellen mit familie_id). 'beitrag' ist für ein späteres Feature reserviert (Tabelle
--   existiert noch nicht -> _ziel_verbund liefert dafür NULL -> RPC meldet 'ziel_unbekannt').
-- =====================================================


-- =====================================================
-- 1) TABELLEN
-- =====================================================

CREATE TABLE IF NOT EXISTS public.reaktionen (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id  uuid NOT NULL,
  ziel_typ    text NOT NULL CHECK (ziel_typ IN ('foto','geschichte','beitrag','person','event')),
  ziel_id     uuid NOT NULL,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  typ         text NOT NULL CHECK (typ IN ('gefaellt','herz','lachen','wow','traurig')),
  erstellt_am timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ziel_typ, ziel_id, user_id)   -- genau EINE Reaktion je Nutzer je Objekt
);
CREATE INDEX IF NOT EXISTS reaktionen_ziel_idx   ON public.reaktionen (ziel_typ, ziel_id);
CREATE INDEX IF NOT EXISTS reaktionen_verbund_idx ON public.reaktionen (verbund_id);

CREATE TABLE IF NOT EXISTS public.kommentare (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id          uuid NOT NULL,
  ziel_typ            text NOT NULL CHECK (ziel_typ IN ('foto','geschichte','beitrag','person','event')),
  ziel_id             uuid NOT NULL,
  user_id             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  eltern_kommentar_id uuid REFERENCES public.kommentare(id) ON DELETE CASCADE,   -- 1 Ebene Threads
  text                text,
  erstellt_am         timestamptz NOT NULL DEFAULT now(),
  bearbeitet_am       timestamptz,
  geloescht           boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS kommentare_ziel_idx    ON public.kommentare (ziel_typ, ziel_id, erstellt_am);
CREATE INDEX IF NOT EXISTS kommentare_verbund_idx ON public.kommentare (verbund_id);

ALTER TABLE public.reaktionen ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kommentare ENABLE ROW LEVEL SECURITY;


-- =====================================================
-- 2) HELFER (SECURITY DEFINER -> rekursionsfrei in den Policies)
-- =====================================================

-- 2a) Ist der eingeloggte Nutzer Mitglied dieses Verbunds?
CREATE OR REPLACE FUNCTION public.ist_in_verbund(p_verbund uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p_verbund IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.mitgliedschaften m
    JOIN public.familien f ON f.id = m.familie_id
    WHERE m.user_id = auth.uid() AND f.verbund_id = p_verbund
  );
$$;

-- 2b) Darf der eingeloggte Nutzer im Verbund moderieren (fremde Kommentare löschen)?
CREATE OR REPLACE FUNCTION public.darf_verbund_moderieren(p_verbund uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.ist_super_admin() OR (p_verbund IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.mitgliedschaften m
    JOIN public.familien f ON f.id = m.familie_id
    WHERE m.user_id = auth.uid() AND f.verbund_id = p_verbund
      AND m.rolle IN ('familien_owner','familien_admin') AND m.aktiv
  ));
$$;

-- 2c) Verbund des Zielobjekts auflösen (polymorph, DEFINER -> umgeht Ziel-RLS).
--     'beitrag' noch nicht vorhanden -> NULL (RPC meldet dann 'ziel_unbekannt').
CREATE OR REPLACE FUNCTION public._ziel_verbund(p_typ text, p_ziel uuid)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v uuid;
BEGIN
  IF p_ziel IS NULL THEN RETURN NULL; END IF;
  IF p_typ = 'person' THEN
    SELECT f.verbund_id INTO v FROM public.personen p
      JOIN public.familien f ON f.id = p.familie_id WHERE p.id = p_ziel AND p.geloescht_am IS NULL;
  ELSIF p_typ = 'foto' THEN
    SELECT f.verbund_id INTO v FROM public.personen_fotos x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSIF p_typ = 'geschichte' THEN
    SELECT f.verbund_id INTO v FROM public.personen_geschichten x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSIF p_typ = 'event' THEN
    SELECT f.verbund_id INTO v FROM public.events x
      JOIN public.familien f ON f.id = x.familie_id WHERE x.id = p_ziel;
  ELSE
    v := NULL;   -- 'beitrag' o. a. (noch) nicht auflösbar
  END IF;
  RETURN v;
END $$;


-- =====================================================
-- 3) RLS-POLICIES (nur SELECT; Schreiben über die RPCs unten)
-- =====================================================

DROP POLICY IF EXISTS "reaktionen_select" ON public.reaktionen;
CREATE POLICY "reaktionen_select" ON public.reaktionen FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );

DROP POLICY IF EXISTS "kommentare_select" ON public.kommentare;
CREATE POLICY "kommentare_select" ON public.kommentare FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );
-- (KEINE INSERT/UPDATE/DELETE-Policies -> ausschließlich die SECURITY-DEFINER-RPCs schreiben.)


-- =====================================================
-- 4) RPCs
-- =====================================================

-- 4a) Reaktion umschalten (toggle): gleiche -> entfernen, andere -> ändern, keine -> setzen.
CREATE OR REPLACE FUNCTION public.reaktion_umschalten(p_typ text, p_ziel uuid, p_reaktion text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_alt  text;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  IF p_reaktion NOT IN ('gefaellt','herz','lachen','wow','traurig') THEN RAISE EXCEPTION 'reaktion_unbekannt'; END IF;
  v_verb := public._ziel_verbund(p_typ, p_ziel);
  IF v_verb IS NULL THEN RAISE EXCEPTION 'ziel_unbekannt'; END IF;
  IF NOT public.ist_in_verbund(v_verb) THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;

  SELECT typ INTO v_alt FROM public.reaktionen
   WHERE ziel_typ = p_typ AND ziel_id = p_ziel AND user_id = v_me;

  IF v_alt IS NULL THEN
    INSERT INTO public.reaktionen (verbund_id, ziel_typ, ziel_id, user_id, typ)
    VALUES (v_verb, p_typ, p_ziel, v_me, p_reaktion);
  ELSIF v_alt = p_reaktion THEN
    DELETE FROM public.reaktionen
     WHERE ziel_typ = p_typ AND ziel_id = p_ziel AND user_id = v_me;
  ELSE
    UPDATE public.reaktionen SET typ = p_reaktion, erstellt_am = now()
     WHERE ziel_typ = p_typ AND ziel_id = p_ziel AND user_id = v_me;
  END IF;

  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.reaktion_umschalten(text, uuid, text) TO authenticated;


-- 4b) Kommentar schreiben (optional als Antwort = 1 Ebene; tiefer wird auf die Wurzel geklappt).
CREATE OR REPLACE FUNCTION public.kommentar_schreiben(
  p_typ text, p_ziel uuid, p_text text, p_eltern uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_verb  uuid;
  v_neu   uuid;
  v_eltern uuid := p_eltern;
  v_e_eltern uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  IF p_text IS NULL OR btrim(p_text) = '' THEN RAISE EXCEPTION 'leer'; END IF;
  v_verb := public._ziel_verbund(p_typ, p_ziel);
  IF v_verb IS NULL THEN RAISE EXCEPTION 'ziel_unbekannt'; END IF;
  IF NOT public.ist_in_verbund(v_verb) THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;

  -- Threads auf 1 Ebene begrenzen: Antwort auf eine Antwort hängt an deren Wurzel.
  IF v_eltern IS NOT NULL THEN
    SELECT eltern_kommentar_id INTO v_e_eltern FROM public.kommentare
     WHERE id = v_eltern AND ziel_typ = p_typ AND ziel_id = p_ziel AND verbund_id = v_verb;
    IF NOT FOUND THEN
      v_eltern := NULL;   -- ungültiges Eltern-Ziel -> Top-Level
    ELSIF v_e_eltern IS NOT NULL THEN
      v_eltern := v_e_eltern;
    END IF;
  END IF;

  INSERT INTO public.kommentare (verbund_id, ziel_typ, ziel_id, user_id, eltern_kommentar_id, text)
  VALUES (v_verb, p_typ, p_ziel, v_me, v_eltern, btrim(p_text))
  RETURNING id INTO v_neu;

  RETURN jsonb_build_object('ok', true, 'id', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.kommentar_schreiben(text, uuid, text, uuid) TO authenticated;


-- 4c) Eigenen Kommentar bearbeiten.
CREATE OR REPLACE FUNCTION public.kommentar_bearbeiten(p_id uuid, p_text text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  IF p_text IS NULL OR btrim(p_text) = '' THEN RAISE EXCEPTION 'leer'; END IF;
  SELECT user_id INTO v_owner FROM public.kommentare WHERE id = p_id AND geloescht = false;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF v_owner <> auth.uid() THEN RAISE EXCEPTION 'keine_berechtigung'; END IF;
  UPDATE public.kommentare SET text = btrim(p_text), bearbeitet_am = now() WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.kommentar_bearbeiten(uuid, text) TO authenticated;


-- 4d) Kommentar löschen (soft): Autor ODER Moderator (owner/admin im Verbund / super_admin).
CREATE OR REPLACE FUNCTION public.kommentar_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid; v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  SELECT user_id, verbund_id INTO v_owner, v_verb FROM public.kommentare WHERE id = p_id;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'nicht_gefunden'; END IF;
  IF v_owner <> auth.uid() AND NOT public.darf_verbund_moderieren(v_verb) THEN
    RAISE EXCEPTION 'keine_berechtigung';
  END IF;
  UPDATE public.kommentare SET geloescht = true, text = NULL WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.kommentar_loeschen(uuid) TO authenticated;


-- 4e) Engagement EINES Zielobjekts holen: Reaktions-Zähler + eigene Reaktion + Kommentar-Thread
--     (mit Anzeigename/Avatar aus profile/auth, darf_bearbeiten je Kommentar). EIN Roundtrip.
CREATE OR REPLACE FUNCTION public.engagement_holen(p_typ text, p_ziel uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_verb uuid;
  v_mod  boolean;
  v_react jsonb;
  v_meine text;
  v_komm jsonb;
BEGIN
  v_verb := public._ziel_verbund(p_typ, p_ziel);
  IF v_verb IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'ziel_unbekannt'); END IF;
  IF NOT public.ist_in_verbund(v_verb) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  v_mod := public.darf_verbund_moderieren(v_verb);

  -- Reaktions-Zähler je Typ
  SELECT coalesce(jsonb_object_agg(typ, anz), '{}'::jsonb) INTO v_react
    FROM (SELECT typ, count(*) AS anz FROM public.reaktionen
           WHERE ziel_typ = p_typ AND ziel_id = p_ziel GROUP BY typ) s;

  SELECT typ INTO v_meine FROM public.reaktionen
   WHERE ziel_typ = p_typ AND ziel_id = p_ziel AND user_id = v_me;

  -- Kommentare (älteste zuerst) inkl. Anzeigename/Avatar + Bearbeitungsrecht
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', k.id,
           'user_id', k.user_id,
           'eltern', k.eltern_kommentar_id,
           'text', CASE WHEN k.geloescht THEN NULL ELSE k.text END,
           'geloescht', k.geloescht,
           'erstellt_am', k.erstellt_am,
           'bearbeitet_am', k.bearbeitet_am,
           'name', COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''),
                            initcap(replace(replace(replace(split_part(u.email,'@',1),'.',' '),'_',' '),'-',' ')),
                            u.email),
           'avatar', CASE WHEN COALESCE(pr.avatar_sichtbarkeit,'verbund') <> 'privat'
                          THEN COALESCE(pr.avatar_thumb_url, pr.avatar_url) END,
           'darf_bearbeiten', (k.user_id = v_me),
           'darf_loeschen', (k.user_id = v_me OR v_mod)
         ) ORDER BY k.erstellt_am), '[]'::jsonb) INTO v_komm
    FROM public.kommentare k
    LEFT JOIN auth.users u   ON u.id = k.user_id
    LEFT JOIN public.profile pr ON pr.user_id = k.user_id
   WHERE k.ziel_typ = p_typ AND k.ziel_id = p_ziel;

  RETURN jsonb_build_object(
    'ok', true,
    'reaktionen', v_react,
    'meine_reaktion', v_meine,
    'kann_moderieren', v_mod,
    'kommentare', v_komm
  );
END $$;
GRANT EXECUTE ON FUNCTION public.engagement_holen(text, uuid) TO authenticated;


-- =====================================================
-- 5) REALTIME-PUBLICATION (wie Baumdaten/Chat)
-- =====================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

DO $$
DECLARE
  t text;
  tabellen text[] := ARRAY['reaktionen', 'kommentare'];
BEGIN
  FOREACH t IN ARRAY tabellen LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

ALTER TABLE public.reaktionen REPLICA IDENTITY FULL;
ALTER TABLE public.kommentare REPLICA IDENTITY FULL;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_reaktionen_kommentare.sql ausgeführt — reaktionen + kommentare (polymorph, verbund-RLS) + RPCs + Realtime' AS status;
