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
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "Stammbaum Vidović <onboarding@resend.dev>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://vidovicm20889.github.io/Stammbaum/stammbaum.html";

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
    subject: "Dein Stammbaum wurde angelegt – Stammbaum Vidović",
    body: "Dein neuer Stammbaum wurde angelegt und du bist sein Administrator. Klicke auf den folgenden Link, um dein Passwort zu setzen und dich anzumelden:",
    btn: "Passwort setzen",
  },
  sr: {
    subject: "Твоје стабло је направљено – Стабло Видовић",
    body: "Твоје ново стабло је направљено и ти си његов администратор. Кликни на следећи линк да поставиш лозинку и пријавиш се:",
    btn: "Постави лозинку",
  },
  hr: {
    subject: "Tvoje stablo je izrađeno – Stablo Vidović",
    body: "Tvoje novo stablo je izrađeno i ti si njegov administrator. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
    btn: "Postavi lozinku",
  },
  ba: {
    subject: "Tvoje stablo je kreirano – Stablo Vidović",
    body: "Tvoje novo stablo je kreirano i ti si njegov administrator. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
    btn: "Postavi lozinku",
  },
  en: {
    subject: "Your family tree was created – Vidović Family Tree",
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
  <h2 style="color:#7a2a2a;margin:0 0 16px;">Stammbaum Vidović</h2>
  ${inner}
  <p style="margin-top:26px;font-size:12px;color:#8a7a5a;">vidovicm20889.github.io/Stammbaum</p>
</div>`;

const jsonResp = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), {
    status, headers: { ...CORS, "Content-Type": "application/json" },
  });

async function sendMail(to: string, subject: string, html: string) {
  // TEST-Modus: wenn TEST_EMAIL gesetzt ist, gehen alle Mails dorthin.
  const empfaenger = Deno.env.get("TEST_EMAIL") || to;
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: MAIL_FROM, to: empfaenger, subject, html }),
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

    if (!email || !familie_name) {
      return jsonResp({ error: "E-Mail und Familienname sind erforderlich." }, 400);
    }

    // 1) Auth-User + Invite-Link (legt User an, falls noch nicht vorhanden)
    const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
      type: "invite", email, options: { redirectTo: APP_URL },
    });
    if (linkErr) {
      // E-Mail evtl. schon registriert -> nicht doppelt anlegen
      return jsonResp({ error: linkErr.message }, 400);
    }
    const userId = linkData.user?.id;
    const setPasswortUrl = linkData.properties?.action_link ?? APP_URL;
    if (!userId) return jsonResp({ error: "Benutzer konnte nicht angelegt werden." }, 500);

    // 2) familie (Konto) – eigener Verbund per Default
    const { data: fam, error: famErr } = await admin
      .from("familien").insert({ name: familie_name }).select("id").single();
    if (famErr) throw famErr;
    const familie_id = fam.id;

    // 3) stammbaum
    const { data: baum, error: baumErr } = await admin
      .from("stammbaeume").insert({ familie_id, name: familie_name }).select("id").single();
    if (baumErr) throw baumErr;
    const stammbaum_id = baum.id;

    // 4) erste Person (der anlegende Nutzer)
    const { data: pers, error: persErr } = await admin.from("personen").insert({
      familie_id,
      stammbaum_id,
      externe_id:   "I" + Date.now(),
      vorname:      p.vorname ?? "",
      nachname:     p.nachname ?? familie_name,
      geburtsdatum: p.geburtsdatum ?? null,
      stammbaum_daten: {
        geburtsort: p.geburtsort, geburtsland: p.geburtsland,
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

    // 5) Mitgliedschaft als Familien-Admin
    const { error: mErr } = await admin.from("mitgliedschaften").insert({
      user_id: userId, familie_id, rolle: "familien_admin", aktiv: true,
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
