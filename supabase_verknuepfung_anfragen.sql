-- =====================================================
-- DUBLETTEN-FRÜHERKENNUNG + VERKNÜPFUNGS-ANTRAG (über Obavještenja)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- Voraussetzung: supabase_merge_gui.sql (merge_norm, person_merge_aufgeloest),
--   supabase_verbund.sql (sieht_familie, kann_familie_bearbeiten, ist_super_admin).
--
-- Idee: Beim Anlegen/Bearbeiten einer Person oder beim Baum-Anlegen wird geprüft,
-- ob dieselbe Person (Vorname+Nachname+Geburtsdatum+Land, ALLE vier) bereits in
-- einem anderen Stammbaum existiert — auch verbund-übergreifend, aber datenschutz-
-- schonend (Antragsteller sieht von fremden Familien nur "Treffer vorhanden", keine
-- Detaildaten). Der Nutzer kann eine VERKNÜPFUNG beantragen. Genehmigung erfolgt durch
-- Owner/Admin des ZIEL-Baums über Obavještenja (Super-Admin: sofort, ohne Genehmigung).
--
-- Bausteine:
--   1) verknuepfungs_anfragen (Tabelle)
--   2) dubletten_check_global(...)        -> mögliche Treffer (privacy-aware)
--   3) _vkn_ausfuehren(...)               -> intern: Verknüpfung real durchführen
--   4) verknuepfung_anfragen(...)         -> Antrag erstellen (Super-Admin: sofort)
--   5) verknuepfungs_anfragen_offen()     -> offene Anträge für den Ziel-Admin (+ Vorschau)
--   6) verknuepfung_entscheiden(id,aktion)-> Genehmigen/Ablehnen
-- =====================================================


-- ---------- 1) Antrags-Tabelle ----------
CREATE TABLE IF NOT EXISTS public.verknuepfungs_anfragen (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at         timestamptz NOT NULL DEFAULT now(),
  antragsteller      uuid DEFAULT auth.uid(),
  modus              text NOT NULL DEFAULT 'beziehung',   -- 'beziehung' (Anlegen) | 'merge' (Bearbeiten/Baum)
  kontext_person     uuid,        -- aktive Person beim Anlegen / bzw. die zu mergende Karte
  ziel_person        uuid,        -- bereits existierender Treffer
  bez_typ            text,        -- 'kind' | 'elternteil' | 'partner' (nur modus='beziehung')
  zweiter_elternteil uuid,        -- optional (bei bez_typ='kind')
  quelle_familie     uuid,
  ziel_familie       uuid,
  quelle_baum        uuid,        -- für die Vorschau
  status             text NOT NULL DEFAULT 'offen',       -- 'offen' | 'genehmigt' | 'abgelehnt'
  entschieden_von    uuid,
  entschieden_am     timestamptz
);
ALTER TABLE public.verknuepfungs_anfragen ENABLE ROW LEVEL SECURITY;
-- Kein direkter Zugriff: Lesen/Schreiben ausschließlich über die SECURITY-DEFINER-RPCs unten.


-- ---------- 2) GLOBALE DUBLETTEN-PRÜFUNG (privacy-aware) ----------
-- Treffer NUR wenn alle vier Kriterien (normalisiert) übereinstimmen UND alle gesetzt sind.
-- Für fremde (nicht sichtbare) Familien werden Baum/Familie NICHT zurückgegeben.
CREATE OR REPLACE FUNCTION public.dubletten_check_global(
  p_vorname text, p_nachname text, p_birth_date text, p_land text,
  p_exclude_person uuid DEFAULT NULL)
RETURNS TABLE(match_id uuid, name text, baum text, baum_id uuid, familie_id uuid, sichtbar boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH n AS (
    SELECT public.merge_norm(p_vorname)  AS vn,
           public.merge_norm(p_nachname) AS nn,
           nullif(trim(coalesce(p_birth_date,'')),'') AS bd,
           public.merge_norm(p_land)     AS ld
  )
  SELECT pe.id,
         trim(coalesce(pe.vorname,'')||' '||coalesce(pe.nachname,'')) AS name,
         CASE WHEN public.sieht_familie(pe.familie_id) THEN s.name || coalesce(' (' || nullif(btrim(s.zusatz),'') || ')', '') END AS baum,
         CASE WHEN public.sieht_familie(pe.familie_id) THEN pe.stammbaum_id END AS baum_id,
         CASE WHEN public.sieht_familie(pe.familie_id) THEN pe.familie_id  END AS familie_id,
         public.sieht_familie(pe.familie_id) AS sichtbar
  FROM public.personen pe
  LEFT JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  CROSS JOIN n
  WHERE n.vn <> '' AND n.nn <> '' AND n.bd IS NOT NULL AND n.ld <> ''
    AND public.merge_norm(pe.vorname)  = n.vn
    AND public.merge_norm(pe.nachname) = n.nn
    AND nullif(trim(coalesce(pe.stammbaum_daten->>'birth_date','')),'') = n.bd
    AND public.merge_norm(coalesce(pe.stammbaum_daten->>'geburtsland','')) = n.ld
    AND (p_exclude_person IS NULL OR pe.id <> p_exclude_person);
$$;
GRANT EXECUTE ON FUNCTION public.dubletten_check_global(text, text, text, text, uuid) TO authenticated;


-- ---------- 3) INTERN: Verknüpfung real durchführen ----------
-- modus='beziehung': legt die geplante Beziehung zwischen kontext_person und ziel_person
--   in der Quell-Familie an (keine Dublette wird erzeugt) und legt beide Familien in denselben Verbund.
-- modus='merge': führt kontext_person in ziel_person zusammen (person_merge_aufgeloest).
CREATE OR REPLACE FUNCTION public._vkn_ausfuehren(
  p_modus text, p_kontext uuid, p_ziel uuid, p_typ text, p_zweiter uuid,
  p_quelle_fam uuid, p_ziel_fam uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_vq uuid; v_vz uuid;
BEGIN
  IF p_modus = 'merge' THEN
    -- Bestehende Karte (ziel) bleibt, applikantenseitige Karte (kontext) wird hineingemergt.
    -- Kern-Merge OHNE erneute Rechteprüfung: die Berechtigung wurde vom Aufrufer
    -- (verknuepfung_entscheiden = Ziel-Admin, bzw. Super-Admin) bereits geprüft.
    PERFORM public._person_merge_core(p_ziel, p_kontext, '{}'::jsonb);
    RETURN;   -- _person_merge_core legt die Verbünde bereits zusammen
  END IF;

  -- modus='beziehung': geplante Kante anlegen (elternteil: person_a=Elternteil -> person_b=Kind)
  IF p_kontext IS NOT NULL AND p_ziel IS NOT NULL THEN
    IF p_typ = 'elternteil' THEN
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
      VALUES (p_ziel, p_kontext, 'elternteil', p_quelle_fam);
    ELSIF p_typ = 'partner' THEN
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
      VALUES (p_kontext, p_ziel, 'ehepartner', p_quelle_fam);
    ELSIF p_typ = 'kind' THEN
      INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
      VALUES (p_kontext, p_ziel, 'elternteil', p_quelle_fam);
      IF p_zweiter IS NOT NULL AND p_zweiter <> p_kontext THEN
        INSERT INTO public.beziehungen(person_a, person_b, typ, familie_id)
        VALUES (p_zweiter, p_ziel, 'elternteil', p_quelle_fam);
      END IF;
    END IF;
  END IF;

  -- Verbünde zusammenlegen (Navigation zwischen den Bäumen, Isolation bleibt sonst gewahrt)
  IF p_quelle_fam IS NOT NULL AND p_ziel_fam IS NOT NULL AND p_quelle_fam <> p_ziel_fam THEN
    SELECT verbund_id INTO v_vq FROM public.familien WHERE id = p_quelle_fam;
    SELECT verbund_id INTO v_vz FROM public.familien WHERE id = p_ziel_fam;
    IF v_vq IS NOT NULL AND v_vz IS NOT NULL AND v_vq <> v_vz THEN
      UPDATE public.familien SET verbund_id = v_vz WHERE verbund_id = v_vq;
    END IF;
  END IF;
END $$;


-- ---------- 4) VERKNÜPFUNG BEANTRAGEN ----------
-- Rückgabe: 'sofort' (Super-Admin -> direkt ausgeführt) | 'angefragt' (Antrag erstellt).
CREATE OR REPLACE FUNCTION public.verknuepfung_anfragen(
  p_modus text, p_kontext uuid, p_ziel uuid, p_typ text DEFAULT NULL,
  p_zweiter uuid DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_qf uuid; v_zf uuid; v_qb uuid;
BEGIN
  IF p_ziel IS NULL THEN RAISE EXCEPTION 'Ziel-Person fehlt.'; END IF;
  SELECT familie_id, stammbaum_id INTO v_qf, v_qb FROM public.personen WHERE id = p_kontext;
  SELECT familie_id INTO v_zf FROM public.personen WHERE id = p_ziel;
  IF v_zf IS NULL THEN RAISE EXCEPTION 'Ziel-Person nicht gefunden.'; END IF;
  -- Antragsteller muss seine eigene (Quell-)Familie bearbeiten dürfen
  IF v_qf IS NOT NULL AND NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_qf)) THEN
    RAISE EXCEPTION 'Keine Berechtigung für die Quell-Familie.';
  END IF;

  -- Super-Admin: sofort verknüpfen, kein Genehmigungsschritt
  IF public.ist_super_admin() THEN
    PERFORM public._vkn_ausfuehren(coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter, v_qf, v_zf);
    INSERT INTO public.verknuepfungs_anfragen(
      modus, kontext_person, ziel_person, bez_typ, zweiter_elternteil,
      quelle_familie, ziel_familie, quelle_baum, status, entschieden_von, entschieden_am)
    VALUES (coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter,
      v_qf, v_zf, v_qb, 'genehmigt', auth.uid(), now());
    RETURN 'sofort';
  END IF;

  -- sonst: Antrag erstellen (Genehmigung durch Ziel-Familie-Admin)
  INSERT INTO public.verknuepfungs_anfragen(
    modus, kontext_person, ziel_person, bez_typ, zweiter_elternteil,
    quelle_familie, ziel_familie, quelle_baum)
  VALUES (coalesce(p_modus,'beziehung'), p_kontext, p_ziel, p_typ, p_zweiter, v_qf, v_zf, v_qb);
  RETURN 'angefragt';
END $$;
GRANT EXECUTE ON FUNCTION public.verknuepfung_anfragen(text, uuid, uuid, text, uuid) TO authenticated;


-- ---------- 5) OFFENE ANTRÄGE FÜR DEN ZIEL-ADMIN (mit Vorschau) ----------
-- Der genehmigende Admin (Owner/Admin der Ziel-Familie) sieht die nötige Vorschau:
-- Antragsteller-Person + Herkunftsbaum, Ziel-Person + Zielbaum, Beziehungstyp.
CREATE OR REPLACE FUNCTION public.verknuepfungs_anfragen_offen()
RETURNS TABLE(
  id uuid, created_at timestamptz, modus text, bez_typ text,
  kontext_name text, quelle_baum_name text,
  ziel_name text, ziel_baum_name text,
  antragsteller_email text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT v.id, v.created_at, v.modus, v.bez_typ,
    trim(coalesce(pk.vorname,'')||' '||coalesce(pk.nachname,'')) AS kontext_name,
    sq.name || coalesce(' (' || nullif(btrim(sq.zusatz),'') || ')', '') AS quelle_baum_name,
    trim(coalesce(pz.vorname,'')||' '||coalesce(pz.nachname,'')) AS ziel_name,
    sz.name || coalesce(' (' || nullif(btrim(sz.zusatz),'') || ')', '') AS ziel_baum_name,
    u.email AS antragsteller_email
  FROM public.verknuepfungs_anfragen v
  LEFT JOIN public.personen   pk ON pk.id = v.kontext_person
  LEFT JOIN public.personen   pz ON pz.id = v.ziel_person
  LEFT JOIN public.stammbaeume sq ON sq.id = v.quelle_baum
  LEFT JOIN public.stammbaeume sz ON sz.id = pz.stammbaum_id
  LEFT JOIN auth.users        u  ON u.id = v.antragsteller
  WHERE v.status = 'offen'
    AND (public.ist_super_admin() OR public.kann_familie_bearbeiten(v.ziel_familie))
  ORDER BY v.created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.verknuepfungs_anfragen_offen() TO authenticated;


-- ---------- 6) ENTSCHEIDUNG: Genehmigen / Ablehnen ----------
CREATE OR REPLACE FUNCTION public.verknuepfung_entscheiden(p_id uuid, p_aktion text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v public.verknuepfungs_anfragen%ROWTYPE;
BEGIN
  SELECT * INTO v FROM public.verknuepfungs_anfragen WHERE id = p_id;
  IF v.id IS NULL THEN RAISE EXCEPTION 'Antrag nicht gefunden.'; END IF;
  IF v.status <> 'offen' THEN RAISE EXCEPTION 'Antrag ist bereits entschieden.'; END IF;
  -- Nur Owner/Admin der ZIEL-Familie (oder Super-Admin) darf entscheiden
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v.ziel_familie)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;

  IF p_aktion = 'genehmigt' THEN
    PERFORM public._vkn_ausfuehren(v.modus, v.kontext_person, v.ziel_person, v.bez_typ,
                                   v.zweiter_elternteil, v.quelle_familie, v.ziel_familie);
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
SELECT 'Verknüpfungs-Anträge angelegt: dubletten_check_global, verknuepfung_anfragen, verknuepfungs_anfragen_offen, verknuepfung_entscheiden (+ Tabelle)' AS status;
