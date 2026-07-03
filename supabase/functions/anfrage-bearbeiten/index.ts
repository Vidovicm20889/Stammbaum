// Edge Function: anfrage-bearbeiten  (app-fähig – aus der Obavještenja-Liste)
// POST { id: <uuid>, aktion: "bestaetigen" | "ablehnen" }
// Im Dashboard "Verify JWT" für diese Function AN lassen (nur eingeloggte Admins).
// Macht dasselbe wie anfrage-entscheiden, aber:
//  - CORS (aus Browser aufrufbar), JSON-Antwort
//  - prüft, dass der Aufrufer Admin der betroffenen Familie ist
//  - protokolliert die Entscheidung (anfrage_log)
//  - Mail-Versand fehlertolerant (Aktion gilt auch, wenn Mail scheitert)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY       = Deno.env.get("SUPABASE_ANON_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "FamilyRoots <support@familyroots.club>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://familyroots.club/stammbaum.html";

const TEXTE: Record<string, Record<string, string>> = {
  de: { ok_subject: "Dein Zugang wurde bestätigt – FamilyRoots",
        ok_body: "Deine Zugangsanfrage wurde bestätigt. Klicke auf den folgenden Link, um dein Passwort zu setzen und dich anzumelden:",
        ok_btn: "Passwort setzen",
        no_subject: "Deine Zugangsanfrage – FamilyRoots",
        no_body: "Deine Zugangsanfrage wurde leider abgelehnt. Bei Fragen wende dich bitte an deinen Familien-Administrator." },
  sr: { ok_subject: "Твој приступ је потврђен – FamilyRoots",
        ok_body: "Твој захтев за приступ је потврђен. Кликни на следећи линк да поставиш лозинку и пријавиш се:",
        ok_btn: "Постави лозинку",
        no_subject: "Твој захтев за приступ – FamilyRoots",
        no_body: "Твој захтев за приступ је нажалост одбијен. За питања се обрати админу породице." },
  hr: { ok_subject: "Tvoj pristup je potvrđen – FamilyRoots",
        ok_body: "Tvoj zahtjev za pristup je potvrđen. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
        ok_btn: "Postavi lozinku",
        no_subject: "Tvoj zahtjev za pristup – FamilyRoots",
        no_body: "Tvoj zahtjev za pristup nažalost je odbijen. Za pitanja se obrati administratoru obitelji." },
  ba: { ok_subject: "Tvoj pristup je potvrđen – FamilyRoots",
        ok_body: "Tvoj zahtjev za pristup je potvrđen. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
        ok_btn: "Postavi lozinku",
        no_subject: "Tvoj zahtjev za pristup – FamilyRoots",
        no_body: "Tvoj zahtjev za pristup nažalost je odbijen. Za pitanja se obrati administratoru porodice." },
  en: { ok_subject: "Your access was approved – FamilyRoots",
        ok_body: "Your access request has been approved. Click the link below to set your password and sign in:",
        ok_btn: "Set password",
        no_subject: "Your access request – FamilyRoots",
        no_body: "Your access request was unfortunately rejected. If you have questions, please contact your family administrator." },
};
const T = (s: string, k: string) => (TEXTE[s] ?? TEXTE.de)[k] ?? TEXTE.de[k] ?? k;
const esc = (v: unknown) => String(v ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const WRAP = (inner: string) => `
<div style="font-family:Georgia,'Times New Roman',serif;max-width:560px;margin:0 auto;
  background:#f6f1e7;color:#2c2418;padding:28px 26px;border:1px solid #d8c9a8;border-radius:14px;">
  <h2 style="color:#7a2a2a;margin:0 0 16px;">FamilyRoots</h2>${inner}
  <p style="margin-top:26px;font-size:12px;color:#8a7a5a;">familyroots.club</p></div>`;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function sendMail(to: string, subject: string, html: string) {
  // TEST-Modus: TEST_EMAIL leitet alle Mails dorthin (Resend ohne verifizierte Domain).
  const empfaenger = Deno.env.get("TEST_EMAIL") || to;
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: MAIL_FROM, to: empfaenger, subject, html }),
  });
  if (!r.ok) throw new Error("Resend: " + await r.text());
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { id, aktion, person_id } = await req.json();
    if (!id || (aktion !== "bestaetigen" && aktion !== "ablehnen"))
      return json({ error: "id/aktion fehlt oder ungültig" }, 400);

    // Aufrufer aus dem JWT bestimmen
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: ures } = await userClient.auth.getUser();
    const user = ures?.user;
    if (!user) return json({ error: "Nicht angemeldet" }, 401);

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data: a } = await admin.from("registrierungs_anfragen").select("*").eq("id", id).single();
    if (!a) return json({ error: "Anfrage nicht gefunden" }, 404);
    if (a.status !== "offen") return json({ ok: true, info: "bereits bearbeitet" });

    // Rechteprüfung: Super-Admin ODER Admin/Owner der betroffenen Familie
    const { data: saRows } = await admin.from("mitgliedschaften").select("id").eq("user_id", user.id).eq("rolle", "super_admin").limit(1);
    let darf = !!(saRows && saRows.length);
    if (!darf && a.familie_id) {
      const { data: m } = await admin.from("mitgliedschaften").select("rolle").eq("user_id", user.id).eq("familie_id", a.familie_id);
      darf = (m ?? []).some((x: { rolle: string }) => ["super_admin", "familien_owner", "familien_admin"].includes(x.rolle));
    }
    if (!darf) return json({ error: "Keine Berechtigung" }, 403);

    const sprache = a.sprache ?? "de";
    let mailWarnung: string | null = null;

    if (aktion === "bestaetigen") {
      const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
        type: "invite", email: a.email, options: { redirectTo: APP_URL },
      });
      if (linkErr) throw linkErr;
      const userId = linkData.user?.id;
      const setPasswortUrl = linkData.properties?.action_link ?? APP_URL;

      if (userId) {
        await admin.from("mitgliedschaften").insert({ user_id: userId, familie_id: a.familie_id, rolle: a.rolle });
      }
      // Person verknüpfen: wenn der Admin eine bestehende Baum-Person gewählt hat ->
      // personen.user_id setzen (DB-Trigger berechnet daraus die Blutlinien-Admin-Rechte).
      // Sonst (keine Auswahl) wie bisher eine eigenständige Person aus den Anfragedaten anlegen.
      if (userId && person_id) {
        await admin.from("personen").update({ user_id: userId }).eq("id", person_id);
      } else if (a.vorname || a.nachname) {
        await admin.from("personen").insert({
          familie_id: a.familie_id, vorname: a.vorname ?? "", nachname: a.nachname ?? "",
          geburtsdatum: a.geburtsdatum ?? null,
          stammbaum_daten: {
            geburtsort: a.geburtsort, geburtsland: a.geburtsland, stadt: a.stadt, gemeinde: a.gemeinde,
            getauft_am: a.getauft_am, verheiratet_am: a.verheiratet_am, telefon: a.telefon,
            kontakt_email: a.kontakt_email, facebook: a.facebook, instagram: a.instagram,
            angelegt_aus: "zugangsanfrage",
          },
        });
      }
      await admin.from("registrierungs_anfragen").update({ status: "bestaetigt" }).eq("id", a.id);

      try {
        const inner = `<p>${esc(T(sprache, "ok_body"))}</p>
          <div style="text-align:center;margin:24px 0;">
            <a href="${setPasswortUrl}" style="display:inline-block;background:#7a2a2a;color:#fff;
              text-decoration:none;padding:12px 26px;border-radius:8px;">${esc(T(sprache, "ok_btn"))}</a></div>`;
        await sendMail(a.email, T(sprache, "ok_subject"), WRAP(inner));
      } catch (mailErr) { console.error("Mail (bestaetigen) fehlgeschlagen:", mailErr); mailWarnung = String(mailErr); }
    } else {
      await admin.from("registrierungs_anfragen").update({ status: "abgelehnt" }).eq("id", a.id);
      try {
        await sendMail(a.email, T(sprache, "no_subject"), WRAP(`<p>${esc(T(sprache, "no_body"))}</p>`));
      } catch (mailErr) { console.error("Mail (ablehnen) fehlgeschlagen:", mailErr); mailWarnung = String(mailErr); }
    }

    // Protokoll (fehlertolerant)
    try {
      await admin.from("anfrage_log").insert({
        anfrage_id: a.id, email: a.email, familie_id: a.familie_id,
        aktion: aktion === "bestaetigen" ? "bestaetigt" : "abgelehnt", entschieden_von: user.id,
      });
    } catch (logErr) { console.error("anfrage_log fehlgeschlagen:", logErr); }

    return json({ ok: true, status: aktion === "bestaetigen" ? "bestaetigt" : "abgelehnt", mail_warnung: mailWarnung });
  } catch (e) {
    console.error("anfrage-bearbeiten Fehler:", e);
    return json({ error: String(e) }, 500);
  }
});
