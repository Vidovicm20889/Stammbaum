-- =====================================================
-- EINKAUFSLISTEN (Rezepte-Bereich) — Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- Mehrere Listen je Verbund, EXPLIZIT geteilt (Teilnehmer wie Gruppen-Chat: nur gezielte
-- Nutzer sehen/bearbeiten eine Liste). Artikel aus Kochbuch (strukturiert Menge/Einheit),
-- eigenen Rezepten (Textzeilen) oder manuell; gleiche Artikel werden ZUSAMMENGEFÜHRT
-- (Menge summiert bei gleichem Name+Einheit). „gekauft" per Klick (Toggle). Realtime wie Chat.
--
-- RLS rekursionsfrei über den SECURITY-DEFINER-Helfer ist_einkauf_teilnehmer(); Schreiben nur
-- über SECURITY-DEFINER-RPCs (Teilnahme serverseitig geprüft). Reihenfolge: NACH supabase_chat.sql
-- (nutzt verbund_nutzer()) und supabase_beitraege.sql (nutzt mein_verbund()).
-- =====================================================

-- ── 1) Tabellen ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.einkaufslisten (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verbund_id  uuid,
  name        text NOT NULL,
  erstellt_von uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  erstellt_am timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.einkauf_teilnehmer (
  liste_id        uuid NOT NULL REFERENCES public.einkaufslisten(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  hinzugefuegt_am timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (liste_id, user_id)
);
CREATE TABLE IF NOT EXISTS public.einkauf_artikel (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  liste_id       uuid NOT NULL REFERENCES public.einkaufslisten(id) ON DELETE CASCADE,
  name           text NOT NULL,
  name_norm      text NOT NULL DEFAULT '',   -- lower(trim(name)) für den Merge
  menge          numeric,                     -- nullable (z. B. „nach Geschmack")
  einheit        text,                        -- Einheiten-Code (g/kg/ml/... /ng) oder NULL
  gekauft        boolean NOT NULL DEFAULT false,
  gekauft_von    uuid,
  gekauft_am     timestamptz,
  hinzugefuegt_von uuid,
  quelle         text,                        -- 'kochbuch' | 'eigene' | 'manuell'
  sortierung     int NOT NULL DEFAULT 0,
  erstellt_am    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ea_liste ON public.einkauf_artikel(liste_id);
CREATE INDEX IF NOT EXISTS idx_et_user  ON public.einkauf_teilnehmer(user_id);

ALTER TABLE public.einkaufslisten    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.einkauf_teilnehmer ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.einkauf_artikel   ENABLE ROW LEVEL SECURITY;

-- ── 2) Teilnehmer-Helfer (rekursionsfrei, DEFINER) ───────────────
CREATE OR REPLACE FUNCTION public.ist_einkauf_teilnehmer(p_liste uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.einkauf_teilnehmer
     WHERE liste_id = p_liste AND user_id = auth.uid()
  );
$$;
GRANT EXECUTE ON FUNCTION public.ist_einkauf_teilnehmer(uuid) TO authenticated;

-- ── 3) RLS: nur SELECT direkt (Teilnehmer); Schreiben ausschließlich über RPCs ──
DROP POLICY IF EXISTS el_sel ON public.einkaufslisten;
CREATE POLICY el_sel ON public.einkaufslisten FOR SELECT USING (public.ist_einkauf_teilnehmer(id));
DROP POLICY IF EXISTS et_sel ON public.einkauf_teilnehmer;
CREATE POLICY et_sel ON public.einkauf_teilnehmer FOR SELECT USING (public.ist_einkauf_teilnehmer(liste_id));
DROP POLICY IF EXISTS ea_sel ON public.einkauf_artikel;
CREATE POLICY ea_sel ON public.einkauf_artikel FOR SELECT USING (public.ist_einkauf_teilnehmer(liste_id));

-- ── 4) RPCs (SECURITY DEFINER, Teilnahme geprüft) ────────────────

-- 4a) Liste anlegen (im eigenen Verbund) + Teilnehmer (inkl. Ersteller). Nur Verbund-Nutzer zulässig.
CREATE OR REPLACE FUNCTION public.einkauf_liste_anlegen(p_name text, p_teilnehmer uuid[] DEFAULT '{}')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_id uuid; v_u uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'nicht_eingeloggt'; END IF;
  IF coalesce(btrim(p_name), '') = '' THEN RAISE EXCEPTION 'name_leer'; END IF;
  INSERT INTO public.einkaufslisten(verbund_id, name, erstellt_von)
    VALUES (public.mein_verbund(), btrim(p_name), v_me) RETURNING id INTO v_id;
  INSERT INTO public.einkauf_teilnehmer(liste_id, user_id) VALUES (v_id, v_me) ON CONFLICT DO NOTHING;
  FOREACH v_u IN ARRAY coalesce(p_teilnehmer, '{}'::uuid[]) LOOP
    IF v_u <> v_me AND EXISTS (SELECT 1 FROM public.verbund_nutzer() vn WHERE vn.user_id = v_u) THEN
      INSERT INTO public.einkauf_teilnehmer(liste_id, user_id) VALUES (v_id, v_u) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.einkauf_liste_anlegen(text, uuid[]) TO authenticated;

-- 4b) Meine Listen (an denen ich teilnehme) + Zähler
CREATE OR REPLACE FUNCTION public.einkauf_listen_holen()
RETURNS TABLE(id uuid, name text, erstellt_von uuid, ist_ersteller boolean,
              teilnehmer_zahl int, offen_zahl int, gekauft_zahl int, erstellt_am timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT l.id, l.name, l.erstellt_von, (l.erstellt_von = auth.uid()),
         (SELECT count(*)::int FROM public.einkauf_teilnehmer t WHERE t.liste_id = l.id),
         (SELECT count(*)::int FROM public.einkauf_artikel a WHERE a.liste_id = l.id AND NOT a.gekauft),
         (SELECT count(*)::int FROM public.einkauf_artikel a WHERE a.liste_id = l.id AND a.gekauft),
         l.erstellt_am
    FROM public.einkaufslisten l
   WHERE public.ist_einkauf_teilnehmer(l.id)
   ORDER BY l.erstellt_am DESC;
$$;
GRANT EXECUTE ON FUNCTION public.einkauf_listen_holen() TO authenticated;

-- 4c) Teilnehmer einer Liste (Namen/Avatare via verbund_nutzer)
CREATE OR REPLACE FUNCTION public.einkauf_teilnehmer_holen(p_liste uuid)
RETURNS TABLE(user_id uuid, anzeigename text, avatar_url text, ist_ersteller boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT t.user_id, vn.anzeigename, vn.avatar_url,
         (t.user_id = (SELECT erstellt_von FROM public.einkaufslisten WHERE id = p_liste))
    FROM public.einkauf_teilnehmer t
    LEFT JOIN public.verbund_nutzer() vn ON vn.user_id = t.user_id
   WHERE t.liste_id = p_liste AND public.ist_einkauf_teilnehmer(p_liste)
   ORDER BY vn.anzeigename NULLS LAST;
$$;
GRANT EXECUTE ON FUNCTION public.einkauf_teilnehmer_holen(uuid) TO authenticated;

-- 4d) Teilen: Teilnehmer hinzufügen (nur Teilnehmer; nur Verbund-Nutzer)
CREATE OR REPLACE FUNCTION public.einkauf_liste_teilen(p_liste uuid, p_user_ids uuid[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_u uuid;
BEGIN
  IF NOT public.ist_einkauf_teilnehmer(p_liste) THEN RAISE EXCEPTION 'nicht_berechtigt'; END IF;
  FOREACH v_u IN ARRAY coalesce(p_user_ids, '{}'::uuid[]) LOOP
    IF EXISTS (SELECT 1 FROM public.verbund_nutzer() vn WHERE vn.user_id = v_u) THEN
      INSERT INTO public.einkauf_teilnehmer(liste_id, user_id) VALUES (p_liste, v_u) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END; $$;
GRANT EXECUTE ON FUNCTION public.einkauf_liste_teilen(uuid, uuid[]) TO authenticated;

-- 4e) Teilnehmer entfernen (sich selbst = verlassen; Ersteller darf andere entfernen)
CREATE OR REPLACE FUNCTION public.einkauf_teilnehmer_entfernen(p_liste uuid, p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_ersteller uuid;
BEGIN
  IF NOT public.ist_einkauf_teilnehmer(p_liste) THEN RAISE EXCEPTION 'nicht_berechtigt'; END IF;
  SELECT erstellt_von INTO v_ersteller FROM public.einkaufslisten WHERE id = p_liste;
  IF p_user <> v_me AND v_me <> v_ersteller THEN RAISE EXCEPTION 'nicht_berechtigt'; END IF;
  DELETE FROM public.einkauf_teilnehmer WHERE liste_id = p_liste AND user_id = p_user;
END; $$;
GRANT EXECUTE ON FUNCTION public.einkauf_teilnehmer_entfernen(uuid, uuid) TO authenticated;

-- 4f) Liste löschen (nur Ersteller)
CREATE OR REPLACE FUNCTION public.einkauf_liste_loeschen(p_liste uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.einkaufslisten WHERE id = p_liste AND erstellt_von = auth.uid())
    THEN RAISE EXCEPTION 'nicht_berechtigt'; END IF;
  DELETE FROM public.einkaufslisten WHERE id = p_liste;   -- Artikel/Teilnehmer per CASCADE
END; $$;
GRANT EXECUTE ON FUNCTION public.einkauf_liste_loeschen(uuid) TO authenticated;

-- 4g) Artikel holen (offen + gekauft; Frontend teilt in zwei Reiter)
CREATE OR REPLACE FUNCTION public.einkauf_artikel_holen(p_liste uuid)
RETURNS TABLE(id uuid, name text, menge numeric, einheit text, gekauft boolean,
              gekauft_von uuid, hinzugefuegt_von uuid, quelle text, erstellt_am timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT a.id, a.name, a.menge, a.einheit, a.gekauft, a.gekauft_von, a.hinzugefuegt_von, a.quelle, a.erstellt_am
    FROM public.einkauf_artikel a
   WHERE a.liste_id = p_liste AND public.ist_einkauf_teilnehmer(p_liste)
   ORDER BY a.gekauft, a.erstellt_am;
$$;
GRANT EXECUTE ON FUNCTION public.einkauf_artikel_holen(uuid) TO authenticated;

-- 4h) EINEN Artikel hinzufügen mit MERGE (gleicher Name+Einheit, noch offen -> Menge summieren)
CREATE OR REPLACE FUNCTION public.einkauf_artikel_add(p_liste uuid, p_name text, p_menge numeric,
                                                      p_einheit text, p_quelle text DEFAULT 'manuell')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_norm text; v_id uuid;
BEGIN
  IF NOT public.ist_einkauf_teilnehmer(p_liste) THEN RAISE EXCEPTION 'nicht_berechtigt'; END IF;
  IF coalesce(btrim(p_name), '') = '' THEN RAISE EXCEPTION 'name_leer'; END IF;
  v_norm := lower(btrim(p_name));
  -- vorhandenen OFFENEN Artikel gleicher Bezeichnung + Einheit suchen
  SELECT id INTO v_id FROM public.einkauf_artikel
   WHERE liste_id = p_liste AND NOT gekauft
     AND name_norm = v_norm AND coalesce(einheit,'') = coalesce(p_einheit,'')
   LIMIT 1;
  IF v_id IS NOT NULL THEN
    IF p_menge IS NOT NULL THEN
      UPDATE public.einkauf_artikel SET menge = coalesce(menge, 0) + p_menge WHERE id = v_id;
    END IF;
    RETURN v_id;
  END IF;
  INSERT INTO public.einkauf_artikel(liste_id, name, name_norm, menge, einheit, hinzugefuegt_von, quelle)
    VALUES (p_liste, btrim(p_name), v_norm, p_menge, nullif(p_einheit,''), v_me, coalesce(p_quelle,'manuell'))
    RETURNING id INTO v_id;
  RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.einkauf_artikel_add(uuid, text, numeric, text, text) TO authenticated;

-- 4i) MEHRERE Artikel aus einem Rezept (jsonb-Array [{name, menge, einheit}]) -> je Artikel Merge
CREATE OR REPLACE FUNCTION public.einkauf_artikel_add_viele(p_liste uuid, p_artikel jsonb, p_quelle text DEFAULT 'kochbuch')
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE e jsonb; n int := 0;
BEGIN
  IF NOT public.ist_einkauf_teilnehmer(p_liste) THEN RAISE EXCEPTION 'nicht_berechtigt'; END IF;
  IF p_artikel IS NULL OR jsonb_typeof(p_artikel) <> 'array' THEN RETURN 0; END IF;
  FOR e IN SELECT * FROM jsonb_array_elements(p_artikel) LOOP
    IF coalesce(btrim(e->>'name'),'') <> '' THEN
      PERFORM public.einkauf_artikel_add(p_liste, e->>'name',
        CASE WHEN (e->>'menge') ~ '^-?\d+(\.\d+)?$' THEN (e->>'menge')::numeric ELSE NULL END,
        e->>'einheit', p_quelle);
      n := n + 1;
    END IF;
  END LOOP;
  RETURN n;
END; $$;
GRANT EXECUTE ON FUNCTION public.einkauf_artikel_add_viele(uuid, jsonb, text) TO authenticated;

-- 4j) gekauft umschalten (1 Klick); stempelt gekauft_von/-am
CREATE OR REPLACE FUNCTION public.einkauf_artikel_toggle(p_artikel uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_liste uuid; v_neu boolean;
BEGIN
  SELECT liste_id, NOT gekauft INTO v_liste, v_neu FROM public.einkauf_artikel WHERE id = p_artikel;
  IF v_liste IS NULL OR NOT public.ist_einkauf_teilnehmer(v_liste) THEN RAISE EXCEPTION 'nicht_berechtigt'; END IF;
  UPDATE public.einkauf_artikel
     SET gekauft = v_neu,
         gekauft_von = CASE WHEN v_neu THEN auth.uid() ELSE NULL END,
         gekauft_am  = CASE WHEN v_neu THEN now() ELSE NULL END
   WHERE id = p_artikel;
END; $$;
GRANT EXECUTE ON FUNCTION public.einkauf_artikel_toggle(uuid) TO authenticated;

-- 4k) Artikel löschen (jeder Teilnehmer)
CREATE OR REPLACE FUNCTION public.einkauf_artikel_loeschen(p_artikel uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_liste uuid;
BEGIN
  SELECT liste_id INTO v_liste FROM public.einkauf_artikel WHERE id = p_artikel;
  IF v_liste IS NULL OR NOT public.ist_einkauf_teilnehmer(v_liste) THEN RAISE EXCEPTION 'nicht_berechtigt'; END IF;
  DELETE FROM public.einkauf_artikel WHERE id = p_artikel;
END; $$;
GRANT EXECUTE ON FUNCTION public.einkauf_artikel_loeschen(uuid) TO authenticated;

-- ── 5) Realtime (wie Chat): die drei Tabellen in die Publication aufnehmen ──
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='einkauf_artikel')
    THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.einkauf_artikel; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='einkauf_teilnehmer')
    THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.einkauf_teilnehmer; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='einkaufslisten')
    THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.einkaufslisten; END IF;
END $$;
ALTER TABLE public.einkauf_artikel REPLICA IDENTITY FULL;

NOTIFY pgrst, 'reload schema';

SELECT 'OK: Einkaufslisten angelegt (einkaufslisten, einkauf_teilnehmer, einkauf_artikel + RPCs + Realtime)' AS status;
