# Edge Function: `neue-familie-anlegen`

Self-Service-Anlage eines neuen, leeren Stammbaums **ohne** Admin-Freigabe.
Wird vom Registrier-Overlay aufgerufen, wenn der Nutzer bei
„Stammbaum schon vorhanden?" → **Nein** wählt.

## Was sie tut (mit Service-Role)
1. Legt einen Auth-User an + erzeugt einen Invite-/Passwort-Link (`generateLink type=invite`).
2. Legt eine `familien`-Zeile an (eigener `verbund_id` per Default).
3. Legt einen `stammbaeume`-Eintrag an.
4. Legt die erste `personen`-Zeile an (der anlegende Nutzer) und setzt sie als `wurzel_person_id`.
5. Legt die `mitgliedschaften`-Zeile als `familien_admin` (aktiv) an.
6. Verschickt die Einladungs-Mail zum Passwort-Setzen (Resend, 5-sprachig).

## Deployen
> Aktueller Weg für Prod: `deploy-manager` über `node scripts/deploy_functions.mjs --name
> neue-familie-anlegen --confirm` (seit 2026-08-06 — die frühere Citrix-Begründung unten war
> veraltet). Die folgenden Dashboard-Schritte bleiben als manueller Fallback gültig.
1. Supabase Dashboard → **Edge Functions** → **Create a new function** → Name exakt
   `neue-familie-anlegen`.
2. Inhalt von `index.ts` komplett einfügen → **Deploy**.
3. **WICHTIG:** Function-Settings → **Verify JWT = OFF**
   (der Nutzer ist beim Anlegen noch nicht eingeloggt).
4. Secrets (Project → Settings → Edge Functions) müssen gesetzt sein – dieselben
   wie bei `anfrage-entscheiden`:
   - `RESEND_API_KEY`
   - `MAIL_FROM` (z. B. `Stammbaum Vidović <noreply@familyroots.club>`)
   - `APP_URL` (`https://familyroots.club/stammbaum.html`)
   - (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` sind automatisch vorhanden)
   - optional `TEST_EMAIL` zum Testen ohne verifizierte Domain.

## Testen
Overlay „Account anlegen" → **Nein** → E-Mail + Familienname → Absenden.
Erwartung: Bestätigung „Stammbaum angelegt …", Einladungs-Mail kommt an,
in Supabase neue Zeilen in `familien`, `stammbaeume`, `personen`, `mitgliedschaften`.
