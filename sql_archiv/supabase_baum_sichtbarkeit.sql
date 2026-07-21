-- ============================================================================
-- BAUM-SICHTBARKEIT — „Im Baum anzeigen" dauerhaft für ALLE Baum-Berechtigten
-- ----------------------------------------------------------------------------
-- Persistiert den Render-Override „diese Karte erzwungen einblenden" (bisher nur
-- clientseitig in forceGezeigt). EIGENE Tabelle statt personen-Spalte, damit ein
-- Ein-/Ausblenden NICHT die schwere personen-Trigger-/Realtime-Kaskade auslöst.
-- Idempotent. Im Supabase SQL-Editor ausführen (nach personen/stammbaeume/familien).
--
-- familie_id ist DENORMALISIERT mitgeführt -> einfache, rekursionsfreie RLS
-- (sieht_familie / kann_familie_bearbeiten), analog reaktionen/benachrichtigungs_einstellungen.
-- Eine Zeile bedeutet: Karte im Baum erzwungen sichtbar (sichtbar=true). Kein Eintrag = Default
-- (Renderer entscheidet). Schreiben ausschließlich über die RPC karte_sichtbar_setzen.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.baum_sichtbarkeit (
  stammbaum_id uuid NOT NULL REFERENCES public.stammbaeume(id) ON DELETE CASCADE,
  person_id    uuid NOT NULL REFERENCES public.personen(id)    ON DELETE CASCADE,
  familie_id   uuid NOT NULL REFERENCES public.familien(id)    ON DELETE CASCADE,  -- denormalisiert für RLS
  sichtbar     boolean NOT NULL DEFAULT true,
  gesetzt_von  uuid REFERENCES auth.users(id),
  gesetzt_am   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (stammbaum_id, person_id)
);

ALTER TABLE public.baum_sichtbarkeit ENABLE ROW LEVEL SECURITY;

-- Lesen: alle Baum-Berechtigten (Verbund) + Super-Admin.
DROP POLICY IF EXISTS "bs_select" ON public.baum_sichtbarkeit;
CREATE POLICY "bs_select" ON public.baum_sichtbarkeit FOR SELECT TO authenticated
  USING (public.ist_super_admin() OR public.sieht_familie(familie_id));

-- Schreiben (defensiv; Hauptpfad ist die SECURITY-DEFINER-RPC): nur owner/familien_admin/super_admin.
DROP POLICY IF EXISTS "bs_write" ON public.baum_sichtbarkeit;
CREATE POLICY "bs_write" ON public.baum_sichtbarkeit FOR ALL TO authenticated
  USING      (public.ist_super_admin() OR public.kann_familie_bearbeiten(familie_id))
  WITH CHECK (public.ist_super_admin() OR public.kann_familie_bearbeiten(familie_id));

-- RPC: Sichtbarkeit setzen/entfernen. Baum + Familie werden SERVERSEITIG aus der Person abgeleitet
-- (Client kann kein fremdes stammbaum_id/familie_id unterschieben). Rechteprüfung explizit.
CREATE OR REPLACE FUNCTION public.karte_sichtbar_setzen(p_person uuid, p_sichtbar boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_me uuid := auth.uid(); v_baum uuid; v_fam uuid;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'nicht_eingeloggt'); END IF;
  SELECT stammbaum_id, familie_id INTO v_baum, v_fam
    FROM public.personen WHERE id = p_person AND geloescht_am IS NULL;
  IF v_baum IS NULL THEN RETURN jsonb_build_object('ok', false, 'grund', 'person_fehlt'); END IF;
  IF NOT (public.ist_super_admin() OR public.kann_familie_bearbeiten(v_fam)) THEN
    RETURN jsonb_build_object('ok', false, 'grund', 'keine_rechte');
  END IF;

  IF p_sichtbar THEN
    INSERT INTO public.baum_sichtbarkeit (stammbaum_id, person_id, familie_id, sichtbar, gesetzt_von)
    VALUES (v_baum, p_person, v_fam, true, v_me)
    ON CONFLICT (stammbaum_id, person_id)
      DO UPDATE SET sichtbar = true, gesetzt_von = v_me, gesetzt_am = now();
  ELSE
    DELETE FROM public.baum_sichtbarkeit WHERE stammbaum_id = v_baum AND person_id = p_person;
  END IF;

  RETURN jsonb_build_object('ok', true, 'stammbaum_id', v_baum, 'sichtbar', p_sichtbar);
END $$;
-- Nur authenticated darf aufrufen (CREATE FUNCTION grantet sonst standardmäßig an PUBLIC/anon;
-- harmlos, da die Funktion ohne auth.uid() nichts tut, aber wir entziehen es zur Sauberkeit).
REVOKE ALL ON FUNCTION public.karte_sichtbar_setzen(uuid, boolean) FROM public;
REVOKE ALL ON FUNCTION public.karte_sichtbar_setzen(uuid, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.karte_sichtbar_setzen(uuid, boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'supabase_baum_sichtbarkeit.sql ausgeführt — Tabelle + RLS + karte_sichtbar_setzen()' AS status;
