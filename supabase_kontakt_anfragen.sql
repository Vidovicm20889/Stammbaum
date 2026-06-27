-- =====================================================
-- KONTAKT- & BAUMZUGRIFF-ANFRAGEN (Stufe 2 + 3 von 3)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run).
-- IDEMPOTENT. NACH supabase_auffindbarkeit.sql ausführen (nutzt _person_entdeckbar).
--
-- FEATURE "verbundübergreifende Personensuche + Kontaktanfragen" (Instagram-Prinzip):
--   Stufe 1 ENTDECKEN     -> supabase_auffindbarkeit.sql (personen_entdecken)
--   Stufe 2 KONTAKT       -> Kontaktanfrage an den Familien-Admin der Zielperson; Genehmigung
--                            erlaubt NUR verbundübergreifenden CHAT zwischen genau 2 Konten.
--   Stufe 3 BAUMZUGRIFF   -> SEPARATE, zweite Anfrage + zweite Admin-Genehmigung; erlaubt NUR
--                            LESEZUGRIFF auf EINEN bestimmten Stammbaum (baum_freigaben).
--
-- SICHERHEIT (hart):
--   * Stufe 2 ändert KEINE RLS auf Baumdaten -> NUR eine Chat-Verbindung (kontakt_verbindungen).
--   * Stufe 3 (baum_freigaben) ist die ZWEITE und letzte verbundübergreifende Bruchstelle; die
--     RLS-Erweiterung dafür liegt in supabase_baum_freigaben_rls.sql (lesend, ein Baum,
--     jederzeit widerrufbar).
--   * Entscheider ist AUSSCHLIESSLICH der Familien-Admin/Owner/Super-Admin der Zielfamilie
--     (kann_familie_bearbeiten). Ein familien_mitglied (Lesezugriff) wird NIE Entscheider.
--   * Kontaktanfrage ist nur auf eine ENTDECKBARE Karte MIT Konto möglich (_person_entdeckbar
--     + personen.user_id), damit niemand über die RPC eine verborgene Person kontaktiert.
--
-- Admin-Benachrichtigung = Polling-Muster wie offene_anfragen() (offene_kontakt_anfragen()).
-- Antragsteller-Ergebnis = Zeile in benachrichtigungen (typ kontakt_*/baumzugriff_*).
--
-- Voraussetzungen: supabase_verbund.sql (verbund_id, sieht_familie, kann_familie_bearbeiten,
--   ist_super_admin), supabase_auffindbarkeit.sql (_person_entdeckbar),
--   supabase_benachrichtigungen.sql (benachrichtigungen), supabase_profile.sql (profile).
-- =====================================================


-- =====================================================
-- 1) TABELLEN
-- =====================================================

-- 1a) Anfragen (Kontakt UND Baumzugriff, getrennt über typ).
CREATE TABLE IF NOT EXISTS public.kontakt_anfragen (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  von_user          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ziel_person_id    uuid NOT NULL REFERENCES public.personen(id) ON DELETE CASCADE,
  ziel_familie_id   uuid NOT NULL REFERENCES public.familien(id) ON DELETE CASCADE,
  ziel_verbund_id   uuid NOT NULL,
  typ               text NOT NULL CHECK (typ IN ('kontakt', 'baumzugriff')),
  ziel_stammbaum_id uuid REFERENCES public.stammbaeume(id) ON DELETE CASCADE,  -- nur baumzugriff
  nachricht         text,
  status            text NOT NULL DEFAULT 'offen'
                      CHECK (status IN ('offen', 'genehmigt', 'abgelehnt', 'zurueckgezogen')),
  entschieden_von   uuid REFERENCES auth.users(id),
  erstellt_am       timestamptz NOT NULL DEFAULT now(),
  entschieden_am    timestamptz,
  -- baumzugriff MUSS einen Baum nennen, kontakt darf keinen nennen
  CONSTRAINT kontakt_anfragen_baum_chk CHECK ((typ = 'baumzugriff') = (ziel_stammbaum_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS kontakt_anfragen_ziel_fam_idx
  ON public.kontakt_anfragen (ziel_familie_id, status);
CREATE INDEX IF NOT EXISTS kontakt_anfragen_von_idx
  ON public.kontakt_anfragen (von_user, status);
-- Keine doppelte OFFENE Anfrage desselben Typs vom selben Nutzer auf dieselbe Karte.
CREATE UNIQUE INDEX IF NOT EXISTS kontakt_anfragen_offen_uidx
  ON public.kontakt_anfragen (von_user, ziel_person_id, typ) WHERE status = 'offen';

-- 1b) Genehmigte Kontakt-Verbindung (erlaubt verbundübergreifenden Chat genau dieser 2 Konten).
--     Sortiertes Paar (user_a < user_b) -> genau EINE Zeile je Paar.
CREATE TABLE IF NOT EXISTS public.kontakt_verbindungen (
  user_a      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_b      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  erstellt_am timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_a, user_b),
  CONSTRAINT kontakt_verbindungen_sortiert_chk CHECK (user_a < user_b)
);

-- 1c) Baum-Freigabe (LESEZUGRIFF auf EINEN Stammbaum; jederzeit widerrufbar).
CREATE TABLE IF NOT EXISTS public.baum_freigaben (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stammbaum_id uuid NOT NULL REFERENCES public.stammbaeume(id) ON DELETE CASCADE,
  gewaehrt_von uuid REFERENCES auth.users(id),
  status       text NOT NULL DEFAULT 'aktiv' CHECK (status IN ('aktiv', 'widerrufen')),
  erstellt_am  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, stammbaum_id)
);
CREATE INDEX IF NOT EXISTS baum_freigaben_user_idx
  ON public.baum_freigaben (user_id) WHERE status = 'aktiv';


-- =====================================================
-- 2) RLS  (Schreiben läuft ausschließlich über die SECURITY-DEFINER-RPCs unten)
-- =====================================================
ALTER TABLE public.kontakt_anfragen     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kontakt_verbindungen ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.baum_freigaben       ENABLE ROW LEVEL SECURITY;

-- kontakt_anfragen: Antragsteller sieht seine eigenen; Ziel-Familien-Admin sieht eingehende.
DROP POLICY IF EXISTS "ka_select" ON public.kontakt_anfragen;
CREATE POLICY "ka_select" ON public.kontakt_anfragen FOR SELECT TO authenticated
  USING ( von_user = auth.uid()
          OR public.ist_super_admin()
          OR public.kann_familie_bearbeiten(ziel_familie_id) );

-- kontakt_verbindungen: nur die beiden Beteiligten sehen ihre Zeile.
DROP POLICY IF EXISTS "kv_select" ON public.kontakt_verbindungen;
CREATE POLICY "kv_select" ON public.kontakt_verbindungen FOR SELECT TO authenticated
  USING ( auth.uid() = user_a OR auth.uid() = user_b );

-- baum_freigaben: der Begünstigte sieht seine; der Admin des Baum-Verbunds sieht seine vergebenen.
DROP POLICY IF EXISTS "bf_select" ON public.baum_freigaben;
CREATE POLICY "bf_select" ON public.baum_freigaben FOR SELECT TO authenticated
  USING ( user_id = auth.uid()
          OR public.ist_super_admin()
          OR public.kann_familie_bearbeiten(
               (SELECT s.familie_id FROM public.stammbaeume s WHERE s.id = baum_freigaben.stammbaum_id) ) );
-- (KEINE INSERT/UPDATE/DELETE-Policies -> nur die RPCs unten schreiben.)


-- =====================================================
-- 3) HELFER (SECURITY DEFINER -> rekursionsfrei; in RLS-Policies einsetzbar)
-- =====================================================

-- 3a) Darf der eingeloggte Nutzer diesen Stammbaum SEHEN? -> Mitgliedschaft (verbund, wie bisher)
--     ODER aktive Baum-Freigabe. (Wird in supabase_baum_freigaben_rls.sql in die SELECT-Policies
--     von personen/stammbaeume eingehängt.)
CREATE OR REPLACE FUNCTION public.darf_baum_sehen(p_stammbaum uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.ist_super_admin()
      OR public.sieht_familie( (SELECT s.familie_id FROM public.stammbaeume s WHERE s.id = p_stammbaum) )
      OR EXISTS (
        SELECT 1 FROM public.baum_freigaben bf
        WHERE bf.stammbaum_id = p_stammbaum
          AND bf.user_id = auth.uid()
          AND bf.status = 'aktiv'
      );
$$;

-- 3b) Darf der eingeloggte Nutzer diese BEZIEHUNG sehen? -> nur wenn BEIDE Endpunkt-Personen
--     sichtbar sind (sonst würde eine Baum-Freigabe für Baum X eine Kante zu einer Person in
--     Baum Y leaken). beziehungen hat KEIN stammbaum_id -> Sicht über die Endpunkte.
CREATE OR REPLACE FUNCTION public.darf_beziehung_sehen(p_a uuid, p_b uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.ist_super_admin()
      OR (
        coalesce((SELECT public.darf_baum_sehen(p.stammbaum_id) FROM public.personen p WHERE p.id = p_a AND p.geloescht_am IS NULL), false)
        AND
        coalesce((SELECT public.darf_baum_sehen(p.stammbaum_id) FROM public.personen p WHERE p.id = p_b AND p.geloescht_am IS NULL), false)
      );
$$;

-- 3c) Darf der eingeloggte Nutzer p_user ANSCHREIBEN? -> gemeinsamer Verbund (wie bisher)
--     ODER genehmigte Kontakt-Verbindung. (Wird in supabase_chat.sql verwendet.)
CREATE OR REPLACE FUNCTION public.darf_chatten(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.teilt_verbund(p_user)
      OR EXISTS (
        SELECT 1 FROM public.kontakt_verbindungen kv
        WHERE (kv.user_a = auth.uid() AND kv.user_b = p_user)
           OR (kv.user_a = p_user     AND kv.user_b = auth.uid())
      );
$$;


-- =====================================================
-- 4) RPCs
-- =====================================================

-- 4a) Anfrage STELLEN (Kontakt ODER Baumzugriff).
--     - kontakt:     nur auf entdeckbare Karte MIT Konto in FREMDEM Verbund; legt eine offene
--                    Anfrage an die Ziel-Familien-Admins an.
--     - baumzugriff: setzt eine bereits GENEHMIGTE Kontakt-Verbindung voraus; Zielbaum =
--                    der Baum, in dem die entdeckte Person liegt (v1-Grenze, dokumentiert).
CREATE OR REPLACE FUNCTION public.kontakt_anfrage_stellen(
  p_ziel_person uuid, p_typ text, p_nachricht text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me      uuid := auth.uid();
  v_fam     uuid; v_baum uuid; v_ziel_user uuid; v_verb uuid;
  v_neu     uuid;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF p_ziel_person IS NULL OR p_typ NOT IN ('kontakt','baumzugriff') THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'parameter');
  END IF;

  SELECT pe.familie_id, pe.stammbaum_id, pe.user_id, f.verbund_id
    INTO v_fam, v_baum, v_ziel_user, v_verb
    FROM public.personen pe JOIN public.familien f ON f.id = pe.familie_id
   WHERE pe.id = p_ziel_person AND pe.geloescht_am IS NULL;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'person_fehlt'); END IF;

  -- HART: die Karte muss für mich entdeckbar sein (fremder Verbund + lebend/minderjährig/opt-in).
  IF NOT public._person_entdeckbar(p_ziel_person) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'nicht_entdeckbar');
  END IF;
  -- Kontakt/Chat geht nur, wenn hinter der Karte ein Konto steht.
  IF v_ziel_user IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'kein_konto');
  END IF;
  IF v_ziel_user = v_me THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'eigene_karte');
  END IF;

  IF p_typ = 'baumzugriff' THEN
    -- Stufe 3 setzt eine bestehende, genehmigte Kontakt-Verbindung voraus.
    IF NOT EXISTS (
      SELECT 1 FROM public.kontakt_verbindungen kv
      WHERE (kv.user_a = LEAST(v_me, v_ziel_user) AND kv.user_b = GREATEST(v_me, v_ziel_user))
    ) THEN
      RETURN jsonb_build_object('ok', false, 'grund', 'kein_kontakt');
    END IF;
    -- Schon Lesezugriff auf den Baum? -> nichts zu tun.
    IF EXISTS (SELECT 1 FROM public.baum_freigaben bf
                WHERE bf.user_id = v_me AND bf.stammbaum_id = v_baum AND bf.status = 'aktiv') THEN
      RETURN jsonb_build_object('ok', false, 'grund', 'schon_freigegeben');
    END IF;
  END IF;

  -- Doppelte offene Anfrage? (idempotent über den partiellen Unique-Index abgesichert)
  IF EXISTS (SELECT 1 FROM public.kontakt_anfragen
              WHERE von_user = v_me AND ziel_person_id = p_ziel_person AND typ = p_typ AND status = 'offen') THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'schon_offen');
  END IF;

  INSERT INTO public.kontakt_anfragen (
    von_user, ziel_person_id, ziel_familie_id, ziel_verbund_id, typ, ziel_stammbaum_id, nachricht)
  VALUES (
    v_me, p_ziel_person, v_fam, v_verb, p_typ,
    CASE WHEN p_typ = 'baumzugriff' THEN v_baum ELSE NULL END,
    nullif(btrim(coalesce(p_nachricht,'')), ''))
  RETURNING id INTO v_neu;

  RETURN jsonb_build_object('ok', true, 'anfrage_id', v_neu, 'typ', p_typ);
END $$;
GRANT EXECUTE ON FUNCTION public.kontakt_anfrage_stellen(uuid, text, text) TO authenticated;


-- 4b) Offene Anfragen für den Admin (Polling-Muster wie offene_anfragen()).
--     Super-Admin sieht alle; sonst nur Familien, die der Nutzer bearbeiten darf.
CREATE OR REPLACE FUNCTION public.offene_kontakt_anfragen()
RETURNS TABLE(
  id uuid, typ text, nachricht text, erstellt_am timestamptz,
  von_user uuid, von_name text, von_avatar text, von_familie text,
  ziel_person_id uuid, ziel_name text, ziel_familie_id uuid, ziel_familie text,
  ziel_stammbaum_id uuid, ziel_baum text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    a.id, a.typ, a.nachricht, a.erstellt_am,
    a.von_user,
    COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''), u.email) AS von_name,
    CASE WHEN COALESCE(pr.avatar_sichtbarkeit,'verbund') <> 'privat'
         THEN COALESCE(pr.avatar_thumb_url, pr.avatar_url) END AS von_avatar,
    (SELECT f2.name FROM public.mitgliedschaften m2
       JOIN public.familien f2 ON f2.id = m2.familie_id
      WHERE m2.user_id = a.von_user ORDER BY f2.name LIMIT 1) AS von_familie,
    a.ziel_person_id,
    trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')) AS ziel_name,
    a.ziel_familie_id, f.name AS ziel_familie,
    a.ziel_stammbaum_id, s.name AS ziel_baum
  FROM public.kontakt_anfragen a
  LEFT JOIN public.personen pe   ON pe.id = a.ziel_person_id
  LEFT JOIN public.familien f    ON f.id = a.ziel_familie_id
  LEFT JOIN public.stammbaeume s ON s.id = a.ziel_stammbaum_id
  LEFT JOIN auth.users u         ON u.id = a.von_user
  LEFT JOIN public.profile pr    ON pr.user_id = a.von_user
  WHERE a.status = 'offen'
    AND (public.ist_super_admin() OR public.kann_familie_bearbeiten(a.ziel_familie_id))
  ORDER BY a.erstellt_am DESC;
$$;
GRANT EXECUTE ON FUNCTION public.offene_kontakt_anfragen() TO authenticated;


-- 4c) Anfrage ENTSCHEIDEN (nur Ziel-Familien-Admin/Owner/Super-Admin).
CREATE OR REPLACE FUNCTION public.kontakt_anfrage_entscheiden(p_id uuid, p_genehmigt boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me   uuid := auth.uid();
  a      public.kontakt_anfragen;
  v_ziel_user uuid;
  v_a uuid; v_b uuid;
  v_pname text; v_bname text;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;

  SELECT * INTO a FROM public.kontakt_anfragen WHERE id = p_id;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF a.status <> 'offen' THEN RETURN jsonb_build_object('ok', false, 'grund', 'schon_entschieden'); END IF;

  -- Entscheider-Recht: NUR Admin/Owner/Super-Admin der Zielfamilie. Mitglied NIE.
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(a.ziel_familie_id)) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;

  -- Anzeige-Infos für die Benachrichtigung
  SELECT trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,'')), pe.user_id
    INTO v_pname, v_ziel_user FROM public.personen pe WHERE pe.id = a.ziel_person_id AND pe.geloescht_am IS NULL;
  SELECT s.name INTO v_bname FROM public.stammbaeume s WHERE s.id = a.ziel_stammbaum_id;

  IF NOT p_genehmigt THEN
    UPDATE public.kontakt_anfragen
       SET status = 'abgelehnt', entschieden_von = v_me, entschieden_am = now()
     WHERE id = p_id;
    INSERT INTO public.benachrichtigungen (user_id, typ, titel, text)
    VALUES (a.von_user,
            CASE WHEN a.typ = 'baumzugriff' THEN 'baumzugriff_abgelehnt' ELSE 'kontakt_abgelehnt' END,
            COALESCE(v_pname, ''), NULL);
    RETURN jsonb_build_object('ok', true, 'status', 'abgelehnt');
  END IF;

  -- GENEHMIGT
  IF a.typ = 'kontakt' THEN
    IF v_ziel_user IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'ziel_ohne_konto'); END IF;
    v_a := LEAST(a.von_user, v_ziel_user);
    v_b := GREATEST(a.von_user, v_ziel_user);
    INSERT INTO public.kontakt_verbindungen (user_a, user_b)
    VALUES (v_a, v_b) ON CONFLICT (user_a, user_b) DO NOTHING;
    INSERT INTO public.benachrichtigungen (user_id, typ, titel, text)
    VALUES (a.von_user, 'kontakt_genehmigt', COALESCE(v_pname, ''), NULL);

  ELSIF a.typ = 'baumzugriff' THEN
    INSERT INTO public.baum_freigaben (user_id, stammbaum_id, gewaehrt_von, status)
    VALUES (a.von_user, a.ziel_stammbaum_id, v_me, 'aktiv')
    ON CONFLICT (user_id, stammbaum_id)
      DO UPDATE SET status = 'aktiv', gewaehrt_von = v_me, erstellt_am = now();
    INSERT INTO public.benachrichtigungen (user_id, typ, titel, text)
    VALUES (a.von_user, 'baumzugriff_genehmigt', COALESCE(v_bname, v_pname, ''), NULL);
  END IF;

  UPDATE public.kontakt_anfragen
     SET status = 'genehmigt', entschieden_von = v_me, entschieden_am = now()
   WHERE id = p_id;

  RETURN jsonb_build_object('ok', true, 'status', 'genehmigt');
END $$;
GRANT EXECUTE ON FUNCTION public.kontakt_anfrage_entscheiden(uuid, boolean) TO authenticated;


-- 4d) Eigene OFFENE Anfrage zurückziehen.
CREATE OR REPLACE FUNCTION public.kontakt_anfrage_zurueckziehen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.kontakt_anfragen
     SET status = 'zurueckgezogen'
   WHERE id = p_id AND von_user = auth.uid() AND status = 'offen';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_moeglich'); END IF;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.kontakt_anfrage_zurueckziehen(uuid) TO authenticated;


-- 4e) Baum-Freigabe WIDERRUFEN (Admin der Baum-Familie / Super-Admin). Wirkt sofort,
--     da darf_baum_sehen live auf status='aktiv' prüft.
CREATE OR REPLACE FUNCTION public.baum_freigabe_widerrufen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid;
BEGIN
  SELECT s.familie_id INTO v_fam
    FROM public.baum_freigaben bf JOIN public.stammbaeume s ON s.id = bf.stammbaum_id
   WHERE bf.id = p_id;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_gefunden'); END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_berechtigung');
  END IF;
  UPDATE public.baum_freigaben SET status = 'widerrufen' WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.baum_freigabe_widerrufen(uuid) TO authenticated;


-- 4f) Kontakt-Verbindung ENTFERNEN (beide Beteiligten dürfen). Beendet die Chat-Erlaubnis;
--     bestehende baum_freigaben bleiben (separat widerrufbar).
CREATE OR REPLACE FUNCTION public.kontakt_verbindung_entfernen(p_other uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL OR p_other IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'parameter'); END IF;
  DELETE FROM public.kontakt_verbindungen
   WHERE user_a = LEAST(v_me, p_other) AND user_b = GREATEST(v_me, p_other);
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION public.kontakt_verbindung_entfernen(uuid) TO authenticated;


-- 4g) Meine genehmigten Kontakte (für den Chat-Partner-Picker; ergänzt verbund_nutzer()).
--     Liefert pro verbundenem Konto Anzeigename/Avatar/Familie.
CREATE OR REPLACE FUNCTION public.meine_kontakte()
RETURNS TABLE(user_id uuid, anzeigename text, avatar_url text, familie_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH partner AS (
    SELECT CASE WHEN kv.user_a = auth.uid() THEN kv.user_b ELSE kv.user_a END AS uid
    FROM public.kontakt_verbindungen kv
    WHERE kv.user_a = auth.uid() OR kv.user_b = auth.uid()
  )
  SELECT
    p.uid AS user_id,
    COALESCE(NULLIF(btrim(concat_ws(' ', pr.vorname, pr.nachname)), ''), u.email) AS anzeigename,
    CASE WHEN COALESCE(pr.avatar_sichtbarkeit,'verbund') <> 'privat'
         THEN COALESCE(pr.avatar_thumb_url, pr.avatar_url) END AS avatar_url,
    (SELECT f.name FROM public.mitgliedschaften m
       JOIN public.familien f ON f.id = m.familie_id
      WHERE m.user_id = p.uid ORDER BY f.name LIMIT 1) AS familie_name
  FROM partner p
  JOIN auth.users u ON u.id = p.uid
  LEFT JOIN public.profile pr ON pr.user_id = p.uid
  ORDER BY anzeigename;
$$;
GRANT EXECUTE ON FUNCTION public.meine_kontakte() TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_kontakt_anfragen.sql ausgeführt — kontakt_anfragen/kontakt_verbindungen/baum_freigaben + Helfer (darf_baum_sehen/darf_beziehung_sehen/darf_chatten) + RPCs' AS status;
