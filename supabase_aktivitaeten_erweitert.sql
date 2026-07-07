-- =====================================================
-- FAMILIEN-FEED — AKTIVITÄTEN ERWEITERN (Event-Album-Fotos, Rezepte, Familien-Änderungen)
--                 + Admin-Löschung einzelner Feed-Einträge
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_aktivitaeten.sql, supabase_event_album.sql UND
-- supabase_familien_rezepte.sql ausführen.
--
-- NEU protokolliert (zusätzlich zu person/foto/geschichte/event/beitrag):
--   * event_foto_neu   — Foto in ein Event-Album hochgeladen (Tabelle event_album_fotos)
--   * rezept_neu       — neues Rezept (Tabelle familien_rezepte)
--   * familie_geaendert— „echte" Familien-/Baum-Änderung: Name ODER Foto/Wappen/Logo/Motto
--                        (NICHT bei jedem Speichern; ref_id=NULL -> wiederholbar, kein Dedup)
--   * album_foto_neu   — Foto/Video in ein STANDALONE-Familien-Album (Tabelle album_medien).
--                        AGGREGIERT: EIN Eintrag je Album (ref_id=album_id), der bei jedem weiteren
--                        Upload per erstellt_am=now() nach oben rutscht -> kein Feed-Spam bei
--                        Mehrfach-Upload (bewusst anders als event_foto_neu = 1 Eintrag je Foto).
--
-- ANTI-SPAM wie gehabt: NUR bei echter Nutzer-Aktion (auth.uid() gesetzt). Service-Role/
-- Bulk-Schreibvorgänge (auth.uid() IS NULL) erzeugen KEINE Aktivitäten.
--
-- ADMIN-LÖSCHUNG (Betreiber-Wunsch): aktivitaet_loeschen(id) entfernt NUR den Feed-Eintrag
-- (das Foto/Rezept/Event bleibt bestehen). Erlaubt für darf_verbund_moderieren
-- (Familien-Owner/-Admin + Super-Admin des Verbunds).
-- =====================================================


-- =====================================================
-- 1) typ-CHECK um die neuen Typen erweitern
-- =====================================================
ALTER TABLE public.aktivitaeten DROP CONSTRAINT IF EXISTS aktivitaeten_typ_check;
ALTER TABLE public.aktivitaeten ADD  CONSTRAINT aktivitaeten_typ_check CHECK (typ IN (
  'person_neu','foto_neu','geschichte_neu','event_neu','beitrag_neu','geburtstag','erinnerung',
  'event_foto_neu','rezept_neu','familie_geaendert','album_foto_neu'));


-- =====================================================
-- 2) TRIGGER für die neuen Quellen (AFTER INSERT; nur echte Nutzer-Aktion)
-- =====================================================

-- 2a) Event-Album-Foto neu (verbund_id liegt denormalisiert auf der Zeile)
CREATE OR REPLACE FUNCTION public.akt_trg_event_foto() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  PERFORM public._akt_log(NEW.verbund_id, 'event_foto_neu', NEW.id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_event_foto_neu ON public.event_album_fotos;
CREATE TRIGGER akt_event_foto_neu AFTER INSERT ON public.event_album_fotos
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_event_foto();

-- 2b) Rezept neu (verbund_id auf der Zeile; gelöschte überspringen)
CREATE OR REPLACE FUNCTION public.akt_trg_rezept() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF coalesce(NEW.geloescht, false) = true THEN RETURN NEW; END IF;
  PERFORM public._akt_log(NEW.verbund_id, 'rezept_neu', NEW.id);
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_rezept_neu ON public.familien_rezepte;
CREATE TRIGGER akt_rezept_neu AFTER INSERT ON public.familien_rezepte
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_rezept();

-- 2c) Familie/Baum geändert — Option (b): NUR bei „echten" Änderungen (Name/Foto/Wappen/Logo/Motto),
--     nicht bei jedem Klick. ref_id = NULL -> mehrere Änderungen über die Zeit ergeben mehrere
--     Einträge (der partielle UNIQUE-Index greift nur bei ref_id IS NOT NULL).
CREATE OR REPLACE FUNCTION public.akt_trg_familie() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF NEW.name IS DISTINCT FROM OLD.name
     OR (NEW.einstellungen->>'foto_url')   IS DISTINCT FROM (OLD.einstellungen->>'foto_url')
     OR (NEW.einstellungen->>'wappen_url') IS DISTINCT FROM (OLD.einstellungen->>'wappen_url')
     OR (NEW.einstellungen->>'logo')       IS DISTINCT FROM (OLD.einstellungen->>'logo')
     OR (NEW.einstellungen->>'motto')      IS DISTINCT FROM (OLD.einstellungen->>'motto')
  THEN
    SELECT verbund_id INTO v_verb FROM public.familien WHERE id = NEW.familie_id;
    PERFORM public._akt_log(v_verb, 'familie_geaendert', NULL);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_familie_geaendert ON public.stammbaeume;
CREATE TRIGGER akt_familie_geaendert AFTER UPDATE ON public.stammbaeume
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_familie();

-- 2d) Standalone-Album: neues Foto/Video -> EIN aggregierter Eintrag je Album (ref_id = album_id).
--     Bei jedem weiteren Upload wird erstellt_am=now() gesetzt (Upsert) -> der Album-Eintrag rutscht
--     erneut nach oben, statt je Foto einen neuen Eintrag zu erzeugen (kein Spam bei Mehrfach-Upload).
--     Nutzt DO UPDATE (nicht _akt_log, das DO NOTHING macht). verbund_id liegt denormalisiert vor.
CREATE OR REPLACE FUNCTION public.akt_trg_album_medium() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;      -- nur echte Nutzer-Aktion (kein Bulk/Service-Role)
  IF NEW.verbund_id IS NULL THEN RETURN NEW; END IF;
  INSERT INTO public.aktivitaeten (verbund_id, typ, ref_id, akteur_id, erstellt_am)
  VALUES (NEW.verbund_id, 'album_foto_neu', NEW.album_id, auth.uid(), now())
  ON CONFLICT (typ, ref_id) WHERE ref_id IS NOT NULL
    DO UPDATE SET erstellt_am = now(), akteur_id = excluded.akteur_id;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akt_album_foto_neu ON public.album_medien;
CREATE TRIGGER akt_album_foto_neu AFTER INSERT ON public.album_medien
  FOR EACH ROW EXECUTE FUNCTION public.akt_trg_album_medium();


-- =====================================================
-- 3) aktivitaeten_holen NEU: neue Typen + darf_eintrag_loeschen (für ALLE Typen)
--    (ersetzt die Funktion aus supabase_aktivitaeten.sql; bestehende Felder unverändert)
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
                     WHEN 'foto_neu'       THEN (SELECT nullif(btrim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')),'') FROM public.personen p WHERE p.id = pf.person_id AND p.geloescht_am IS NULL)
                     WHEN 'geschichte_neu' THEN (SELECT nullif(btrim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')),'') FROM public.personen p WHERE p.id = pg.person_id AND p.geloescht_am IS NULL)
                     WHEN 'beitrag_neu'    THEN (SELECT nullif(btrim(coalesce(p.vorname,'')||' '||coalesce(p.nachname,'')),'') FROM public.personen p WHERE p.id = b.ref_person AND p.geloescht_am IS NULL)
                   END,
      'titel', CASE a.typ
                 WHEN 'event_neu'       THEN ev.titel
                 WHEN 'geschichte_neu'  THEN pg.titel
                 WHEN 'event_foto_neu'  THEN ev2.titel
                 WHEN 'rezept_neu'      THEN fr.titel
                 WHEN 'album_foto_neu'  THEN al2.titel
               END,
      'foto_pfad', CASE a.typ
                     WHEN 'foto_neu'       THEN pf.storage_pfad
                     WHEN 'event_foto_neu' THEN ea.storage_pfad
                   END,
      -- Zielobjekt für Klick: bei Event-Album-Foto das zugehörige Event öffnen.
      'ziel_event', CASE a.typ WHEN 'event_foto_neu' THEN ea.event_id END,
      -- bei Standalone-Album-Foto das Album öffnen (ref_id = album_id).
      'ziel_album', CASE a.typ WHEN 'album_foto_neu' THEN a.ref_id END,
      -- Vorschau: EIN zufälliges BILD des Albums (Videos ausgeschlossen); Frontend signiert die URL.
      'album_foto_pfad', CASE a.typ WHEN 'album_foto_neu' THEN (
                            SELECT m.storage_pfad FROM public.album_medien m
                             WHERE m.album_id = a.ref_id
                               AND coalesce(m.mime,'') NOT LIKE 'video/%'
                             ORDER BY random() LIMIT 1) END,
      -- Beitragsfelder (nur beitrag_neu) — Frontend reused feedBeitragHtml
      'text', CASE a.typ WHEN 'beitrag_neu' THEN b.text END,
      'bild_url', CASE a.typ WHEN 'beitrag_neu' THEN b.bild_url END,
      'bearbeitet_am', CASE a.typ WHEN 'beitrag_neu' THEN b.bearbeitet_am END,
      'darf_bearbeiten', (a.typ = 'beitrag_neu' AND b.autor = auth.uid()),
      'darf_loeschen',   (a.typ = 'beitrag_neu' AND (b.autor = auth.uid() OR public.darf_verbund_moderieren(a.verbund_id))),
      -- NEU: Feed-Eintrag selbst entfernen (Objekt bleibt) — nur Verbund-Moderatoren, ALLE Typen.
      'darf_eintrag_loeschen', public.darf_verbund_moderieren(a.verbund_id)
    ) AS j, a.erstellt_am
    FROM public.aktivitaeten a
    LEFT JOIN auth.users au       ON au.id = a.akteur_id
    LEFT JOIN public.profile apr  ON apr.user_id = a.akteur_id
    LEFT JOIN public.beitraege b             ON a.typ = 'beitrag_neu'     AND b.id = a.ref_id AND b.geloescht = false
    LEFT JOIN public.personen_fotos pf       ON a.typ = 'foto_neu'        AND pf.id = a.ref_id
    LEFT JOIN public.personen_geschichten pg ON a.typ = 'geschichte_neu'  AND pg.id = a.ref_id
    LEFT JOIN public.events ev               ON a.typ = 'event_neu'       AND ev.id = a.ref_id
    LEFT JOIN public.event_album_fotos ea    ON a.typ = 'event_foto_neu'  AND ea.id = a.ref_id
    LEFT JOIN public.events ev2              ON a.typ = 'event_foto_neu'  AND ev2.id = ea.event_id
    LEFT JOIN public.familien_rezepte fr     ON a.typ = 'rezept_neu'      AND fr.id = a.ref_id AND fr.geloescht = false
    LEFT JOIN public.alben al2               ON a.typ = 'album_foto_neu'  AND al2.id = a.ref_id
    WHERE public.ist_in_verbund(a.verbund_id)
      AND (p_vor IS NULL OR a.erstellt_am < p_vor)
      AND (
            (a.typ = 'beitrag_neu'     AND b.id  IS NOT NULL)
         OR (a.typ = 'foto_neu'        AND pf.id IS NOT NULL)
         OR (a.typ = 'geschichte_neu'  AND pg.id IS NOT NULL)
         OR (a.typ = 'event_neu'       AND ev.id IS NOT NULL)
         OR (a.typ = 'event_foto_neu'  AND ea.id IS NOT NULL)
         OR (a.typ = 'rezept_neu'      AND fr.id IS NOT NULL)
         OR (a.typ = 'album_foto_neu'  AND al2.id IS NOT NULL)
         OR (a.typ = 'familie_geaendert')
         OR (a.typ = 'person_neu'      AND EXISTS (SELECT 1 FROM public.personen p WHERE p.id = a.ref_id AND p.geloescht_am IS NULL AND coalesce(p.stammbaum_daten->>'platzhalter','') <> 'true'))
         OR (a.typ IN ('geburtstag','erinnerung'))
      )
    ORDER BY a.erstellt_am DESC
    LIMIT greatest(1, least(coalesce(p_limit, 20), 50))
  ) s;
$$;
GRANT EXECUTE ON FUNCTION public.aktivitaeten_holen(int, timestamptz) TO authenticated;


-- =====================================================
-- 4) RPC: Admin-Löschung EINES Feed-Eintrags (Objekt bleibt unberührt)
--    Nur darf_verbund_moderieren (Owner/Admin/Super-Admin des Verbunds).
-- =====================================================
CREATE OR REPLACE FUNCTION public.aktivitaet_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verb uuid;
BEGIN
  SELECT verbund_id INTO v_verb FROM public.aktivitaeten WHERE id = p_id;
  IF v_verb IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden');
  END IF;
  IF NOT public.darf_verbund_moderieren(v_verb) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  DELETE FROM public.aktivitaeten WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.aktivitaet_loeschen(uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_aktivitaeten_erweitert.sql ausgeführt — Typen event_foto_neu/rezept_neu/familie_geaendert/album_foto_neu + Trigger + aktivitaeten_holen erweitert + aktivitaet_loeschen (Moderatoren)' AS status;
