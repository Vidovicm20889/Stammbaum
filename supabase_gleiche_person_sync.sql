-- =====================================================
-- GLEICHE PERSON: Daten-Angleich beim Verknüpfen + LIVE-SYNC bei Bearbeitung
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Voraussetzung: supabase_gleiche_person.sql (identitaet_id), supabase_merge_gui.sql (merge_fill).
--
-- 1) personen_verknuepfen: gleicht beim Verknüpfen die GANZE Gruppe an (alle Felder INKL.
--    Name; vollständigste Karte gewinnt, Super-Admin-Auflösung gewinnt darüber).
-- 2) Trigger ident_sync: wird eine verknüpfte Karte bearbeitet, übernehmen ALLE
--    Zwillingskarten automatisch dieselben Daten (inkl. Vor-/Nachname).
-- =====================================================

-- ---------- 1) Verknüpfen + Gruppen-Angleich (mit Konfliktauflösung) ----------
-- p_aufloesung: vom Super-Admin gewählte Endwerte für Konfliktfelder (gewinnen über alles).
DROP FUNCTION IF EXISTS public.personen_verknuepfen(uuid, uuid);
CREATE OR REPLACE FUNCTION public.personen_verknuepfen(
  p_a uuid, p_b uuid, p_aufloesung jsonb DEFAULT '{}'::jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_fa uuid; v_fb uuid; v_ia uuid; v_ib uuid; v_grp uuid;
  v_va uuid; v_vb uuid; v_base jsonb; v_rec record;
BEGIN
  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN RAISE EXCEPTION 'Ungültige Auswahl.'; END IF;
  p_aufloesung := coalesce(p_aufloesung, '{}'::jsonb);
  SELECT familie_id, identitaet_id INTO v_fa, v_ia FROM public.personen WHERE id = p_a;
  SELECT familie_id, identitaet_id INTO v_fb, v_ib FROM public.personen WHERE id = p_b;
  IF v_fa IS NULL OR v_fb IS NULL THEN RAISE EXCEPTION 'Person(en) nicht gefunden.'; END IF;
  IF NOT (public.ist_super_admin()
          OR (public.kann_familie_bearbeiten(v_fa) AND public.kann_familie_bearbeiten(v_fb)))
    THEN RAISE EXCEPTION 'Keine Berechtigung (Admin/Owner beider Familien nötig).'; END IF;

  v_grp := coalesce(v_ia, v_ib, gen_random_uuid());
  UPDATE public.personen SET identitaet_id = v_grp
   WHERE id IN (p_a, p_b)
      OR (v_ia IS NOT NULL AND identitaet_id = v_ia)
      OR (v_ib IS NOT NULL AND identitaet_id = v_ib);

  -- Gemeinsame Biografie bilden: vollständigste Karte zuerst -> gewinnt Konflikte
  v_base := '{}'::jsonb;
  FOR v_rec IN
    SELECT stammbaum_daten AS sd
    FROM public.personen
    WHERE identitaet_id = v_grp
    ORDER BY (SELECT count(*) FROM jsonb_each_text(coalesce(stammbaum_daten,'{}'::jsonb)) e
              WHERE trim(e.value) <> '') DESC
  LOOP
    v_base := public.merge_fill(v_base, coalesce(v_rec.sd,'{}'::jsonb));
  END LOOP;
  -- Konfliktauflösung des Super-Admins gewinnt über die zusammengeführte Basis
  v_base := v_base || p_aufloesung;
  -- Anzeigename aus given+surname neu bilden
  v_base := jsonb_set(v_base, '{name}',
              to_jsonb(trim(coalesce(v_base->>'given','')||' '||coalesce(v_base->>'surname',''))));

  -- Auf ALLE Karten anwenden (inkl. Namen) + Spalten vorname/nachname. Trigger dabei aussetzen.
  PERFORM set_config('app.ident_sync_off', '1', true);
  UPDATE public.personen s SET
       stammbaum_daten = v_base,
       vorname  = coalesce(v_base->>'given',''),
       nachname = coalesce(v_base->>'surname','')
   WHERE s.identitaet_id = v_grp;
  PERFORM set_config('app.ident_sync_off', '0', true);

  -- Verbünde zusammenlegen (Bäume bleiben getrennt, werden gegenseitig sichtbar)
  IF v_fa <> v_fb THEN
    SELECT verbund_id INTO v_va FROM public.familien WHERE id = v_fa;
    SELECT verbund_id INTO v_vb FROM public.familien WHERE id = v_fb;
    IF v_va IS NOT NULL AND v_vb IS NOT NULL AND v_va <> v_vb THEN
      UPDATE public.familien SET verbund_id = v_va WHERE verbund_id = v_vb;
    END IF;
  END IF;

  RETURN v_grp;
END $$;
GRANT EXECUTE ON FUNCTION public.personen_verknuepfen(uuid, uuid, jsonb) TO authenticated;


-- ---------- 2) LIVE-SYNC-Trigger ----------
-- Bei Bearbeitung einer verknüpften Karte: Biografie auf alle Zwillinge übertragen.
-- Namensfelder (given/surname/name/ehename) bleiben je Karte erhalten.
-- Schutz vor Endlosschleife: pg_trigger_depth (Kaskade) + app.ident_sync_off (Bulk-Angleich).
CREATE OR REPLACE FUNCTION public.trg_ident_sync()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.identitaet_id IS NULL THEN RETURN NEW; END IF;
  IF coalesce(current_setting('app.ident_sync_off', true), '0') = '1' THEN RETURN NEW; END IF;
  IF pg_trigger_depth() > 1 THEN RETURN NEW; END IF;
  UPDATE public.personen s SET
       stammbaum_daten = NEW.stammbaum_daten,
       vorname  = coalesce(NEW.stammbaum_daten->>'given',  s.vorname),
       nachname = coalesce(NEW.stammbaum_daten->>'surname', s.nachname)
   WHERE s.identitaet_id = NEW.identitaet_id AND s.id <> NEW.id;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS ident_sync ON public.personen;
CREATE TRIGGER ident_sync
AFTER UPDATE OF stammbaum_daten ON public.personen
FOR EACH ROW
WHEN (NEW.identitaet_id IS NOT NULL AND NEW.stammbaum_daten IS DISTINCT FROM OLD.stammbaum_daten)
EXECUTE FUNCTION public.trg_ident_sync();


-- ---------- 3) HINWEIS: noch nicht verknüpfte Dubletten (gleicher Name + Geburtsdatum) ----------
-- Liefert Gruppen von Karten über mehrere Bäume, die dieselbe Person sein dürften, aber
-- (noch) NICHT vollständig als gleiche Person verknüpft sind. Für den Aufräum-Hinweis.
-- Erkennung robust über VORNAME + GEBURTSJAHR (4-stellige Jahreszahl aus dem birth_date,
-- egal ob '1989-08-20' oder '20 AUG 1989'). Unabhängig von Nachname (Mädchen-/Ehename),
-- Datumsformat und Eltern-Edges. Der Super-Admin bestätigt die Auswahl per Checkbox.
DROP FUNCTION IF EXISTS public.offene_dubletten();
CREATE OR REPLACE FUNCTION public.offene_dubletten(p_baum_a uuid, p_baum_b uuid)
RETURNS TABLE(person text, geboren text, baeume text, ids uuid[], anzahl int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH g AS (
    SELECT pe.id, pe.identitaet_id,
           trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS person,
           coalesce(pe.stammbaum_daten->>'birth_date','') AS geboren,
           s.name AS baum,
           public.merge_norm(pe.vorname) || '|' ||
             substring(coalesce(pe.stammbaum_daten->>'birth_date','') from '\d{4}') AS k
    FROM public.personen pe
    LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
    WHERE pe.stammbaum_id IN (p_baum_a, p_baum_b)          -- nur die zwei gewählten Bäume
      AND (public.ist_super_admin() OR public.sieht_familie(pe.familie_id))
      AND trim(coalesce(pe.vorname,'')) <> ''
      AND substring(coalesce(pe.stammbaum_daten->>'birth_date','') from '\d{4}') IS NOT NULL
  )
  SELECT max(person) AS person, max(geboren) AS geboren,
         string_agg(DISTINCT baum, ', ') AS baeume,
         array_agg(id) AS ids,
         count(*)::int AS anzahl
  FROM g
  GROUP BY k
  HAVING count(*) > 1
     AND count(DISTINCT coalesce(identitaet_id::text, id::text)) > 1   -- noch nicht alle verknüpft
  ORDER BY count(*) DESC, max(person);
$$;
GRANT EXECUTE ON FUNCTION public.offene_dubletten(uuid, uuid) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'Gleiche-Person Sync angelegt: personen_verknuepfen (Name-Angleich) + Trigger ident_sync + offene_dubletten()' AS status;
