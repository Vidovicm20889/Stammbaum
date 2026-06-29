-- =====================================================
-- FAMILIEN-REZEPTE & TRADITIONEN — verbund-gebundene Sammlung (Rezepte, Bräuche, Slava).
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
-- SETZT supabase_reaktionen_kommentare.sql (ist_in_verbund/darf_verbund_moderieren) +
-- supabase_beitraege.sql (mein_verbund) VORAUS. Muster exakt wie beitraege/familien_fragen.
-- STRIKT VERBUND-GEBUNDEN; Schreiben nur über SECURITY-DEFINER-RPCs.
-- Bilder: Bucket 'beitraege' (wiederverwendet, wie familien_fragen).
-- =====================================================

CREATE TABLE IF NOT EXISTS public.familien_rezepte (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id    uuid NOT NULL,
  autor         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  titel         text NOT NULL,
  kategorie     text NOT NULL DEFAULT 'rezept'
                  CHECK (kategorie IN ('rezept','tradition','brauch','slava','sonstiges')),
  text          text,                      -- Markdown-Quelle (Zutaten/Schritte/Beschreibung)
  bild_pfad     text,
  bild_url      text,
  ref_person    uuid REFERENCES public.personen(id) ON DELETE SET NULL,
  geloescht     boolean NOT NULL DEFAULT false,
  erstellt_am   timestamptz NOT NULL DEFAULT now(),
  aktualisiert_am timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS familien_rezepte_verbund_idx ON public.familien_rezepte(verbund_id, erstellt_am DESC);

ALTER TABLE public.familien_rezepte ENABLE ROW LEVEL SECURITY;

-- SELECT: nur Verbund-Mitglieder, nur nicht-gelöschte. Schreiben über RPCs (kein direktes INSERT/UPDATE).
DROP POLICY IF EXISTS familien_rezepte_select ON public.familien_rezepte;
CREATE POLICY familien_rezepte_select ON public.familien_rezepte
  FOR SELECT USING (public.ist_in_verbund(verbund_id) AND NOT geloescht);


-- Rezept/Tradition erstellen ---------------------------------------------------
CREATE OR REPLACE FUNCTION public.rezept_erstellen(
  p_titel text, p_kategorie text, p_text text,
  p_bild_pfad text DEFAULT NULL, p_bild_url text DEFAULT NULL, p_ref_person uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_verbund uuid; v_id uuid; v_ref uuid;
BEGIN
  v_verbund := public.mein_verbund();
  IF v_verbund IS NULL THEN RAISE EXCEPTION 'Kein Verbund.'; END IF;
  IF coalesce(trim(p_titel),'') = '' THEN RAISE EXCEPTION 'Titel ist erforderlich.'; END IF;

  -- Markierung nur, wenn die Person im EIGENEN Verbund liegt (Isolation).
  v_ref := NULL;
  IF p_ref_person IS NOT NULL THEN
    SELECT pe.id INTO v_ref FROM public.personen pe
      JOIN public.familien f ON f.id = pe.familie_id
     WHERE pe.id = p_ref_person AND f.verbund_id = v_verbund LIMIT 1;
  END IF;

  INSERT INTO public.familien_rezepte (verbund_id, autor, titel, kategorie, text, bild_pfad, bild_url, ref_person)
  VALUES (v_verbund, auth.uid(), trim(p_titel),
          CASE WHEN p_kategorie IN ('rezept','tradition','brauch','slava','sonstiges') THEN p_kategorie ELSE 'rezept' END,
          nullif(trim(coalesce(p_text,'')),''), p_bild_pfad, p_bild_url, v_ref)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.rezept_erstellen(text, text, text, text, text, uuid) TO authenticated;


-- Bearbeiten (nur Autor) -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rezept_bearbeiten(
  p_id uuid, p_titel text, p_kategorie text, p_text text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_autor uuid;
BEGIN
  SELECT autor INTO v_autor FROM public.familien_rezepte WHERE id = p_id AND NOT geloescht;
  IF v_autor IS NULL THEN RETURN false; END IF;
  IF v_autor <> auth.uid() THEN RAISE EXCEPTION 'Nur der Autor darf bearbeiten.'; END IF;
  IF coalesce(trim(p_titel),'') = '' THEN RAISE EXCEPTION 'Titel ist erforderlich.'; END IF;
  UPDATE public.familien_rezepte
     SET titel = trim(p_titel),
         kategorie = CASE WHEN p_kategorie IN ('rezept','tradition','brauch','slava','sonstiges') THEN p_kategorie ELSE kategorie END,
         text = nullif(trim(coalesce(p_text,'')),''), aktualisiert_am = now()
   WHERE id = p_id;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION public.rezept_bearbeiten(uuid, text, text, text) TO authenticated;


-- Löschen (Autor ODER Moderator) — soft; gibt bild_pfad für Storage-Cleanup ---
CREATE OR REPLACE FUNCTION public.rezept_loeschen(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_autor uuid; v_verbund uuid; v_pfad text;
BEGIN
  SELECT autor, verbund_id, bild_pfad INTO v_autor, v_verbund, v_pfad
    FROM public.familien_rezepte WHERE id = p_id AND NOT geloescht;
  IF v_verbund IS NULL THEN RETURN jsonb_build_object('ok', false); END IF;
  IF NOT (v_autor = auth.uid() OR public.darf_verbund_moderieren(v_verbund)) THEN
    RAISE EXCEPTION 'Keine Berechtigung.';
  END IF;
  UPDATE public.familien_rezepte SET geloescht = true, aktualisiert_am = now() WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'bild_pfad', v_pfad);
END $$;
GRANT EXECUTE ON FUNCTION public.rezept_loeschen(uuid) TO authenticated;


-- Liste laden (verbund-intern, optional nach Kategorie gefiltert) --------------
CREATE OR REPLACE FUNCTION public.rezepte_holen(p_kategorie text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_verbund uuid; v_out jsonb;
BEGIN
  v_verbund := public.mein_verbund();
  IF v_verbund IS NULL THEN RETURN '[]'::jsonb; END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', r.id, 'titel', r.titel, 'kategorie', r.kategorie, 'text', r.text,
           'bild_url', r.bild_url, 'ref_person', r.ref_person, 'erstellt_am', r.erstellt_am,
           'autor', r.autor,
           'autor_name', nullif(trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')),''),
           'autor_avatar', pr.avatar_url,
           'darf_bearbeiten', (r.autor = auth.uid()),
           'darf_loeschen', (r.autor = auth.uid() OR public.darf_verbund_moderieren(r.verbund_id))
         ) ORDER BY r.erstellt_am DESC), '[]'::jsonb)
    INTO v_out
    FROM public.familien_rezepte r
    LEFT JOIN public.profile pr ON pr.user_id = r.autor
   WHERE r.verbund_id = v_verbund AND NOT r.geloescht
     AND (p_kategorie IS NULL OR r.kategorie = p_kategorie);
  RETURN v_out;
END $$;
GRANT EXECUTE ON FUNCTION public.rezepte_holen(text) TO authenticated;


NOTIFY pgrst, 'reload schema';
SELECT 'OK: familien_rezepte + RLS + RPCs (erstellen/bearbeiten/loeschen/holen) angelegt' AS status;
