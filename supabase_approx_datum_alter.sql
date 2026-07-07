-- =====================================================
-- UNGEFÄHRE DATEN (Option A) — Alters-Check für die verbundübergreifende Discovery
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- HINTERGRUND: Datumsfelder (birth_date etc.) können jetzt auch ungenau sein:
--   * exakt      -> "YYYY-MM-DD"
--   * nur Jahr   -> "YYYY"      (z. B. "1890")
--   * circa      -> "~YYYY"     (z. B. "~1890", Anzeige "≈ 1890")
--
-- `_alter_jahre` wird von personen_entdecken()/kontakt_anfrage_stellen() für die
-- Volljährigkeits-Prüfung (>=18) genutzt. Es muss die neuen Formate verstehen — aber
-- KONSERVATIV, damit der Minderjährigenschutz streng bleibt: für "nur Jahr"/"circa" wird
-- das MINDESTALTER angenommen (Geburt am 31.12. des Jahres). Im Grenzfall gilt eine Person
-- damit eher als "zu jung" = NICHT auffindbar (sicher). Ohne diese Anpassung liefert
-- `_alter_jahre` für nicht-ISO-Werte NULL -> die Person wäre ohnehin ausgeschlossen (auch sicher),
-- aber klar volljährige Personen mit Circa-/Jahr-Datum (z. B. "circa 1970") blieben unnötig
-- unauffindbar. Diese Datei macht sie auffindbar, OHNE Minderjährige zu gefährden.
--
-- Ersetzt die frühere Definition aus supabase_auffindbarkeit.sql (gleiche Signatur).
-- =====================================================

CREATE OR REPLACE FUNCTION public._alter_jahre(p_iso text)
RETURNS int LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT CASE
    -- exaktes ISO-Datum -> genaues Alter
    WHEN p_iso ~ '^\d{4}-\d{2}-\d{2}$'
      THEN extract(year from age(p_iso::date))::int
    -- "1890" (nur Jahr) ODER "~1890" (circa) -> Mindestalter (angenommen 31.12. des Jahres);
    -- Zukunftsjahre ergeben ein negatives Alter -> automatisch < 18 -> nicht auffindbar.
    WHEN p_iso ~ '^~?\d{4}$'
      THEN extract(year from age(make_date((regexp_replace(p_iso, '\D', '', 'g'))::int, 12, 31)))::int
  END;
$$;

NOTIFY pgrst, 'reload schema';

SELECT 'OK: _alter_jahre akzeptiert exakt / nur Jahr / circa (Discovery-Volljaehrigkeit bleibt konservativ)' AS status;
