// Edge Function: anfrage-entscheiden  (selbst-enthaltend – für Dashboard-Editor)
// ÖFFENTLICH – im Dashboard "Verify JWT" für diese Function AUSschalten!
// Aufruf über den Link in der Admin-Mail:
//   .../anfrage-entscheiden?token=<uuid>&aktion=bestaetigen|ablehnen

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "Vidović AI <onboarding@resend.dev>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://vidovicm20889.github.io/Stammbaum/stammbaum.html";

// ---------------------------------------------------------------------------
// Mehrsprachige Texte
// ---------------------------------------------------------------------------
const TEXTE: Record<string, Record<string, string>> = {
  de: {
    ok_subject: "Dein Zugang wurde bestätigt – Vidović AI",
    ok_body: "Deine Zugangsanfrage wurde bestätigt. Klicke auf den folgenden Link, um dein Passwort zu setzen und dich anzumelden:",
    ok_btn: "Passwort setzen",
    no_subject: "Deine Zugangsanfrage – Vidović AI",
    no_body: "Deine Zugangsanfrage wurde leider abgelehnt. Bei Fragen wende dich bitte an deinen Familien-Administrator.",
    page_ok: "Sie haben die Anfrage bestätigt. Die Person wurde per E-Mail benachrichtigt und erhält einen Link zum Passwort-Setzen.",
    page_no: "Sie haben die Anfrage abgelehnt. Die Person wurde per E-Mail benachrichtigt.",
    page_done: "Diese Anfrage wurde bereits bearbeitet.",
    page_err: "Es ist ein Fehler aufgetreten. Bitte später erneut versuchen.",
  },
  sr: {
    ok_subject: "Твој приступ је потврђен – Vidović AI",
    ok_body: "Твој захтев за приступ је потврђен. Кликни на следећи линк да поставиш лозинку и пријавиш се:",
    ok_btn: "Постави лозинку",
    no_subject: "Твој захтев за приступ – Vidović AI",
    no_body: "Твој захтев за приступ је нажалост одбијен. За питања се обрати админу породице.",
    page_ok: "Потврдили сте захтев. Особа је обавештена имејлом и добија линк за постављање лозинке.",
    page_no: "Одбили сте захтев. Особа је обавештена имејлом.",
    page_done: "Овај захтев је већ обрађен.",
    page_err: "Дошло је до грешке. Покушај поново касније.",
  },
  hr: {
    ok_subject: "Tvoj pristup je potvrđen – Vidović AI",
    ok_body: "Tvoj zahtjev za pristup je potvrđen. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
    ok_btn: "Postavi lozinku",
    no_subject: "Tvoj zahtjev za pristup – Vidović AI",
    no_body: "Tvoj zahtjev za pristup nažalost je odbijen. Za pitanja se obrati administratoru obitelji.",
    page_ok: "Potvrdili ste zahtjev. Osoba je obaviještena e-mailom i dobiva link za postavljanje lozinke.",
    page_no: "Odbili ste zahtjev. Osoba je obaviještena e-mailom.",
    page_done: "Ovaj zahtjev je već obrađen.",
    page_err: "Došlo je do greške. Pokušaj ponovno kasnije.",
  },
  ba: {
    ok_subject: "Tvoj pristup je potvrđen – Vidović AI",
    ok_body: "Tvoj zahtjev za pristup je potvrđen. Klikni na sljedeći link da postaviš lozinku i prijaviš se:",
    ok_btn: "Postavi lozinku",
    no_subject: "Tvoj zahtjev za pristup – Vidović AI",
    no_body: "Tvoj zahtjev za pristup nažalost je odbijen. Za pitanja se obrati administratoru porodice.",
    page_ok: "Potvrdili ste zahtjev. Osoba je obaviještena e-mailom i dobiva link za postavljanje lozinke.",
    page_no: "Odbili ste zahtjev. Osoba je obaviještena e-mailom.",
    page_done: "Ovaj zahtjev je već obrađen.",
    page_err: "Došlo je do greške. Pokušaj ponovo kasnije.",
  },
  en: {
    ok_subject: "Your access was approved – Vidović AI",
    ok_body: "Your access request has been approved. Click the link below to set your password and sign in:",
    ok_btn: "Set password",
    no_subject: "Your access request – Vidović AI",
    no_body: "Your access request was unfortunately rejected. If you have questions, please contact your family administrator.",
    page_ok: "You approved the request. The person has been notified by email and receives a link to set their password.",
    page_no: "You rejected the request. The person has been notified by email.",
    page_done: "This request has already been processed.",
    page_err: "An error occurred. Please try again later.",
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

const ergebnisSeite = (sprache: string, key: string, ok = true) =>
  `<!doctype html><html lang="${sprache}"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Vidović AI</title></head>
    <body style="font-family:Georgia,serif;background:#2c2418;color:#f6f1e7;
      display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0;padding:20px;">
      <div style="background:#f6f1e7;color:#2c2418;max-width:420px;padding:32px;border-radius:16px;text-align:center;">
        <h2 style="color:#7a2a2a;margin-top:0;">Vidović AI</h2>
        <p style="font-size:16px;color:${ok ? "#2e7d32" : "#9b2226"};">${esc(T(sprache, key))}</p>
      </div></body></html>`;

// ---------------------------------------------------------------------------
const htmlResp = (body: string, status = 200) =>
  new Response(body, { status, headers: { "Content-Type": "text/html; charset=utf-8" } });

async function sendMail(to: string, subject: string, html: string) {
  // TEST-Modus: wenn TEST_EMAIL gesetzt ist, gehen alle Mails dorthin
  // (Resend-Testbeschränkung ohne verifizierte Domain). In Produktion löschen.
  const empfaenger = Deno.env.get("TEST_EMAIL") || to;
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: MAIL_FROM, to: empfaenger, subject, html }),
  });
  if (!r.ok) console.error("Resend-Fehler:", await r.text());
}

Deno.serve(async (req) => {
  const url    = new URL(req.url);
  const token  = url.searchParams.get("token") ?? "";
  const aktion = url.searchParams.get("aktion") ?? "";
  const admin  = createClient(SUPABASE_URL, SERVICE_KEY);

  const { data: a } = await admin
    .from("registrierungs_anfragen").select("*").eq("token", token).single();

  if (!a) return htmlResp(ergebnisSeite("de", "page_err", false), 404);
  const sprache = a.sprache ?? "de";
  if (a.status !== "offen") return htmlResp(ergebnisSeite(sprache, "page_done", false));

  try {
    if (aktion === "bestaetigen") {
      const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
        type: "invite", email: a.email, options: { redirectTo: APP_URL },
      });
      if (linkErr) throw linkErr;
      const userId = linkData.user?.id;
      const setPasswortUrl = linkData.properties?.action_link ?? APP_URL;

      if (userId) {
        await admin.from("mitgliedschaften").insert({
          user_id: userId, familie_id: a.familie_id, rolle: a.rolle,
        });
      }

      if (a.vorname || a.nachname) {
        await admin.from("personen").insert({
          familie_id:   a.familie_id,
          vorname:      a.vorname ?? "",
          nachname:     a.nachname ?? "",
          geburtsdatum: a.geburtsdatum ?? null,
          stammbaum_daten: {
            geburtsort: a.geburtsort, geburtsland: a.geburtsland,
            stadt: a.stadt, gemeinde: a.gemeinde,
            getauft_am: a.getauft_am, verheiratet_am: a.verheiratet_am,
            telefon: a.telefon, kontakt_email: a.kontakt_email,
            facebook: a.facebook, instagram: a.instagram,
            angelegt_aus: "zugangsanfrage",
          },
        });
      }

      await admin.from("registrierungs_anfragen")
        .update({ status: "bestaetigt" }).eq("id", a.id);

      const inner = `
        <p>${esc(T(sprache, "ok_body"))}</p>
        <div style="text-align:center;margin:24px 0;">
          <a href="${setPasswortUrl}" style="display:inline-block;background:#7a2a2a;color:#fff;
            text-decoration:none;padding:12px 26px;border-radius:8px;">${esc(T(sprache, "ok_btn"))}</a>
        </div>`;
      await sendMail(a.email, T(sprache, "ok_subject"), WRAP(inner));

      return htmlResp(ergebnisSeite(sprache, "page_ok", true));
    }

    if (aktion === "ablehnen") {
      await admin.from("registrierungs_anfragen")
        .update({ status: "abgelehnt" }).eq("id", a.id);
      await sendMail(a.email, T(sprache, "no_subject"),
        WRAP(`<p>${esc(T(sprache, "no_body"))}</p>`));
      return htmlResp(ergebnisSeite(sprache, "page_no", false));
    }

    return htmlResp(ergebnisSeite(sprache, "page_err", false), 400);
  } catch (e) {
    console.error("Entscheidung fehlgeschlagen:", e);
    return htmlResp(ergebnisSeite(sprache, "page_err", false), 500);
  }
});
