-- =====================================================
-- PERSONEN EINES BAUMS (für manuelle "Gleiche Person"-Verknüpfung)
-- Ausführen in: Supabase -> SQL Editor. Idempotent.
--
-- Hintergrund: Das "Gleiche Person verknüpfen"-Modal (nur Super-Admin) zeigte
-- bislang nur AUTOMATISCH erkannte Dubletten (offene_dubletten). Wenn zwischen
-- zwei Bäumen keine automatische Übereinstimmung gefunden wird (z. B. Vorname
-- weicht ab: "Desa" vs "Desanka"), konnte man die Karten nicht verknüpfen.
-- Diese RPC liefert ALLE Personen eines Baums für eine manuelle Auswahl je Baum.
--
-- Rechte: nur Super-Admin ODER Admin/Owner der Familie des Baums (wie
-- personen_fuer_verknuepfung). identitaet_id wird mitgeliefert, damit das
-- Frontend bereits verknüpfte Karten markieren kann (🔗).
-- Voraussetzung: public.ist_super_admin(), public.kann_familie_bearbeiten(uuid).
-- =====================================================
CREATE OR REPLACE FUNCTION public.personen_eines_baums(p_baum uuid)
RETURNS TABLE(id uuid, name text, identitaet_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT pe.id,
         trim(coalesce(pe.vorname,'') || ' ' || coalesce(pe.nachname,''))
           || coalesce(' (* ' || (pe.stammbaum_daten->>'birth_date') || ')', '') AS name,
         pe.identitaet_id
  FROM public.personen pe
  JOIN public.stammbaeume s ON s.id = pe.stammbaum_id
  WHERE pe.stammbaum_id = p_baum
    AND pe.geloescht_am IS NULL
    AND (public.ist_super_admin() OR public.kann_familie_bearbeiten(s.familie_id))
  ORDER BY pe.nachname, pe.vorname;
$$;
GRANT EXECUTE ON FUNCTION public.personen_eines_baums(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'personen_eines_baums(p_baum) angelegt (manuelle Gleiche-Person-Auswahl je Baum)' AS status;
