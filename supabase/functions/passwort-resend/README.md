# passwort-resend

Nachversand des „Passwort setzen"-Links an neu registrierte Konten — nötig nach dem
`TEST_EMAIL`-Vorfall (die erste Willkommens-Mail ging an die Testadresse statt an die Nutzer).

Sendet über **Resend** (gleicher Kanal wie `neue-familie-anlegen`), **ohne** `TEST_EMAIL`-Umleitung,
und meldet **jeden Fehler sichtbar** zurück (kein stilles Verschlucken).

## Zielgruppe (Standard)
Konten, die in den **letzten 7 Tagen** registriert wurden **und** sich **noch nie eingeloggt**
haben (= wegen `TEST_EMAIL` ohne Passwort steckengeblieben). Bereits aktive Nutzer werden
standardmäßig übersprungen.

## Deploy (Dashboard)
1. Supabase → **Edge Functions** → **Create function** → Name `passwort-resend` → `index.ts` einfügen → **Deploy**.
2. **Verify JWT: AN** lassen (Aufruf erfolgt mit dem Service-Role-Key).
3. Secrets prüfen (sind i. d. R. schon gesetzt, wie bei `neue-familie-anlegen`):
   `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `MAIL_FROM`, `APP_URL`.
   **`TEST_EMAIL` darf NICHT gesetzt sein** (diese Function ignoriert es ohnehin).

## Aufrufen
Immer mit dem **Service-Role-Key** als Bearer (nicht aus dem Browser!). `<PROJECT>` = deine Projekt-Ref.

**1) Erst DRY-RUN** (zeigt nur, wer eine Mail bekäme + Gesamtzahl):
```bash
curl -X POST "https://<PROJECT>.supabase.co/functions/v1/passwort-resend" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"dry_run":true,"tage":7}'
```

**2) Dann tatsächlich senden** (in Stapeln à 40 gegen Timeouts; `offset` hochzählen, bis
`hinweis` „Alle Kandidaten verarbeitet." meldet):
```bash
curl -X POST "https://<PROJECT>.supabase.co/functions/v1/passwort-resend" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>" -H "Content-Type: application/json" \
  -d '{"tage":7,"limit":40,"offset":0}'
```

**Gezielt an einzelne Adressen** (ignoriert Zeitfenster/Login-Filter):
```bash
curl -X POST "https://<PROJECT>.supabase.co/functions/v1/passwort-resend" \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>" -H "Content-Type: application/json" \
  -d '{"emails":["branko.vasiljevic90@gmail.com"]}'
```

## Body-Parameter (alle optional)
| Feld | Standard | Wirkung |
|------|----------|---------|
| `dry_run` | `false` | nur auflisten, nichts senden |
| `tage` | `7` | Zeitfenster: Registrierung in den letzten N Tagen |
| `nur_ohne_login` | `true` | nur nie eingeloggte Konten (aktive überspringen) |
| `emails` | – | gezielt an diese Adressen (ignoriert `tage`/`nur_ohne_login`) |
| `limit` | `40` | Stapelgröße pro Aufruf (max. 200) |
| `offset` | `0` | Startpunkt für den nächsten Stapel |

## Antwort
- Dry-Run: `{ dry_run, fenster_tage, gesamt_kandidaten, in_diesem_stapel, emails[], hinweis }`
- Echtlauf: `{ ok, gesamt_kandidaten, gesendet, fehlgeschlagen, sent[], failed[{email,error}], hinweis }`

Der Link im Mail ist ein Recovery-Link (`type=recovery`) → führt in die App und öffnet das
Passwort-setzen-Modal (`pruefePasswortSetzen`).
