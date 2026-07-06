// Edge Function: broadcast-info  (selbst-enthaltend – für Dashboard-Editor)
// ===========================================================================
// EINMALIGE Info-Mail an ALLE registrierten Konten — z. B. „FamilyRoots hat eine neue
// Web-Adresse (familyroots.club)". Mehrsprachig (Sprache je Nutzer aus profile).
//
// Ablauf:
//   1) broadcast_empfaenger(KAMPAGNE) -> alle Konten mit E-Mail, die NOCH NICHT gemailt wurden
//      (die Merk-Tabelle broadcast_gesendet verhindert Doppelversand bei erneutem Auslösen).
//   2) In Blöcken zu 100 per Resend-BATCH verschicken (rate-limit-schonend), Sprache je Nutzer.
//   3) broadcast_markiere_gesendet(ids, KAMPAGNE) -> erfolgreich Versandte merken.
//
// TEST-MODUS: Body {"test": true} -> schickt je EINE Vorschau-Mail pro Sprache an TEST_EMAIL
//   und markiert NICHTS (echte Nutzer bleiben unberührt). Ideal zum Korrekturlesen.
//
// AUTH: Aufruf NUR mit Header `x-cron-secret` == Secret CRON_SECRET (wie anlaesse-erinnerung).
//   Empfehlung: im Dashboard für diese Function „Verify JWT" AUS.
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY, CRON_SECRET,
//   optional MAIL_FROM, APP_URL, TEST_EMAIL.
//
// VORAUSSETZUNG: supabase_broadcast_url_info.sql ausgeführt UND Absenderdomain
//   (familyroots.club) in Resend verifiziert (SPF/DKIM), sonst Spam/Ablehnung.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "FamilyRoots <support@familyroots.club>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://familyroots.club/stammbaum.html";
const CRON_SECRET    = Deno.env.get("CRON_SECRET") ?? "";

// Kampagnen-Schlüssel: steuert die Doppelversand-Sperre. Für eine SPÄTERE andere
// Broadcast-Mail einfach einen neuen Schlüssel verwenden.
const KAMPAGNE = "url_familyroots_2026";

const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "FamilyRoots hat eine neue Web-Adresse",
    hallo: "Hallo{name},",
    t1: "unser Familienstammbaum ist ab sofort unter einer neuen, einfacheren Web-Adresse erreichbar:",
    t2: "Bitte aktualisiere dein Lesezeichen. Alte Links funktionieren weiterhin (sie leiten automatisch weiter) — die neue Adresse ist nur kürzer und leichter zu merken.",
    btn: "App öffnen",
    sign: "Herzliche Grüße<br>FamilyRoots",
  },
  sr: {
    subject: "FamilyRoots има нову веб-адресу",
    hallo: "Здраво{name},",
    t1: "наше породично стабло је од сада доступно на новој, једноставнијој веб-адреси:",
    t2: "Молимо ажурирај обележивач (bookmark). Стари линкови и даље раде (аутоматски преусмеравају) — нова адреса је само краћа и лакша за памћење.",
    btn: "Отвори апликацију",
    sign: "Срдачан поздрав<br>FamilyRoots",
  },
  hr: {
    subject: "FamilyRoots ima novu web-adresu",
    hallo: "Bok{name},",
    t1: "naše obiteljsko stablo od sada je dostupno na novoj, jednostavnijoj web-adresi:",
    t2: "Molimo ažuriraj oznaku (bookmark). Stari linkovi i dalje rade (automatski preusmjeravaju) — nova je adresa samo kraća i lakša za pamćenje.",
    btn: "Otvori aplikaciju",
    sign: "Srdačan pozdrav<br>FamilyRoots",
  },
  ba: {
    subject: "FamilyRoots ima novu web-adresu",
    hallo: "Zdravo{name},",
    t1: "naše porodično stablo od sada je dostupno na novoj, jednostavnijoj web-adresi:",
    t2: "Molimo ažuriraj bookmark. Stari linkovi i dalje rade (automatski preusmjeravaju) — nova adresa je samo kraća i lakša za pamćenje.",
    btn: "Otvori aplikaciju",
    sign: "Srdačan pozdrav<br>FamilyRoots",
  },
  en: {
    subject: "FamilyRoots has a new web address",
    hallo: "Hello{name},",
    t1: "our family tree is now available at a new, simpler web address:",
    t2: "Please update your bookmark. Old links keep working (they redirect automatically) — the new address is just shorter and easier to remember.",
    btn: "Open app",
    sign: "Best regards<br>FamilyRoots",
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

// Innerer Mailtext EINER Sprache (ohne WRAP), name optional.
function innerMail(sprache: string, name: string | null) {
  const anrede = T(sprache, "hallo").replace("{name}", name ? " " + name : "");
  return `
    <p>${esc(anrede)}</p>
    <p>${esc(T(sprache, "t1"))}</p>
    <p style="text-align:center;font-size:22px;font-weight:bold;color:#7a2a2a;margin:18px 0;">familyroots.club</p>
    <div style="text-align:center;margin:24px 0;">
      <a href="${APP_URL}" style="display:inline-block;background:#7a2a2a;color:#fff;
        text-decoration:none;padding:12px 28px;border-radius:8px;">${esc(T(sprache, "btn"))}</a>
    </div>
    <p style="font-size:13px;color:#8a7a5a;">${esc(T(sprache, "t2"))}</p>
    <p style="font-size:13px;color:#8a7a5a;">${T(sprache, "sign")}</p>`;
}
// Fertige Mail (mit WRAP) in EINER Sprache — für den Echtversand je Nutzer.
function baueMail(sprache: string, name: string | null) {
  return { subject: T(sprache, "subject"), html: WRAP(innerMail(sprache, name)) };
}

const SPRACHEN = ["de", "sr", "hr", "ba", "en"];
const SPRACH_LABEL: Record<string, string> =
  { de: "Deutsch", sr: "Српски", hr: "Hrvatski", ba: "Bosanski", en: "English" };

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });

// Resend-Batch: bis zu 100 Mails in EINEM API-Call (rate-limit-schonend).
async function resendBatch(mails: Array<{ from: string; to: string[]; subject: string; html: string }>) {
  const r = await fetch("https://api.resend.com/emails/batch", {
    method: "POST",
    headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(mails),
  });
  return { ok: r.ok, text: r.ok ? "" : await r.text() };
}

type Empf = { user_id: string; email: string; name: string | null; sprache: string | null };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const secret = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!CRON_SECRET || secret !== CRON_SECRET) return json({ error: "unauthorized" }, 401);

  let body: { test?: boolean } = {};
  try { body = await req.json(); } catch { /* leerer Body ist ok */ }

  const testEmail = Deno.env.get("TEST_EMAIL");

  try {
    // --- TEST-MODUS: EINE Mail an TEST_EMAIL mit ALLEN 5 Sprachversionen gestapelt, markiert NICHTS ---
    if (body?.test) {
      if (!testEmail) return json({ error: "TEST_EMAIL nicht gesetzt" }, 400);
      const kombiniert = SPRACHEN.map((spr, i) => `
        ${i > 0 ? '<hr style="border:none;border-top:1px solid #d8c9a8;margin:26px 0;">' : ""}
        <p style="font-size:12px;letter-spacing:1px;text-transform:uppercase;color:#9b7d3a;margin:0 0 4px;">${SPRACH_LABEL[spr]}</p>
        ${innerMail(spr, "Test")}`).join("");
      const html = WRAP(`<p style="font-size:13px;color:#8a7a5a;margin-top:0;">Vorschau aller 5 Sprachversionen (Testmail):</p>${kombiniert}`);
      const res = await resendBatch([{
        from: MAIL_FROM, to: [testEmail],
        subject: "[TEST] FamilyRoots – neue Web-Adresse (alle 5 Sprachen)", html,
      }]);
      return json({ ok: res.ok, modus: "test", mails: 1, sprachen: SPRACHEN.length, an: testEmail,
                    fehler: res.ok ? undefined : res.text });
    }

    // --- ECHTVERSAND ---
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data, error } = await admin.rpc("broadcast_empfaenger", { p_kampagne: KAMPAGNE });
    if (error) return json({ error: error.message }, 500);
    const empf = (data ?? []) as Empf[];
    if (empf.length === 0) return json({ ok: true, gesendet: 0, info: "keine offenen Empfänger" });

    let gesendet = 0;
    const fehler: string[] = [];

    // In Blöcken zu 100 (Resend-Batch-Limit) verschicken + je Block sofort markieren.
    for (let i = 0; i < empf.length; i += 100) {
      const block = empf.slice(i, i + 100);
      const mails = block.map((e) => {
        const m = baueMail(e.sprache ?? "de", e.name);
        // Echtlauf geht IMMER an die echte Adresse (Vorschau nur über {"test":true} an TEST_EMAIL)
        // -> kein Footgun, dass bei gesetztem TEST_EMAIL alle als "gesendet" markiert werden.
        return { from: MAIL_FROM, to: [e.email], subject: m.subject, html: m.html };
      });
      const res = await resendBatch(mails);
      if (res.ok) {
        gesendet += block.length;
        const ids = block.map((e) => e.user_id);
        const { error: mErr } = await admin.rpc("broadcast_markiere_gesendet",
          { p_users: ids, p_kampagne: KAMPAGNE });
        if (mErr) console.error("markiere_gesendet:", mErr.message);
      } else {
        fehler.push(res.text);
      }
    }

    return json({ ok: true, empfaenger: empf.length, gesendet,
                  fehler: fehler.length ? fehler : undefined });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
