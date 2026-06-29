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
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "FamilyRoots <support@vidovic-ai.com>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://vidovicm20889.github.io/Stammbaum/stammbaum.html";
const CRON_SECRET    = Deno.env.get("CRON_SECRET") ?? "";

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

const WRAP = (inner: string) => `
<div style="font-family:Georgia,'Times New Roman',serif;max-width:560px;margin:0 auto;
  background:#f6f1e7;color:#2c2418;padding:28px 26px;border:1px solid #d8c9a8;border-radius:14px;">
  <h2 style="color:#7a2a2a;margin:0 0 16px;">FamilyRoots</h2>
  ${inner}
  <p style="margin-top:26px;font-size:12px;color:#8a7a5a;">vidovicm20889.github.io/Stammbaum</p>
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

    for (const g of proEmpf.values()) {
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

      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: MAIL_FROM, to,
          subject: T(sprache, "subject"), html: WRAP(inner),
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
