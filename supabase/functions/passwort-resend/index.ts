// Edge Function: passwort-resend  (selbst-enthaltend – für Dashboard-Editor)
// ---------------------------------------------------------------------------
// ZWECK: Nach dem TEST_EMAIL-Vorfall (alle Willkommens-Mails gingen an die Test-
// adresse) allen NEUEN, noch nicht eingeloggten Konten erneut den „Passwort
// setzen"-Link schicken — über Resend (derselbe Kanal wie neue-familie-anlegen),
// OHNE TEST_EMAIL-Umleitung und mit SICHTBAREN Fehlern (kein stilles Verschlucken).
//
// SICHERHEIT (Massen-Mail!): geschützt durch ein EIGENES Secret. Im Dashboard das Secret
// RESEND_ADMIN_SECRET setzen (frei wählbarer Wert) und beim Aufruf als Header
// "x-admin-secret: <wert>" mitgeben. „Verify JWT" für diese Function AUSschalten (der Guard
// prüft selbst). Alternativ akzeptiert der Guard weiterhin den service_role-JWT als Bearer.
//
// AUFRUF (Body JSON, alles optional):
//   { "dry_run": true }                 -> nur AUFLISTEN, wer eine Mail bekäme (nichts senden)
//   { }                                 -> Registrierungen der letzten 7 Tage (nur nicht eingeloggte)
//   { "tage": 7 }                       -> Zeitfenster in Tagen (Standard 7)
//   { "nur_ohne_login": false }         -> auch bereits eingeloggte Konten einbeziehen (Standard true)
//   { "emails": ["a@x.de","b@y.de"] }   -> gezielt an diese Adressen (ignoriert Zeitfenster/Login)
//   { "limit": 40, "offset": 0 }        -> Stapelgröße/Startpunkt (gegen Timeouts; Standard 40)
//
// Standard-Zielgruppe (ohne "emails"): Konten, die in den letzten `tage` Tagen
// registriert wurden (created_at) UND noch nie eingeloggt sind (last_sign_in_at == null)
// -> wegen TEST_EMAIL ohne Passwort steckengeblieben. Bereits aktive Nutzer werden
// standardmäßig NICHT angeschrieben (nur_ohne_login=true).
//
// Empfohlenes Vorgehen: ERST dry_run:true (Liste + Gesamtzahl prüfen), dann in
// Stapeln (limit/offset) tatsächlich senden.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "FamilyRoots <support@familyroots.club>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://familyroots.club/stammbaum.html";
// Eigenes Zugriff-Secret (unabhängig vom service_role-JWT/JWT-Key-System): im Dashboard als
// Secret RESEND_ADMIN_SECRET setzen und beim Aufruf als Header "x-admin-secret" mitgeben.
const ADMIN_SECRET   = Deno.env.get("RESEND_ADMIN_SECRET") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "Dein Zugang zu FamilyRoots – Passwort setzen",
    body: "Dein Konto bei FamilyRoots ist angelegt. Aus technischen Gründen konnte die erste E-Mail nicht zugestellt werden — bitte setze jetzt über den folgenden Link dein Passwort und melde dich an:",
    btn: "Passwort setzen",
  },
  sr: {
    subject: "Твој приступ FamilyRoots – постави лозинку",
    body: "Твој налог на FamilyRoots је направљен. Из техничких разлога прва порука није могла бити испоручена — постави сада лозинку преко следећег линка и пријави се:",
    btn: "Постави лозинку",
  },
  hr: {
    subject: "Tvoj pristup FamilyRoots – postavi lozinku",
    body: "Tvoj račun na FamilyRoots je izrađen. Iz tehničkih razloga prva poruka nije mogla biti dostavljena — postavi sada lozinku putem sljedeće poveznice i prijavi se:",
    btn: "Postavi lozinku",
  },
  ba: {
    subject: "Tvoj pristup FamilyRoots – postavi lozinku",
    body: "Tvoj račun na FamilyRoots je kreiran. Iz tehničkih razloga prva poruka nije mogla biti dostavljena — postavi sada lozinku putem sljedeće poveznice i prijavi se:",
    btn: "Postavi lozinku",
  },
  en: {
    subject: "Your FamilyRoots access – set your password",
    body: "Your FamilyRoots account has been created. For technical reasons the first email could not be delivered — please set your password now via the link below and sign in:",
    btn: "Set password",
  },
};
const T = (sprache: string, key: string) =>
  (TEXTE[sprache] ?? TEXTE.de)[key] ?? TEXTE.de[key] ?? key;

const esc = (v: unknown) => String(v ?? "")
  .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

const WRAP = (inner: string) => `
<div style="font-family:Georgia,'Times New Roman',serif;max-width:560px;margin:0 auto;
  background:#f6f1e7;color:#2c2418;padding:28px 26px;border:1px solid #d8c9a8;border-radius:14px;">
  <h2 style="color:#7a2a2a;margin:0 0 16px;">FamilyRoots</h2>
  ${inner}
  <p style="margin-top:26px;font-size:12px;color:#8a7a5a;">familyroots.club</p>
</div>`;

const jsonResp = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), {
    status, headers: { ...CORS, "Content-Type": "application/json" },
  });

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Sendet über Resend und GIBT den Status ZURÜCK (bewusst KEIN TEST_EMAIL-Override,
// damit der Nachversand nicht erneut umgeleitet werden kann).
async function sendMail(to: string, subject: string, html: string) {
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: MAIL_FROM, to, subject, html }),
  });
  const body = await r.text();
  return { ok: r.ok, status: r.status, body };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return jsonResp({ error: "Method not allowed" }, 405);

  // Guard: eigenes Secret (Header "x-admin-secret") ODER service_role-Bearer (Massen-Mail schützen).
  const bearer = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "").trim();
  const secret = (req.headers.get("x-admin-secret") || "").trim();
  const okSecret = !!ADMIN_SECRET && secret === ADMIN_SECRET;
  const okBearer = !!SERVICE_KEY && bearer === SERVICE_KEY;
  if (!okSecret && !okBearer) {
    return jsonResp({ error: "nicht_berechtigt" }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  try {
    const payload = await req.json().catch(() => ({}));
    const dryRun  = payload?.dry_run === true;
    const limit   = Math.max(1, Math.min(Number(payload?.limit ?? 40), 200));
    const offset  = Math.max(0, Number(payload?.offset ?? 0));
    const tage    = Math.max(1, Math.min(Number(payload?.tage ?? 7), 365));
    const nurOhneLogin = payload?.nur_ohne_login !== false;   // Standard: nur nie eingeloggte
    const emails  = Array.isArray(payload?.emails)
      ? payload.emails.map((e: unknown) => String(e).trim().toLowerCase()).filter(Boolean)
      : null;
    const cutoff = Date.now() - tage * 86400000;

    // 1) Alle Auth-User paginiert einsammeln
    const alle: any[] = [];
    for (let page = 1; page <= 200; page++) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
      if (error) throw error;
      const users = data?.users ?? [];
      alle.push(...users);
      if (users.length < 200) break;
    }

    // 2) Zielgruppe bestimmen
    let kandidaten: any[];
    if (emails && emails.length) {
      const set = new Set(emails);
      kandidaten = alle.filter((u) => u.email && set.has(String(u.email).toLowerCase()));
    } else {
      // Standard: in den letzten `tage` Tagen registriert (created_at) und – sofern
      // nurOhneLogin – noch nie eingeloggt (wegen TEST_EMAIL ohne Passwort steckengeblieben).
      kandidaten = alle.filter((u) => {
        const created = Date.parse(u.created_at || "");
        if (!Number.isFinite(created) || created < cutoff) return false;
        if (nurOhneLogin && u.last_sign_in_at) return false;
        return true;
      });
    }
    kandidaten.sort((a, b) => String(a.created_at || "").localeCompare(String(b.created_at || "")));

    const gesamt = kandidaten.length;
    const stapel = kandidaten.slice(offset, offset + limit);

    // 3) Sprache je Nutzer best-effort aus profile
    const spracheVon: Record<string, string> = {};
    try {
      const ids = stapel.map((u) => u.id);
      if (ids.length) {
        const { data: profs } = await admin.from("profile").select("user_id, sprache").in("user_id", ids);
        (profs ?? []).forEach((p: any) => { if (p.sprache) spracheVon[p.user_id] = p.sprache; });
      }
    } catch (_) { /* Profil optional */ }

    // Dry-Run: nur auflisten, NICHTS senden
    if (dryRun) {
      return jsonResp({
        dry_run: true,
        fenster_tage: emails && emails.length ? null : tage,
        nur_ohne_login: emails && emails.length ? null : nurOhneLogin,
        gesamt_kandidaten: gesamt,
        in_diesem_stapel: stapel.length,
        offset, limit,
        emails: stapel.map((u) => u.email),
        hinweis: gesamt > offset + limit
          ? `Weitere Stapel nötig: als Nächstes offset=${offset + limit} aufrufen.`
          : "Dies ist der letzte Stapel.",
      });
    }

    // 4) Senden
    const sent: string[] = [];
    const failed: { email: string; error: string }[] = [];
    for (const u of stapel) {
      const email = String(u.email || "").trim();
      if (!email) continue;
      try {
        const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
          type: "recovery", email, options: { redirectTo: APP_URL },
        });
        if (linkErr) { failed.push({ email, error: linkErr.message }); await sleep(700); continue; }
        const link = linkData.properties?.action_link ?? APP_URL;
        const spr  = spracheVon[u.id] || "de";
        const inner = `
          <p>${esc(T(spr, "body"))}</p>
          <div style="text-align:center;margin:24px 0;">
            <a href="${link}" style="display:inline-block;background:#7a2a2a;color:#fff;
              text-decoration:none;padding:12px 26px;border-radius:8px;">${esc(T(spr, "btn"))}</a>
          </div>`;
        const res = await sendMail(email, T(spr, "subject"), WRAP(inner));
        if (res.ok) sent.push(email);
        else failed.push({ email, error: `resend ${res.status}: ${res.body}` });
      } catch (e) {
        failed.push({ email, error: (e as Error).message ?? String(e) });
      }
      await sleep(700);   // Resend-Rate-Limit schonen
    }

    return jsonResp({
      ok: true,
      fenster_tage: emails && emails.length ? null : tage,
      gesamt_kandidaten: gesamt,
      verarbeitet: stapel.length,
      gesendet: sent.length,
      fehlgeschlagen: failed.length,
      sent, failed,
      offset, limit,
      hinweis: gesamt > offset + limit
        ? `Noch nicht fertig: als Nächstes offset=${offset + limit} aufrufen.`
        : "Alle Kandidaten verarbeitet.",
    });
  } catch (e) {
    console.error("passwort-resend fehlgeschlagen:", e);
    return jsonResp({ error: (e as Error).message ?? String(e) }, 500);
  }
});
