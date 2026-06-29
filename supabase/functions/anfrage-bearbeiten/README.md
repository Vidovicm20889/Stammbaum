# Edge Function: anfrage-bearbeiten

App-fähige Variante zum Akzeptieren/Ablehnen von Zugangsanfragen direkt aus dem
Obavještenja-Overlay (statt nur über die Links in der Admin-Mail).

POST `{ id: <uuid>, aktion: "bestaetigen" | "ablehnen" }`
→ JSON `{ ok: true, status, mail_warnung }` bzw. `{ error }`.

Macht dasselbe wie `anfrage-entscheiden`, zusätzlich:
- CORS (aus dem Browser per `functions.invoke` aufrufbar)
- prüft, dass der Aufrufer **Super-Admin** oder **Admin/Owner der betroffenen Familie** ist
- protokolliert die Entscheidung in `public.anfrage_log`
- Mail-Versand fehlertolerant (Aktion gilt auch, wenn die Mail scheitert)

## Voraussetzung (DB)
`supabase_obavjestenja.sql` ausführen (RPC `offene_anfragen()` + Tabelle `anfrage_log`).

## Deploy (Supabase-Dashboard, da CLI durch Citrix blockiert)
1. Edge Functions → **Create a new function** → Name exakt `anfrage-bearbeiten`.
2. Inhalt von `index.ts` (dieser Ordner) komplett einfügen → **Deploy**.
3. **Verify JWT: AN lassen** (nur eingeloggte Admins dürfen aufrufen).
4. Secrets (sind durch die anderen Functions i. d. R. schon gesetzt; sonst nachtragen):
   `RESEND_API_KEY`, `MAIL_FROM` (z. B. `FamilyRoots <noreply@vidovic-ai.com>`),
   `APP_URL`. `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`/`SUPABASE_ANON_KEY` stellt
   Supabase automatisch bereit. Optional `TEST_EMAIL` (leitet alle Mails dorthin,
   solange keine eigene Domain bei Resend verifiziert ist).

## Test
Eingeloggt als Admin → ⚙ → Obavještenja → bei einer offenen Anfrage „Akzeptieren"
bzw. „Ablehnen". Karte + Badge verschwinden sofort; die Person erhält eine E-Mail.
