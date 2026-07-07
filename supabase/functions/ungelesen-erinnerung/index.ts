// Edge Function: ungelesen-erinnerung  (selbst-enthaltend – für Dashboard-Editor)
// Stündlich per pg_cron + pg_net aufgerufen. Ablauf:
//   1) ungelesen_erinnerung_offen()  -> je Nutzer gebündelt: Anzahl + Referenzen der NEUEN
//      (noch nicht gemailten) ungelesenen Anlässe (Chat >12 h / Benachrichtigung >12 h),
//      gefiltert nach Opt-in, Lese-Status zum Aufrufzeitpunkt.
//   2) je Empfänger EINE zusammenfassende Mail (nur Zähler + App-Link, KEINE Inhalte) per Resend.
//   3) ungelesen_erinnerung_erledigt(user, chat_refs, benachr_refs) -> protokollieren
//      (Anti-Doppel-Mail; eine Mail je Anlass und Nutzer).
//
// Body: {} (keine Eingabe). Aufruf NUR mit korrektem Header `x-cron-secret` (== CRON_SECRET).
// Empfehlung: für diese Function "Verify JWT" AUS (Dashboard), dann zählt nur x-cron-secret.
//
// Secrets (wie die anderen Functions): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY,
//   CRON_SECRET (selbst vergeben), optional MAIL_FROM, APP_URL, TEST_EMAIL.

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

// Sprachabhängige Vorlagen (5 Sprachen). {n} wird ersetzt. Neutral, KEINE Inhalte.
const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "Ungelesene Aktivität – FamilyRoots",
    intro: "Sie haben ungelesene Aktivität in Ihrem Stammbaum:",
    nachrichten: "{n} ungelesene Nachricht(en) im Chat",
    benachrichtigungen: "{n} ungelesene Benachrichtigung(en)",
    btn_app: "In der App ansehen",
    hint: "Sobald Sie die App öffnen und lesen, erhalten Sie für diese Aktivität keine weitere E-Mail.",
    optout: "E-Mail-Erinnerungen können Sie jederzeit im Profil unter „Erinnerungen“ abschalten.",
  },
  sr: {
    subject: "Непрочитана активност – FamilyRoots",
    intro: "Имате непрочитану активност у свом стаблу:",
    nachrichten: "{n} непрочитан(их) порука у ћаскању",
    benachrichtigungen: "{n} непрочитан(их) обавештења",
    btn_app: "Погледај у апликацији",
    hint: "Чим отворите апликацију и прочитате, нећете добити нову е-пошту за ову активност.",
    optout: "Е-маил подсетнике можете искључити у профилу под „Подсетници“.",
  },
  hr: {
    subject: "Nepročitana aktivnost – FamilyRoots",
    intro: "Imate nepročitanu aktivnost u svom stablu:",
    nachrichten: "{n} nepročitan(ih) poruka u chatu",
    benachrichtigungen: "{n} nepročitan(ih) obavijesti",
    btn_app: "Pogledaj u aplikaciji",
    hint: "Čim otvorite aplikaciju i pročitate, nećete dobiti novu e-poštu za ovu aktivnost.",
    optout: "E-mail podsjetnike možete isključiti u profilu pod „Podsjetnici“.",
  },
  ba: {
    subject: "Nepročitana aktivnost – FamilyRoots",
    intro: "Imate nepročitanu aktivnost u svom stablu:",
    nachrichten: "{n} nepročitan(ih) poruka u chatu",
    benachrichtigungen: "{n} nepročitan(ih) obavještenja",
    btn_app: "Pogledaj u aplikaciji",
    hint: "Čim otvorite aplikaciju i pročitate, nećete dobiti novu e-poštu za ovu aktivnost.",
    optout: "E-mail podsjetnike možete isključiti u profilu pod „Podsjetnici“.",
  },
  en: {
    subject: "Unread activity – FamilyRoots",
    intro: "You have unread activity in your family tree:",
    nachrichten: "{n} unread chat message(s)",
    benachrichtigungen: "{n} unread notification(s)",
    btn_app: "View in the app",
    hint: "Once you open the app and read it, you won't get another email for this activity.",
    optout: "You can turn off email reminders anytime in your profile under “Reminders”.",
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
  user_id: string; email: string; name: string | null; sprache: string | null;
  anzahl_chat: number; anzahl_benachr: number;
  chat_refs: string[] | null; benachr_refs: string[] | null;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // Nur Cron-/Service-Kontext: eigener Geheimschlüssel im Header.
  const secret = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!CRON_SECRET || secret !== CRON_SECRET) return json({ error: "unauthorized" }, 401);

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    const { data: offen, error: errOffen } = await admin.rpc("ungelesen_erinnerung_offen");
    if (errOffen) return json({ error: errOffen.message }, 500);
    const liste = (offen ?? []) as Offen[];
    if (liste.length === 0) return json({ ok: true, gesendet: 0, info: "nichts Offenes" });

    const appUrl = APP_URL + (APP_URL.includes("?") ? "&" : "?") + "obav=1";
    const testEmail = Deno.env.get("TEST_EMAIL");
    let gesendet = 0;
    const fehler: string[] = [];

    for (const g of liste) {
      if (!g.email) continue;
      const sprache = g.sprache ?? "de";
      const to = testEmail ? [testEmail] : [g.email];

      const zeilen: string[] = [];
      if (g.anzahl_chat > 0)
        zeilen.push(`<li style="margin:6px 0;">💬 ${esc(T(sprache, "nachrichten").replace("{n}", String(g.anzahl_chat)))}</li>`);
      if (g.anzahl_benachr > 0)
        zeilen.push(`<li style="margin:6px 0;">🔔 ${esc(T(sprache, "benachrichtigungen").replace("{n}", String(g.anzahl_benachr)))}</li>`);
      if (zeilen.length === 0) continue;   // Sicherheitsnetz (sollte nicht vorkommen)

      const inner = `
        <p>${esc(g.name ? g.name + "," : "")}</p>
        <p>${esc(T(sprache, "intro"))}</p>
        <ul style="list-style:none;padding:0;margin:12px 0 18px;font-size:15px;">${zeilen.join("")}</ul>
        <div style="text-align:center;margin:24px 0;">
          <a href="${appUrl}" style="display:inline-block;background:#7a2a2a;color:#fff;
            text-decoration:none;padding:12px 26px;border-radius:8px;">${esc(T(sprache, "btn_app"))}</a>
        </div>
        <p style="font-size:13px;color:#8a7a5a;">${esc(T(sprache, "hint"))}</p>
        <p style="font-size:12px;color:#a89878;">${esc(T(sprache, "optout"))}</p>`;

      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from: MAIL_FROM, to, subject: T(sprache, "subject"), html: WRAP(inner), text: htmlZuText(WRAP(inner)),
          headers: { "List-Unsubscribe": "<mailto:support@familyroots.club?subject=Abmelden>" } }),
      });

      if (r.ok) {
        gesendet++;
        // NUR bei erfolgreichem Versand protokollieren -> kein Verlust bei Mail-Fehlern.
        const { error: errMark } = await admin.rpc("ungelesen_erinnerung_erledigt", {
          p_user: g.user_id,
          p_chat_refs: g.chat_refs ?? [],
          p_benachr_refs: g.benachr_refs ?? [],
        });
        if (errMark) console.error("ungelesen_erinnerung_erledigt:", errMark.message);
      } else {
        fehler.push(await r.text());
      }
    }

    return json({ ok: true, empfaenger: liste.length, gesendet, fehler: fehler.length ? fehler : undefined });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
