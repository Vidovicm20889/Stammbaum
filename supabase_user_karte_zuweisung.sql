-- =====================================================
-- BENUTZER <-> NAMENSKARTE: flexible Zuweisung durch Admin/Super-Admin
-- Ausführen in: Supabase -> SQL Editor. Idempotent (mehrfach ausführbar).
--
-- Feature „Benutzer mit Namenskarten verknüpfen":
--   1) karten_suche_admin(...)  -> baumübergreifende Suche NUR über Karten, die der
--      Aufrufer zuweisen darf (Super-Admin = alle; Familien-Admin = bearbeitbare/Verbund),
--      inkl. Belegt-Status (welches Konto die Karte bereits hat) + dessen E-Mail.
--   2) karte_user_zuweisen(person, user, force) -> sichere Zuweisung mit Belegt-Warnung;
--      hält „1 Nutzer pro Karte" UND „1 Karte pro Nutzer"; rechnet Auto-Rechte beider
--      betroffener Konten neu (verdrängtes Konto verliert seine Auto-Admin-Rollen sauber).
--   3) meine_person_status() -> zusätzlicher jsonb-Key person_familie (Profilanzeige).
--   4) mitglieder_verwaltbar() -> zusätzliche Spalten: verknüpfte Karte/Baum je Mitglied.
--
-- Voraussetzungen: supabase_personen_suche_verbinden.sql (personen_suche, merge_norm),
--   supabase_blutlinie_rechte.sql (personen.user_id, rechte_neu_berechnen, ist_super_admin,
--   kann_familie_bearbeiten), supabase_verbund.sql (sieht_familie),
--   supabase_meine_person.sql, supabase_rolle_owner.sql (mitglieder_verwaltbar).
-- =====================================================


-- ---------- 1) ADMIN-SUCHE über zuweisbare Karten (inkl. Belegt-Status) ----------
-- Wie personen_suche, ABER: nur Karten in Bäumen, die der Aufrufer BEARBEITEN darf
-- (Super-Admin = alle), plus belegt_user/belegt_email (aktuell verknüpftes Konto).
CREATE OR REPLACE FUNCTION public.karten_suche_admin(
  p_vorname text DEFAULT NULL, p_nachname text DEFAULT NULL, p_geburt text DEFAULT NULL,
  p_limit int DEFAULT 30, p_offset int DEFAULT 0)
RETURNS TABLE(
  id uuid, name text, given text, surname text,
  birth_date text, death_date text,
  baum text, baum_id uuid, familie_id uuid, identitaet_id uuid,
  eltern text, partner text,
  belegt_user uuid, belegt_email text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH n AS (
    SELECT nullif(public.merge_norm(p_vorname),'')  AS vn,
           nullif(public.merge_norm(p_nachname),'') AS nn,
           nullif(trim(coalesce(p_geburt,'')),'')   AS bd
  )
  SELECT pe.id,
    trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS name,
    pe.vorname AS given, pe.nachname AS surname,
    nullif(trim(coalesce(pe.stammbaum_daten->>'birth_date','')),'') AS birth_date,
    nullif(trim(coalesce(pe.stammbaum_daten->>'death_date','')),'') AS death_date,
    s.name AS baum, pe.stammbaum_id AS baum_id, pe.familie_id, pe.identitaet_id,
    (SELECT string_agg(DISTINCT trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')), ', ')
       FROM public.beziehungen b JOIN public.personen po ON po.id = b.person_a
       WHERE b.typ='elternteil' AND b.person_b = pe.id
         AND b.geloescht_am IS NULL AND po.geloescht_am IS NULL) AS eltern,
    (SELECT string_agg(DISTINCT trim(coalesce(po.vorname,'')||' '||coalesce(po.nachname,'')), ', ')
       FROM public.beziehungen b
       JOIN public.personen po ON po.id = CASE WHEN b.person_a = pe.id THEN b.person_b ELSE b.person_a END
       WHERE b.typ='ehepartner' AND (b.person_a = pe.id OR b.person_b = pe.id)
         AND b.geloescht_am IS NULL AND po.geloescht_am IS NULL) AS partner,
    pe.user_id AS belegt_user,
    (SELECT u.email FROM auth.users u WHERE u.id = pe.user_id) AS belegt_email
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  CROSS JOIN n
  WHERE pe.geloescht_am IS NULL
    AND (public.ist_super_admin() OR public.kann_familie_bearbeiten(pe.familie_id))
    AND (n.vn IS NOT NULL OR n.nn IS NOT NULL OR n.bd IS NOT NULL)   -- mind. ein Kriterium
    AND (n.vn IS NULL OR public.merge_norm(pe.vorname)  LIKE n.vn || '%')
    AND (n.nn IS NULL OR public.merge_norm(pe.nachname) LIKE n.nn || '%')
    AND (n.bd IS NULL OR coalesce(pe.stammbaum_daten->>'birth_date','') ILIKE '%'||n.bd||'%')
  ORDER BY pe.nachname, pe.vorname
  LIMIT greatest(1, least(coalesce(p_limit,30), 100))
  OFFSET greatest(0, coalesce(p_offset,0));
$$;
GRANT EXECUTE ON FUNCTION public.karten_suche_admin(text, text, text, int, int) TO authenticated;


-- ---------- 2) SICHERE ZUWEISUNG Konto <-> Karte (mit Belegt-Warnung) ----------
-- p_force=false: ist die Karte schon einem ANDEREN Konto zugeordnet -> {ok:false,'belegt'}.
-- p_force=true : Karte wird übernommen (altes Konto verliert sie). In jedem Fall wird
--   außerdem die bisherige Karte des p_user gelöst (1 Karte pro Konto) und die Auto-Rechte
--   aller betroffenen Konten neu berechnet.
CREATE OR REPLACE FUNCTION public.karte_user_zuweisen(
  p_person uuid, p_user uuid, p_force boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fam   uuid;
  v_cur   uuid;    -- aktuell verknüpftes Konto der Zielkarte
  v_email text;
  v_name  text;
  v_baum  text;
  v_famname text;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  IF p_person IS NULL OR p_user IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'parameter_fehlt');
  END IF;

  SELECT pe.familie_id, pe.user_id,
         trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')),
         s.name, f.name
    INTO v_fam, v_cur, v_name, v_baum, v_famname
    FROM public.personen pe
    LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
    LEFT JOIN public.familien f     ON f.id = pe.familie_id
   WHERE pe.id = p_person;
  IF v_fam IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'person_fehlt'); END IF;

  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  -- bereits exakt diese Verknüpfung -> idempotent ok
  IF v_cur = p_user THEN
    RETURN jsonb_build_object('ok', true, 'grund', 'unveraendert',
      'person_name', v_name, 'baum', v_baum, 'familie', v_famname);
  END IF;

  -- Karte gehört einem ANDEREN Konto -> ohne Force nur Warnung zurückgeben
  IF v_cur IS NOT NULL AND NOT p_force THEN
    SELECT u.email INTO v_email FROM auth.users u WHERE u.id = v_cur;
    RETURN jsonb_build_object('ok', false, 'grund', 'belegt',
      'belegt_email', v_email, 'person_name', v_name, 'baum', v_baum, 'familie', v_famname);
  END IF;

  -- bisherige (andere) Karte des Ziel-Kontos lösen -> 1 Karte pro Konto
  UPDATE public.personen SET user_id = NULL WHERE user_id = p_user AND id <> p_person;

  -- Zielkarte übernehmen (verdrängt ggf. v_cur)
  UPDATE public.personen SET user_id = p_user WHERE id = p_person;

  -- Auto-Rechte neu berechnen: neues Konto, und falls eine Karte verdrängt wurde, das alte Konto
  PERFORM public.rechte_neu_berechnen(p_user);
  IF v_cur IS NOT NULL AND v_cur <> p_user THEN
    PERFORM public.rechte_neu_berechnen(v_cur);
  END IF;

  RETURN jsonb_build_object('ok', true, 'grund', 'verknuepft',
    'person_name', v_name, 'baum', v_baum, 'familie', v_famname);
END $$;
GRANT EXECUTE ON FUNCTION public.karte_user_zuweisen(uuid, uuid, boolean) TO authenticated;


-- ---------- 3) meine_person_status() um person_familie erweitern ----------
-- (Signatur bleibt jsonb -> CREATE OR REPLACE genügt. Rest unverändert zu supabase_meine_person.sql.)
CREATE OR REPLACE FUNCTION public.meine_person_status()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH meine AS (
    SELECT pe.id, pe.stammbaum_id, pe.familie_id,
           trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS name
      FROM public.personen pe
     WHERE pe.user_id = auth.uid() AND pe.geloescht_am IS NULL
     ORDER BY pe.updated_at DESC NULLS LAST
     LIMIT 1
  )
  SELECT jsonb_build_object(
    'verknuepft',      EXISTS (SELECT 1 FROM meine),
    'person_id',       (SELECT id FROM meine),
    'person_name',     (SELECT name FROM meine),
    'person_baum',     (SELECT s.name FROM public.stammbaeume s
                          WHERE s.id = (SELECT stammbaum_id FROM meine)),
    'person_baum_id',  (SELECT stammbaum_id FROM meine),
    'person_familie',  (SELECT f.name FROM public.familien f
                          WHERE f.id = (SELECT familie_id FROM meine)),
    'baum_anzahl',     (SELECT count(*) FROM public.stammbaeume s
                          WHERE public.ist_super_admin() OR public.sieht_familie(s.familie_id)),
    'personen_anzahl', (SELECT count(*) FROM public.personen pe
                          WHERE pe.geloescht_am IS NULL
                            AND (public.ist_super_admin() OR public.sieht_familie(pe.familie_id))),
    'super_admin',     public.ist_super_admin()
  );
$$;
GRANT EXECUTE ON FUNCTION public.meine_person_status() TO authenticated;


-- ---------- 4) mitglieder_verwaltbar() um verknüpfte Karte erweitern ----------
-- Return-Signatur ändert sich (neue Spalten) -> DROP vor CREATE nötig.
DROP FUNCTION IF EXISTS public.mitglieder_verwaltbar();
CREATE OR REPLACE FUNCTION public.mitglieder_verwaltbar()
RETURNS TABLE (
  mitgliedschaft_id uuid, user_id uuid, email text, name text,
  rolle text, familie_id uuid, familie_name text, aktiv boolean,
  verknuepfte_person_id uuid, verknuepfte_person_name text, verknuepfte_baum text
)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT m.id, m.user_id, u.email,
    trim(coalesce(ra.vorname,'') || ' ' || coalesce(ra.nachname,'')) AS name,
    m.rolle, m.familie_id, f.name, m.aktiv,
    pv.id AS verknuepfte_person_id,
    pv.pname AS verknuepfte_person_name,
    pv.bname AS verknuepfte_baum
  FROM public.mitgliedschaften m
  JOIN auth.users u       ON u.id = m.user_id
  JOIN public.familien f   ON f.id = m.familie_id
  LEFT JOIN LATERAL (
    SELECT vorname, nachname FROM public.registrierungs_anfragen r
    WHERE lower(r.email) = lower(u.email) ORDER BY r.created_at DESC LIMIT 1
  ) ra ON true
  LEFT JOIN LATERAL (
    SELECT pe.id,
           trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS pname,
           s.name AS bname
    FROM public.personen pe
    LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
    WHERE pe.user_id = m.user_id AND pe.geloescht_am IS NULL
    ORDER BY pe.updated_at DESC NULLS LAST
    LIMIT 1
  ) pv ON true
  WHERE public.ist_super_admin()
     OR m.familie_id IN (
       SELECT familie_id FROM public.mitgliedschaften
       WHERE user_id = auth.uid() AND rolle IN ('familien_admin','familien_owner') AND aktiv
     )
  ORDER BY f.name, (NOT m.aktiv), u.email;
$$;
GRANT EXECUTE ON FUNCTION public.mitglieder_verwaltbar() TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'User<->Karte-Zuweisung: karten_suche_admin, karte_user_zuweisen, meine_person_status(+familie), mitglieder_verwaltbar(+karte)' AS status;
