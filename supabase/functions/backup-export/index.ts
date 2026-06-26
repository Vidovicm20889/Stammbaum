// Edge Function: backup-export  (selbst-enthaltend – für Dashboard-Editor)
// Erstellt EINEN logischen JSON-Snapshot aller relevanten Tabellen (kein pg_dump) + ein
// Medien-Manifest und legt ihn im PRIVATEN Bucket 'backups' ab. Hält die Aufbewahrung (14).
//
// AUSLÖSER (zwei Wege):
//   1) pg_cron (täglich): Header x-cron-secret == Secret CRON_SECRET.
//   2) Manuell aus der App: eingeloggter super_admin (JWT im Authorization-Header) -> die
//      Function prüft die Rolle, erstellt den Snapshot und gibt den Pfad zurück (Frontend lädt
//      ihn dann per signierter URL offsite herunter = eigentlicher Katastrophenschutz).
//
// SICHERHEIT: Service-Role-Key NUR hier (Secret), nie im Frontend. Keine personenbezogenen
//   Daten in Logs (es werden nur Zähler geloggt).
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CRON_SECRET (selbst vergeben),
//   optional BACKUP_BEHALTEN (Default 14).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET  = Deno.env.get("CRON_SECRET") ?? "";
const BEHALTEN     = parseInt(Deno.env.get("BACKUP_BEHALTEN") ?? "14", 10) || 14;

// Alle zu sichernden Tabellen (Reihenfolge irrelevant für den Export). History-Tabellen
// werden mit-exportiert (Verlauf), aber beim Restore bewusst nicht eingespielt.
const TABELLEN = [
  "familien","stammbaeume","personen","beziehungen","mitgliedschaften","profile",
  "registrierungs_anfragen","verknuepfungs_anfragen","kontakt_anfragen","kontakt_verbindungen","baum_freigaben",
  "events","event_teilnehmer","event_kosten","event_eingeladene","event_album_fotos",
  "personen_fotos","personen_dokumente","personen_geschichten","person_aufnahmen",
  "beitraege","reaktionen","kommentare","gedenk_eintraege","familien_fragen","foto_personen",
  "aktivitaeten","beitrags_statistik",
  "chats","chat_teilnehmer","chat_nachrichten",
  "benachrichtigungen","benachrichtigungs_einstellungen","digest_versand","erinnerungs_mails",
  "familien_audit","merge_log","anfrage_log",
];
const BUCKETS = ["avatars","familien","events","event-album","personen-fotos",
                 "personen-dokumente","person-aufnahmen","gedenkseiten","beitraege"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
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

// Alle Zeilen einer Tabelle holen (paginiert, da PostgREST ~1000/Seite liefert).
async function tabelleLesen(admin: any, tabelle: string): Promise<any[]> {
  const out: any[] = [];
  const seite = 1000;
  let von = 0;
  for (;;) {
    const { data, error } = await admin.from(tabelle).select("*").range(von, von + seite - 1);
    if (error) throw new Error(`${tabelle}: ${error.message}`);
    const rows = data ?? [];
    out.push(...rows);
    if (rows.length < seite) break;
    von += seite;
  }
  return out;
}

// Rekursiv alle Objekte eines Buckets auflisten (Pfad + Größe).
async function bucketManifest(admin: any, bucket: string): Promise<any[]> {
  const out: any[] = [];
  async function walk(prefix: string) {
    let offset = 0;
    const limit = 100;
    for (;;) {
      const { data, error } = await admin.storage.from(bucket)
        .list(prefix, { limit, offset, sortBy: { column: "name", order: "asc" } });
      if (error) throw new Error(`storage ${bucket}/${prefix}: ${error.message}`);
      const eintraege = data ?? [];
      for (const e of eintraege) {
        const pfad = prefix ? `${prefix}/${e.name}` : e.name;
        if (e.id === null && !e.metadata) {
          await walk(pfad);                       // Ordner -> rekursiv
        } else {
          out.push({ bucket, pfad, groesse: e.metadata?.size ?? null,
                     mime: e.metadata?.mimetype ?? null, aktualisiert: e.updated_at ?? null });
        }
      }
      if (eintraege.length < limit) break;
      offset += limit;
    }
  }
  await walk("");
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Auth: Cron-Secret ODER eingeloggter super_admin
    const secret = (req.headers.get("x-cron-secret") ?? "").trim();
    const cronOk = !!CRON_SECRET && secret === CRON_SECRET;
    if (!cronOk) {
      const ok = await istSuperAdmin(admin, req.headers.get("authorization"));
      if (!ok) return json({ error: "unauthorized" }, 401);
    }

    // 1) Tabellen serialisieren
    const tabellen: Record<string, any[]> = {};
    let zeilenGesamt = 0;
    for (const t of TABELLEN) {
      const rows = await tabelleLesen(admin, t);
      tabellen[t] = rows;
      zeilenGesamt += rows.length;
    }

    // 2) Medien-Manifest (nur Pfade/Größen, KEINE Binärdaten)
    const medien: any[] = [];
    let medienBytes = 0;
    for (const b of BUCKETS) {
      try {
        const m = await bucketManifest(admin, b);
        medien.push(...m);
        for (const x of m) medienBytes += (x.groesse ?? 0);
      } catch (e) { console.error("Manifest-Fehler:", String(e)); }
    }

    const stamp = new Date().toISOString().replace(/[:.]/g, "-");   // dateinamen-sicher, sortierbar
    const snapshot = {
      meta: {
        format: 1,
        erstellt_am: new Date().toISOString(),
        quelle: SUPABASE_URL,
        ausloeser: cronOk ? "cron" : "manuell",
        tabellen_anzahl: TABELLEN.length,
        zeilen_gesamt: zeilenGesamt,
        medien_anzahl: medien.length,
        medien_bytes: medienBytes,
        hinweis: "Logischer Zeilen-Export (kein pg_dump). auth.users NICHT enthalten. Medien = Manifest.",
      },
      tabellen,
      medien_manifest: medien,
    };

    const body = JSON.stringify(snapshot);
    const pfad = `snapshot-${stamp}.json`;
    const up = await admin.storage.from("backups")
      .upload(pfad, new Blob([body], { type: "application/json" }),
              { contentType: "application/json", upsert: false });
    if (up.error) return json({ error: up.error.message }, 500);

    // 3) Aufbewahrung: neueste BEHALTEN behalten, ältere löschen (Dateiname sortiert = chronologisch)
    let geloescht = 0;
    try {
      const { data: liste } = await admin.storage.from("backups")
        .list("", { limit: 1000, sortBy: { column: "name", order: "desc" } });
      const snaps = (liste ?? []).filter((o: any) => o.name.startsWith("snapshot-"));
      const alt = snaps.slice(BEHALTEN).map((o: any) => o.name);
      if (alt.length) { await admin.storage.from("backups").remove(alt); geloescht = alt.length; }
    } catch (e) { console.error("Rotation-Fehler:", String(e)); }

    return json({ ok: true, pfad, groesse_bytes: body.length,
                  zeilen: zeilenGesamt, tabellen: TABELLEN.length,
                  medien: medien.length, rotiert_geloescht: geloescht });
  } catch (e) {
    console.error("backup-export:", String(e));
    return json({ error: String(e) }, 500);
  }
});
