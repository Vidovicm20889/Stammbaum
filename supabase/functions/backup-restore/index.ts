// Edge Function: backup-restore  (selbst-enthaltend – für Dashboard-Editor)
// Stellt einen Snapshot aus dem Bucket 'backups' wieder her. STARK ABGESICHERT:
//   * NUR eingeloggter super_admin (JWT-Prüfung über die Rolle). KEIN Cron-Pfad -> Restore
//     ist NIE automatisch.
//   * ZWEISTUFIG:
//       modus='bericht'    -> Dry-Run: je Tabelle Snapshot- vs. aktuelle Zeilen (schreibt NICHTS).
//       modus='ausfuehren' -> nur mit body.bestaetigung === 'RESTORE-AUSFUEHREN'. Transaktionaler
//                             Wipe+Insert in FK-Reihenfolge (RPC backup_restore_ausfuehren).
//   * Die eigentliche Schreiblogik liegt in der DB-RPC (eine Transaktion -> alles oder nichts).
//
// WARNUNG (Frontend zeigt das ebenfalls): 'ausfuehren' LÖSCHT alle App-Tabellen und ersetzt sie
//   durch den Snapshot. Idealerweise in ein leeres/separates Projekt. auth.users wird NICHT
//   wiederhergestellt -> bei einem fremden/leeren Projekt scheitern user_id-Fremdschlüssel
//   (Restore ist v. a. für „Fehllöschung im SELBEN Projekt rückgängig machen" gedacht).
//
// Body: { pfad: "snapshot-….json", modus: "bericht"|"ausfuehren", bestaetigung?: "RESTORE-AUSFUEHREN" }
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function istSuperAdmin(admin: any, authHeader: string | null): Promise<boolean> {
  const token = (authHeader ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return false;
  const { data: u, error } = await admin.auth.getUser(token);
  if (error || !u?.user) return false;
  const { data: m } = await admin.from("mitgliedschaften")
    .select("user_id").eq("user_id", u.user.id).eq("rolle", "super_admin").limit(1);
  return !!(m && m.length);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Auth: ausschließlich super_admin
    const ok = await istSuperAdmin(admin, req.headers.get("authorization"));
    if (!ok) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const pfad = String(body?.pfad ?? "").trim();
    const modus = String(body?.modus ?? "bericht");
    if (!pfad || !pfad.startsWith("snapshot-")) return json({ error: "pfad_ungueltig" }, 400);
    if (modus !== "bericht" && modus !== "ausfuehren") return json({ error: "modus_ungueltig" }, 400);

    // Snapshot aus dem privaten Bucket laden + parsen
    const dl = await admin.storage.from("backups").download(pfad);
    if (dl.error || !dl.data) return json({ error: "snapshot_nicht_gefunden" }, 404);
    let snapshot: any;
    try { snapshot = JSON.parse(await dl.data.text()); }
    catch { return json({ error: "snapshot_unlesbar" }, 422); }

    if (modus === "bericht") {
      const { data, error } = await admin.rpc("backup_restore_bericht", { p_snapshot: snapshot });
      if (error) return json({ error: error.message }, 500);
      return json({ ok: true, modus, ...data });
    }

    // modus === 'ausfuehren'
    const bestaetigung = String(body?.bestaetigung ?? "");
    if (bestaetigung !== "RESTORE-AUSFUEHREN") return json({ error: "bestaetigung_fehlt" }, 400);
    const { data, error } = await admin.rpc("backup_restore_ausfuehren",
      { p_snapshot: snapshot, p_bestaetigung: "RESTORE-AUSFUEHREN" });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true, modus, ...data });
  } catch (e) {
    console.error("backup-restore:", String(e));
    return json({ error: String(e) }, 500);
  }
});
