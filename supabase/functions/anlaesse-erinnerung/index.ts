// Edge Function: anlaesse-erinnerung  (selbst-enthaltend – für Dashboard-Editor)
// Täglich per pg_cron + pg_net aufgerufen. Ablauf:
//   1) anlaesse_taeglich_erzeugen()  -> erzeugt/ergänzt die heutigen In-App-Anlässe
//      (idempotent; Geburtstage/Gedenktage gemäß vorlauf_tage der Einstellungen).
//   2) anlaesse_email_offen()        -> noch nicht gemailte Anlass-Benachrichtigungen
//      inkl. Empfänger-E-Mail/Name/Sprache (letzte 2 Tage).
//   3) je Empfänger EINE Digest-Mail (alle seine Anlässe gebündelt) per Resend.
//   4) anlaesse_email_erledigt(ids)  -> erfolgreiche als gesendet markieren.
//
// Body: {} (keine Eingabe nötig). Aufruf NUR mit korrektem Header `x-cron-secret`
//   (== Secret CRON_SECRET). Bewusst KEIN Service-Role-JWT-Vergleich mehr -> unabhängig
//   von der Supabase-API-Key-Umstellung. Empfehlung: für diese Function die JWT-Prüfung
//   abschalten (Dashboard -> Function -> "Verify JWT" AUS), dann zählt nur x-cron-secret.
//
// Secrets (wie die anderen Functions): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
//   RESEND_API_KEY, CRON_SECRET (selbst vergeben), optional MAIL_FROM, APP_URL, TEST_EMAIL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "FamilyRoots <support@familyroots.club>";

// HTML -> lesbarer Klartext für den text/plain-Teil (Links als "Text: URL").
// multipart/alternative statt HTML-only -> besseres Zustell-/Spamverhalten.
function htmlZuText(html: string): string {
  return html
    .replace(/<a\b[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gis, "$2: $1")
    .replace(/<\/(p|div|h[1-6]|tr|li)>/gi, "\n")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&nbsp;/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]+/g, " ")
    .split("\n").map((z) => z.trim()).join("\n")
    .trim();
}
const APP_URL        = Deno.env.get("APP_URL") ?? "https://familyroots.club/stammbaum.html";
const CRON_SECRET    = Deno.env.get("CRON_SECRET") ?? "";
const UNSUB_SECRET   = Deno.env.get("UNSUBSCRIBE_SECRET") ?? "";   // für den Abmelde-Token

const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "Anstehende Anlässe – FamilyRoots",
    intro: "Diese Anlässe stehen bald an:",
    geburtstag: "Geburtstag", gedenktag: "Gedenktag",
    btn_app: "App öffnen", hint: "Öffne die App, um die Personen zu sehen.",
  },
  sr: {
    subject: "Предстојећи догађаји – FamilyRoots",
    intro: "Ускоро следе ови догађаји:",
    geburtstag: "Рођендан", gedenktag: "Помен",
    btn_app: "Отвори апликацију", hint: "Отвори апликацију да видиш особе.",
  },
  hr: {
    subject: "Nadolazeći događaji – FamilyRoots",
    intro: "Uskoro slijede ovi događaji:",
    geburtstag: "Rođendan", gedenktag: "Godišnjica smrti",
    btn_app: "Otvori aplikaciju", hint: "Otvori aplikaciju da vidiš osobe.",
  },
  ba: {
    subject: "Nadolazeći događaji – FamilyRoots",
    intro: "Uskoro slijede ovi događaji:",
    geburtstag: "Rođendan", gedenktag: "Godišnjica smrti",
    btn_app: "Otvori aplikaciju", hint: "Otvori aplikaciju da vidiš osobe.",
  },
  en: {
    subject: "Upcoming occasions – FamilyRoots",
    intro: "These occasions are coming up soon:",
    geburtstag: "Birthday", gedenktag: "Memorial day",
    btn_app: "Open app", hint: "Open the app to see the people.",
  },
};
const T = (sprache: string, key: string) =>
  (TEXTE[sprache] ?? TEXTE.de)[key] ?? TEXTE.de[key] ?? key;

const esc = (v: unknown) => String(v ?? "")
  .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

// ---- Abmelde-/Unsubscribe-Helfer (geteilt, siehe _shared_unsub.ts) --------
const _unsubEnc = new TextEncoder();
const _b64urlFromBytes = (b: Uint8Array) =>
  btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const _b64urlFromString = (s: string) => _b64urlFromBytes(_unsubEnc.encode(s));
async function makeUnsubToken(userId: string, typ: string, ttlDays = 60): Promise<string> {
  const exp = Math.floor(Date.now() / 1000) + ttlDays * 86400;
  const payloadB64 = _b64urlFromString(JSON.stringify({ u: userId, t: typ, e: exp }));
  const key = await crypto.subtle.importKey(
    "raw", _unsubEnc.encode(UNSUB_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, _unsubEnc.encode(payloadB64)));
  return payloadB64 + "." + _b64urlFromBytes(sig);
}
const buildUnsubUrl = (token: string, lang = "de") =>
  `${SUPABASE_URL}/functions/v1/abmelden?token=${encodeURIComponent(token)}&lang=${encodeURIComponent(lang)}`;
const _UNSUB_FOOTER: Record<string, { one: string; all: string }> = {
  de: { one: "Diese Benachrichtigungen abbestellen", all: "von allen E-Mails abmelden" },
  sr: { one: "Одјави се са ових обавештења",           all: "одјави се са свих е-порука" },
  hr: { one: "Odjavi se s ovih obavijesti",            all: "odjavi se sa svih e-poruka" },
  ba: { one: "Odjavi se s ovih obavještenja",          all: "odjavi se sa svih e-poruka" },
  en: { one: "Unsubscribe from these notifications",   all: "unsubscribe from all emails" },
};
async function unsubBundle(userId: string, typ: string, lang = "de") {
  const urlSpecific = buildUnsubUrl(await makeUnsubToken(userId, typ), lang);
  const urlAlle     = buildUnsubUrl(await makeUnsubToken(userId, "alle"), lang);
  const x = _UNSUB_FOOTER[lang] ?? _UNSUB_FOOTER.de;
  const footer = `<div style="margin-top:22px;padding-top:14px;border-top:1px solid #e4d8bf;
      font-size:12px;color:#a89878;text-align:center;line-height:1.7;">
    <a href="${urlSpecific}" style="color:#722f37;text-decoration:underline;">${esc(x.one)}</a>
    &nbsp;·&nbsp;
    <a href="${urlAlle}" style="color:#a89878;text-decoration:underline;">${esc(x.all)}</a>
  </div>`;
  return {
    footer,
    headers: {
      "List-Unsubscribe": `<${urlSpecific}>, <mailto:support@familyroots.club?subject=Abmelden>`,
      "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
    } as Record<string, string>,
  };
}

const WRAP = (inner: string) => `
<div style="font-family:Georgia,'Times New Roman',serif;max-width:560px;margin:0 auto;
  background:#f6f1e7;color:#2c2418;padding:28px 26px;border:1px solid #d8c9a8;border-radius:14px;">
  <h2 style="color:#7a2a2a;margin:0 0 16px;">FamilyRoots</h2>
  ${inner}
  <p style="margin-top:26px;font-size:12px;color:#8a7a5a;">familyroots.club</p>
</div>`;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });

type Offen = {
  id: string; user_id: string; email: string;
  name: string | null; sprache: string | null;
  typ: string; person_name: string | null;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // Nur der Cron-/Service-Kontext darf auslösen: eigener Geheimschlüssel im Header
  // (unabhängig von der Supabase-Key-Migration). CRON_SECRET muss als Secret gesetzt sein.
  const secret = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!CRON_SECRET || secret !== CRON_SECRET) return json({ error: "unauthorized" }, 401);

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // 1) In-App-Anlässe für heute sicherstellen (idempotent)
    const { error: errGen } = await admin.rpc("anlaesse_taeglich_erzeugen");
    if (errGen) console.error("anlaesse_taeglich_erzeugen:", errGen.message);

    // 2) Offene (noch nicht gemailte) Anlässe holen
    const { data: offen, error: errOffen } = await admin.rpc("anlaesse_email_offen");
    if (errOffen) return json({ error: errOffen.message }, 500);
    const liste = (offen ?? []) as Offen[];
    if (liste.length === 0) return json({ ok: true, gesendet: 0, info: "keine offenen Anlässe" });

    // Je Empfänger bündeln
    const proEmpf = new Map<string, { email: string; name: string | null; sprache: string;
                                      items: Offen[]; ids: string[] }>();
    for (const r of liste) {
      if (!r.email) continue;
      const g = proEmpf.get(r.user_id) ??
        { email: r.email, name: r.name, sprache: r.sprache ?? "de", items: [], ids: [] };
      g.items.push(r); g.ids.push(r.id);
      proEmpf.set(r.user_id, g);
    }

    const appUrl = APP_URL + (APP_URL.includes("?") ? "&" : "?") + "obav=1";
    const testEmail = Deno.env.get("TEST_EMAIL");
    let gesendet = 0;
    const erledigt: string[] = [];
    const fehler: string[] = [];

    for (const [uid, g] of proEmpf.entries()) {
      const sprache = g.sprache;
      const to = testEmail ? [testEmail] : [g.email];
      const zeilen = g.items.map((it) => {
        const ic = it.typ === "anlass_gedenktag" ? "🕯️" : "🎂";
        const lbl = T(sprache, it.typ === "anlass_gedenktag" ? "gedenktag" : "geburtstag");
        return `<li style="margin:6px 0;">${ic} <strong>${esc(lbl)}:</strong> ${esc(it.person_name ?? "")}</li>`;
      }).join("");

      const inner = `
        <p>${esc(g.name ? g.name + "," : "")}</p>
        <p>${esc(T(sprache, "intro"))}</p>
        <ul style="list-style:none;padding:0;margin:12px 0 18px;font-size:15px;">${zeilen}</ul>
        <div style="text-align:center;margin:24px 0;">
          <a href="${appUrl}" style="display:inline-block;background:#7a2a2a;color:#fff;
            text-decoration:none;padding:12px 26px;border-radius:8px;">${esc(T(sprache, "btn_app"))}</a>
        </div>
        <p style="font-size:13px;color:#8a7a5a;">${esc(T(sprache, "hint"))}</p>`;

      // Abmelde-Footer + List-Unsubscribe-Header (typ 'anlaesse' = Geburtstage + Gedenktage).
      const unsub = await unsubBundle(uid, "anlaesse", sprache);
      const htmlBody = WRAP(inner + unsub.footer);

      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: MAIL_FROM, to,
          subject: T(sprache, "subject"), html: htmlBody,
          text: htmlZuText(htmlBody),
          headers: unsub.headers,
        }),
      });
      if (r.ok) { gesendet++; erledigt.push(...g.ids); }
      else fehler.push(await r.text());
    }

    // 4) Erfolgreich versendete als gesendet markieren
    if (erledigt.length) {
      const { error: errMark } = await admin.rpc("anlaesse_email_erledigt", { p_ids: erledigt });
      if (errMark) console.error("anlaesse_email_erledigt:", errMark.message);
    }

    return json({ ok: true, empfaenger: proEmpf.size, gesendet,
                  markiert: erledigt.length, fehler: fehler.length ? fehler : undefined });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
