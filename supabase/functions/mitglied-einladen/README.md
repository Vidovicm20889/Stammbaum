# Edge Function: `mitglied-einladen`

Ein Admin legt über das Overlay **„Mitglied hinzufügen"** ein neues Mitglied an.
Die Function (Service-Role) erledigt:

1. **Aufrufer prüfen:** Nur eingeloggte Admins, die die gewählte Familie
   verwalten dürfen (`kann_familie_bearbeiten` im JWT-Kontext des Aufrufers).
2. **Benutzer anlegen** (falls neu) via `generateLink type=invite` –
   oder vorhandenen Benutzer per E-Mail finden.
3. **Mitgliedschaft** mit Rolle + Familie anlegen (`aktiv = true`).
4. **Einladungs-Mail** mit Passwort-Link verschicken (neuer Nutzer) bzw.
   Info-Mail (bestehender Nutzer). 5-sprachig.

Erlaubte Rollen über diesen Weg: `familien_mitglied`, `familien_admin`
(kein `super_admin`).

## Deployen (Dashboard)
1. Supabase Dashboard → **Edge Functions** → **Create a new function** → Name
   exakt `mitglied-einladen`.
2. Inhalt von `index.ts` einfügen → **Deploy**.
3. **Verify JWT = ON lassen** (nur eingeloggte Admins dürfen aufrufen).
4. Secrets (dieselben wie bei den anderen Functions):
   `RESEND_API_KEY`, `MAIL_FROM`, `APP_URL`
   (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` sind
   automatisch vorhanden). Optional `TEST_EMAIL` zum Testen.

## Falls „Keine Berechtigung"/PGRST-Fehler beim Rechte-Check
Einmalig im SQL-Editor ausführen:
```sql
GRANT EXECUTE ON FUNCTION public.kann_familie_bearbeiten(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_per_email(text) TO authenticated;
```

## Testen
Eingeloggt als Admin → ☰-Menü → **Admin-Einstellungen → Mitglied hinzufügen**
→ E-Mail + Rolle + Familie → **Hinzufügen**.
Erwartung: „Einladung versendet …", Mail kommt an, neue Zeile in
`mitgliedschaften`, im Overlay „Mitglieder verwalten" taucht das Mitglied auf.
