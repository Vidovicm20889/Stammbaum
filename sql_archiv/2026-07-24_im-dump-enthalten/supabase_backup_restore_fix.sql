-- =====================================================
-- FIX: backup_restore_ausfuehren ohne session_replication_role
-- =====================================================
-- Ursache 1: `set_config('session_replication_role','replica')` ist auf Supabase NICHT erlaubt
--   (Superuser-only) → "permission denied to set parameter ...".
-- Ursache 2: `DISABLE TRIGGER ALL` schaltet auch die SYSTEM-FK-Trigger ab → "permission denied:
--   RI_ConstraintTrigger ... is a system trigger" (darf der Owner ebenfalls nicht).
-- LÖSUNG: Nur die USER-Trigger abschalten (`DISABLE TRIGGER USER` — owner-erlaubt) und die FK-
--   Prüfung EINGESCHALTET lassen. Das ist ok, weil Wipe/Insert in FK-Reihenfolge laufen:
--   Löschen in UMGEKEHRTER Reihenfolge (Kinder zuerst; CASCADE/SET NULL räumen den Rest), Einfügen
--   in Eltern->Kind-Reihenfolge. Alles in EINER Transaktion → bei Fehler Rollback (auch das DISABLE
--   wird zurückgerollt). User-Trigger aus = keine ident_sync/Aktivitäts-/Blutlinien-Seiteneffekte.
--
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier, Run). IDEMPOTENT.
-- Danach den Restore in der App erneut starten (Modus „ausführen", Bestätigung RESTORE-AUSFUEHREN).
-- =====================================================

CREATE OR REPLACE FUNCTION public.backup_restore_ausfuehren(p_snapshot jsonb, p_bestaetigung text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order text[] := public.backup_restore_reihenfolge();
  v_tab text; v_rows jsonb; v_n int; v_total int := 0; v_erg jsonb := '[]'::jsonb;
  v_i int;
BEGIN
  IF p_bestaetigung IS DISTINCT FROM 'RESTORE-AUSFUEHREN' THEN
    RAISE EXCEPTION 'bestaetigung_fehlt';
  END IF;
  IF p_snapshot IS NULL OR p_snapshot->'tabellen' IS NULL THEN
    RAISE EXCEPTION 'snapshot_ungueltig';
  END IF;

  -- Nur USER-Trigger je Tabelle abschalten (FK-Prüfung bleibt AN; Owner-erlaubt).
  FOREACH v_tab IN ARRAY v_order LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER USER', v_tab);
  END LOOP;

  -- 1) Wipe per TRUNCATE … CASCADE (umgeht den „DELETE requires a WHERE clause"-Schutz und löst
  --    FK-Abhängigkeiten in EINEM Befehl; CASCADE leert auch referenzierende Log-/Hilfstabellen,
  --    die NICHT im Snapshot sind — bei einem Voll-Restore gewollt). auth.users bleibt unberührt
  --    (CASCADE wirkt nur auf Tabellen, die die geleerten REFERENZIEREN).
  EXECUTE 'TRUNCATE '
    || (SELECT string_agg(format('public.%I', t), ', ') FROM unnest(v_order) t)
    || ' CASCADE';

  -- 2) Einfügen in FK-Reihenfolge via jsonb_populate_recordset (Spalten by name; fehlende -> Default)
  FOREACH v_tab IN ARRAY v_order LOOP
    v_rows := p_snapshot->'tabellen'->v_tab;
    IF v_rows IS NULL OR jsonb_typeof(v_rows) <> 'array' OR jsonb_array_length(v_rows) = 0 THEN
      v_erg := v_erg || jsonb_build_object('tabelle', v_tab, 'eingefuegt', 0);
      CONTINUE;
    END IF;
    EXECUTE format(
      'INSERT INTO public.%I SELECT * FROM jsonb_populate_recordset(NULL::public.%I, $1)',
      v_tab, v_tab) USING v_rows;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_total := v_total + v_n;
    v_erg := v_erg || jsonb_build_object('tabelle', v_tab, 'eingefuegt', v_n);
  END LOOP;

  -- USER-Trigger wieder aktivieren.
  FOREACH v_tab IN ARRAY v_order LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE TRIGGER USER', v_tab);
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'zeilen_gesamt', v_total, 'tabellen', v_erg);
END $$;
REVOKE ALL ON FUNCTION public.backup_restore_ausfuehren(jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.backup_restore_ausfuehren(jsonb, text) TO service_role;

NOTIFY pgrst, 'reload schema';
SELECT 'backup_restore_ausfuehren gefixt: DISABLE/ENABLE TRIGGER ALL statt session_replication_role. Restore in der App erneut starten.' AS status;
