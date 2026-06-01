// Edge Function: anfrage-senden  (selbst-enthaltend – für Dashboard-Editor)
// Wird vom Frontend nach dem Speichern einer Anfrage aufgerufen.
// Lädt die Anfrage, ermittelt die Admin-Empfänger und verschickt per Resend
// die Benachrichtigungs-Mail mit Bestätigen-/Ablehnen-Links.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "Stammbaum Vidović <onboarding@resend.dev>";

// ---------------------------------------------------------------------------
// Mehrsprachige Texte
// ---------------------------------------------------------------------------
const TEXTE: Record<string, Record<string, string>> = {
  de: {
    admin_subject: "Neue Zugangsanfrage – Stammbaum Vidović",
    admin_intro: "Eine Person möchte Zugang zum Stammbaum Vidović:",
    lbl_email: "E-Mail", lbl_familie: "Familie", lbl_rolle: "Gewünschte Rolle",
    btn_ok: "Bestätigen", btn_no: "Ablehnen",
    admin_hint: "Bei Bestätigung wird ein Zugang angelegt; die Person erhält eine E-Mail zum Passwort-Setzen. Bei Ablehnung wird die Anfrage storniert.",
    rolle_familien_admin: "Familien-Admin", rolle_familien_mitglied: "Mitglied",
  },
  sr: {
    admin_subject: "Нови захтев за приступ – Стабло Видовић",
    admin_intro: "Особа жели приступ стаблу Видовић:",
    lbl_email: "Имејл", lbl_familie: "Породица", lbl_rolle: "Жељена улога",
    btn_ok: "Потврди", btn_no: "Одбиј",
    admin_hint: "Након потврде се креира налог; особа добија имејл за постављање лозинке. Након одбијања захтев се поништава.",
    rolle_familien_admin: "Админ породице", rolle_familien_mitglied: "Члан",
  },
  hr: {
    admin_subject: "Novi zahtjev za pristup – Stablo Vidović",
    admin_intro: "Osoba želi pristup stablu Vidović:",
    lbl_email: "E-mail", lbl_familie: "Obitelj", lbl_rolle: "Željena uloga",
    btn_ok: "Potvrdi", btn_no: "Odbij",
    admin_hint: "Nakon potvrde kreira se pristup; osoba dobiva e-mail za postavljanje lozinke. Nakon odbijanja zahtjev se poništava.",
    rolle_familien_admin: "Admin obitelji", rolle_familien_mitglied: "Član",
  },
  ba: {
    admin_subject: "Novi zahtjev za pristup – Stablo Vidović",
    admin_intro: "Osoba želi pristup stablu Vidović:",
    lbl_email: "E-mail", lbl_familie: "Porodica", lbl_rolle: "Željena uloga",
    btn_ok: "Potvrdi", btn_no: "Odbij",
    admin_hint: "Nakon potvrde kreira se pristup; osoba dobiva e-mail za postavljanje lozinke. Nakon odbijanja zahtjev se poništava.",
    rolle_familien_admin: "Admin porodice", rolle_familien_mitglied: "Član",
  },
  en: {
    admin_subject: "New access request – Vidović Family Tree",
    admin_intro: "Someone is requesting access to the Vidović family tree:",
    lbl_email: "Email", lbl_familie: "Family", lbl_rolle: "Requested role",
    btn_ok: "Approve", btn_no: "Reject",
    admin_hint: "On approval an account is created and the person receives an email to set their password. On rejection the request is cancelled.",
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
  <h2 style="color:#7a2a2a;margin:0 0 16px;">Stammbaum Vidović</h2>
  ${inner}
  <p style="margin-top:26px;font-size:12px;color:#8a7a5a;">vidovicm20889.github.io/Stammbaum</p>
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

    const base  = `${SUPABASE_URL}/functions/v1/anfrage-entscheiden?token=${a.token}`;
    const okUrl = `${base}&aktion=bestaetigen`;
    const noUrl = `${base}&aktion=ablehnen`;
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
        <a href="${okUrl}" style="display:inline-block;background:#2e7d32;color:#fff;
          text-decoration:none;padding:12px 26px;border-radius:8px;margin:4px;">${esc(T(sprache, "btn_ok"))}</a>
        <a href="${noUrl}" style="display:inline-block;background:#9b2226;color:#fff;
          text-decoration:none;padding:12px 26px;border-radius:8px;margin:4px;">${esc(T(sprache, "btn_no"))}</a>
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
