// Edge Function: papierkorb-purge  (selbst-enthaltend – für Dashboard-Editor)
// Wöchentlich/täglich per pg_cron + pg_net aufgerufen. Ablauf (VOLL UNBEAUFSICHTIGT):
//   1) papierkorb_purge(30)          -> löscht physisch, was >30 Tage im Papierkorb liegt
//      (CASCADE). Dabei füllen die BEFORE-DELETE-Trigger die Queue `verwaiste_medien`
//      mit den Storage-Pfaden der mitgelöschten Medien.
//   2) verwaiste_medien (bereinigt=false) lesen (service_role -> RLS-Bypass).
//   3) Dateien je Bucket aus dem Storage löschen (service_role darf überall).
//   4) Zeilen als bereinigt markieren.
//
// Damit ist die 30-Tage-Bereinigung komplett server-seitig — kein super_admin muss den
// Papierkorb öffnen. (Der Frontend-Sweep bleibt als sofortige Bereinigung bei „Endgültig
// löschen" zusätzlich erhalten; beide drainen dieselbe Queue idempotent.)
//
// Body: {} . Aufruf NUR mit Header `x-cron-secret` (== Secret CRON_SECRET).
//   Für diese Function „Verify JWT" AUS (dann zählt nur x-cron-secret).
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CRON_SECRET, optional PURGE_TAGE (Default 30).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET  = Deno.env.get("CRON_SECRET") ?? "";
const PURGE_TAGE   = parseInt(Deno.env.get("PURGE_TAGE") ?? "30", 10) || 30;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const secret = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!CRON_SECRET || secret !== CRON_SECRET) return json({ error: "unauthorized" }, 401);

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // 1) Physischer Purge (>30 Tage). Trigger füllen dabei verwaiste_medien.
    const { data: purge, error: errPurge } = await admin.rpc("papierkorb_purge", { p_tage: PURGE_TAGE });
    if (errPurge) return json({ error: errPurge.message }, 500);

    // 2) Offene Storage-Waisen holen (service_role -> RLS-Bypass).
    const { data: offen, error: errSel } = await admin
      .from("verwaiste_medien")
      .select("id, bucket, pfad")
      .eq("bereinigt", false)
      .limit(2000);
    if (errSel) return json({ error: errSel.message, purge }, 500);
    const rows = (offen ?? []) as { id: string; bucket: string; pfad: string }[];

    // 3) Dateien je Bucket löschen (best-effort).
    const proBucket: Record<string, string[]> = {};
    for (const r of rows) {
      if (!r.bucket || !r.pfad) continue;
      (proBucket[r.bucket] = proBucket[r.bucket] ?? []).push(r.pfad);
    }
    let geloescht = 0;
    const fehler: string[] = [];
    for (const bucket of Object.keys(proBucket)) {
      const pfade = [...new Set(proBucket[bucket])];
      const { error } = await admin.storage.from(bucket).remove(pfade);
      if (error) fehler.push(`${bucket}: ${error.message}`);
      else geloescht += pfade.length;
    }

    // 4) Zeilen als bereinigt markieren (auch wenn eine Datei schon fehlte -> kein Endlos-Retry).
    let markiert = 0;
    if (rows.length) {
      const ids = rows.map((r) => r.id);
      const { error: errUpd, count } = await admin
        .from("verwaiste_medien")
        .update({ bereinigt: true, bereinigt_am: new Date().toISOString() }, { count: "exact" })
        .in("id", ids);
      if (errUpd) fehler.push(`mark: ${errUpd.message}`);
      else markiert = count ?? ids.length;
    }

    return json({ ok: true, purge, storage_dateien: geloescht, markiert,
                  fehler: fehler.length ? fehler : undefined });
  } catch (e) {
    console.error("papierkorb-purge:", String(e));
    return json({ error: String(e) }, 500);
  }
});
