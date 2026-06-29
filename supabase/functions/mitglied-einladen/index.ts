// Edge Function: mitglied-einladen  (selbst-enthaltend – für Dashboard-Editor)
// Ein Admin legt ein neues Mitglied an: Benutzer (falls nötig) + Rolle + Familie,
// und es geht automatisch eine Einladungs-Mail mit Registrierungslink raus.
//
// Im Dashboard "Verify JWT" für diese Function AN lassen (nur eingeloggte Admins).
// Zusätzlich wird serverseitig geprüft, dass der Aufrufer die Familie verwalten darf.
//
// Erwarteter Body (JSON): { email, rolle, familie_id, sprache }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY       = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "FamilyRoots <support@vidovic-ai.com>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://vidovicm20889.github.io/Stammbaum/stammbaum.html";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ERLAUBTE_ROLLEN = ["familien_mitglied", "familien_admin"];

// ---------------------------------------------------------------------------
// Mehrsprachige Mail-Texte
// ---------------------------------------------------------------------------
const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "Du wurdest eingeladen – FamilyRoots",
    body: "Du wurdest zum Familienstammbaum eingeladen. Klicke auf den folgenden Link, um dein Passwort zu setzen und dich anzumelden:",
    btn: "Passwort setzen",
    add_subject: "Du wurdest hinzugefügt – FamilyRoots",
    add_body: "Du wurdest einem weiteren Familienstammbaum hinzugefügt. Melde dich wie gewohnt an, um ihn zu sehen.",
  },
  sr: {
    subject: "Позван си – FamilyRoots",
    body: "Позван си у породично стабло. Кликни на следећи линк да поставиш лозинку и пријавиш се:",
    btn: "Постави лозинку",
    add_subject: "Додат си – FamilyRoots",
    add_body: "Додат си још једном породичном стаблу. Пријави се као обично да га видиш.",
  },
  hr: {
    subject: "Pozvan si – FamilyRoots",
    body: "Pozvan si u obiteljsko stablo. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
    btn: "Postavi lozinku",
    add_subject: "Dodan si – FamilyRoots",
    add_body: "Dodan si još jednom obiteljskom stablu. Prijavi se kao i obično da ga vidiš.",
  },
  ba: {
    subject: "Pozvan si – FamilyRoots",
    body: "Pozvan si u porodično stablo. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
    btn: "Postavi lozinku",
    add_subject: "Dodan si – FamilyRoots",
    add_body: "Dodan si još jednom porodičnom stablu. Prijavi se kao i obično da ga vidiš.",
  },
  en: {
    subject: "You have been invited – FamilyRoots",
    body: "You have been invited to the family tree. Click the link below to set your password and sign in:",
    btn: "Set password",
    add_subject: "You have been added – FamilyRoots",
    add_body: "You have been added to another family tree. Sign in as usual to see it.",
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

async function sendMail(to: string, subject: string, html: string) {
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

  const authHeader = req.headers.get("Authorization") ?? "";
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  try {
    const payload = await req.json();
    const email      = String(payload?.email ?? "").trim().toLowerCase();
    const rolle      = String(payload?.rolle ?? "");
    const familie_id = String(payload?.familie_id ?? "");
    const sprache    = String(payload?.sprache ?? "de");

    if (!email || !familie_id) return jsonResp({ error: "E-Mail und Familie sind erforderlich." }, 400);
    if (!isValidEmail(email)) return jsonResp({ error: "Ungültige E-Mail-Adresse.", code: "email_invalid" }, 400);
    if (!ERLAUBTE_ROLLEN.includes(rolle)) return jsonResp({ error: "Unzulässige Rolle." }, 400);

    // 1) Aufrufer authentifizieren und Berechtigung prüfen (im Kontext seines JWT)
    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await userClient.auth.getUser();
    if (!userData?.user) return jsonResp({ error: "Nicht angemeldet." }, 401);

    const { data: darf, error: darfErr } = await userClient
      .rpc("kann_familie_bearbeiten", { p_familie_id: familie_id });
    if (darfErr) throw darfErr;
    if (!darf) return jsonResp({ error: "Keine Berechtigung für diese Familie." }, 403);

    // 2) Benutzer anlegen (Invite) oder vorhandenen finden
    let userId: string | undefined;
    let inviteLink: string | undefined;
    const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
      type: "invite", email, options: { redirectTo: APP_URL },
    });
    if (linkErr) {
      // Vermutlich schon registriert -> vorhandene User-ID holen
      const { data: uid } = await admin.rpc("user_per_email", { p_email: email });
      if (!uid) return jsonResp({ error: linkErr.message }, 400);
      userId = uid as string;
    } else {
      userId = linkData.user?.id;
      inviteLink = linkData.properties?.action_link ?? APP_URL;
    }
    if (!userId) return jsonResp({ error: "Benutzer konnte nicht ermittelt werden." }, 500);

    // 3) Mitgliedschaft anlegen
    const { error: mErr } = await admin.from("mitgliedschaften")
      .insert({ user_id: userId, familie_id, rolle, aktiv: true });
    if (mErr) {
      if (mErr.code === "23505") return jsonResp({ error: "bereits" }, 409);
      throw mErr;
    }

    // 4) Mail verschicken
    if (inviteLink) {
      const inner = `
        <p>${esc(T(sprache, "body"))}</p>
        <div style="text-align:center;margin:24px 0;">
          <a href="${inviteLink}" style="display:inline-block;background:#7a2a2a;color:#fff;
            text-decoration:none;padding:12px 26px;border-radius:8px;">${esc(T(sprache, "btn"))}</a>
        </div>`;
      await sendMail(email, T(sprache, "subject"), WRAP(inner));
    } else {
      // Vorhandener Nutzer: nur Info-Mail (kein Passwort-Link nötig)
      await sendMail(email, T(sprache, "add_subject"),
        WRAP(`<p>${esc(T(sprache, "add_body"))}</p>`));
    }

    return jsonResp({ ok: true, user_id: userId, neu: !!inviteLink });
  } catch (e) {
    console.error("mitglied-einladen fehlgeschlagen:", e);
    return jsonResp({ error: (e as Error).message ?? String(e) }, 500);
  }
});
