-- =====================================================
-- DATENBEREINIGUNG — WERKZEUG (nur Super-Admin)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Wiederverwendbares Admin-Werkzeug, das "verwaiste" Daten rund um die
-- Stammbaum-Zuordnung findet und auf Wunsch bereinigt. Zwei Schritte:
--
--   1) VORSCHLAG (read-only):  stammbaum_bereinigung_diagnose()
--        -> findet Personen/Familien ohne Stammbaum, gruppiert je familie_id +
--           normalisiertem Nachnamen und schlägt pro Gruppe vor:
--           'zuordnen' (passender Baum existiert in DIESER Familie) oder
--           'neu_anlegen'. MUTIERT NICHTS.
--
--   2) ANWENDEN (mutierend, pro Fall):  bereinigung_anwenden(...)
--        -> ordnet die verwaisten Personen EINER Gruppe einem Baum zu bzw. legt
--           den Baum an. Wird vom Super-Admin pro Gruppe BEWUSST aufgerufen
--           (erst Vorschlag, dann Bestätigung) und ins familien_audit protokolliert.
--
-- WICHTIG (CLAUDE.md-konform):
--   * Nur super_admin (Rechteprüfung in jeder RPC). KEIN Auto-Job/Trigger.
--   * Alles STRIKT innerhalb derselben familie_id — Familien-Isolation gewahrt,
--     KEINE kontenübergreifende Verschmelzung allein über den Nachnamen.
--   * Dubletten-Schutz: ein Baum gilt nur dann als "vorhanden", wenn er in
--     DERSELBEN Familie (= Name+Land+Ort+Gemeinde-Tupel, 4-Felder) liegt und der
--     normalisierte Baumname passt. Über merge_norm() (ć č š ž đ -> c c s z d).
--   * Es werden NUR Bäume innerhalb bestehender Familien angelegt (nie neue
--     Familien) -> die bestehende Owner-/super_admin-Verantwortung bleibt.
--   * Voraussetzung: merge_norm() (supabase_merge_gui / familie_finden_exakt),
--     ist_super_admin() (mitglieder_komplett), familien_audit (familie_einstellungen),
--     UNIQUE(familie_id, name) auf stammbaeume (multitree_phase5).
--
-- Verwendung:
--   SELECT public.stammbaum_bereinigung_diagnose();           -- Vorschlag holen
--   -- pro Gruppe aus 'gruppen_vorschlag' dann eines von beiden:
--   SELECT public.bereinigung_anwenden('<familie_id>','<nachname_norm>','<ziel_baum_id>'); -- zuordnen
--   SELECT public.bereinigung_anwenden('<familie_id>','<nachname_norm>', NULL);            -- neu anlegen
-- =====================================================

DROP FUNCTION IF EXISTS public.stammbaum_bereinigung_diagnose();
CREATE OR REPLACE FUNCTION public.stammbaum_bereinigung_diagnose()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Rechteprüfung: ausschließlich Super-Admin
  IF NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'Nur Super-Admin darf die Bereinigungs-Diagnose ausführen.'
      USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'erzeugt_am', now(),

    -- Kurz-Zusammenfassung (Zähler)
    'zusammenfassung', jsonb_build_object(
      'personen_ohne_baum',
        (SELECT count(*) FROM public.personen WHERE stammbaum_id IS NULL),
      'personen_baum_verwaist',
        (SELECT count(*) FROM public.personen p
          WHERE p.stammbaum_id IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.id = p.stammbaum_id)),
      'personen_familie_verwaist',
        (SELECT count(*) FROM public.personen p
          WHERE p.familie_id IS NULL
             OR NOT EXISTS (SELECT 1 FROM public.familien f WHERE f.id = p.familie_id)),
      'baeume_familie_verwaist',
        (SELECT count(*) FROM public.stammbaeume s
          WHERE s.familie_id IS NULL
             OR NOT EXISTS (SELECT 1 FROM public.familien f WHERE f.id = s.familie_id)),
      'familien_ohne_baum',
        (SELECT count(*) FROM public.familien f
          WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id))
    ),

    -- 1) Personen OHNE Stammbaum-Zuordnung (stammbaum_id IS NULL),
    --    gruppiert je familie_id + normalisierter Nachname.
    'personen_ohne_baum', (
      SELECT coalesce(jsonb_agg(row_to_json(t) ORDER BY t.familie_name, t.nachname_norm), '[]'::jsonb)
      FROM (
        SELECT p.familie_id,
               f.name AS familie_name,
               public.merge_norm(p.nachname) AS nachname_norm,
               min(coalesce(nullif(trim(p.nachname), ''), '(leer)')) AS beispiel_nachname,
               count(*) AS anzahl
        FROM public.personen p
        LEFT JOIN public.familien f ON f.id = p.familie_id
        WHERE p.stammbaum_id IS NULL
        GROUP BY p.familie_id, f.name, public.merge_norm(p.nachname)
      ) t
    ),

    -- 2) AKTIONS-VORSCHLAG je Gruppe (nur Personen mit nicht-leerem Nachnamen
    --    und gültiger familie_id). STRIKT innerhalb familie_id:
    --    Gibt es in DERSELBEN Familie bereits einen Baum mit passendem
    --    (normalisiertem) Namen? -> 'zuordnen', sonst 'neu_anlegen'.
    'gruppen_vorschlag', (
      SELECT coalesce(jsonb_agg(row_to_json(g) ORDER BY g.familie_name, g.nachname_norm), '[]'::jsonb)
      FROM (
        SELECT grp.familie_id,
               f.name  AS familie_name,
               grp.nachname_norm,
               grp.beispiel_nachname,
               grp.anzahl,
               zb.id   AS ziel_baum_id,
               zb.name AS ziel_baum_name,
               CASE WHEN zb.id IS NOT NULL THEN 'zuordnen' ELSE 'neu_anlegen' END AS vorschlag
        FROM (
          SELECT p.familie_id,
                 public.merge_norm(p.nachname) AS nachname_norm,
                 min(trim(p.nachname)) AS beispiel_nachname,
                 count(*) AS anzahl
          FROM public.personen p
          WHERE p.stammbaum_id IS NULL
            AND p.familie_id IS NOT NULL
            AND coalesce(trim(p.nachname), '') <> ''
          GROUP BY p.familie_id, public.merge_norm(p.nachname)
        ) grp
        LEFT JOIN public.familien f ON f.id = grp.familie_id
        LEFT JOIN LATERAL (
          SELECT s.id, s.name
          FROM public.stammbaeume s
          WHERE s.familie_id = grp.familie_id
            AND public.merge_norm(s.name) = grp.nachname_norm
          ORDER BY s.name
          LIMIT 1
        ) zb ON true
      ) g
    ),

    -- 3) Personen mit stammbaum_id, der ins Leere zeigt (Dangling-FK; sollte
    --    durch FK-Constraints nie vorkommen — defensive Prüfung).
    'personen_baum_verwaist', (
      SELECT coalesce(jsonb_agg(row_to_json(t) ORDER BY t.stammbaum_id), '[]'::jsonb)
      FROM (
        SELECT p.stammbaum_id, p.familie_id, count(*) AS anzahl,
               string_agg(DISTINCT coalesce(nullif(trim(p.nachname), ''), '(leer)'), ', ') AS nachnamen
        FROM public.personen p
        WHERE p.stammbaum_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.id = p.stammbaum_id)
        GROUP BY p.stammbaum_id, p.familie_id
      ) t
    ),

    -- 4) Personen ohne (gültige) familie_id.
    'personen_familie_verwaist', (
      SELECT coalesce(jsonb_agg(row_to_json(t) ORDER BY t.id), '[]'::jsonb)
      FROM (
        SELECT p.id, p.familie_id, p.stammbaum_id,
               coalesce(nullif(trim(p.nachname), ''), '(leer)') AS nachname,
               coalesce(nullif(trim(p.vorname),  ''), '(leer)') AS vorname
        FROM public.personen p
        WHERE p.familie_id IS NULL
           OR NOT EXISTS (SELECT 1 FROM public.familien f WHERE f.id = p.familie_id)
      ) t
    ),

    -- 5) Stammbäume ohne (gültige) familie_id.
    'baeume_familie_verwaist', (
      SELECT coalesce(jsonb_agg(row_to_json(t) ORDER BY t.name), '[]'::jsonb)
      FROM (
        SELECT s.id, s.name, s.familie_id,
               (SELECT count(*) FROM public.personen p WHERE p.stammbaum_id = s.id) AS personen
        FROM public.stammbaeume s
        WHERE s.familie_id IS NULL
           OR NOT EXISTS (SELECT 1 FROM public.familien f WHERE f.id = s.familie_id)
      ) t
    ),

    -- 6) Familien ganz ohne Stammbaum.
    'familien_ohne_baum', (
      SELECT coalesce(jsonb_agg(row_to_json(t) ORDER BY t.name), '[]'::jsonb)
      FROM (
        SELECT f.id, f.name, f.land, f.stadt, f.gemeinde,
               (SELECT count(*) FROM public.personen p WHERE p.familie_id = f.id) AS personen
        FROM public.familien f
        WHERE NOT EXISTS (SELECT 1 FROM public.stammbaeume s WHERE s.familie_id = f.id)
      ) t
    )
  ) INTO v_result;

  RETURN v_result;
END $$;

GRANT EXECUTE ON FUNCTION public.stammbaum_bereinigung_diagnose() TO authenticated;


-- =====================================================
-- ANWENDEN (mutierend, pro Gruppe, nur Super-Admin)
--
-- Ordnet ALLE verwaisten Personen (stammbaum_id IS NULL) einer Gruppe
-- (familie_id + normalisierter Nachname) einem Stammbaum zu:
--   * p_ziel_baum_id gesetzt  -> 'zuordnen' (Baum MUSS zu p_familie_id gehören)
--   * p_ziel_baum_id = NULL    -> 'neu_anlegen' (Baum in DIESER Familie anlegen;
--                                  existiert bereits ein namensgleicher Baum in
--                                  dieser Familie, wird er genutzt = Dubletten-Schutz)
-- Mutiert NUR personen.stammbaum_id (familie_id/verbund bleiben). Protokolliert
-- jeden Aufruf in familien_audit (alt: ohne Baum / neu: Baum + Anzahl).
-- =====================================================
DROP FUNCTION IF EXISTS public.bereinigung_anwenden(uuid, text, uuid);
CREATE OR REPLACE FUNCTION public.bereinigung_anwenden(
  p_familie_id    uuid,
  p_nachname      text,           -- roh ODER normalisiert (wird normalisiert verglichen)
  p_ziel_baum_id  uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_norm        text := public.merge_norm(p_nachname);
  v_person_ids  uuid[];
  v_anzahl      int;
  v_baum_id     uuid;
  v_baum_name   text;
  v_neu         boolean := false;
BEGIN
  -- Rechte + Pflichtfelder
  IF NOT public.ist_super_admin() THEN
    RAISE EXCEPTION 'Nur Super-Admin darf die Bereinigung anwenden.' USING ERRCODE = '42501';
  END IF;
  IF p_familie_id IS NULL OR v_norm = '' THEN
    RAISE EXCEPTION 'familie_id und (nicht-leerer) Nachname sind Pflicht.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.familien WHERE id = p_familie_id) THEN
    RAISE EXCEPTION 'familie_unbekannt';
  END IF;

  -- Betroffene verwaiste Personen — STRIKT innerhalb dieser Familie
  SELECT array_agg(p.id), count(*)
    INTO v_person_ids, v_anzahl
    FROM public.personen p
   WHERE p.familie_id = p_familie_id
     AND p.stammbaum_id IS NULL
     AND public.merge_norm(p.nachname) = v_norm;

  IF coalesce(v_anzahl, 0) = 0 THEN
    RAISE EXCEPTION 'keine_verwaisten_personen';  -- evtl. schon erledigt
  END IF;

  IF p_ziel_baum_id IS NOT NULL THEN
    -- ZUORDNEN: Zielbaum muss zu DIESER Familie gehören (Isolation!)
    SELECT s.id, s.name INTO v_baum_id, v_baum_name
      FROM public.stammbaeume s
     WHERE s.id = p_ziel_baum_id AND s.familie_id = p_familie_id;
    IF v_baum_id IS NULL THEN
      RAISE EXCEPTION 'zielbaum_fremd_oder_unbekannt';
    END IF;
  ELSE
    -- NEU ANLEGEN: Name = repräsentativer ECHTER Nachname der Gruppe (mit Diakritik)
    SELECT min(trim(p.nachname)) INTO v_baum_name
      FROM public.personen p
     WHERE p.id = ANY(v_person_ids) AND coalesce(trim(p.nachname), '') <> '';
    v_baum_name := coalesce(nullif(v_baum_name, ''), 'Unbekannt');

    -- Dubletten-Schutz: existiert in DIESER Familie schon ein normalisiert
    -- gleichnamiger Baum? -> nutzen statt neu anlegen.
    SELECT s.id, s.name INTO v_baum_id, v_baum_name
      FROM public.stammbaeume s
     WHERE s.familie_id = p_familie_id
       AND public.merge_norm(s.name) = public.merge_norm(v_baum_name)
     ORDER BY s.name
     LIMIT 1;

    IF v_baum_id IS NULL THEN
      INSERT INTO public.stammbaeume (familie_id, name)
      VALUES (p_familie_id, v_baum_name)
      RETURNING id, name INTO v_baum_id, v_baum_name;
      v_neu := true;
    END IF;
  END IF;

  -- Zuordnen (nur stammbaum_id; familie_id bleibt unverändert)
  UPDATE public.personen
     SET stammbaum_id = v_baum_id
   WHERE id = ANY(v_person_ids);

  -- Protokoll
  INSERT INTO public.familien_audit
    (familie_id, stammbaum_id, aktion, geaendert_von, alte_werte, neue_werte)
  VALUES (
    p_familie_id, v_baum_id,
    CASE WHEN v_neu THEN 'bereinigung_neu_anlegen' ELSE 'bereinigung_zuordnen' END,
    auth.uid(),
    jsonb_build_object('nachname_norm', v_norm, 'stammbaum_id', NULL,
                       'personen_ids', to_jsonb(v_person_ids), 'anzahl', v_anzahl),
    jsonb_build_object('stammbaum_id', v_baum_id, 'stammbaum_name', v_baum_name,
                       'neu_angelegt', v_neu, 'anzahl', v_anzahl)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'familie_id', p_familie_id,
    'stammbaum_id', v_baum_id,
    'stammbaum_name', v_baum_name,
    'neu_angelegt', v_neu,
    'zugeordnete_personen', v_anzahl
  );
END $$;
GRANT EXECUTE ON FUNCTION public.bereinigung_anwenden(uuid, text, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'Datenbereinigung-Werkzeug angelegt: stammbaum_bereinigung_diagnose() (Vorschlag) + bereinigung_anwenden() (anwenden, nur super_admin, Audit)' AS status;
