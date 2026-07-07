// Edge Function: neue-familie-anlegen  (selbst-enthaltend – für Dashboard-Editor)
// SELF-SERVICE: Ein neuer Nutzer legt OHNE Admin-Freigabe einen leeren Stammbaum an
// und wird dessen Familien-Admin. Aufruf aus dem Browser via supabase.functions.invoke.
//
// Im Dashboard "Verify JWT" für diese Function AUSschalten (Aufruf ohne Login).
//
// Ablauf (Service-Role):
//   1. Auth-User anlegen + Invite-/Recovery-Link erzeugen (generateLink type=invite)
//   2. familie (Konto) anlegen  -> eigener verbund_id (Default)
//   3. stammbaum anlegen
//   4. erste Person anlegen (der anlegende Nutzer)
//   5. Mitgliedschaft als familien_admin
//   6. Einladungs-Mail zum Passwort-Setzen verschicken
//
// Erwarteter Body (JSON):
//   { email, familie_name, sprache, person: { vorname, nachname, geburtsdatum,
//     geburtsort, geburtsland, getauft_am, verheiratet_am, telefon,
//     kontakt_email, facebook, instagram } }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "FamilyRoots <support@familyroots.club>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://familyroots.club/stammbaum.html";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ---------------------------------------------------------------------------
// Mehrsprachige Mail-Texte
// ---------------------------------------------------------------------------
const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "Dein Stammbaum wurde angelegt – FamilyRoots",
    body: "Dein neuer Stammbaum wurde angelegt und du bist sein Administrator. Klicke auf den folgenden Link, um dein Passwort zu setzen und dich anzumelden:",
    btn: "Passwort setzen",
  },
  sr: {
    subject: "Твоје стабло је направљено – FamilyRoots",
    body: "Твоје ново стабло је направљено и ти си његов администратор. Кликни на следећи линк да поставиш лозинку и пријавиш се:",
    btn: "Постави лозинку",
  },
  hr: {
    subject: "Tvoje stablo je izrađeno – FamilyRoots",
    body: "Tvoje novo stablo je izrađeno i ti si njegov administrator. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
    btn: "Postavi lozinku",
  },
  ba: {
    subject: "Tvoje stablo je kreirano – FamilyRoots",
    body: "Tvoje novo stablo je kreirano i ti si njegov administrator. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
    btn: "Postavi lozinku",
  },
  en: {
    subject: "Your family tree was created – FamilyRoots",
    body: "Your new family tree has been created and you are its administrator. Click the link below to set your password and sign in:",
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

// Zentrale E-Mail-Format-Prüfung (identisch zur Frontend-Regel isValidEmail)
function isValidEmail(email: string): boolean {
  const e = (email ?? "").trim();
  if (!e || /\s/.test(e)) return false;
  if ((e.match(/@/g) || []).length !== 1) return false;
  if (e.includes("..")) return false;
  return /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/.test(e);
}

// HTML -> lesbarer Klartext für den text/plain-Teil (Links als "Text: URL",
// Tags entfernt, Entities zurück). Sorgt für multipart/alternative statt
// HTML-only -> deutlich besseres Zustell-/Spam-Verhalten.
function htmlZuText(html: string): string {
  return html
    .replace(/<a\b[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gis, "$2: $1")
    .replace(/<\/(p|div|h[1-6])>/gi, "\n")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]+/g, " ")
    .split("\n").map((z) => z.trim()).join("\n")
    .trim();
}

async function sendMail(to: string, subject: string, html: string) {
  // TEST-Modus: wenn TEST_EMAIL gesetzt ist, gehen alle Mails dorthin.
  const empfaenger = Deno.env.get("TEST_EMAIL") || to;
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: MAIL_FROM, to: empfaenger, subject, html, text: htmlZuText(html) }),
  });
  if (!r.ok) console.error("Resend-Fehler:", await r.text());
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return jsonResp({ error: "Method not allowed" }, 405);

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  try {
    const payload = await req.json();
    const email        = String(payload?.email ?? "").trim().toLowerCase();
    const familie_name = String(payload?.familie_name ?? "").trim();
    const sprache      = String(payload?.sprache ?? "de");
    const p            = payload?.person ?? {};
    // Ortsfelder der Familie (Država / Grad-selo / Opština) – wichtig fürs spätere
    // strikte Matching (familie_finden_exakt). Leere Werte werden zu null.
    const land     = String(payload?.land ?? "").trim()     || null;
    const stadt    = String(payload?.stadt ?? "").trim()    || null;
    const gemeinde = String(payload?.gemeinde ?? "").trim() || null;

    if (!email || !familie_name) {
      return jsonResp({ error: "E-Mail und Familienname sind erforderlich." }, 400);
    }
    // Serverseitige E-Mail-Format-Prüfung (niemals nur dem Frontend vertrauen)
    if (!isValidEmail(email)) {
      return jsonResp({ error: "Ungültige E-Mail-Adresse.", code: "email_invalid" }, 400);
    }
    const kontaktEmail = String(p?.kontakt_email ?? "").trim();
    if (kontaktEmail && !isValidEmail(kontaktEmail)) {
      return jsonResp({ error: "Ungültige Kontakt-E-Mail.", code: "email_invalid" }, 400);
    }

    // 1) Auth-User + Invite-Link (legt User an, falls noch nicht vorhanden)
    const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
      type: "invite", email, options: { redirectTo: APP_URL },
    });
    if (linkErr) {
      // E-Mail evtl. schon registriert -> stabilen Code mitgeben, damit das
      // Frontend eine lokalisierte, sprechende Meldung zeigen kann.
      const m = (linkErr.message || "").toLowerCase();
      const code = (m.includes("already") || m.includes("registered") || m.includes("exist"))
        ? "email_exists" : "invite_failed";
      return jsonResp({ error: linkErr.message, code }, 400);
    }
    const userId = linkData.user?.id;
    const setPasswortUrl = linkData.properties?.action_link ?? APP_URL;
    if (!userId) return jsonResp({ error: "Benutzer konnte nicht angelegt werden." }, 500);

    // 2) familie (Konto) – eigener Verbund per Default; Ortsfelder fürs Matching
    const { data: fam, error: famErr } = await admin
      .from("familien").insert({ name: familie_name, land, stadt, gemeinde })
      .select("id").single();
    if (famErr) throw famErr;
    const familie_id = fam.id;

    // 3) stammbaum
    const { data: baum, error: baumErr } = await admin
      .from("stammbaeume").insert({ familie_id, name: familie_name }).select("id").single();
    if (baumErr) throw baumErr;
    const stammbaum_id = baum.id;

    // 4) erste Person (der anlegende Nutzer)
    const externe_id = "I" + Date.now();
    const vorname  = p.vorname ?? "";
    const nachname = p.nachname ?? familie_name;
    const { data: pers, error: persErr } = await admin.from("personen").insert({
      familie_id,
      stammbaum_id,
      externe_id,
      vorname,
      nachname,
      geburtsdatum: null,   // Rohdatum bleibt Freitext in stammbaum_daten (Spalte ist date)
      stammbaum_daten: {
        id: externe_id, given: vorname, surname: nachname,
        name: (vorname + " " + nachname).trim(), sex: "",
        birth_date: p.geburtsdatum ?? "", birth_place: p.geburtsort ?? "",
        geburtsland: p.geburtsland,
        getauft_am: p.getauft_am, verheiratet_am: p.verheiratet_am,
        telefon: p.telefon, kontakt_email: p.kontakt_email,
        facebook: p.facebook, instagram: p.instagram,
        angelegt_aus: "selbst-anlegen",
      },
    }).select("id").single();
    if (persErr) throw persErr;

    // Wurzel des neuen Baums = diese Person
    await admin.from("stammbaeume")
      .update({ wurzel_person_id: pers.id }).eq("id", stammbaum_id);

    // 5) Mitgliedschaft als Eigentümer (familien_owner) — der Ersteller des Baums
    const { error: mErr } = await admin.from("mitgliedschaften").insert({
      user_id: userId, familie_id, rolle: "familien_owner", aktiv: true,
    });
    if (mErr) throw mErr;

    // 6) Einladungs-Mail
    const inner = `
      <p>${esc(T(sprache, "body"))}</p>
      <div style="text-align:center;margin:24px 0;">
        <a href="${setPasswortUrl}" style="display:inline-block;background:#7a2a2a;color:#fff;
          text-decoration:none;padding:12px 26px;border-radius:8px;">${esc(T(sprache, "btn"))}</a>
      </div>`;
    await sendMail(email, T(sprache, "subject"), WRAP(inner));

    return jsonResp({ ok: true, familie_id, stammbaum_id });
  } catch (e) {
    console.error("neue-familie-anlegen fehlgeschlagen:", e);
    return jsonResp({ error: (e as Error).message ?? String(e) }, 500);
  }
});
