// Edge Function: event-einladung-senden  (selbst-enthaltend – für Dashboard-Editor)
// Wird vom Frontend NACH dem Speichern der Event-Teilnehmer aufgerufen, mit der Liste
// der NEU eingeladenen Konten (aus der RPC event_einladung_benachrichtige). Verschickt
// je Empfänger eine Einladungs-Mail per Resend. Den Event-Titel/-Datum/-Ort liest die
// Funktion serverseitig aus der DB (authoritativ); die Empfänger kommen vom Frontend.
//
// Body: { event_id: string, empfaenger: [{ email, name?, sprache? }] }
//
// Secrets (wie anfrage-senden): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY,
//   optional MAIL_FROM, APP_URL, TEST_EMAIL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "Vidović AI <onboarding@resend.dev>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://vidovicm20889.github.io/Stammbaum/stammbaum.html";

const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "Einladung zu einem Event – Vidović AI",
    intro: "Du wurdest zu einem Event eingeladen:",
    lbl_datum: "Datum", lbl_ort: "Ort",
    btn_app: "App öffnen", hint: "Öffne die App, um das Event zu sehen.",
  },
  sr: {
    subject: "Позивница за догађај – Vidović AI",
    intro: "Позван/а си на догађај:",
    lbl_datum: "Датум", lbl_ort: "Место",
    btn_app: "Отвори апликацију", hint: "Отвори апликацију да видиш догађај.",
  },
  hr: {
    subject: "Pozivnica za događaj – Vidović AI",
    intro: "Pozvan/a si na događaj:",
    lbl_datum: "Datum", lbl_ort: "Mjesto",
    btn_app: "Otvori aplikaciju", hint: "Otvori aplikaciju da vidiš događaj.",
  },
  ba: {
    subject: "Pozivnica za događaj – Vidović AI",
    intro: "Pozvan/a si na događaj:",
    lbl_datum: "Datum", lbl_ort: "Mjesto",
    btn_app: "Otvori aplikaciju", hint: "Otvori aplikaciju da vidiš događaj.",
  },
  en: {
    subject: "Invitation to an event – Vidović AI",
    intro: "You have been invited to an event:",
    lbl_datum: "Date", lbl_ort: "Place",
    btn_app: "Open app", hint: "Open the app to view the event.",
  },
};
const T = (sprache: string, key: string) =>
  (TEXTE[sprache] ?? TEXTE.de)[key] ?? TEXTE.de[key] ?? key;

const esc = (v: unknown) => String(v ?? "")
  .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

const WRAP = (inner: string) => `
<div style="font-family:Georgia,'Times New Roman',serif;max-width:560px;margin:0 auto;
  background:#f6f1e7;color:#2c2418;padding:28px 26px;border:1px solid #d8c9a8;border-radius:14px;">
  <h2 style="color:#7a2a2a;margin:0 0 16px;">Vidović AI</h2>
  ${inner}
  <p style="margin-top:26px;font-size:12px;color:#8a7a5a;">vidovicm20889.github.io/Stammbaum</p>
</div>`;

const zeile = (label: string, wert: string) =>
  wert ? `<tr><td style="padding:3px 12px 3px 0;color:#8a7a5a;">${esc(label)}</td>
          <td style="padding:3px 0;">${esc(wert)}</td></tr>` : "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });

type Empf = { email: string; name?: string; sprache?: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { event_id, empfaenger } = await req.json() as { event_id: string; empfaenger: Empf[] };
    if (!event_id) return json({ error: "event_id fehlt" }, 400);
    const liste = (empfaenger ?? []).filter((e) => e && e.email);
    if (liste.length === 0) return json({ ok: true, gesendet: 0, info: "keine Empfänger" });

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Event-Daten authoritativ aus der DB (Titel/Datum/Ort)
    const { data: ev, error } = await admin
      .from("events").select("titel, datum, ort").eq("id", event_id).single();
    if (error || !ev) return json({ error: "Event nicht gefunden" }, 404);

    const appUrl = APP_URL + (APP_URL.includes("?") ? "&" : "?") + "event=" + event_id;
    const testEmail = Deno.env.get("TEST_EMAIL");

    let gesendet = 0;
    const fehler: string[] = [];
    for (const e of liste) {
      const sprache = e.sprache ?? "de";
      const to = testEmail ? [testEmail] : [e.email];
      const inner = `
        <p>${esc(e.name ? e.name + "," : "")}</p>
        <p>${esc(T(sprache, "intro"))}</p>
        <h3 style="color:#7a2a2a;margin:8px 0 12px;">${esc(ev.titel)}</h3>
        <table style="font-size:14px;border-collapse:collapse;margin:0 0 18px;">
          ${zeile(T(sprache, "lbl_datum"), ev.datum ?? "")}
          ${zeile(T(sprache, "lbl_ort"), ev.ort ?? "")}
        </table>
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
      if (r.ok) gesendet++;
      else fehler.push(await r.text());
    }

    return json({ ok: true, gesendet, fehler: fehler.length ? fehler : undefined });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
