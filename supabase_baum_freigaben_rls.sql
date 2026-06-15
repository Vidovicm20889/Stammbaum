-- =====================================================
-- RLS-ERWEITERUNG FÜR BAUM-FREIGABEN (Stufe 3 — zweite & letzte Isolations-Bruchstelle)
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
-- NACH supabase_verbund.sql UND supabase_kontakt_anfragen.sql ausführen.
--
-- ZWECK: Erweitert die SELECT-Policies auf personen/stammbaeume/beziehungen ADDITIV um den
-- Helfer darf_baum_sehen()/darf_beziehung_sehen(), sodass ein per baum_freigaben freigegebener
-- Stammbaum für den Begünstigten LESBAR wird — und sonst nichts.
--
-- SICHERHEIT:
--   * Erweiterung NUR auf SELECT (Lesen). INSERT/UPDATE/DELETE bleiben verbund-/admin-gebunden
--     (unverändert aus supabase_verbund.sql) -> eine Freigabe gibt NIE Schreibrechte.
--   * personen/stammbaeume: + darf_baum_sehen(stammbaum_id / id).
--   * beziehungen (hat KEIN stammbaum_id): + darf_beziehung_sehen(person_a, person_b) -> eine
--     Kante wird nur sichtbar, wenn BEIDE Endpunkt-Personen sichtbar sind (kein Y-Baum-Leak).
--   * Widerruf (baum_freigaben.status='widerrufen') wirkt sofort, da darf_baum_sehen live prüft.
--
-- ROLLBACK: supabase_verbund.sql erneut ausführen (stellt die reinen Verbund-Policies wieder her).
-- =====================================================

-- PERSONEN: Verbund (wie bisher) ODER freigegebener Baum (lesend).
DROP POLICY IF EXISTS "personen_select" ON public.personen;
CREATE POLICY "personen_select" ON public.personen FOR SELECT
  USING (
    public.ist_super_admin()
    OR public.sieht_familie(familie_id)
    OR public.darf_baum_sehen(stammbaum_id)
  );

-- STAMMBAEUME: der freigegebene Baum selbst muss lesbar sein.
DROP POLICY IF EXISTS "stammbaeume_select" ON public.stammbaeume;
CREATE POLICY "stammbaeume_select" ON public.stammbaeume FOR SELECT
  USING (
    public.ist_super_admin()
    OR public.sieht_familie(familie_id)
    OR public.darf_baum_sehen(id)
  );

-- BEZIEHUNGEN: nur Kanten, deren BEIDE Endpunkte sichtbar sind.
DROP POLICY IF EXISTS "beziehungen_select" ON public.beziehungen;
CREATE POLICY "beziehungen_select" ON public.beziehungen FOR SELECT
  USING (
    public.ist_super_admin()
    OR public.sieht_familie(familie_id)
    OR public.darf_beziehung_sehen(person_a, person_b)
  );

-- Kontrolle: aktuelle SELECT-Policies der drei Tabellen anzeigen.
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('personen', 'stammbaeume', 'beziehungen')
  AND cmd = 'SELECT'
ORDER BY tablename;
