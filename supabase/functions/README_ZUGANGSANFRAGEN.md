# Zugangsanfragen – Phase 2 (Edge Functions + Resend-E-Mails)

Zwei Edge Functions für den „Account anlegen"-Flow:

| Function | Zweck | Verify JWT |
|---|---|---|
| `anfrage-senden` | Nach Absenden einer Anfrage: E-Mail an Admins mit Bestätigen/Ablehnen-Links | **AN** (Standard) |
| `anfrage-entscheiden` | Link aus der Mail: legt User+Mitgliedschaft+Person an, Zu-/Absage-Mail | **AUS** |

Beide Dateien (`*/index.ts`) sind **selbst-enthaltend** (Vorlagen eingebettet) –
also direkt im Dashboard-Editor einfügbar.

---

## Weg A — Über das Dashboard (Browser) — empfohlen bei Firewall/Citrix

### 1. SQL ausführen (SQL Editor)
- `supabase_registrierung_setup.sql` (Tabelle + Familien-RPC) – erledigt
- `supabase_registrierung_phase2.sql` (`admin_emails_fuer_familie`) – erledigt

### 2. Auth → URL Configuration → Redirect URLs
App-URL eingetragen – erledigt.

### 3. Secrets eintragen
Dashboard → **Project Settings → Edge Functions → Secrets** (bzw. **Edge Functions → Secrets**):
füge drei Secrets hinzu (Werte aus `supabase/.env`):
| Name | Wert |
|---|---|
| `RESEND_API_KEY` | dein `re_...` Key |
| `MAIL_FROM` | `Stammbaum Vidović <onboarding@resend.dev>` |
| `APP_URL` | `https://vidovicm20889.github.io/Stammbaum/stammbaum.html` |

> `SUPABASE_URL` und `SUPABASE_SERVICE_ROLE_KEY` sind automatisch vorhanden.

### 4. Function `anfrage-senden` anlegen
Dashboard → **Edge Functions → Create a new function** (oder „Via Editor"):
- Name exakt: `anfrage-senden`
- Den **kompletten** Inhalt von [anfrage-senden/index.ts](anfrage-senden/index.ts) in den Editor einfügen.
- **Deploy** klicken. „Verify JWT" bleibt **an** (Standard).

### 5. Function `anfrage-entscheiden` anlegen
- Name exakt: `anfrage-entscheiden`
- Inhalt von [anfrage-entscheiden/index.ts](anfrage-entscheiden/index.ts) einfügen.
- In den **Function-Settings „Verify JWT" AUSschalten** (der Link wird aus der
  E-Mail ohne Key geöffnet). 
- **Deploy**.

### 6. Testen
App → „Account anlegen" → absenden → Admin-Mail kommt → Bestätigen → Passwort-Link.
Logs im Dashboard unter der jeweiligen Function → **Logs**.

---

## Weg B — Über die CLI (nur in nicht-gesperrtem Netz)

```bash
supabase login
supabase link --project-ref tybvzhifvufgvlgjpmyl
supabase secrets set --env-file supabase/.env
supabase functions deploy anfrage-senden
supabase functions deploy anfrage-entscheiden --no-verify-jwt
```
> Scheitert in Firmen-/Citrix-Netzen oft mit `TransportError` (Firewall blockt die CLI).
> Dann Weg A nutzen oder ein anderes Netz (Handy-Hotspot).

---

## Resend (Voraussetzung für E-Mail-Versand)
- Account auf resend.com, **API-Key** (`re_...`) erstellen → in Secrets als `RESEND_API_KEY`.
- **Test:** Absender `onboarding@resend.dev` sendet **nur an deine eigene Resend-Account-Adresse**.
- **Produktiv:** eigene Domain in Resend verifizieren, dann `MAIL_FROM` darauf umstellen.
