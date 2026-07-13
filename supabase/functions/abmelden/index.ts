// Edge Function: abmelden  (selbst-enthaltend – für Dashboard-Editor)
// ---------------------------------------------------------------------------
// ÖFFENTLICHE Ein-Klick-Abmeldung aus Erinnerungs-/Status-Mails — OHNE Login.
// Deploy OHNE JWT-Pflicht:  supabase functions deploy abmelden --no-verify-jwt
// (bzw. im Dashboard "Verify JWT" für diese Function AUSschalten).
//
//   GET  /abmelden?token=…&lang=de|sr|hr|ba|en
//        -> Token prüfen, Spalte(n) auf false setzen, würdevolle HTML-Bestätigungsseite.
//   POST /abmelden?token=…   (RFC 8058 List-Unsubscribe One-Click)
//        -> nur 200, kein HTML.
//
// Sicherheit: Token = base64url(payload).base64url(HMAC-SHA256(UNSUBSCRIBE_SECRET, payload)),
// payload = { u:user_id, t:typ, e:exp_unix }. Signatur wird zeitkonstant via crypto.subtle.verify
// geprüft (kein manueller Byte-Vergleich). Der Typ wird NICHT direkt ins SQL gegeben — die RPC
// abmelden_anwenden hat eine eigene Whitelist und mappt auf statische Spalten.
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, UNSUBSCRIBE_SECRET, optional APP_URL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const UNSUB_SECRET = Deno.env.get("UNSUBSCRIBE_SECRET") ?? "";
const APP_URL      = Deno.env.get("APP_URL") ?? "https://familyroots.club/stammbaum.html";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// ---- base64url + HMAC (Web Crypto) ----------------------------------------
const encTE = new TextEncoder();
const decTD = new TextDecoder();
const b64urlFromBytes = (b: Uint8Array) =>
  btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlToBytes = (s: string) => {
  let t = s.replace(/-/g, "+").replace(/_/g, "/");
  while (t.length % 4) t += "=";
  const bin = atob(t);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
};
const b64urlToString = (s: string) => decTD.decode(b64urlToBytes(s));

async function hmacKey(usages: KeyUsage[]) {
  return await crypto.subtle.importKey(
    "raw", encTE.encode(UNSUB_SECRET), { name: "HMAC", hash: "SHA-256" }, false, usages);
}

// Prüft Token zeitkonstant. Gibt { valid, userId, typ, reason }.
async function verifyUnsubToken(token: string): Promise<
  { valid: true; userId: string; typ: string } | { valid: false; reason: string }> {
  try {
    if (!UNSUB_SECRET) return { valid: false, reason: "kein_secret" };
    const parts = String(token ?? "").split(".");
    if (parts.length !== 2 || !parts[0] || !parts[1]) return { valid: false, reason: "format" };
    const [payloadB64, sigB64] = parts;
    const key = await hmacKey(["verify"]);
    const ok = await crypto.subtle.verify("HMAC", key, b64urlToBytes(sigB64), encTE.encode(payloadB64));
    if (!ok) return { valid: false, reason: "signatur" };          // zeitkonstant (crypto.subtle.verify)
    const p = JSON.parse(b64urlToString(payloadB64));
    if (!p || !p.u || !p.t || !p.e) return { valid: false, reason: "payload" };
    if (Math.floor(Date.now() / 1000) > Number(p.e)) return { valid: false, reason: "abgelaufen" };
    return { valid: true, userId: String(p.u), typ: String(p.t) };
  } catch (_e) {
    return { valid: false, reason: "fehler" };
  }
}

// ---- lokalisierte Seiten-Texte --------------------------------------------
const L: Record<string, Record<string, string>> = {
  de: {
    titel: "Abgemeldet – FamilyRoots",
    ok_h: "Du bist abgemeldet",
    ok_b: "Du erhältst diese Benachrichtigungen per E-Mail nicht mehr.",
    reaktiv: "Du kannst das jederzeit im Profil unter „Erinnerungen“ wieder aktivieren.",
    btn: "Zur App",
    err_h: "Link nicht gültig",
    err_abgelaufen: "Dieser Abmelde-Link ist abgelaufen. Öffne die App und passe deine Einstellungen im Profil an.",
    err_ungueltig: "Dieser Abmelde-Link ist ungültig. Öffne die App und passe deine Einstellungen im Profil an.",
  },
  sr: {
    titel: "Одјављено – FamilyRoots",
    ok_h: "Одјављени сте",
    ok_b: "Више нећете добијати ова обавештења путем е-поште.",
    reaktiv: "Ово можете поново укључити у профилу под „Подсетници“ у сваком тренутку.",
    btn: "Отвори апликацију",
    err_h: "Линк није важећи",
    err_abgelaufen: "Овај линк за одјаву је истекао. Отворите апликацију и подесите обавештења у профилу.",
    err_ungueltig: "Овај линк за одјаву није важећи. Отворите апликацију и подесите обавештења у профилу.",
  },
  hr: {
    titel: "Odjavljeno – FamilyRoots",
    ok_h: "Odjavljeni ste",
    ok_b: "Više nećete primati ove obavijesti e-poštom.",
    reaktiv: "Ovo možete ponovno uključiti u profilu pod „Podsjetnici“ u svakom trenutku.",
    btn: "Otvori aplikaciju",
    err_h: "Poveznica nije važeća",
    err_abgelaufen: "Ova poveznica za odjavu je istekla. Otvorite aplikaciju i podesite obavijesti u profilu.",
    err_ungueltig: "Ova poveznica za odjavu nije važeća. Otvorite aplikaciju i podesite obavijesti u profilu.",
  },
  ba: {
    titel: "Odjavljeno – FamilyRoots",
    ok_h: "Odjavljeni ste",
    ok_b: "Više nećete primati ova obavještenja e-poštom.",
    reaktiv: "Ovo možete ponovo uključiti u profilu pod „Podsjetnici“ u svakom trenutku.",
    btn: "Otvori aplikaciju",
    err_h: "Poveznica nije važeća",
    err_abgelaufen: "Ova poveznica za odjavu je istekla. Otvorite aplikaciju i podesite obavještenja u profilu.",
    err_ungueltig: "Ova poveznica za odjavu nije važeća. Otvorite aplikaciju i podesite obavještenja u profilu.",
  },
  en: {
    titel: "Unsubscribed – FamilyRoots",
    ok_h: "You're unsubscribed",
    ok_b: "You will no longer receive these notifications by email.",
    reaktiv: "You can re-enable this anytime in your profile under “Reminders”.",
    btn: "Open the app",
    err_h: "Link not valid",
    err_abgelaufen: "This unsubscribe link has expired. Open the app and adjust your notifications in your profile.",
    err_ungueltig: "This unsubscribe link is invalid. Open the app and adjust your notifications in your profile.",
  },
};
const pick = (lang: string) => L[lang] ?? L.de;
const esc = (v: unknown) => String(v ?? "")
  .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

function seite(lang: string, ok: boolean, reason?: string): string {
  const x = pick(lang);
  const inner = ok
    ? `<h1 style="color:#722f37;margin:0 0 12px;font-size:26px;">${esc(x.ok_h)}</h1>
       <p style="margin:0 0 10px;font-size:16px;">${esc(x.ok_b)}</p>
       <p style="margin:0 0 24px;font-size:13px;color:#8a7a5a;">${esc(x.reaktiv)}</p>`
    : `<h1 style="color:#722f37;margin:0 0 12px;font-size:26px;">${esc(x.err_h)}</h1>
       <p style="margin:0 0 24px;font-size:15px;">${esc(reason === "abgelaufen" ? x.err_abgelaufen : x.err_ungueltig)}</p>`;
  return `<!doctype html><html lang="${esc(lang)}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>${esc(x.titel)}</title></head>
<body style="margin:0;background:#efe7d6;font-family:Georgia,'Times New Roman',serif;color:#2c2418;">
  <div style="max-width:520px;margin:8vh auto;padding:34px 28px;background:#f6f1e7;border:1px solid #d8c9a8;
       border-radius:16px;text-align:center;">
    <div style="font-size:13px;letter-spacing:.12em;text-transform:uppercase;color:#9c7c3c;margin-bottom:18px;">FamilyRoots</div>
    ${inner}
    <a href="${esc(APP_URL)}" style="display:inline-block;background:#722f37;color:#fff;text-decoration:none;
       padding:12px 28px;border-radius:8px;font-size:15px;">${esc(x.btn)}</a>
  </div>
</body></html>`;
}

const htmlResp = (body: string, status = 200) =>
  new Response(body, { status, headers: { ...cors, "Content-Type": "text/html; charset=utf-8" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = new URL(req.url);
  const token = url.searchParams.get("token") ?? "";
  const lang = (url.searchParams.get("lang") ?? "de").toLowerCase();

  const v = await verifyUnsubToken(token);

  // --- RFC 8058 One-Click: POST -> nur 200/kein HTML. Ungültig -> trotzdem 200 (kein Info-Leak). ---
  if (req.method === "POST") {
    if (v.valid) {
      try {
        const admin = createClient(SUPABASE_URL, SERVICE_KEY);
        await admin.rpc("abmelden_anwenden", { p_user: v.userId, p_typ: v.typ, p_quelle: "oneclick" });
      } catch (_e) { /* idempotent; Fehler ignorieren, Provider erwartet 200 */ }
    }
    return new Response("ok", { status: 200, headers: cors });
  }

  // --- GET: Token prüfen, anwenden, HTML-Seite. ---
  if (req.method === "GET") {
    if (!v.valid) {
      return htmlResp(seite(lang, false, v.reason === "abgelaufen" ? "abgelaufen" : "ungueltig"), 200);
    }
    try {
      const admin = createClient(SUPABASE_URL, SERVICE_KEY);
      const { error } = await admin.rpc("abmelden_anwenden",
        { p_user: v.userId, p_typ: v.typ, p_quelle: "email" });
      if (error) return htmlResp(seite(lang, false, "ungueltig"), 200);
      return htmlResp(seite(lang, true), 200);
    } catch (_e) {
      return htmlResp(seite(lang, false, "ungueltig"), 200);
    }
  }

  return new Response("Method not allowed", { status: 405, headers: cors });
});
