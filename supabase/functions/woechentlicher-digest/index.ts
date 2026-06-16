// Edge Function: woechentlicher-digest  (selbst-enthaltend – für Dashboard-Editor)
// Wöchentlich per pg_cron + pg_net aufgerufen (z. B. Montag 08:00 UTC). Ablauf:
//   1) digest_woche_sammeln()  -> je Empfänger+Verbund EINE Zeile mit Zählern (letzte 7 Tage:
//      Beiträge/Fotos/Personen/Geschichten/Events), anstehenden Geburtstagen/Gedenktagen
//      (nächste 7 Tage, Namen) und offenen Familien-Fragen. Nur Zeilen mit „etwas Neuem",
//      nur opted-in, nur diese Woche noch nicht versorgt (-> keine Doppel-/Leer-Mails).
//   2) je Zeile EINE zusammenfassende Mail (Sprache aus profile) per Resend.
//   3) digest_markiere_gesendet([{user_id,verbund_id,woche_start}]) -> Protokoll schreiben.
//
// DATENSCHUTZ: nur Zähler + Namen anstehender Anlässe (verbund-intern). KEINE Beitrags-/
//   Nachrichten-Texte, keine Fotos, keine Chat-Inhalte.
//
// Body: {} (keine Eingabe nötig). Aufruf NUR mit Header `x-cron-secret` (== Secret CRON_SECRET).
//   Empfehlung: für diese Function „Verify JWT" AUS (Dashboard) -> dann zählt nur x-cron-secret.
//
// Secrets (wie die anderen Functions): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
//   RESEND_API_KEY, CRON_SECRET (selbst vergeben), optional MAIL_FROM, APP_URL, TEST_EMAIL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "Vidović AI <onboarding@resend.dev>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://vidovicm20889.github.io/Stammbaum/stammbaum.html";
const CRON_SECRET    = Deno.env.get("CRON_SECRET") ?? "";

const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "Euer Familien-Wochenrückblick – Vidović AI",
    hallo: "Hallo", intro: "Das ist in eurer Familie passiert:",
    l_beitraege: "neue Beiträge", l_fotos: "neue Fotos", l_personen: "neue Personen",
    l_geschichten: "neue Geschichten", l_events: "neue Ereignisse",
    anlaesse: "Anstehende Anlässe (nächste 7 Tage):",
    geburtstage: "Geburtstage", gedenktage: "Gedenktage",
    fragen: "offene Familien-Fragen warten auf Antworten",
    btn_app: "In der App ansehen",
    hint: "Du erhältst diese Wochenzusammenfassung als Familienmitglied. Abbestellen jederzeit im Profil.",
  },
  sr: {
    subject: "Породични недељни преглед – Vidović AI",
    hallo: "Здраво", intro: "Ово се дешавало у вашој породици:",
    l_beitraege: "нових објава", l_fotos: "нових фотографија", l_personen: "нових особа",
    l_geschichten: "нових прича", l_events: "нових догађаја",
    anlaesse: "Предстојећи догађаји (наредних 7 дана):",
    geburtstage: "Рођендани", gedenktage: "Помени",
    fragen: "отворених породичних питања чека одговоре",
    btn_app: "Погледај у апликацији",
    hint: "Овај недељни преглед добијаш као члан породице. Одјава у сваком тренутку у профилу.",
  },
  hr: {
    subject: "Obiteljski tjedni pregled – Vidović AI",
    hallo: "Pozdrav", intro: "Ovo se događalo u vašoj obitelji:",
    l_beitraege: "novih objava", l_fotos: "novih fotografija", l_personen: "novih osoba",
    l_geschichten: "novih priča", l_events: "novih događaja",
    anlaesse: "Nadolazeći događaji (sljedećih 7 dana):",
    geburtstage: "Rođendani", gedenktage: "Godišnjice smrti",
    fragen: "otvorenih obiteljskih pitanja čeka odgovore",
    btn_app: "Pogledaj u aplikaciji",
    hint: "Ovaj tjedni pregled primaš kao član obitelji. Odjava bilo kada u profilu.",
  },
  ba: {
    subject: "Porodični sedmični pregled – Vidović AI",
    hallo: "Pozdrav", intro: "Ovo se dešavalo u vašoj porodici:",
    l_beitraege: "novih objava", l_fotos: "novih fotografija", l_personen: "novih osoba",
    l_geschichten: "novih priča", l_events: "novih događaja",
    anlaesse: "Nadolazeći događaji (narednih 7 dana):",
    geburtstage: "Rođendani", gedenktage: "Godišnjice smrti",
    fragen: "otvorenih porodičnih pitanja čeka odgovore",
    btn_app: "Pogledaj u aplikaciji",
    hint: "Ovaj sedmični pregled primaš kao član porodice. Odjava bilo kada u profilu.",
  },
  en: {
    subject: "Your family week in review – Vidović AI",
    hallo: "Hello", intro: "Here's what happened in your family:",
    l_beitraege: "new posts", l_fotos: "new photos", l_personen: "new people",
    l_geschichten: "new stories", l_events: "new events",
    anlaesse: "Upcoming occasions (next 7 days):",
    geburtstage: "Birthdays", gedenktage: "Memorial days",
    fragen: "open family questions awaiting answers",
    btn_app: "View in the app",
    hint: "You receive this weekly summary as a family member. Unsubscribe anytime in your profile.",
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

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...cors, "Content-Type": "application/json" } });

type Row = {
  user_id: string; verbund_id: string; email: string;
  name: string | null; sprache: string | null; woche_start: string;
  cnt_beitraege: number; cnt_fotos: number; cnt_personen: number;
  cnt_geschichten: number; cnt_events: number;
  geburtstage: string[] | null; gedenktage: string[] | null;
  offene_fragen: number; neue_fragen: number;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const secret = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!CRON_SECRET || secret !== CRON_SECRET) return json({ error: "unauthorized" }, 401);

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // 1) Wochen-Zeilen sammeln (nur „etwas Neues", opted-in, noch nicht versorgt)
    const { data, error } = await admin.rpc("digest_woche_sammeln");
    if (error) return json({ error: error.message }, 500);
    const rows = (data ?? []) as Row[];
    if (rows.length === 0) return json({ ok: true, gesendet: 0, info: "keine Digest-Zeilen" });

    const appUrl = APP_URL + (APP_URL.includes("?") ? "&" : "?") + "feed=1";
    const testEmail = Deno.env.get("TEST_EMAIL");
    let gesendet = 0;
    const erledigt: { user_id: string; verbund_id: string; woche_start: string }[] = [];
    const fehler: string[] = [];

    for (const r of rows) {
      if (!r.email) continue;
      const s = r.sprache ?? "de";
      const to = testEmail ? [testEmail] : [r.email];

      // Zähler-Zeilen (nur > 0)
      const zaehler: Array<[string, number, string]> = [
        ["📝", r.cnt_beitraege,   T(s, "l_beitraege")],
        ["📷", r.cnt_fotos,       T(s, "l_fotos")],
        ["👤", r.cnt_personen,    T(s, "l_personen")],
        ["📖", r.cnt_geschichten, T(s, "l_geschichten")],
        ["📅", r.cnt_events,      T(s, "l_events")],
      ];
      const zaehlerHtml = zaehler.filter(([, n]) => n > 0)
        .map(([ic, n, lbl]) => `<li style="margin:6px 0;">${ic} <strong>${n}</strong> ${esc(lbl)}</li>`)
        .join("");

      // Anstehende Anlässe (Namen, datensparsam)
      const geb = (r.geburtstage ?? []).filter(Boolean);
      const ged = (r.gedenktage ?? []).filter(Boolean);
      const anlaesseTeile: string[] = [];
      if (geb.length) anlaesseTeile.push(`<li style="margin:6px 0;">🎂 <strong>${esc(T(s, "geburtstage"))}:</strong> ${esc(geb.join(", "))}</li>`);
      if (ged.length) anlaesseTeile.push(`<li style="margin:6px 0;">🕯️ <strong>${esc(T(s, "gedenktage"))}:</strong> ${esc(ged.join(", "))}</li>`);
      const anlaesseHtml = anlaesseTeile.length
        ? `<p style="margin:16px 0 4px;">${esc(T(s, "anlaesse"))}</p>
           <ul style="list-style:none;padding:0;margin:8px 0 0;font-size:15px;">${anlaesseTeile.join("")}</ul>`
        : "";

      const fragenHtml = r.offene_fragen > 0
        ? `<p style="margin:16px 0 0;font-size:15px;">❓ <strong>${r.offene_fragen}</strong> ${esc(T(s, "fragen"))}</p>`
        : "";

      const inner = `
        <p>${esc(r.name ? T(s, "hallo") + " " + r.name + "," : T(s, "hallo") + ",")}</p>
        <p>${esc(T(s, "intro"))}</p>
        ${zaehlerHtml ? `<ul style="list-style:none;padding:0;margin:12px 0 0;font-size:15px;">${zaehlerHtml}</ul>` : ""}
        ${anlaesseHtml}
        ${fragenHtml}
        <div style="text-align:center;margin:26px 0;">
          <a href="${appUrl}" style="display:inline-block;background:#7a2a2a;color:#fff;
            text-decoration:none;padding:12px 26px;border-radius:8px;">${esc(T(s, "btn_app"))}</a>
        </div>
        <p style="font-size:12px;color:#8a7a5a;">${esc(T(s, "hint"))}</p>`;

      const resp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from: MAIL_FROM, to, subject: T(s, "subject"), html: WRAP(inner) }),
      });
      if (resp.ok) {
        gesendet++;
        erledigt.push({ user_id: r.user_id, verbund_id: r.verbund_id, woche_start: r.woche_start });
      } else {
        fehler.push(await resp.text());
      }
    }

    // 3) Protokoll schreiben (nur erfolgreich versendete)
    if (erledigt.length) {
      const { error: errMark } = await admin.rpc("digest_markiere_gesendet", { p_rows: erledigt });
      if (errMark) console.error("digest_markiere_gesendet:", errMark.message);
    }

    return json({ ok: true, zeilen: rows.length, gesendet,
                  markiert: erledigt.length, fehler: fehler.length ? fehler : undefined });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
