-- =====================================================
-- TERMINFINDUNG (Doodle-Prinzip) — mehrere Datumsvorschläge, Familie stimmt ab,
-- bester Termin wird zum echten Event. Ausführen in: Supabase -> SQL Editor.
-- Idempotent. SETZT supabase_verbund.sql (sieht_familie/kann_familie_bearbeiten),
-- supabase_reaktionen_kommentare.sql (ist_in_verbund) und das Event-System
-- (event_speichern) VORAUS. VERBUND-GEBUNDEN; Schreiben nur über SECURITY-DEFINER-RPCs.
-- =====================================================

-- 1) Tabellen ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.terminfindung (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id   uuid NOT NULL,
  stammbaum_id uuid NOT NULL REFERENCES public.stammbaeume(id) ON DELETE CASCADE,
  familie_id   uuid NOT NULL,
  titel        text NOT NULL,
  beschreibung text,
  ersteller    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status       text NOT NULL DEFAULT 'offen' CHECK (status IN ('offen','entschieden','abgesagt')),
  event_id     uuid REFERENCES public.events(id) ON DELETE SET NULL,
  gewinner_option uuid,
  eingeschraenkt boolean NOT NULL DEFAULT false,   -- true = nur eingeladene Konten dürfen sehen/abstimmen
  erstellt_am  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS terminfindung_tree_idx ON public.terminfindung(stammbaum_id);
-- Falls die Tabelle aus einer früheren Version ohne die Spalte existiert:
ALTER TABLE public.terminfindung ADD COLUMN IF NOT EXISTS eingeschraenkt boolean NOT NULL DEFAULT false;

-- Eingeladene Konten (nur relevant, wenn eingeschraenkt = true) ----------------
CREATE TABLE IF NOT EXISTS public.terminfindung_eingeladene (
  terminfindung_id uuid NOT NULL REFERENCES public.terminfindung(id) ON DELETE CASCADE,
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (terminfindung_id, user_id)
);
ALTER TABLE public.terminfindung_eingeladene ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.terminfindung_option (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  terminfindung_id uuid NOT NULL REFERENCES public.terminfindung(id) ON DELETE CASCADE,
  datum            date NOT NULL,
  uhrzeit          text,
  sortierung       int NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS terminfindung_option_tf_idx ON public.terminfindung_option(terminfindung_id);

CREATE TABLE IF NOT EXISTS public.terminfindung_stimme (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  option_id        uuid NOT NULL REFERENCES public.terminfindung_option(id) ON DELETE CASCADE,
  terminfindung_id uuid NOT NULL REFERENCES public.terminfindung(id) ON DELETE CASCADE,
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stimme           text NOT NULL CHECK (stimme IN ('ja','vielleicht','nein')),
  UNIQUE (option_id, user_id)
);
CREATE INDEX IF NOT EXISTS terminfindung_stimme_tf_idx ON public.terminfindung_stimme(terminfindung_id);

-- RLS an, KEINE Policies -> Zugriff ausschließlich über die SECURITY-DEFINER-RPCs unten.
ALTER TABLE public.terminfindung         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.terminfindung_option  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.terminfindung_stimme  ENABLE ROW LEVEL SECURITY;


-- Sichtbarkeit/Stimmrecht einer Umfrage (analog darf_event_sehen):
-- offen -> jeder im Verbund; eingeschränkt -> nur Ersteller/Admin/Eingeladene.
CREATE OR REPLACE FUNCTION public.darf_terminfindung_sehen(p_tf uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.terminfindung tf
    WHERE tf.id = p_tf
      AND public.ist_in_verbund(tf.verbund_id)
      AND (
        NOT tf.eingeschraenkt
        OR tf.ersteller = auth.uid()
        OR public.kann_familie_bearbeiten(tf.familie_id)
        OR EXISTS (SELECT 1 FROM public.terminfindung_eingeladene te
                    WHERE te.terminfindung_id = tf.id AND te.user_id = auth.uid())
      )
  );
$$;
GRANT EXECUTE ON FUNCTION public.darf_terminfindung_sehen(uuid) TO authenticated;


-- 2) Liste der Umfragen eines Baums (verbund-sichtbar) ------------------------
CREATE OR REPLACE FUNCTION public.terminfindungen_liste(p_tree uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_fam uuid; v_out jsonb;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT public.sieht_familie(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', tf.id, 'titel', tf.titel, 'status', tf.status, 'event_id', tf.event_id,
           'erstellt_am', tf.erstellt_am,
           'ersteller_name', nullif(trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')),''),
           'optionen', (SELECT count(*) FROM public.terminfindung_option o WHERE o.terminfindung_id = tf.id),
           'stimmen', (SELECT count(DISTINCT s.user_id) FROM public.terminfindung_stimme s WHERE s.terminfindung_id = tf.id)
         ) ORDER BY tf.erstellt_am DESC), '[]'::jsonb)
    INTO v_out
    FROM public.terminfindung tf
    LEFT JOIN public.profile pr ON pr.user_id = tf.ersteller
   WHERE tf.stammbaum_id = p_tree AND public.darf_terminfindung_sehen(tf.id);
  RETURN v_out;
END $$;
GRANT EXECUTE ON FUNCTION public.terminfindungen_liste(uuid) TO authenticated;


-- 3) Umfrage erstellen (jeder Verbund-Nutzer mit Baum-Sicht) ------------------
DROP FUNCTION IF EXISTS public.terminfindung_erstellen(uuid, text, text, jsonb);
CREATE OR REPLACE FUNCTION public.terminfindung_erstellen(
  p_tree uuid, p_titel text, p_beschreibung text, p_optionen jsonb,
  p_eingeladene uuid[] DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_verbund uuid; v_id uuid; v_n int;
BEGIN
  SELECT familie_id INTO v_fam FROM public.stammbaeume WHERE id = p_tree;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'Stammbaum nicht gefunden.'; END IF;
  IF NOT public.sieht_familie(v_fam) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  IF coalesce(trim(p_titel),'') = '' THEN RAISE EXCEPTION 'Titel ist erforderlich.'; END IF;
  SELECT verbund_id INTO v_verbund FROM public.familien WHERE id = v_fam;

  SELECT count(*) INTO v_n FROM jsonb_array_elements(coalesce(p_optionen,'[]'::jsonb)) e
   WHERE nullif(e->>'datum','') IS NOT NULL;
  IF v_n < 2 THEN RAISE EXCEPTION 'Mindestens zwei Datumsvorschläge nötig.'; END IF;

  INSERT INTO public.terminfindung (verbund_id, stammbaum_id, familie_id, titel, beschreibung, ersteller, eingeschraenkt)
  VALUES (v_verbund, p_tree, v_fam, trim(p_titel), nullif(trim(coalesce(p_beschreibung,'')),''), auth.uid(),
          (p_eingeladene IS NOT NULL AND array_length(p_eingeladene,1) > 0))
  RETURNING id INTO v_id;

  INSERT INTO public.terminfindung_option (terminfindung_id, datum, uhrzeit, sortierung)
  SELECT v_id, (e->>'datum')::date, nullif(trim(coalesce(e->>'uhrzeit','')),''), (ord - 1)::int
    FROM jsonb_array_elements(p_optionen) WITH ORDINALITY AS t(e, ord)
   WHERE nullif(e->>'datum','') IS NOT NULL;

  -- Eingeladene (nur gültige Verbund-Konten) + Benachrichtigung
  IF p_eingeladene IS NOT NULL AND array_length(p_eingeladene,1) > 0 THEN
    INSERT INTO public.terminfindung_eingeladene (terminfindung_id, user_id)
    SELECT DISTINCT v_id, m.user_id
      FROM unnest(p_eingeladene) AS inp(uid)
      JOIN public.mitgliedschaften m ON m.user_id = inp.uid
      JOIN public.familien f ON f.id = m.familie_id
     WHERE f.verbund_id = v_verbund AND m.user_id <> auth.uid()
    ON CONFLICT DO NOTHING;

    INSERT INTO public.benachrichtigungen (user_id, typ, titel, text)
    SELECT te.user_id, 'termin_einladung', trim(p_titel), v_id::text
      FROM public.terminfindung_eingeladene te WHERE te.terminfindung_id = v_id;
  END IF;

  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.terminfindung_erstellen(uuid, text, text, jsonb, uuid[]) TO authenticated;


-- 4) Umfrage + Stimmen laden ---------------------------------------------------
CREATE OR REPLACE FUNCTION public.terminfindung_holen(p_tf uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_fam uuid; v_rec record; v_opt jsonb;
BEGIN
  SELECT * INTO v_rec FROM public.terminfindung WHERE id = p_tf;
  IF v_rec.id IS NULL THEN RAISE EXCEPTION 'Umfrage nicht gefunden.'; END IF;
  IF NOT public.darf_terminfindung_sehen(p_tf) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', o.id, 'datum', o.datum, 'uhrzeit', o.uhrzeit,
           'ja',        (SELECT count(*) FROM public.terminfindung_stimme s WHERE s.option_id = o.id AND s.stimme = 'ja'),
           'vielleicht',(SELECT count(*) FROM public.terminfindung_stimme s WHERE s.option_id = o.id AND s.stimme = 'vielleicht'),
           'nein',      (SELECT count(*) FROM public.terminfindung_stimme s WHERE s.option_id = o.id AND s.stimme = 'nein'),
           'meine',     (SELECT s.stimme FROM public.terminfindung_stimme s WHERE s.option_id = o.id AND s.user_id = auth.uid())
         ) ORDER BY o.sortierung, o.datum), '[]'::jsonb)
    INTO v_opt
    FROM public.terminfindung_option o WHERE o.terminfindung_id = p_tf;

  RETURN jsonb_build_object(
    'id', v_rec.id, 'titel', v_rec.titel, 'beschreibung', v_rec.beschreibung,
    'status', v_rec.status, 'event_id', v_rec.event_id, 'gewinner_option', v_rec.gewinner_option,
    'darf_entscheiden', public.kann_familie_bearbeiten(v_rec.familie_id),
    'darf_verwalten', (v_rec.ersteller = auth.uid() OR public.kann_familie_bearbeiten(v_rec.familie_id)),
    'eingeschraenkt', v_rec.eingeschraenkt,
    'eingeladene', (SELECT count(*) FROM public.terminfindung_eingeladene te WHERE te.terminfindung_id = p_tf),
    'optionen', v_opt);
END $$;
GRANT EXECUTE ON FUNCTION public.terminfindung_holen(uuid) TO authenticated;


-- 5) Abstimmen (eigene Stimmen je Option setzen) ------------------------------
CREATE OR REPLACE FUNCTION public.terminfindung_abstimmen(p_tf uuid, p_stimmen jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rec record;
BEGIN
  SELECT * INTO v_rec FROM public.terminfindung WHERE id = p_tf;
  IF v_rec.id IS NULL THEN RAISE EXCEPTION 'Umfrage nicht gefunden.'; END IF;
  IF NOT public.darf_terminfindung_sehen(p_tf) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  IF v_rec.status <> 'offen' THEN RAISE EXCEPTION 'Umfrage ist abgeschlossen.'; END IF;

  INSERT INTO public.terminfindung_stimme (option_id, terminfindung_id, user_id, stimme)
  SELECT (e->>'option_id')::uuid, p_tf, auth.uid(), e->>'stimme'
    FROM jsonb_array_elements(coalesce(p_stimmen,'[]'::jsonb)) e
   WHERE e->>'stimme' IN ('ja','vielleicht','nein')
     AND EXISTS (SELECT 1 FROM public.terminfindung_option o
                  WHERE o.id = (e->>'option_id')::uuid AND o.terminfindung_id = p_tf)
  ON CONFLICT (option_id, user_id) DO UPDATE SET stimme = excluded.stimme;

  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.terminfindung_abstimmen(uuid, jsonb) TO authenticated;


-- 6) Entscheiden: Gewinner-Option -> echtes Event (nur Admin/Owner) -----------
CREATE OR REPLACE FUNCTION public.terminfindung_entscheiden(p_tf uuid, p_option uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rec record; v_opt record; v_event uuid;
BEGIN
  SELECT * INTO v_rec FROM public.terminfindung WHERE id = p_tf;
  IF v_rec.id IS NULL THEN RAISE EXCEPTION 'Umfrage nicht gefunden.'; END IF;
  IF NOT public.kann_familie_bearbeiten(v_rec.familie_id) THEN RAISE EXCEPTION 'Keine Berechtigung.'; END IF;
  SELECT * INTO v_opt FROM public.terminfindung_option WHERE id = p_option AND terminfindung_id = p_tf;
  IF v_opt.id IS NULL THEN RAISE EXCEPTION 'Option nicht gefunden.'; END IF;

  -- Gewinner-Termin als echtes Event anlegen (event_speichern prüft Rechte erneut).
  v_event := public.event_speichern(
    NULL, v_rec.stammbaum_id, v_rec.titel, v_rec.beschreibung,
    to_char(v_opt.datum, 'YYYY-MM-DD'), NULL, NULL, 'de', NULL,
    NULL, NULL, NULL, v_opt.uhrzeit, NULL, 'Europe/Belgrade');

  UPDATE public.terminfindung
     SET status = 'entschieden', event_id = v_event, gewinner_option = p_option
   WHERE id = p_tf;

  -- Abstimmende benachrichtigen (außer mir)
  INSERT INTO public.benachrichtigungen (user_id, typ, titel, text, event_id)
  SELECT DISTINCT s.user_id, 'termin_entschieden', v_rec.titel, to_char(v_opt.datum,'YYYY-MM-DD'), v_event
    FROM public.terminfindung_stimme s
   WHERE s.terminfindung_id = p_tf AND s.user_id <> auth.uid();

  RETURN v_event;
END $$;
GRANT EXECUTE ON FUNCTION public.terminfindung_entscheiden(uuid, uuid) TO authenticated;


-- 7) Umfrage löschen (Ersteller ODER Admin/Owner) ----------------------------
CREATE OR REPLACE FUNCTION public.terminfindung_loeschen(p_tf uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rec record;
BEGIN
  SELECT * INTO v_rec FROM public.terminfindung WHERE id = p_tf;
  IF v_rec.id IS NULL THEN RETURN false; END IF;
  IF NOT (v_rec.ersteller = auth.uid() OR public.kann_familie_bearbeiten(v_rec.familie_id)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  DELETE FROM public.terminfindung WHERE id = p_tf;   -- Optionen/Stimmen per CASCADE
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.terminfindung_loeschen(uuid) TO authenticated;


-- 8) Kandidaten (Verbund-Konten + eingeladen-Flag) — nur Ersteller/Admin -------
CREATE OR REPLACE FUNCTION public.terminfindung_kandidaten(p_tf uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_rec record; v_out jsonb;
BEGIN
  SELECT * INTO v_rec FROM public.terminfindung WHERE id = p_tf;
  IF v_rec.id IS NULL THEN RAISE EXCEPTION 'Umfrage nicht gefunden.'; END IF;
  IF NOT (v_rec.ersteller = auth.uid() OR public.kann_familie_bearbeiten(v_rec.familie_id)) THEN
    RETURN '[]'::jsonb;
  END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'user_id', k.user_id,
           'name', nullif(trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')),''),
           'email', u.email,
           'eingeladen', EXISTS (SELECT 1 FROM public.terminfindung_eingeladene te
                                  WHERE te.terminfindung_id = p_tf AND te.user_id = k.user_id)
         ) ORDER BY pr.nachname, pr.vorname, u.email), '[]'::jsonb)
    INTO v_out
    FROM (SELECT DISTINCT m.user_id FROM public.mitgliedschaften m
            JOIN public.familien f ON f.id = m.familie_id
           WHERE f.verbund_id = v_rec.verbund_id AND m.rolle <> 'super_admin'
             AND m.user_id <> auth.uid()) k
    JOIN auth.users u ON u.id = k.user_id
    LEFT JOIN public.profile pr ON pr.user_id = k.user_id;
  RETURN v_out;
END $$;
GRANT EXECUTE ON FUNCTION public.terminfindung_kandidaten(uuid) TO authenticated;


-- 9) Einladungen setzen (idempotent) + neue benachrichtigen — Ersteller/Admin --
CREATE OR REPLACE FUNCTION public.terminfindung_einladen(p_tf uuid, p_user_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rec record; v_neu int;
BEGIN
  SELECT * INTO v_rec FROM public.terminfindung WHERE id = p_tf;
  IF v_rec.id IS NULL THEN RAISE EXCEPTION 'Umfrage nicht gefunden.'; END IF;
  IF NOT (v_rec.ersteller = auth.uid() OR public.kann_familie_bearbeiten(v_rec.familie_id)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  CREATE TEMP TABLE _gueltig ON COMMIT DROP AS
    SELECT DISTINCT m.user_id
      FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) AS inp(uid)
      JOIN public.mitgliedschaften m ON m.user_id = inp.uid
      JOIN public.familien f ON f.id = m.familie_id
     WHERE f.verbund_id = v_rec.verbund_id AND m.user_id <> auth.uid();

  CREATE TEMP TABLE _neu ON COMMIT DROP AS
    SELECT g.user_id FROM _gueltig g
     WHERE NOT EXISTS (SELECT 1 FROM public.terminfindung_eingeladene te
                        WHERE te.terminfindung_id = p_tf AND te.user_id = g.user_id);

  DELETE FROM public.terminfindung_eingeladene te
   WHERE te.terminfindung_id = p_tf
     AND NOT EXISTS (SELECT 1 FROM _gueltig g WHERE g.user_id = te.user_id);

  INSERT INTO public.terminfindung_eingeladene (terminfindung_id, user_id)
  SELECT p_tf, g.user_id FROM _gueltig g ON CONFLICT DO NOTHING;

  UPDATE public.terminfindung
     SET eingeschraenkt = EXISTS (SELECT 1 FROM public.terminfindung_eingeladene te WHERE te.terminfindung_id = p_tf)
   WHERE id = p_tf;

  INSERT INTO public.benachrichtigungen (user_id, typ, titel, text)
  SELECT n.user_id, 'termin_einladung', v_rec.titel, p_tf::text FROM _neu n;

  SELECT count(*) INTO v_neu FROM _neu;
  RETURN jsonb_build_object('ok', true, 'neu', v_neu);
END $$;
GRANT EXECUTE ON FUNCTION public.terminfindung_einladen(uuid, uuid[]) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'OK: terminfindung + option + stimme + RPCs (liste/erstellen/holen/abstimmen/entscheiden/loeschen) angelegt' AS status;
