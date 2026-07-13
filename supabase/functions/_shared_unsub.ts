// ============================================================================
// GETEILTER UNSUB-HELFER  —  in JEDE Versand-Function (die self-contained im
// Dashboard-Editor liegt) hineinkopieren. Erzeugt den signierten Abmelde-Token,
// baut die Abmelde-URL + den E-Mail-Footer und liefert die List-Unsubscribe-Header.
//
// Voraussetzungen in der Ziel-Function:
//   - const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
//   - const UNSUB_SECRET   = Deno.env.get("UNSUBSCRIBE_SECRET") ?? "";
//   - ein esc()-Helfer (HTML-Escape) ist vorhanden (haben alle Functions bereits).
//
// TYP je Mail-Art (muss zur Whitelist in abmelden_anwenden passen):
//   anlaesse-erinnerung      -> "anlaesse"     (Geburtstage + Gedenktage)
//   ungelesen-erinnerung     -> "ungelesen"    (ungelesene Nachrichten + Benachrichtigungen)
//   woechentlicher-digest    -> "email_woechentlicher_digest"
//   (Einzel-Mails ginge auch: "email_geburtstage" / "email_gedenktage" / …)
// ============================================================================

const _unsubEnc = new TextEncoder();
const _b64urlFromBytes = (b: Uint8Array) =>
  btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const _b64urlFromString = (s: string) => _b64urlFromBytes(_unsubEnc.encode(s));

// Signierten Token bauen: base64url({u,t,e}).base64url(HMAC-SHA256(secret, payload)).
async function makeUnsubToken(userId: string, typ: string, ttlDays = 60): Promise<string> {
  const exp = Math.floor(Date.now() / 1000) + ttlDays * 86400;
  const payloadB64 = _b64urlFromString(JSON.stringify({ u: userId, t: typ, e: exp }));
  const key = await crypto.subtle.importKey(
    "raw", _unsubEnc.encode(UNSUB_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, _unsubEnc.encode(payloadB64)));
  return payloadB64 + "." + _b64urlFromBytes(sig);
}

function buildUnsubUrl(token: string, lang = "de"): string {
  return `${SUPABASE_URL}/functions/v1/abmelden?token=${encodeURIComponent(token)}&lang=${encodeURIComponent(lang)}`;
}

// Unaufdringlicher Footer: „Diese Benachrichtigungen abbestellen" + „von allen E-Mails abmelden".
const _UNSUB_FOOTER: Record<string, { one: string; all: string }> = {
  de: { one: "Diese Benachrichtigungen abbestellen", all: "von allen E-Mails abmelden" },
  sr: { one: "Одјави се са ових обавештења",           all: "одјави се са свих е-порука" },
  hr: { one: "Odjavi se s ovih obavijesti",            all: "odjavi se sa svih e-poruka" },
  ba: { one: "Odjavi se s ovih obavještenja",          all: "odjavi se sa svih e-poruka" },
  en: { one: "Unsubscribe from these notifications",   all: "unsubscribe from all emails" },
};
function unsubFooterHtml(urlSpecific: string, urlAll: string, lang = "de"): string {
  const x = _UNSUB_FOOTER[lang] ?? _UNSUB_FOOTER.de;
  return `<div style="margin-top:22px;padding-top:14px;border-top:1px solid #e4d8bf;
      font-size:12px;color:#a89878;text-align:center;line-height:1.7;">
    <a href="${urlSpecific}" style="color:#722f37;text-decoration:underline;">${esc(x.one)}</a>
    &nbsp;·&nbsp;
    <a href="${urlAll}" style="color:#a89878;text-decoration:underline;">${esc(x.all)}</a>
  </div>`;
}

// Bequemer Rundum-Helfer: liefert Footer-HTML + fertige Mail-Header für den Versand.
async function unsubBundle(userId: string, typ: string, lang = "de"): Promise<{
  footer: string; headers: Record<string, string>;
}> {
  const tokSpecific = await makeUnsubToken(userId, typ);
  const tokAlle     = await makeUnsubToken(userId, "alle");
  const urlSpecific = buildUnsubUrl(tokSpecific, lang);
  const urlAlle     = buildUnsubUrl(tokAlle, lang);
  return {
    footer: unsubFooterHtml(urlSpecific, urlAlle, lang),
    headers: {
      // RFC 8058: HTTPS-URL (One-Click) + mailto-Fallback.
      "List-Unsubscribe": `<${urlSpecific}>, <mailto:support@familyroots.club?subject=Abmelden>`,
      "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
    },
  };
}

export { makeUnsubToken, buildUnsubUrl, unsubFooterHtml, unsubBundle };
