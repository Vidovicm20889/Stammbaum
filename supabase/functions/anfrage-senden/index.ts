// Edge Function: anfrage-senden  (selbst-enthaltend – für Dashboard-Editor)
// Wird vom Frontend nach dem Speichern einer Anfrage aufgerufen.
// Lädt die Anfrage, ermittelt die Admin-Empfänger und verschickt per Resend
// eine reine BENACHRICHTIGUNGS-Mail (KEINE Bestätigen-/Ablehnen-Links mehr).
// Die Entscheidung trifft der Admin AUSSCHLIESSLICH in der App unter „Obavještenja“.
// Die Mail enthält nur einen „App öffnen"-Link (Deep-Link ?obav=1).

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

// ---------------------------------------------------------------------------
// Mehrsprachige Texte
// ---------------------------------------------------------------------------
const TEXTE: Record<string, Record<string, string>> = {
  de: {
    admin_subject: "Neue Anfrage eingegangen – FamilyRoots",
    admin_intro: "Eine neue Zugangsanfrage ist eingegangen. Die Bearbeitung erfolgt in der App unter „Obavještenja“:",
    lbl_email: "E-Mail", lbl_familie: "Familie / Stammbaum", lbl_rolle: "Gewünschte Rolle",
    btn_app: "App öffnen",
    admin_hint: "Bitte öffne die App und entscheide unter „Obavještenja“ über die Anfrage. Eine Bearbeitung per E-Mail ist nicht mehr möglich.",
    rolle_familien_admin: "Familien-Admin", rolle_familien_mitglied: "Mitglied",
  },
  sr: {
    admin_subject: "Нови захтев је стигао – FamilyRoots",
    admin_intro: "Стигао је нови захтев за приступ. Обрада се врши у апликацији у одељку „Обавјештења“:",
    lbl_email: "Имејл", lbl_familie: "Породица / стабло", lbl_rolle: "Жељена улога",
    btn_app: "Отвори апликацију",
    admin_hint: "Отвори апликацију и одлучи о захтеву у одељку „Обавјештења“. Обрада путем имејла више није могућа.",
    rolle_familien_admin: "Админ породице", rolle_familien_mitglied: "Члан",
  },
  hr: {
    admin_subject: "Stigao je novi zahtjev – FamilyRoots",
    admin_intro: "Stigao je novi zahtjev za pristup. Obrada se vrši u aplikaciji u dijelu „Obavještenja“:",
    lbl_email: "E-mail", lbl_familie: "Obitelj / stablo", lbl_rolle: "Željena uloga",
    btn_app: "Otvori aplikaciju",
    admin_hint: "Otvori aplikaciju i odluči o zahtjevu u dijelu „Obavještenja“. Obrada putem e-maila više nije moguća.",
    rolle_familien_admin: "Admin obitelji", rolle_familien_mitglied: "Član",
  },
  ba: {
    admin_subject: "Stigao je novi zahtjev – FamilyRoots",
    admin_intro: "Stigao je novi zahtjev za pristup. Obrada se vrši u aplikaciji u dijelu „Obavještenja“:",
    lbl_email: "E-mail", lbl_familie: "Porodica / stablo", lbl_rolle: "Željena uloga",
    btn_app: "Otvori aplikaciju",
    admin_hint: "Otvori aplikaciju i odluči o zahtjevu u dijelu „Obavještenja“. Obrada putem e-maila više nije moguća.",
    rolle_familien_admin: "Admin porodice", rolle_familien_mitglied: "Član",
  },
  en: {
    admin_subject: "New request received – FamilyRoots",
    admin_intro: "A new access request has arrived. It is handled in the app under „Obavještenja“:",
    lbl_email: "Email", lbl_familie: "Family / tree", lbl_rolle: "Requested role",
    btn_app: "Open app",
    admin_hint: "Please open the app and decide on the request under „Obavještenja“. Handling via email is no longer possible.",
    rolle_familien_admin: "Family admin", rolle_familien_mitglied: "Member",
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

const zeile = (label: string, wert: string) =>
  wert ? `<tr><td style="padding:3px 12px 3px 0;color:#8a7a5a;">${esc(label)}</td>
          <td style="padding:3px 0;">${esc(wert)}</td></tr>` : "";

// ---------------------------------------------------------------------------
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { id } = await req.json();
    if (!id) return json({ error: "id fehlt" }, 400);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    const { data: a, error } = await admin
      .from("registrierungs_anfragen").select("*").eq("id", id).single();
    if (error || !a) return json({ error: "Anfrage nicht gefunden" }, 404);
    if (a.status !== "offen") return json({ ok: true, info: "bereits bearbeitet" });

    let familie_name = "";
    if (a.familie_id) {
      const { data: f } = await admin
        .from("familien").select("name").eq("id", a.familie_id).single();
      familie_name = f?.name ?? "";
    }

    const { data: emails } = await admin
      .rpc("admin_emails_fuer_familie", { p_familie_id: a.familie_id });
    const empfaenger = (emails ?? [])
      .map((e: { email: string }) => e.email).filter(Boolean);
    if (empfaenger.length === 0)
      return json({ error: "Keine Admin-Empfänger gefunden" }, 422);

    // TEST-Modus: Solange keine eigene Domain bei Resend verifiziert ist, dürfen
    // Mails nur an die eigene Resend-Adresse gehen. Ist das Secret TEST_EMAIL
    // gesetzt, gehen ALLE Mails dorthin. In Produktion (verifizierte Domain)
    // einfach das Secret TEST_EMAIL löschen.
    const testEmail = Deno.env.get("TEST_EMAIL");
    const to = testEmail ? [testEmail] : empfaenger;

    // Deep-Link in die App: öffnet nach (ggf.) Login direkt die Obavještenja-Liste.
    const appUrl = APP_URL + (APP_URL.includes("?") ? "&" : "?") + "obav=1";
    const sprache = a.sprache ?? "de";

    const person = [
      zeile("•", `${a.vorname ?? ""} ${a.nachname ?? ""}`.trim()),
      zeile(T(sprache, "lbl_email"), a.email),
      zeile(T(sprache, "lbl_familie"), familie_name),
      zeile(T(sprache, "lbl_rolle"), T(sprache, "rolle_" + a.rolle)),
      zeile("Geburtsdatum", a.geburtsdatum ?? ""),
      zeile("Geburtsort", a.geburtsort ?? ""),
      zeile("Land", a.geburtsland ?? ""),
      zeile("Stadt", a.stadt ?? ""),
      zeile("Gemeinde", a.gemeinde ?? ""),
      zeile("Getauft am", a.getauft_am ?? ""),
      zeile("Verheiratet am", a.verheiratet_am ?? ""),
      zeile("Telefon", a.telefon ?? ""),
      zeile("Kontakt-E-Mail", a.kontakt_email ?? ""),
      zeile("Facebook", a.facebook ?? ""),
      zeile("Instagram", a.instagram ?? ""),
    ].join("");

    const inner = `
      <p>${esc(T(sprache, "admin_intro"))}</p>
      <table style="font-size:14px;border-collapse:collapse;margin:10px 0 18px;">${person}</table>
      <div style="text-align:center;margin:24px 0;">
        <a href="${appUrl}" style="display:inline-block;background:#7a2a2a;color:#fff;
          text-decoration:none;padding:12px 26px;border-radius:8px;margin:4px;">${esc(T(sprache, "btn_app"))}</a>
      </div>
      <p style="font-size:13px;color:#8a7a5a;">${esc(T(sprache, "admin_hint"))}</p>`;

    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: MAIL_FROM, to,
        subject: T(sprache, "admin_subject"), html: WRAP(inner),
        text: htmlZuText(WRAP(inner)),
      }),
    });
    if (!r.ok) {
      const detail = await r.text();
      console.error("Resend-Fehler:", detail);
      return json({ error: "Mail-Versand fehlgeschlagen", detail }, 502);
    }
    return json({ ok: true, gesendet_an: empfaenger.length });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
