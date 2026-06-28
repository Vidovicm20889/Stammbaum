// Edge Function: event-einladung-senden  (selbst-enthaltend – für Dashboard-Editor)
// Wird vom Frontend NACH dem Speichern der Event-Teilnehmer aufgerufen, mit der Liste
// der NEU eingeladenen Konten (aus der RPC event_einladung_benachrichtige). Verschickt
// je Empfänger eine Einladungs-Mail per Resend. Den Event-Titel/-Datum/-Ort liest die
// Funktion serverseitig aus der DB (authoritativ); die Empfänger kommen vom Frontend.
//
// Kalender-Anhang (ab v14.11): Bei parsebarem ISO-Datum hängt die Mail eine
// iCalendar-Datei (einladung.ics) an. Mit Uhrzeit = echter Termin (TZID + VTIMEZONE),
// ohne Uhrzeit = Ganztags-Termin. UID = event_id -> Änderung ersetzt den Termin.
// Voraussetzung: supabase_event_kalender.sql (Spalten uhrzeit/ende_uhrzeit/zeitzone).
//
// METHOD:REQUEST (ab v14.12): echte Termin-Einladung mit ORGANIZER + ATTENDEE ->
// Outlook zeigt Annehmen/Ablehnen und aktualisiert bei höherer SEQUENCE den
// vorhandenen Termin (ggf. ohne erneutes Öffnen). Die .ics wird PRO Empfänger gebaut
// (ATTENDEE = dieser Empfänger). RSVP-Antworten gehen an ORGANIZER_EMAIL (aus MAIL_FROM
// abgeleitet); sie landen im Postfach von MAIL_FROM (support@vidovic-ai.com), sofern dort
// Posteingang eingerichtet ist (kein eigenes Inbound-Handling in der Function).
//
// Kalender-UPDATE (ab v14.12): Body-Feld aktualisierung=true -> Update-Texte
// (subject_update/intro_update). Die SEQUENCE kommt aus events.kalender_seq (steigt
// bei jeder Eventänderung) -> gleiche UID + höhere SEQUENCE aktualisiert den Termin.
// Voraussetzung: supabase_event_kalender_update.sql (kalender_seq + event_einladung_empfaenger).
//
// Body: { event_id: string, empfaenger: [{ email, name?, sprache? }] }
//
// Secrets (wie anfrage-senden): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY,
//   optional MAIL_FROM, APP_URL, TEST_EMAIL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY    = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const MAIL_FROM      = Deno.env.get("MAIL_FROM") ?? "Vidović AI <support@vidovic-ai.com>";
const APP_URL        = Deno.env.get("APP_URL") ?? "https://vidovicm20889.github.io/Stammbaum/stammbaum.html";
// ORGANIZER für die .ics (METHOD:REQUEST). RSVP-Antworten gehen an dieses Postfach
// (support@vidovic-ai.com aus MAIL_FROM); kein eigenes Inbound-Handling in der Function.
const MAIL_FROM_EMAIL = (MAIL_FROM.match(/<([^>]+)>/)?.[1] ?? MAIL_FROM).trim();
const ORGANIZER_EMAIL = (Deno.env.get("ORGANIZER_EMAIL") ?? MAIL_FROM_EMAIL).trim();
const ORGANIZER_NAME  = "Vidović AI";

const TEXTE: Record<string, Record<string, string>> = {
  de: {
    subject: "Einladung zu einem Event – Vidović AI",
    intro: "Du wurdest zu einem Event eingeladen:",
    subject_update: "Aktualisierter Termin – Vidović AI",
    intro_update: "Ein Event wurde aktualisiert. Der Kalender-Anhang aktualisiert deinen Termin:",
    lbl_datum: "Datum", lbl_ort: "Ort",
    btn_app: "App öffnen", hint: "Öffne die App, um das Event zu sehen.",
  },
  sr: {
    subject: "Позивница за догађај – Vidović AI",
    intro: "Позван/а си на догађај:",
    subject_update: "Ажуриран термин – Vidović AI",
    intro_update: "Догађај је ажуриран. Прилог за календар ажурира твој термин:",
    lbl_datum: "Датум", lbl_ort: "Место",
    btn_app: "Отвори апликацију", hint: "Отвори апликацију да видиш догађај.",
  },
  hr: {
    subject: "Pozivnica za događaj – Vidović AI",
    intro: "Pozvan/a si na događaj:",
    subject_update: "Ažuriran termin – Vidović AI",
    intro_update: "Događaj je ažuriran. Privitak za kalendar ažurira tvoj termin:",
    lbl_datum: "Datum", lbl_ort: "Mjesto",
    btn_app: "Otvori aplikaciju", hint: "Otvori aplikaciju da vidiš događaj.",
  },
  ba: {
    subject: "Pozivnica za događaj – Vidović AI",
    intro: "Pozvan/a si na događaj:",
    subject_update: "Ažuriran termin – Vidović AI",
    intro_update: "Događaj je ažuriran. Prilog za kalendar ažurira tvoj termin:",
    lbl_datum: "Datum", lbl_ort: "Mjesto",
    btn_app: "Otvori aplikaciju", hint: "Otvori aplikaciju da vidiš događaj.",
  },
  en: {
    subject: "Invitation to an event – Vidović AI",
    intro: "You have been invited to an event:",
    subject_update: "Updated appointment – Vidović AI",
    intro_update: "An event has been updated. The calendar attachment updates your appointment:",
    lbl_datum: "Date", lbl_ort: "Place",
    btn_app: "Open app", hint: "Open the app to view the event.",
  },
};
const T = (sprache: string, key: string) =>
  (TEXTE[sprache] ?? TEXTE.de)[key] ?? TEXTE.de[key] ?? key;

const esc = (v: unknown) => String(v ?? "")
  .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

// ---- iCalendar (.ics) Helfer ----------------------------------------------
// Reiner Text, von Hand gebaut (keine Library). METHOD:PUBLISH -> Mail-Clients
// (Outlook/Apple/Google) bieten "Zum Kalender hinzufügen". UID = event_id ->
// spätere Änderungen ersetzen den Termin statt zu duplizieren.

// ICS-Textwert escapen (RFC 5545): \ ; , und Zeilenumbruch.
const icsEsc = (v: unknown) => String(v ?? "")
  .replaceAll("\\", "\\\\").replaceAll(";", "\\;").replaceAll(",", "\\,")
  .replace(/\r\n|\r|\n/g, "\\n");

// Zeilen auf 75 Oktette falten (RFC 5545), Fortsetzung mit Leerzeichen.
const icsFold = (line: string): string => {
  const enc = new TextEncoder();
  if (enc.encode(line).length <= 75) return line;
  let out = "", cur = "", curBytes = 0, first = true;
  for (const ch of line) {
    const chBytes = enc.encode(ch).length;
    const limit = first ? 75 : 74; // Fortsetzungszeilen haben 1 führendes Leerzeichen
    if (curBytes + chBytes > limit) {
      out += (out ? "\r\n " : "") + cur;
      cur = ch; curBytes = chBytes; first = false;
    } else { cur += ch; curBytes += chBytes; }
  }
  out += (out ? "\r\n " : "") + cur;
  return out;
};

// "2026-08-15" + "18:00" -> {y,m,d,h,min}; Zeit optional.
const parseDatumZeit = (datum: string, zeit?: string | null) => {
  const md = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(datum ?? "").trim());
  if (!md) return null;
  let h = 0, min = 0, hatZeit = false;
  if (zeit) {
    const mt = /^(\d{1,2}):(\d{2})/.exec(String(zeit).trim());
    if (mt) { h = +mt[1]; min = +mt[2]; hatZeit = true; }
  }
  return { y: +md[1], m: +md[2], d: +md[3], h, min, hatZeit };
};
const pad = (n: number) => String(n).padStart(2, "0");
const dateStamp = (y: number, m: number, d: number) => `${y}${pad(m)}${pad(d)}`;
const dateTimeStamp = (p: { y: number; m: number; d: number; h: number; min: number }) =>
  `${p.y}${pad(p.m)}${pad(p.d)}T${pad(p.h)}${pad(p.min)}00`;

// Wandgenaue Arithmetik (Tages-/Stundenüberlauf) über UTC, zeitzonen-neutral.
const addStunden = (p: { y: number; m: number; d: number; h: number; min: number }, std: number) => {
  const dt = new Date(Date.UTC(p.y, p.m - 1, p.d, p.h, p.min));
  dt.setUTCHours(dt.getUTCHours() + std);
  return { y: dt.getUTCFullYear(), m: dt.getUTCMonth() + 1, d: dt.getUTCDate(),
           h: dt.getUTCHours(), min: dt.getUTCMinutes() };
};
const addTage = (y: number, m: number, d: number, tage: number) => {
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + tage);
  return { y: dt.getUTCFullYear(), m: dt.getUTCMonth() + 1, d: dt.getUTCDate() };
};

// VTIMEZONE-Block für CET/CEST-Zonen (Belgrade/Vienna/Zurich/Berlin teilen die
// EU-DST-Regeln). UTC braucht keinen Block (Z-Suffix).
const vtimezone = (tzid: string) => [
  "BEGIN:VTIMEZONE", `TZID:${tzid}`,
  "BEGIN:DAYLIGHT", "TZOFFSETFROM:+0100", "TZOFFSETTO:+0200", "TZNAME:CEST",
  "DTSTART:19700329T020000", "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU", "END:DAYLIGHT",
  "BEGIN:STANDARD", "TZOFFSETFROM:+0200", "TZOFFSETTO:+0100", "TZNAME:CET",
  "DTSTART:19701025T030000", "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU", "END:STANDARD",
  "END:VTIMEZONE",
];

const dtstampNow = () => {
  const d = new Date();
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T` +
         `${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}Z`;
};

// CN-Parameterwert für ORGANIZER/ATTENDEE (immer in Anführungszeichen, RFC 5545).
const cnParam = (name?: string | null) =>
  `CN="${String(name ?? "").replace(/["\r\n]/g, " ").trim()}"`;

// Baut die komplette .ics oder null (wenn das Datum nicht parsebar ist).
// opts.attendee = Empfänger (für METHOD:REQUEST -> Outlook zeigt Annehmen/Ablehnen
// und aktualisiert bei höherer SEQUENCE den vorhandenen Termin).
function baueIcs(ev: {
  id: string; titel: string; beschreibung?: string | null; datum?: string | null;
  ort?: string | null; uhrzeit?: string | null; ende_uhrzeit?: string | null;
  zeitzone?: string | null; latitude?: number | null; longitude?: number | null;
  kalender_seq?: number | null;
}, appUrl: string, opts: { attendee?: { email: string; name?: string } } = {}): string | null {
  const start = parseDatumZeit(ev.datum ?? "", ev.uhrzeit);
  if (!start) return null; // Freitext-Datum -> kein Kalender-Anhang

  const tz = (ev.zeitzone || "Europe/Belgrade").trim();
  const istUtc = tz.toUpperCase() === "UTC";
  const lines: string[] = [
    "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Vidovic AI//Stammbaum//DE",
    "CALSCALE:GREGORIAN", "METHOD:REQUEST",
  ];

  let dtStart: string, dtEnd: string;
  if (start.hatZeit) {
    if (!istUtc) lines.push(...vtimezone(tz));
    const ende = parseDatumZeit(ev.datum ?? "", ev.ende_uhrzeit);
    let endP: { y: number; m: number; d: number; h: number; min: number };
    if (ende && ende.hatZeit) {
      endP = { y: ende.y, m: ende.m, d: ende.d, h: ende.h, min: ende.min };
      // Ende <= Start -> als über Mitternacht werten (+1 Tag)
      const sMin = start.h * 60 + start.min, eMin = endP.h * 60 + endP.min;
      if (eMin <= sMin) { const nx = addTage(endP.y, endP.m, endP.d, 1); endP = { ...nx, h: endP.h, min: endP.min }; }
    } else {
      endP = addStunden(start, 1);
    }
    if (istUtc) {
      dtStart = `DTSTART:${dateTimeStamp(start)}Z`;
      dtEnd   = `DTEND:${dateTimeStamp(endP)}Z`;
    } else {
      dtStart = `DTSTART;TZID=${tz}:${dateTimeStamp(start)}`;
      dtEnd   = `DTEND;TZID=${tz}:${dateTimeStamp(endP)}`;
    }
  } else {
    // Ganztags-Termin: DTEND ist exklusiv -> nächster Tag.
    const nx = addTage(start.y, start.m, start.d, 1);
    dtStart = `DTSTART;VALUE=DATE:${dateStamp(start.y, start.m, start.d)}`;
    dtEnd   = `DTEND;VALUE=DATE:${dateStamp(nx.y, nx.m, nx.d)}`;
  }

  const beschr = [String(ev.beschreibung ?? "").trim(), appUrl].filter(Boolean).join("\n\n");
  lines.push(
    "BEGIN:VEVENT",
    `UID:${ev.id}@vidovic-ai`,
    `DTSTAMP:${dtstampNow()}`,
    `SEQUENCE:${Math.max(0, Number(ev.kalender_seq) || 0)}`,
    dtStart, dtEnd,
    icsFold(`SUMMARY:${icsEsc(ev.titel)}`),
  );
  if (beschr) lines.push(icsFold(`DESCRIPTION:${icsEsc(beschr)}`));
  if (ev.ort) lines.push(icsFold(`LOCATION:${icsEsc(ev.ort)}`));
  if (typeof ev.latitude === "number" && typeof ev.longitude === "number") {
    lines.push(`GEO:${ev.latitude};${ev.longitude}`);
  }
  // METHOD:REQUEST braucht ORGANIZER + ATTENDEE, damit Outlook RSVP/Update erkennt.
  lines.push(icsFold(`ORGANIZER;${cnParam(ORGANIZER_NAME)}:mailto:${ORGANIZER_EMAIL}`));
  if (opts.attendee?.email) {
    lines.push(icsFold(
      `ATTENDEE;${cnParam(opts.attendee.name || opts.attendee.email)};ROLE=REQ-PARTICIPANT;` +
      `PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:${opts.attendee.email}`));
  }
  lines.push("STATUS:CONFIRMED");
  lines.push("END:VEVENT", "END:VCALENDAR");
  return lines.join("\r\n");
}

// UTF-8-sichere base64-Kodierung (für Resend-Attachment).
const toBase64 = (s: string) => {
  const bytes = new TextEncoder().encode(s);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
};

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
    const { event_id, empfaenger, aktualisierung } = await req.json() as
      { event_id: string; empfaenger: Empf[]; aktualisierung?: boolean };
    if (!event_id) return json({ error: "event_id fehlt" }, 400);
    const liste = (empfaenger ?? []).filter((e) => e && e.email);
    if (liste.length === 0) return json({ ok: true, gesendet: 0, info: "keine Empfänger" });

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Event-Daten authoritativ aus der DB (Titel/Datum/Ort/Zeit/Geo für die .ics)
    const { data: ev, error } = await admin
      .from("events")
      .select("titel, datum, ort, beschreibung, uhrzeit, ende_uhrzeit, zeitzone, latitude, longitude, kalender_seq")
      .eq("id", event_id).single();
    if (error || !ev) return json({ error: "Event nicht gefunden" }, 404);

    const appUrl = APP_URL + (APP_URL.includes("?") ? "&" : "?") + "event=" + event_id;
    const testEmail = Deno.env.get("TEST_EMAIL");

    // Datum + optionale Uhrzeit für die Mail-Anzeige (rein kosmetisch).
    const datumAnzeige = ev.datum
      ? ev.datum + (ev.uhrzeit ? " " + ev.uhrzeit + (ev.ende_uhrzeit ? "–" + ev.ende_uhrzeit : "") : "")
      : "";

    let gesendet = 0;
    const fehler: string[] = [];
    for (const e of liste) {
      const sprache = e.sprache ?? "de";
      const to = testEmail ? [testEmail] : [e.email];
      // Kalender-Anhang pro Empfänger (METHOD:REQUEST -> ATTENDEE = dieser Empfänger).
      const icsR = baueIcs({ id: event_id, ...ev } as any, appUrl,
        { attendee: { email: e.email, name: e.name } });
      const attachments = icsR
        ? [{ filename: "einladung.ics", content: toBase64(icsR),
             content_type: "text/calendar; method=REQUEST; charset=utf-8" }]
        : undefined;
      const introKey   = aktualisierung ? "intro_update"   : "intro";
      const subjectKey = aktualisierung ? "subject_update" : "subject";
      const inner = `
        <p>${esc(e.name ? e.name + "," : "")}</p>
        <p>${esc(T(sprache, introKey))}</p>
        <h3 style="color:#7a2a2a;margin:8px 0 12px;">${esc(ev.titel)}</h3>
        <table style="font-size:14px;border-collapse:collapse;margin:0 0 18px;">
          ${zeile(T(sprache, "lbl_datum"), datumAnzeige)}
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
          subject: T(sprache, subjectKey), html: WRAP(inner),
          ...(attachments ? { attachments } : {}),
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
