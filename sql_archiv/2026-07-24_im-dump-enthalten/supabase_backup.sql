-- =====================================================
-- BACKUP / WIEDERHERSTELLUNG (Feature: regelmäßige, wiederherstellbare Snapshots)
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run). IDEMPOTENT.
--
-- KONZEPT: Der Supabase-Free-Tier hat KEINE automatischen Backups. Eine Edge Function
-- `backup-export` schreibt täglich (pg_cron) einen LOGISCHEN JSON-Snapshot ALLER relevanten
-- Tabellen (kein pg_dump) + ein Medien-Manifest in den PRIVATEN Bucket `backups`. Wiederher-
-- stellung über die Edge Function `backup-restore` -> ruft die hier definierten, transaktionalen
-- RPCs auf (Dry-Run-Bericht, dann Ausführen nur mit Bestätigungs-Token).
--
-- SICHERHEIT:
--   * Bucket `backups` ist PRIVAT. SELECT (Liste + signierte Download-URL) nur für super_admin.
--     Schreiben/Rotieren macht ausschließlich die Edge Function mit dem Service-Role-Key
--     (bypassed RLS) — KEINE INSERT/UPDATE/DELETE-Policy für normale Nutzer.
--   * Die Restore-RPCs sind SECURITY DEFINER und NUR an service_role gegrantet. Die
--     super_admin-Prüfung leistet die Edge Function (via JWT), bevor sie die RPC ruft —
--     analog zum bestehenden Edge-Function-Muster (anlaesse/digest).
--   * Ausführen erfordert zusätzlich den Token 'RESTORE-AUSFUEHREN' (zweite Sicherung).
--
-- EHRLICHE GRENZE (dokumentiert): auth.users (Konten/Passwörter, auth-Schema) ist NICHT Teil des
--   Exports (Supabase-verwaltet, nicht über die Daten-API sicher reproduzierbar). Ein 1:1-Restore
--   in ein FRISCHES Projekt scheitert daher an den user_id-Fremdschlüsseln, solange die Konten dort
--   nicht existieren. Der realistische Schutz ist: (a) Restore IM SELBEN Projekt (Konten existieren
--   noch) gegen Fehllöschung/Migrationsfehler, (b) der Offsite-Download der Rohdaten.
--
-- Voraussetzungen: supabase_rls_setup.sql (ist_super_admin), Basistabellen vorhanden.
-- =====================================================


-- =====================================================
-- 1) PRIVATER Bucket 'backups' + Storage-RLS (nur super_admin liest/signiert)
-- =====================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('backups', 'backups', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "backups_select" ON storage.objects;
-- SELECT/list/signieren: ausschließlich super_admin. (Schreiben nur via service_role -> kein Policy.)
CREATE POLICY "backups_select" ON storage.objects FOR SELECT TO authenticated
  USING ( bucket_id = 'backups' AND public.ist_super_admin() );


-- =====================================================
-- 2) Kanonische Tabellen-Reihenfolge (Eltern -> Kinder) als EINZIGE Quelle der Wahrheit.
--    Bewusst AUSGESCHLOSSEN: bak_*/Migrations-Schrott, wartungs_sperren + verwaiste_event_medien
--    (reine Laufzeit/Queue). History-Tabellen (familien_audit/merge_log/anfrage_log) werden
--    EXPORTIERT (Edge Function), aber NICHT wieder eingespielt (Identity-/Verlaufsdaten) -> sie
--    stehen daher NICHT in dieser Restore-Reihenfolge.
-- =====================================================
CREATE OR REPLACE FUNCTION public.backup_restore_reihenfolge()
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT ARRAY[
    'familien','stammbaeume','personen','beziehungen','mitgliedschaften','profile',
    'registrierungs_anfragen','verknuepfungs_anfragen','kontakt_anfragen','kontakt_verbindungen','baum_freigaben',
    'events','event_teilnehmer','event_kosten','event_eingeladene','event_album_fotos',
    'personen_fotos','personen_dokumente','personen_geschichten','person_aufnahmen',
    'beitraege','reaktionen','kommentare','gedenk_eintraege','familien_fragen','foto_personen',
    'aktivitaeten','beitrags_statistik',
    'chats','chat_teilnehmer','chat_nachrichten',
    'benachrichtigungen','benachrichtigungs_einstellungen','digest_versand','erinnerungs_mails'
  ]::text[];
$$;


-- =====================================================
-- 3) DRY-RUN-BERICHT: je Tabelle Snapshot-Zeilen vs. aktuelle Zeilen (schreibt NICHTS).
-- =====================================================
CREATE OR REPLACE FUNCTION public.backup_restore_bericht(p_snapshot jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order text[] := public.backup_restore_reihenfolge();
  v_tab text; v_snap int; v_cur int; v_erg jsonb := '[]'::jsonb;
BEGIN
  IF p_snapshot IS NULL OR p_snapshot->'tabellen' IS NULL THEN
    RAISE EXCEPTION 'snapshot_ungueltig';
  END IF;
  FOREACH v_tab IN ARRAY v_order LOOP
    v_snap := coalesce(jsonb_array_length(p_snapshot->'tabellen'->v_tab), 0);
    EXECUTE format('SELECT count(*)::int FROM public.%I', v_tab) INTO v_cur;
    v_erg := v_erg || jsonb_build_object('tabelle', v_tab, 'snapshot', v_snap, 'aktuell', v_cur);
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'meta', p_snapshot->'meta', 'tabellen', v_erg);
END $$;
REVOKE ALL ON FUNCTION public.backup_restore_bericht(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.backup_restore_bericht(jsonb) TO service_role;


-- =====================================================
-- 4) AUSFÜHREN: transaktionaler Wipe + Insert in FK-Reihenfolge.
--    Erfordert den Token 'RESTORE-AUSFUEHREN'. session_replication_role='replica' deaktiviert
--    FK-/Trigger-Prüfung für die Transaktion (keine Aktivitäts-/Sync-Trigger beim Restore, keine
--    FK-Blockade durch ausgeschlossene Tabellen). Alles in EINER Funktion = EINE Transaktion:
--    schlägt etwas fehl, wird nichts committet.
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

  -- FK-/Trigger-Prüfung für diese Transaktion aussetzen (Supabase: Owner=postgres darf das).
  PERFORM set_config('session_replication_role', 'replica', true);

  -- 1) Löschen in UMGEKEHRTER Reihenfolge (Kinder zuerst)
  FOR v_i IN REVERSE array_length(v_order,1)..1 LOOP
    EXECUTE format('DELETE FROM public.%I', v_order[v_i]);
  END LOOP;

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

  PERFORM set_config('session_replication_role', 'origin', true);

  RETURN jsonb_build_object('ok', true, 'zeilen_gesamt', v_total, 'tabellen', v_erg);
END $$;
REVOKE ALL ON FUNCTION public.backup_restore_ausfuehren(jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.backup_restore_ausfuehren(jsonb, text) TO service_role;


NOTIFY pgrst, 'reload schema';
SELECT 'supabase_backup.sql ausgeführt — Bucket backups (privat, super_admin-RLS) + Restore-RPCs (bericht/ausfuehren, service_role). Edge Functions backup-export/backup-restore + pg_cron separat aktivieren.' AS status;
