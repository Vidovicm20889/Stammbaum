-- =====================================================
-- FAMILIEN-FEED — AKTIVITÄTEN-STREAM (Feature 3)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_reaktionen_kommentare.sql UND supabase_beitraege.sql ausführen.
--
-- KONZEPT (Facebook-Prinzip): EINE schlanke Tabelle `aktivitaeten` sammelt „Was ist neu in der
-- Familie": neue Personen, Fotos, Geschichten, Events, Beiträge. Geschrieben per DB-TRIGGER an
-- den Schreibstellen (robust, deckt auch RPC-/Spiegel-Pfade ab) — NICHT per Live-Aggregation.
-- STRIKT VERBUND-GEBUNDEN (CLAUDE.md Social-Regel): SELECT nur für Mitglieder des verbund_id.
--
-- ANTI-SPAM: Aktivitäten werden NUR erzeugt, wenn auth.uid() gesetzt ist (= echte Nutzer-Aktion).
-- Bulk-/Import-Schreibvorgänge über service_role (auth.uid() IS NULL) erzeugen KEINE Aktivitäten
-- -> ein GEDCOM-Import flutet den Feed nicht. Platzhalter-Personen + identitaet_id-Spiegelkarten
-- (zweite+ Karte derselben realen Person) werden ebenfalls übersprungen.
--
-- Voraussetzungen: supabase_verbund.sql (verbund_id, ist_in_verbund/darf_verbund_moderieren via
--   supabase_reaktionen_kommentare.sql), supabase_profile.sql, supabase_multitree_phase5.sql,
--   supabase_personen_fotos.sql, supabase_personen_geschichten.sql, supabase_events.sql,
--   supabase_beitraege.sql.
-- =====================================================


-- =====================================================
-- 1) TABELLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.aktivitaeten (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id  uuid NOT NULL,
  typ         text NOT NULL CHECK (typ IN
                ('person_neu','foto_neu','geschichte_neu','event_neu','beitrag_neu','geburtstag','erinnerung')),
  ref_id      uuid,
  akteur_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  erstellt_am timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS aktivitaeten_verbund_zeit_idx ON public.aktivitaeten (verbund_id, erstellt_am DESC);
-- Idempotenz pro (typ, ref_id): keine doppelte Aktivität für dasselbe Objekt.
CREATE UNIQUE INDEX IF NOT EXISTS aktivitaeten_typ_ref_uidx
  ON public.aktivitaeten (typ, ref_id) WHERE ref_id IS NOT NULL;

ALTER TABLE public.aktivitaeten ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "aktivitaeten_select" ON public.aktivitaeten;
CREATE POLICY "aktivitaeten_select" ON public.aktivitaeten FOR SELECT TO authenticated
  USING ( public.ist_in_verbund(verbund_id) );
-- (Schreiben nur über die SECURITY-DEFINER-Trigger unten.)


-- =====================================================
-- 2) HELFER: Aktivität anlegen (idempotent über den UNIQUE-Index)
-- =====================================================
CREATE OR REPLACE FUNCTION public._akt_log(p_verbund uuid, p_typ text, p_ref uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO public.aktivitaeten (verbund_id, typ, ref_id, akteur_id)
  SELECT p_verbund, p_typ, p_ref, auth.uid()
  WHERE p_verbund IS NOT NULL
  ON CONFLICT (typ, ref_id) WHERE ref_id IS NOT NULL DO NOTHING;
$$;


-- =====================================================
-- 3) TRIGGER je Schreibstelle (AFTER INSERT). Nur bei echter Nutzer-Aktion (auth.uid()).
-- =====================================================

-- 3a) Person neu (kein Platzhalter, keine identitaet_id-Spiegelkarte)
CREATE OR REPLACE FUNCTION public.akt_trg_person() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF coalesce(NEW.stammbaum_daten->>'platzhalter','') = 'true' THEN RETURN NEW; END IF;
  IF NEW.identitaet_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personen WHERE identitaet_id = NEW.identitaet_id AND id <> NEW.id)
  THEN RETURN NEW; END IF;   -- Spiegelkarte -> nur die erste zählt
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
  PERFORM public._akt_log(v_verb, 'person_neu', NEW.id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_person_neu ON public.personen;
CREATE TRIGGER akt_person_neu AFTER INSERT ON public.personen
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_person();

-- 3b) Foto neu
CREATE OR REPLACE FUNCTION public.akt_trg_foto() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
  PERFORM public._akt_log(v_verb, 'foto_neu', NEW.id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_foto_neu ON public.personen_fotos;
CREATE TRIGGER akt_foto_neu AFTER INSERT ON public.personen_fotos
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_foto();

-- 3c) Geschichte neu (nur veröffentlicht)
CREATE OR REPLACE FUNCTION public.akt_trg_geschichte() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF coalesce(NEW.veroeffentlicht, false) = false THEN RETURN NEW; END IF;
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
  PERFORM public._akt_log(v_verb, 'geschichte_neu', NEW.id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_geschichte_neu ON public.personen_geschichten;
CREATE TRIGGER akt_geschichte_neu AFTER INSERT ON public.personen_geschichten
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_geschichte();

-- 3d) Event neu
CREATE OR REPLACE FUNCTION public.akt_trg_event() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
  PERFORM public._akt_log(v_verb, 'event_neu', NEW.id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_event_neu ON public.events;
CREATE TRIGGER akt_event_neu AFTER INSERT ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_event();

-- 3e) Beitrag neu (verbund_id liegt direkt auf der Zeile)
CREATE OR REPLACE FUNCTION public.akt_trg_beitrag() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF coalesce(NEW.geloescht, false) = true THEN RETURN NEW; END IF;
  PERFORM public._akt_log(NEW.verbund_id, 'beitrag_neu', NEW.id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_beitrag_neu ON public.beitraege;
CREATE TRIGGER akt_beitrag_neu AFTER INSERT ON public.beitraege
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_beitrag();


-- =====================================================
-- 4) RPC: Feed holen (alle Aktivitätstypen, verbund-RLS, Cursor über erstellt_am).
--    Liefert je Aktivität: Akteur (Name/Avatar), Typ-spezifische Felder + (bei beitrag_neu) die
--    vollständigen Beitragsfelder, damit das Frontend die Beitrags-Karte wiederverwenden kann.
--    Gelöschte/verschwundene Zielobjekte werden ausgeblendet.
-- =====================================================
CREATE OR REPLACE FUNCTION public.aktivitaeten_holen(p_limit int DEFAULT 20, p_vor timestamptz DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(jsonb_agg(j ORDER BY (j->>'erstellt_am') DESC), '[]'::jsonb) FROM (
    SELECT jsonb_build_object(
      'id', a.id,
      'typ', a.typ,
      'ref_id', a.ref_id,
      'erstellt_am', a.erstellt_am,
      'akteur_id', a.akteur_id,
      'akteur_name', COALESCE(NULLIF(btrim(concat_ws(' ', apr.vorname, apr.nachname)), ''),
                              initcap(replace(replace(replace(split_part(au.email,'@',1),'.',' '),'_',' '),'-',' ')),
                              au.email),
      'akteur_avatar', CASE WHEN COALESCE(apr.avatar_sichtbarkeit,'verbund') <> 'privat'
                            THEN COALESCE(apr.avatar_thumb_url, apr.avatar_url) END,
      'person_id', CASE a.typ
                     WHEN 'person_neu'     THEN a.ref_id
                     WHEN 'foto_neu'       THEN pf.person_id
                     WHEN 'geschichte_neu' THEN pg.person_id
                     WHEN 'beitrag_neu'    THEN b.ref_person
                   END,
      'person_name', CASE a.typ
                     WHEN 'person_neu'     THEN (SELECT nullif(btrim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')),'') FROM public.personen p WHERE p.id = a.ref_id)
                     WHEN 'foto_neu'       THEN (SELECT nullif(btrim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')),'') FROM public.personen p WHERE p.id = pf.person_id)
                     WHEN 'geschichte_neu' THEN (SELECT nullif(btrim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')),'') FROM public.personen p WHERE p.id = pg.person_id)
                     WHEN 'beitrag_neu'    THEN (SELECT nullif(btrim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')),'') FROM public.personen p WHERE p.id = b.ref_person)
                   END,
      'titel', CASE a.typ WHEN 'event_neu' THEN ev.titel WHEN 'geschichte_neu' THEN pg.titel END,
      'foto_pfad', CASE a.typ WHEN 'foto_neu' THEN pf.storage_pfad END,
      -- Beitragsfelder (nur beitrag_neu) — Frontend reused feedBeitragHtml
      'text', CASE a.typ WHEN 'beitrag_neu' THEN b.text END,
      'bild_url', CASE a.typ WHEN 'beitrag_neu' THEN b.bild_url END,
      'bearbeitet_am', CASE a.typ WHEN 'beitrag_neu' THEN b.bearbeitet_am END,
      'darf_bearbeiten', (a.typ = 'beitrag_neu' AND b.autor = auth.uid()),
      'darf_loeschen',   (a.typ = 'beitrag_neu' AND (b.autor = auth.uid() OR public.darf_verbund_moderieren(a.verbund_id)))
    ) AS j, a.erstellt_am
    FROM public.aktivitaeten a
    LEFT JOIN auth.users au       ON au.id = a.akteur_id
    LEFT JOIN public.profile apr  ON apr.user_id = a.akteur_id
    LEFT JOIN public.beitraege b           ON a.typ = 'beitrag_neu'    AND b.id = a.ref_id AND b.geloescht = false
    LEFT JOIN public.personen_fotos pf     ON a.typ = 'foto_neu'       AND pf.id = a.ref_id
    LEFT JOIN public.personen_geschichten pg ON a.typ = 'geschichte_neu' AND pg.id = a.ref_id
    LEFT JOIN public.events ev             ON a.typ = 'event_neu'      AND ev.id = a.ref_id
    WHERE public.ist_in_verbund(a.verbund_id)
      AND (p_vor IS NULL OR a.erstellt_am < p_vor)
      AND (
            (a.typ = 'beitrag_neu'    AND b.id IS NOT NULL)
         OR (a.typ = 'foto_neu'       AND pf.id IS NOT NULL)
         OR (a.typ = 'geschichte_neu' AND pg.id IS NOT NULL)
         OR (a.typ = 'event_neu'      AND ev.id IS NOT NULL)
         OR (a.typ = 'person_neu'     AND EXISTS (SELECT 1 FROM public.personen p WHERE p.id = a.ref_id AND coalesce(p.stammbaum_daten->>'platzhalter','') <> 'true'))
         OR (a.typ IN ('geburtstag','erinnerung'))
      )
    ORDER BY a.erstellt_am DESC
    LIMIT greatest(1, least(coalesce(p_limit, 20), 50))
  ) s;
$$;
GRANT EXECUTE ON FUNCTION public.aktivitaeten_holen(int, timestamptz) TO authenticated;


-- =====================================================
-- 5) REALTIME-PUBLICATION (neue Aktivitäten live oben einfügen)
-- =====================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'aktivitaeten'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.aktivitaeten;
  END IF;
END $$;
ALTER TABLE public.aktivitaeten REPLICA IDENTITY FULL;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_aktivitaeten.sql ausgeführt — aktivitaeten (verbund-RLS) + Trigger (person/foto/geschichte/event/beitrag) + aktivitaeten_holen + Realtime' AS status;
