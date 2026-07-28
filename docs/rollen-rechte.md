# Rollen & Rechte

**Status:** verbindlich. Ausgelagert aus `CLAUDE.md` (Token-Entlastung) — Regelrang unverändert.
Die Kurzform (welche vier Rollen es gibt) steht weiterhin in `CLAUDE.md`.

Verwandte Dateien: [profil-konten-mitglieder.md](profil-konten-mitglieder.md) (Mitglieder-Verwaltung,
Konto↔Karte), [baum-struktur-blutlinie.md](baum-struktur-blutlinie.md) (Blutlinien-Kanten).

---

## 1. Die vier Rollen

Rollen liegen in `mitgliedschaften` (`user_id` + `familie_id` + `rolle`).

### `super_admin`
Betrieb/Wartung, Vollzugriff. **In der GUI für normale Nutzer unsichtbar** — nur im eigenen
Login-Badge erkennbar.

### `familien_owner`
Eigentümer eines Stammbaums (der Ersteller). Admin-Rechte **+ EXKLUSIV** Stammbaum löschen/anlegen.
Nicht über die normale Rollenänderung vergeb-/entfernbar.

### `familien_admin`
Verwaltet Baum/Mitglieder. Darf **nicht** löschen und **nicht** den Owner ändern.

### `familien_mitglied`
Nur Lesen.

## 2. Owner-Übertragung durch Super-Admin (einzige Ausnahme)

Nur der `super_admin` kann den `familien_owner` gezielt übertragen. UI: Abschnitt
„Vlasnik porodičnog stabla / Familien-Owner" in „Podešavanje porodice" — für normale
Nutzer/Admins/Mitglieder unsichtbar.

Ablauf über RPC `stammbaum_owner_wechseln`:
- neuer Nutzer → `familien_owner` (Mitgliedschaft wird bei Bedarf angelegt, `auto = false`);
- bisheriger Owner → automatisch `familien_admin` (`auto = false`).

**Owner hängt an der Familie** → ein Wechsel gilt für ALLE Bäume dieser Familie.

**Protokollierung** in `familien_audit` (`aktion = 'owner_wechsel'`: Stammbaum, alter/neuer Owner,
Datum, ausführender Super-Admin).

**Kandidaten:** aktive Mitglieder des **gesamten Verbunds** (verwandte Familien, ohne `super_admin`
und ohne aktuellen Owner) ODER per E-Mail gesuchte registrierte Nutzer —
RPCs `stammbaum_owner_kandidaten` / `owner_nutzer_suche`.

**DB-Datei:** [supabase_owner_wechsel.sql](../sql_archiv/2026-07-24_im-dump-enthalten/supabase_owner_wechsel.sql)
(bereits in Prod, daher im Archiv — siehe `SCHEMA.md`).

## 3. Blutlinien-Rechte (additiv, automatisch)

Wird ein Konto mit einer Baum-Person verknüpft (`personen.user_id`, z. B. bei
Anfrage-Genehmigung), bekommen automatisch ALLE Familien der **direkten Blutlinie**
(Vorfahren + Nachkommen über `elternteil`-Kanten, **nur eigener Verbund**) die Rolle
`familien_admin`.

**Streng additiv:**
- `familien_owner` und **manuell** gesetzte Rollen (`mitgliedschaften.auto = false`) werden
  NIE überschrieben oder herabgestuft.
- Nur `auto = true`-Rollen werden neu berechnet bzw. entzogen.

**Neuberechnung** läuft automatisch bei Baumänderungen (DB-Trigger auf `personen`/`beziehungen`)
sowie bei jeder Verknüpfung.

„Familie" = eine `familien`-Zeile (Nachnamen-Baum), **nicht** konto-/verbundübergreifend —
die Mandanten-Isolation bleibt gewahrt.
