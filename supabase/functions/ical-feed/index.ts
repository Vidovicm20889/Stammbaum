// Edge Function: ical-feed  (selbst-enthaltend – für Dashboard-Editor)
// Abonnierbarer Kalender-Feed (webcal/iCal). Aufruf: GET .../ical-feed?token=<uuid>
// Liefert ein VCALENDAR mit allen für den Token-Inhaber sichtbaren, DATIERTEN Events.
//
// Sicherheit: das Token (profile.ical_token) identifiziert das Konto; die Sichtbarkeit
// wird serverseitig in der RPC ical_feed(p_token) erzwungen (nicht hier). KEIN JWT nötig
// -> im Dashboard für diese Function „Verify JWT" AUS (Kalender-Clients senden keinen Bearer).
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

// ICS-Textescape (Komma, Semikolon, Backslash, Zeilenumbruch).
function esc(s: string): string {
  return String(s ?? "")
    .replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,")
    .replace(/\r?\n/g, "\\n");
}
function dat(iso: string): string { return (iso || "").slice(0, 10).replace(/-/g, ""); }
function zeit(hhmm: string): string { return (hhmm || "").replace(":", "") + "00"; }

function baueVevent(ev: any): string {
  const uid = `${ev.id}@vidovic-stammbaum`;
  const seq = Number.isFinite(ev.kalender_seq) ? ev.kalender_seq : 0;
  const tz  = ev.zeitzone || "Europe/Belgrade";
  const d   = dat(ev.datum);
  let dtstart: string, dtend = "";
  if (ev.uhrzeit) {
    dtstart = `DTSTART;TZID=${tz}:${d}T${zeit(ev.uhrzeit)}`;
    if (ev.ende_uhrzeit) dtend = `DTEND;TZID=${tz}:${d}T${zeit(ev.ende_uhrzeit)}`;
  } else {
    dtstart = `DTSTART;VALUE=DATE:${d}`;   // ganztägig
  }
  const lines = [
    "BEGIN:VEVENT",
    `UID:${uid}`,
    `SEQUENCE:${seq}`,
    `DTSTAMP:${dat(ev.datum)}T000000Z`,
    dtstart,
    dtend,
    `SUMMARY:${esc(ev.titel || "")}`,
    ev.beschreibung ? `DESCRIPTION:${esc(ev.beschreibung)}` : "",
    ev.ort ? `LOCATION:${esc(ev.ort)}` : "",
    "END:VEVENT",
  ].filter(Boolean);
  return lines.join("\r\n");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const url = new URL(req.url);
    const token = (url.searchParams.get("token") || "").trim();
    if (!token) return new Response("token fehlt", { status: 400, headers: CORS });

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data, error } = await admin.rpc("ical_feed", { p_token: token });
    if (error) return new Response("Fehler", { status: 500, headers: CORS });

    const events = Array.isArray(data) ? data : [];
    const body = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Vidovic//Stammbaum//DE",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH",
      "X-WR-CALNAME:FamilyRoots — Porodični događaji",
      ...events.map(baueVevent),
      "END:VCALENDAR",
    ].join("\r\n");

    return new Response(body, {
      status: 200,
      headers: {
        ...CORS,
        "Content-Type": "text/calendar; charset=utf-8",
        "Content-Disposition": 'inline; filename="vidovic.ics"',
        "Cache-Control": "max-age=900",
      },
    });
  } catch (e) {
    return new Response("Fehler", { status: 500, headers: CORS });
  }
});
