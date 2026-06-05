-- =====================================================
-- FAMILIEN-OWNER WECHSELN (nur Super-Admin)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Der Super-Admin kann den familien_owner eines Stammbaums gezielt übertragen.
-- Der Owner hängt an der FAMILIE (mitgliedschaften.familie_id), nicht am
-- einzelnen Baum -> ein Wechsel gilt für ALLE Bäume dieser Familie.
--
-- Ablauf von stammbaum_owner_wechseln():
--   * neuer Nutzer  -> Rolle familien_owner (Mitgliedschaft wird bei Bedarf
--                       angelegt; auto=false = manuell, vor Blutlinien-Recompute
--                       geschützt, siehe rechte_neu_berechnen)
--   * alter Owner   -> automatisch zurück auf familien_admin (auto=false)
--   * Protokoll      -> public.familien_audit (aktion='owner_wechsel'):
--                       Stammbaum, alter/neuer Owner, Datum, ausführender Admin
--
-- Voraussetzung: ist_super_admin() (mitglieder_komplett),
--   familien_audit (familie_einstellungen), UNIQUE(user_id, familie_id) auf
--   mitgliedschaften (supabase_mitglieder.sql), Spalte auto (blutlinie_rechte).
-- =====================================================

-- 1) Aktueller Owner + letzte Änderung (Super-Admin) -----------------
DROP FUNCTION IF EXISTS public.stammbaum_owner_info(uuid);
CREATE OR REPLACE FUNCTION public.stammbaum_owner_info(p_stammbaum_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_fam_name text; v_owner record; v_letzte record;
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'owner_keine_berechtigung'; END IF;
  IF p_stammbaum_id IS NULL THEN RAISE EXCEPTION 'owner_keine_familie'; END IF;

  SELECT s.familie_id, f.name INTO v_fam, v_fam_name
    FROM public.stammbaeume s JOIN public.familien f ON f.id = s.familie_id
   WHERE s.id = p_stammbaum_id;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'owner_keine_familie'; END IF;

  -- Aktueller Owner (aktive Zeile bevorzugt)
  SELECT m.user_id, u.email,
         trim(coalesce(ra.vorname,'') || ' ' || coalesce(ra.nachname,'')) AS name
    INTO v_owner
    FROM public.mitgliedschaften m
    JOIN auth.users u ON u.id = m.user_id
    LEFT JOIN LATERAL (
      SELECT vorname, nachname FROM public.registrierungs_anfragen r
      WHERE lower(r.email) = lower(u.email) ORDER BY r.created_at DESC LIMIT 1
    ) ra ON true
   WHERE m.familie_id = v_fam AND m.rolle = 'familien_owner'
   ORDER BY m.aktiv DESC
   LIMIT 1;

  -- Letzter Owner-Wechsel (optional)
  SELECT a.geaendert_am, u.email AS von_email
    INTO v_letzte
    FROM public.familien_audit a
    LEFT JOIN auth.users u ON u.id = a.geaendert_von
   WHERE a.familie_id = v_fam AND a.aktion = 'owner_wechsel'
   ORDER BY a.geaendert_am DESC
   LIMIT 1;

  RETURN jsonb_build_object(
    'familie_id',      v_fam,
    'familie_name',    v_fam_name,
    'owner_user_id',   v_owner.user_id,
    'owner_email',     v_owner.email,
    'owner_name',      nullif(v_owner.name, ''),
    'letzte_aenderung', v_letzte.geaendert_am,
    'letzte_von',      v_letzte.von_email
  );
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_owner_info(uuid) TO authenticated;

-- 2) Wählbare Mitglieder im VERBUND (Super-Admin) -------------------
--    Aktive Mitglieder ALLER Familien desselben Verbunds (verwandte Bäume),
--    ohne super_admin-Konten und ohne den aktuellen Owner DIESER Familie.
--    Pro Nutzer genau EIN Eintrag (DISTINCT ON user_id). Hat die Familie keinen
--    Verbund (verbund_id IS NULL), bleibt es bei den Mitgliedern dieser Familie.
DROP FUNCTION IF EXISTS public.stammbaum_owner_kandidaten(uuid);
CREATE OR REPLACE FUNCTION public.stammbaum_owner_kandidaten(p_stammbaum_id uuid)
RETURNS TABLE(user_id uuid, email text, name text, rolle text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_verbund uuid; v_owner uuid;
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'owner_keine_berechtigung'; END IF;
  IF p_stammbaum_id IS NULL THEN RAISE EXCEPTION 'owner_keine_familie'; END IF;
  SELECT s.familie_id INTO v_fam FROM public.stammbaeume s WHERE s.id = p_stammbaum_id;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'owner_keine_familie'; END IF;

  SELECT f.verbund_id INTO v_verbund FROM public.familien f WHERE f.id = v_fam;

  -- aktueller Owner dieser Familie (von der Auswahl ausnehmen)
  SELECT m.user_id INTO v_owner
    FROM public.mitgliedschaften m
   WHERE m.familie_id = v_fam AND m.rolle = 'familien_owner'
   ORDER BY m.aktiv DESC LIMIT 1;

  RETURN QUERY
    SELECT k.user_id, k.email, k.name, k.rolle
    FROM (
      SELECT DISTINCT ON (u.id)
             u.id AS user_id, u.email::text AS email,
             trim(coalesce(ra.vorname,'') || ' ' || coalesce(ra.nachname,''))::text AS name,
             m.rolle::text AS rolle
        FROM public.mitgliedschaften m
        JOIN public.familien f2 ON f2.id = m.familie_id
        JOIN auth.users u ON u.id = m.user_id
        LEFT JOIN LATERAL (
          SELECT vorname, nachname FROM public.registrierungs_anfragen r
          WHERE lower(r.email) = lower(u.email) ORDER BY r.created_at DESC LIMIT 1
        ) ra ON true
       WHERE m.aktiv
         AND ( (v_verbund IS NOT NULL AND f2.verbund_id = v_verbund) OR f2.id = v_fam )
         AND m.rolle <> 'super_admin'
         AND (v_owner IS NULL OR u.id <> v_owner)
         -- System-Konten (super_admin in irgendeiner Familie) generell ausschließen
         AND NOT EXISTS (SELECT 1 FROM public.mitgliedschaften sa
                         WHERE sa.user_id = u.id AND sa.rolle = 'super_admin')
       -- pro Nutzer die "höchste" Rolle als Anzeige bevorzugen
       ORDER BY u.id,
                CASE m.rolle WHEN 'familien_owner' THEN 1 WHEN 'familien_admin' THEN 2 ELSE 3 END
    ) k
    ORDER BY k.email;
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_owner_kandidaten(uuid) TO authenticated;

-- 3) Registrierte Nutzer per E-Mail suchen (Super-Admin) -------------
--    Liefert Treffer inkl. Hinweis, ob bereits Mitglied DIESER Familie.
DROP FUNCTION IF EXISTS public.owner_nutzer_suche(uuid, text);
CREATE OR REPLACE FUNCTION public.owner_nutzer_suche(p_stammbaum_id uuid, p_email text)
RETURNS TABLE(user_id uuid, email text, ist_mitglied boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fam uuid; v_q text := lower(trim(coalesce(p_email,'')));
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'owner_keine_berechtigung'; END IF;
  IF p_stammbaum_id IS NULL THEN RAISE EXCEPTION 'owner_keine_familie'; END IF;
  IF v_q = '' THEN RETURN; END IF;
  SELECT s.familie_id INTO v_fam FROM public.stammbaeume s WHERE s.id = p_stammbaum_id;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'owner_keine_familie'; END IF;

  RETURN QUERY
    SELECT u.id, u.email::text,
           EXISTS (SELECT 1 FROM public.mitgliedschaften m
                   WHERE m.user_id = u.id AND m.familie_id = v_fam AND m.aktiv) AS ist_mitglied
      FROM auth.users u
     WHERE lower(u.email) LIKE '%' || v_q || '%'
       -- System-Konten (super_admin) nicht als Owner-Kandidaten anbieten
       AND NOT EXISTS (SELECT 1 FROM public.mitgliedschaften s2
                       WHERE s2.user_id = u.id AND s2.rolle = 'super_admin')
     ORDER BY u.email
     LIMIT 10;
END $$;
GRANT EXECUTE ON FUNCTION public.owner_nutzer_suche(uuid, text) TO authenticated;

-- 4) Owner übertragen (Super-Admin) ---------------------------------
DROP FUNCTION IF EXISTS public.stammbaum_owner_wechseln(uuid, uuid);
CREATE OR REPLACE FUNCTION public.stammbaum_owner_wechseln(p_stammbaum_id uuid, p_neuer_user uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam       uuid;
  v_neu_email text;
  v_alt_user  uuid;
  v_alt_email text;
BEGIN
  IF NOT public.ist_super_admin() THEN RAISE EXCEPTION 'owner_keine_berechtigung'; END IF;
  IF p_stammbaum_id IS NULL OR p_neuer_user IS NULL THEN RAISE EXCEPTION 'owner_keine_familie'; END IF;

  SELECT s.familie_id INTO v_fam FROM public.stammbaeume s WHERE s.id = p_stammbaum_id;
  IF v_fam IS NULL THEN RAISE EXCEPTION 'owner_keine_familie'; END IF;

  SELECT email INTO v_neu_email FROM auth.users WHERE id = p_neuer_user;
  IF v_neu_email IS NULL THEN RAISE EXCEPTION 'owner_user_fehlt'; END IF;

  -- Neuer Nutzer darf kein System-Konto (super_admin) sein
  IF EXISTS (SELECT 1 FROM public.mitgliedschaften WHERE user_id = p_neuer_user AND rolle = 'super_admin') THEN
    RAISE EXCEPTION 'owner_keine_berechtigung';
  END IF;

  -- Aktueller Owner (für Audit + Rückstufung)
  SELECT m.user_id, u.email INTO v_alt_user, v_alt_email
    FROM public.mitgliedschaften m JOIN auth.users u ON u.id = m.user_id
   WHERE m.familie_id = v_fam AND m.rolle = 'familien_owner'
   ORDER BY m.aktiv DESC LIMIT 1;

  IF v_alt_user = p_neuer_user THEN RAISE EXCEPTION 'owner_unveraendert'; END IF;

  -- Neuer Owner: Mitgliedschaft anlegen ODER hochstufen (manuell -> auto=false)
  INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv, auto)
  VALUES (p_neuer_user, v_fam, 'familien_owner', true, false)
  ON CONFLICT (user_id, familie_id)
  DO UPDATE SET rolle = 'familien_owner', aktiv = true, auto = false;

  -- Bisherige(n) Owner zurückstufen auf familien_admin (manuell, geschützt)
  UPDATE public.mitgliedschaften
     SET rolle = 'familien_admin', aktiv = true, auto = false
   WHERE familie_id = v_fam
     AND rolle = 'familien_owner'
     AND user_id <> p_neuer_user;

  -- Protokoll (wer/wann/alt/neu, inkl. Stammbaum)
  INSERT INTO public.familien_audit (familie_id, stammbaum_id, aktion, geaendert_von, alte_werte, neue_werte)
  VALUES (
    v_fam, p_stammbaum_id, 'owner_wechsel', auth.uid(),
    jsonb_build_object('user_id', v_alt_user, 'email', v_alt_email),
    jsonb_build_object('user_id', p_neuer_user, 'email', v_neu_email)
  );

  RETURN jsonb_build_object('ok', true, 'owner_email', v_neu_email);
END $$;
GRANT EXECUTE ON FUNCTION public.stammbaum_owner_wechseln(uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'owner_wechsel: info/kandidaten/suche/wechseln (Super-Admin) + Audit angelegt' AS status;
