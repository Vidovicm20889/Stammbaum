-- ============================================================================
-- FIX #6 — Gelöschte/leere Familie noch in den Einstellungen sichtbar
-- ----------------------------------------------------------------------------
-- URSACHE (belegt):
--   * Nav-Dropdown  -> befuelleStammbaumAuswahl() liest aus `stammbaeume` (stammbaeumeListe).
--     Eine Familie OHNE Baum erscheint dort NICHT.
--   * Einstellungen -> ladeMitglieder()/ladeAddFamilien() lesen aus RPC `verwaltbare_familien`,
--     die JEDE Familie mit Owner/Admin-Mitgliedschaft (bzw. super_admin = ALLE) liefert —
--     OHNE Filter auf vorhandene Bäume. -> tree-lose Familie bleibt sichtbar.
--   * Die Auto-Löschung leerer Bäume behält Familie/Mitgliedschaften BEWUSST (kontoschonend),
--     daher entstehen legitim tree-lose Familien. Kein Bug im Löschen — nur uneinheitlicher Filter.
--
-- FIX: `verwaltbare_familien` bekommt DENSELBEN Ausschluss wie die Nav — nur Familien mit
--   mindestens EINEM Stammbaum. Rückgabesignatur unverändert (CREATE OR REPLACE genügt).
--   Idempotent. Im Supabase SQL-Editor ausführen.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.verwaltbare_familien()
RETURNS TABLE(familie_id uuid, familie_name text, baum_namen text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT f.id, f.name,
    (SELECT string_agg(DISTINCT s.name || coalesce(' (' || nullif(btrim(s.zusatz),'') || ')',''), ', '
              ORDER BY (s.name || coalesce(' (' || nullif(btrim(s.zusatz),'') || ')','')))
       FROM public.stammbaeume s WHERE s.familie_id = f.id) AS baum_namen
  FROM public.familien f
  -- EINHEITLICH mit der Nav: nur Familien, die (noch) mindestens einen Stammbaum haben.
  WHERE EXISTS (SELECT 1 FROM public.stammbaeume s2 WHERE s2.familie_id = f.id)
    AND (
      public.ist_super_admin()
      OR EXISTS (SELECT 1 FROM public.mitgliedschaften m
                  WHERE m.familie_id = f.id AND m.user_id = auth.uid() AND m.aktiv
                    AND m.rolle IN ('familien_owner','familien_admin'))
    )
  ORDER BY f.name;
$$;
GRANT EXECUTE ON FUNCTION public.verwaltbare_familien() TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'verwaltbare_familien: nur noch Familien mit >=1 Stammbaum (einheitlich mit Nav)' AS status;
