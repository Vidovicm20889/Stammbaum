-- =====================================================
-- FAMROOTS-43 + FAMROOTS-45 — partner_art durch den VERKNÜPFUNGS-Pfad reichen
--                             + Verknüpfen im EIGENEN Baum sofort (ohne Genehmigung)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT (mehrfach ausführbar).
--
-- ZWECK 1 (FAMROOTS-43): Beim Board-Verknüpfen zweier Karten als „Ex-Partner" soll die angelegte
-- 'ehepartner'-Kante direkt `partner_art='ex_partner'` bekommen — auch dann, wenn die
-- Verknüpfung erst über eine Genehmigung (`status='offen'` -> `verknuepfung_entscheiden`)
-- wirklich entsteht. Deshalb wird die Art atomar durch `verknuepfung_anfragen` ->
-- (Antragszeile) -> `_vkn_ausfuehren` gereicht, statt sie nachträglich per zweitem RPC-Aufruf
-- zu setzen (der im 'angefragt'-Fall ins Leere liefe, weil die Kante noch nicht existiert).
--
-- ZWECK 2 (FAMROOTS-45): `verknuepfung_anfragen` verknüpfte bisher NUR für Super-Admin sofort;
-- ein Familien-Owner/-Admin bekam selbst beim Verknüpfen ZWEIER Karten des EIGENEN Baums die
-- Meldung „Antrag gesendet, Admin des anderen Baums muss genehmigen". Der Sofort-Zweig wird auf
-- „Nutzer darf die Ziel-Familie ohnehin bearbeiten" erweitert (gleiche Familie ODER
-- kann_familie_bearbeiten(ziel)); der Genehmigungs-Weg bleibt NUR für den echten Cross-Tree-Fall
-- (fremde, nicht bearbeitbare Ziel-Familie — Datenschutz/Kinderschutz).
--
-- Baut auf supabase_verknuepfung_anfragen.sql (Tabelle + die drei Funktionen) und
-- supabase_partner_art.sql (Spalte beziehungen.partner_art + CHECK) auf. Reine Erweiterung —
-- bestehende Aufrufer OHNE `p_art` funktionieren unverändert (Default NULL = wie bisher 'ehe').
-- Ersetzt die Sofort-/Antrags-Entscheidung des Basis-Skripts (dieses hier ist der reale Endstand;
-- Neuaufbau läuft ohnehin über den Prod-Dump, nicht über den .sql-Replay — siehe docs/lessons.md).
-- =====================================================

-- ---------- 1) Antragszeile bekommt die Art ----------
ALTER TABLE public.verknuepfungs_anfragen ADD COLUMN IF NOT EXISTS partner_art text;
ALTER TABLE public.verknuepfungs_anfragen DROP CONSTRAINT IF EXISTS vkn_anfragen_partner_art_chk;
ALTER TABLE public.verknuepfungs_anfragen ADD CONSTRAINT vkn_anfragen_partner_art_chk
  CHECK (partner_art IS NULL OR partner_art IN ('ehe','partner','ex_ehe','ex_partner'));


-- ---------- 2) INTERN: Verknüpfung real durchführen (jetzt mit p_art) ----------
-- Signatur ändert sich (7 -> 8 Parameter) -> alte Version explizit droppen, sonst entstünde
-- ein Overload. Nur intern aufgerufen (verknuepfung_anfragen / verknuepfung_entscheiden).
DROP FUNCTION IF EXISTS public._vkn_ausfuehren(text, uuid, uuid, text, uuid, uuid, uuid);
CREATE OR REPLACE FUNCTION public._vkn_ausfuehren(
  p_modus text, p_kontext uuid, p_ziel uuid, p_typ text, p_zweiter uuid,
  p_quelle_fam uuid, p_ziel_fam uuid, p_art text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_vq uuid; v_vz uuid;
        v_art text := CASE WHEN p_art IN ('ehe','partner','ex_ehe','ex_partner') THEN p_art ELSE NULL END;
BEGIN
  IF p_modus = 'merge' THEN
    PERFORM public._person_merge_core(p_ziel, p_kontext, '{}'::jsonb);
    RETURN;
  END IF;

  IF p_kontext IS NOT NULL AND p_ziel IS NOT NULL THEN
    IF p_typ = 'elternteil' THEN
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
      VALUES (p_ziel, p_kontext, 'elternteil', p_quelle_fam);
    ELSIF p_typ = 'partner' THEN
      -- FAMROOTS-43: Art direkt auf der Kante setzen (NULL = wie bisher 'ehe').
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id, partner_art)
      VALUES (p_kontext, p_ziel, 'ehepartner', p_quelle_fam, v_art);
    ELSIF p_typ = 'kind' THEN
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
      VALUES (p_kontext, p_ziel, 'elternteil', p_quelle_fam);
      IF p_zweiter IS NOT NULL AND p_zweiter <> p_kontext THEN
        INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
        VALUES (p_zweiter, p_ziel, 'elternteil', p_quelle_fam);
      END IF;
    END IF;
  END IF;

  IF p_quelle_fam IS NOT NULL AND p_ziel_fam IS NOT NULL AND p_quelle_fam <> p_ziel_fam THEN
    SELECT verbund_id INTO v_vq FROM public.familien WHERE id = p_quelle_fam;
    SELECT verbund_id INTO v_vz FROM public.familien WHERE id = p_ziel_fam;
    IF v_vq IS NOT NULL AND v_vz IS NOT NULL AND v_vq <> v_vz THEN
      UPDATE public.familien SET verbund_id = v_vz WHERE verbund_id = v_vq;
    END IF;
  END IF;
END $$;


-- ---------- 3) VERKNÜPFUNG BEANTRAGEN (jetzt mit p_art) ----------
-- Signatur ändert sich (5 -> 6 Parameter, p_art optional) -> alte Version droppen + neu granten.
-- Bestehende Aufrufer ohne p_art nutzen den Default NULL (unverändertes Verhalten).
DROP FUNCTION IF EXISTS public.verknuepfung_anfragen(text, uuid, uuid, text, uuid);
CREATE OR REPLACE FUNCTION public.verknuepfung_anfragen(
  p_modus text, p_kontext uuid, p_ziel uuid, p_typ text DEFAULT NULL,
  p_zweiter uuid DEFAULT NULL, p_art text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_qf uuid; v_zf uuid; v_qb uuid;
        v_art text := CASE WHEN p_art IN ('ehe','partner','ex_ehe','ex_partner') THEN p_art ELSE NULL END;
BEGIN
  IF p_ziel IS NULL THEN RAISE EXCEPTION 'Ziel-Person fehlt.'; END IF;
  SELECT familie_id, stammbaum_id INTO v_qf, v_qb FROM public.personen WHERE id = p_kontext AND geloescht_am IS NULL;
  SELECT familie_id INTO v_zf FROM public.personen WHERE id = p_ziel AND geloescht_am IS NULL;
  IF v_zf IS NULL THEN RAISE EXCEPTION 'Ziel-Person nicht gefunden.'; END IF;
  IF v_qf IS NOT NULL AND NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_qf)) THEN
    RAISE EXCEPTION 'Keine Berechtigung für die Quell-Familie.';
  END IF;

  -- FAMROOTS-45: Sofort verknüpfen (kein Genehmigungsschritt), wenn der Nutzer die ZIEL-Familie
  -- ohnehin bearbeiten darf: Super-Admin, GLEICHE Familie (v_qf=v_zf, eigener Baum) ODER
  -- Bearbeitungsrecht an der Ziel-Familie. Die Quell-Familie wurde oben bereits geprüft. Der
  -- Genehmigungs-Weg ('angefragt') bleibt NUR für den echten Cross-Tree-Fall (fremde, nicht
  -- bearbeitbare Ziel-Familie) — dort schützt die Zustimmung des Ziel-Admins (Datenschutz).
  IF public.ist_super_admin()
     OR (v_zf IS NOT NULL AND (v_qf = v_zf OR public.kann_familie_bearbeiten(v_zf))) THEN
    PERFORM public._vkn_ausfuehren(coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter, v_qf, v_zf, v_art);
    INSERT INTO public.verknuepfungs_anfragen(
      modus, kontext_person, ziel_person, bez_typ, zweiter_elternteil, partner_art,
      quelle_familie, ziel_familie, quelle_baum, status, entschieden_von, entschieden_am)
    VALUES (coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter, v_art,
      v_qf, v_zf, v_qb, 'genehmigt', auth.uid(), now());
    RETURN 'sofort';
  END IF;

  -- sonst: Antrag erstellen (Genehmigung durch Ziel-Familie-Admin) — Art wird mitgespeichert
  INSERT INTO public.verknuepfungs_anfragen(
    modus, kontext_person, ziel_person, bez_typ, zweiter_elternteil, partner_art,
    quelle_familie, ziel_familie, quelle_baum)
  VALUES (coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter, v_art, v_qf, v_zf, v_qb);
  RETURN 'angefragt';
END $$;
GRANT EXECUTE ON FUNCTION public.verknuepfung_anfragen(text, uuid, uuid, text, uuid, text) TO authenticated;


-- ---------- 4) ENTSCHEIDUNG: Genehmigen / Ablehnen (Art aus der Antragszeile durchreichen) ----------
CREATE OR REPLACE FUNCTION public.verknuepfung_entscheiden(p_id uuid, p_aktion text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v public.verknuepfungs_anfragen%ROWTYPE;
BEGIN
  SELECT * INTO v FROM public.verknuepfungs_anfragen WHERE id = p_id;
  IF v.id IS NULL THEN RAISE EXCEPTION 'Antrag nicht gefunden.'; END IF;
  IF v.status <> 'offen' THEN RAISE EXCEPTION 'Antrag ist bereits entschieden.'; END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v.ziel_familie)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  IF p_aktion = 'genehmigt' THEN
    PERFORM public._vkn_ausfuehren(v.modus, v.kontext_person, v.ziel_person, v.bez_typ,
                                   v.zweiter_elternteil, v.quelle_familie, v.ziel_familie, v.partner_art);
    UPDATE public.verknuepfungs_anfragen
       SET status='genehmigt', entschieden_von=auth.uid(), entschieden_am=now() WHERE id = p_id;
  ELSIF p_aktion = 'abgelehnt' THEN
    UPDATE public.verknuepfungs_anfragen
       SET status='abgelehnt', entschieden_von=auth.uid(), entschieden_am=now() WHERE id = p_id;
  ELSE
    RAISE EXCEPTION 'Ungültige Aktion.';
  END IF;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.verknuepfung_entscheiden(uuid, text) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'FAMROOTS-43 + FAMROOTS-45: partner_art gereicht + Verknüpfen im eigenen/bearbeitbaren Baum sofort' AS status;
