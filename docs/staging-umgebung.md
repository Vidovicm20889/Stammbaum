# Staging-/Testumgebungen — lokal → staging → prod

**Status:** Stufe 1 (lokal) umgesetzt in FAMROOTS-36. Stufe 2 (Staging-Cloud) ist FAMROOTS-37.
**Zweck:** DB-/Backend-Änderungen **real verproben, bevor sie Prod berühren** — kein direktes
Ausführen von `.sql` gegen produktive Familiendaten mehr.

## Das Problem (Ist-Zustand vor FAMROOTS-36)

Jede Migration wurde bislang **direkt im Prod-SQL-Editor** ausgeführt (SCHEMA.md: „Ausführung im
Supabase-SQL-Editor"). Ein fehlerhaftes `DROP`/`UPDATE`/eine kaputte RLS-Policy schlägt damit
**sofort auf echte Personendaten** durch. Der Workflow prüfte `.sql` nur per „Gegenlesen"
(`docs/workflow-branching-versionierung.md`), nie durch reale Ausführung.

## Drei Stufen

| Stufe | Wo | Zweck | Daten | Status |
|---|---|---|---|---|
| **1 — lokal** | Docker auf dem Entwicklungsrechner (`supabase start`) | schnelles, kostenloses Verproben jeder Migration; RLS/FK real testen | **nur synthetisch** (`supabase/seed.sql`) | ✅ FAMROOTS-36 |
| **2 — staging** | eigenes 2. Supabase-Cloud-Projekt | realitätsnahe Endprüfung (Realtime/Storage/Edge/Resend) vor Prod | synthetisch oder **anonymisierter** Prod-Abzug | ⏳ FAMROOTS-37 |
| **3 — prod** | produktives Supabase-Projekt | Livebetrieb | echte Familiendaten | bestehend |

**Promotion-Regel (Datenfluss immer nur aufwärts):** eine Migration wird **erst lokal** gegen den
frischen Stack ausgeführt (Idempotenz + FK-Reihenfolge **real**), **dann** (ab FAMROOTS-37) auf
Staging, **erst dann** auf Prod. Nie umgekehrt; Code wandert, **echte Daten wandern nie nach unten**.

## Datenstrategie (hart)

- **Lokal & Staging bekommen NIE echte Familiendaten** ungefiltert. Default ist **synthetisch**
  (`supabase/seed.sql`, erfundene Namen).
- Wird für einen realitätsnahen Test je ein Prod-Abzug nötig (nur Staging, nie lokal-by-default),
  dann **anonymisiert/maskiert** (Namen, Geburtsdaten, Kontakt, Fotos) — Details legt FAMROOTS-37
  fest. Minderjährige und lebende Personen sind besonders geschützt (CLAUDE.md, Kinderschutz).

---

## Stufe 1 einrichten (lokal)

### Voraussetzungen (macht der Nutzer selbst — transparente, interaktive Befehle)

Der Umsetzungs-Agent führt CLI-Install/-Start **nicht** aus (Defender/EDR-Regeln, CLAUDE.md). Die
Befehle sind bewusst offen und nachvollziehbar — kein `-EncodedCommand`, nichts im Hintergrund.

```powershell
# 1) Docker läuft (Docker Desktop). Prüfen:
docker version

# 2) Supabase-CLI installieren. ⚠️ winget hat KEIN Supabase-Paket (geprüft 23.07.2026) — der
#    direkte Binär-Download von GitHub ist der transparenteste Weg (sichtbare Datei, nichts wird
#    remote ausgeführt; passt zu den Defender/EDR-Regeln). Version bei Bedarf auf den neuesten
#    Release von https://github.com/supabase/cli/releases anheben:
$dir = "$HOME\supabase-cli"
New-Item -ItemType Directory -Force $dir | Out-Null
Invoke-WebRequest -Uri "https://github.com/supabase/cli/releases/download/v2.109.1/supabase_2.109.1_windows_amd64.zip" -OutFile "$dir\supabase.zip"
Expand-Archive "$dir\supabase.zip" -DestinationPath $dir -Force
[Environment]::SetEnvironmentVariable("Path", "$env:Path;$dir", "User")   # PATH dauerhaft; neues Fenster öffnen
#    (Scoop-Weg NICHT genutzt: dessen Bootstrap `irm get.scoop.sh | iex` ist ein Remote-Exec-
#    Einzeiler, den die CLAUDE.md-Sicherheitsregeln vermeiden.)

# 3) Im FamilyRoots-Ordner den lokalen Stack starten (nutzt das laufende Docker):
cd C:\VidovicAi\FamilyRoots
supabase --version      # muss die Version zeigen (sonst PATH/neues Fenster prüfen)
supabase start          # zeigt am Ende API-URL, anon key, DB-URL, Studio-URL
supabase status         # dieselben Werte jederzeit erneut anzeigen
```

`supabase start` liest `supabase/config.toml` aus dem Repo. **`supabase init` ist nicht nötig** —
die `config.toml` liegt bereits vor.

### Ports (Koexistenz mit StockFlow — Pflicht)

Im VidovicAI-Ordner liegen **zwei** Apps mit je einem lokalen Stack. StockFlow belegt die
**Default-Ports**; FamilyRoots weicht um **+10** aus, damit beide Stacks **gleichzeitig** laufen:

| Dienst | StockFlow (Default) | **FamilyRoots (+10)** |
|---|---|---|
| API | 54321 | **54331** |
| DB (Postgres) | 54322 | **54332** |
| Shadow-DB | 54320 | **54330** |
| Pooler | 54329 | **54339** |
| Studio (Web-UI) | 54323 | **54333** |
| E-Mail-Fänger | 54324 | **54334** |
| Analytics | 54327 | **54337** (aus) |
| Edge-Inspector | 8083 | **8093** |

Die lokale DB erreichst du damit unter
`postgresql://postgres:postgres@127.0.0.1:54332/postgres`, Studio unter `http://127.0.0.1:54333`.

### Prod-Schema erzeugen (EINMALIG bzw. nach Prod-Änderungen)

Der lokale Aufbau spiegelt Prod **exakt** über den kompletten Prod-Schema-Dump. Das ist die einzige
verlässliche Methode — die 117 gewachsenen `.sql` lassen sich **nicht** am Stück replayen (siehe
Kasten „Warum kein Replay" unten).

```powershell
# gegen das PROD-Projekt (einmalig; Prod-Zugriff = Nutzer-ToDo):
supabase login
supabase link --project-ref tybvzhifvufgvlgjpmyl
supabase db dump -f supabase_prod_schema.sql
```

Ergebnis: `supabase_prod_schema.sql` im Repo-Root (Tabellen + Spalten + Functions + Policies + RPCs +
Trigger + FKs, 1:1 Prod). ⚠️ **`winget` hat kein Supabase-Paket** — CLI per Binär-Download
installieren (Schritt 2 oben). `supabase login` öffnet den Browser; falls das nicht geht, ein
Personal Access Token setzen (`$env:SUPABASE_ACCESS_TOKEN = "…"`, Dashboard → Account → Access Tokens).

#### Warum kein Replay der 117 Skripte? (FAMROOTS-36)

Die gewachsene Migrationskette ist **nicht** als Start-zu-Ende-Aufbau lauffähig — empirisch belegt:
- **Tabellen später als benutzt erzeugt** (z. B. `verbund`→`stammbaeume`, `mitglieder_komplett`→
  `registrierungs_anfragen`).
- **Nicht-Idempotenz** einzelner Altskripte (`CREATE POLICY` ohne `DROP … IF EXISTS`; Postgres kennt
  kein `CREATE POLICY IF NOT EXISTS`).
- **Überholte Migrationen** (der harte Fall): `event_eingeladene.sql` legt `person_id` an, die nächste
  Migration `event_eingeladene_user.sql` stellte das auf `user_id` um. Ein überholter Schritt läuft
  gegen den **Prod-Endstand** prinzipiell auf Grund.

Deshalb: **der Dump IST das Schema.** Die nummerierten `.sql` bleiben als Änderungs-Historie in
`SCHEMA.md`, werden lokal aber nicht mehr ausgeführt. „Erst lokal, dann prod" gilt ab jetzt für
**neue** `.sql` — die testest du gegen diesen Prod-Spiegel, bevor sie nach Prod gehen.

### Schema + Seed einspielen

```powershell
node scripts/lokal_db_aufbau.mjs --dry-run   # nur anzeigen (kein DB-Zugriff)

# frischer Aufbau: DB leeren, dann Prod-Schema + synthetisches Seed einspielen
supabase db reset                     # leert die lokale FamilyRoots-DB (StockFlow unberührt)
node scripts/lokal_db_aufbau.mjs      # supabase_prod_schema.sql, dann supabase/seed.sql
```

**Kein separates `psql` nötig:** läuft der DB-Container (`supabase_db_familyroots`), spricht das
Skript die DB automatisch per `docker exec` an (psql ist im Container). Host-`psql` wird bevorzugt,
wenn vorhanden; erzwingen mit `--host` bzw. `--docker`, Container via `--container <name>`,
nur-Schema mit `--schema-only`. `supabase db reset` davor sorgt für einen sauberen, frischen Stand.

### App lokal gegen den Stack laufen lassen

Die Prod-Zugangsdaten in [stammbaum.html](../stammbaum.html) bleiben der **Default**. Umgeschaltet
wird über eine **gitignored** Datei:

```powershell
copy supabase_local.example.js supabase_local.js
# in supabase_local.js url (http://127.0.0.1:54331) + anon key aus `supabase status` eintragen
```

Beim Öffnen der App auf `localhost`/`127.0.0.1` lädt ein kleiner Loader `supabase_local.js` und
setzt `window.__SB_LOCAL` → die App zeigt auf den lokalen Stack (Konsolen-Warnung „LOKALER Stack
aktiv"). **Auf GitHub Pages (Prod) wird die Datei nie angefragt** (der Loader prüft den Hostname) —
kein 404, kein lokaler Key im Repo. `supabase_local.js` ist in `.gitignore`.

---

## Warum lokal (Stufe 1) und Staging (Stufe 2) getrennt sind

- **Lokal ist gratis, sofort, offline** — ideal, um jede Migration und RLS/FK real durchzuspielen,
  bevor überhaupt etwas die Cloud sieht.
- **Lokal ≠ Cloud:** Realtime, Storage-Signaturen, Edge Functions (Resend-Mail) und einzelne
  RLS-Details können minimal abweichen. Die **realitätsnahe Endabnahme** liefert erst die
  Staging-Cloud (FAMROOTS-37) mit echten Keys/Secrets.
- **Drift-Schutz:** Die neue verbindliche Workflow-Stufe (unten) stellt sicher, dass Migrationen
  diszipliniert lokal verprobt werden, damit lokal und Prod nicht auseinanderlaufen.

## Stufe 2 einrichten (Staging-Cloud) — FAMROOTS-37

Ein **zweites Supabase-Cloud-Projekt** „FamilyRoots-Staging" als realitätsnahe Vorstufe vor Prod:
dieselbe Änderung, die lokal grün war, wird hier mit echten Cloud-Eigenheiten (RLS, Realtime,
Storage-Signaturen, Resend-Mail) verprobt, bevor sie Prod berührt. **Kern ist manuelle Account-/
Dashboard-Arbeit** — der Agent liefert nur Doku + die (bereits vorhandene) Frontend-Umschaltung.

### Was der Nutzer manuell einrichtet (🔬)

1. **Projekt anlegen** (Supabase-Dashboard, eigener Account/Org) → Projekt-Ref, `SUPABASE_URL`,
   Anon-Key, Service-Role-Key notieren.
2. **Schema einspielen — wie lokal per Prod-Dump, NICHT per 117-Replay.** Die gewachsene
   `.sql`-Kette ist nicht am Stück lauffähig (FAMROOTS-36, Kasten „Warum kein Replay"). Also:
   `supabase_prod_schema.sql` (denselben Dump) im Staging-**SQL-Editor** ausführen, oder per CLI
   gegen Staging linken und `supabase db push` mit dem Dump. Ergebnis: Staging = exakter Prod-Spiegel.
3. **Edge Functions deployen** (Dashboard/CLI) — die 16 Functions aus `supabase/functions/`.
4. **Resend:** eigener Test-Absender/eigene Test-Domain für Staging, **nie** der Prod-Absender.
5. **Test-Accounts:** `supabase/seed.sql` (synthetisch) im Staging-SQL-Editor ausführen — legt den
   Auth-Testnutzer `test@familyroots.local` / `test1234` + die Testfamilie an (Token-Spalten stehen
   bereits korrekt auf `''`, siehe FAMROOTS-36). Alternativ Auth-User über Studio anlegen.
6. **Secrets getrennt halten:** Staging-Keys **nie** committen. `supabase/.env` bleibt gitignored;
   die Staging-URL/Keys fürs Frontend kommen in die gitignored `supabase_local.js` (s. u.).

### Frontend gegen Staging — bereits gebaut, kein Code nötig

Die Umschaltung aus FAMROOTS-36 zeigt auf **jede** URL, ohne den Prod-Default anzufassen. Für einen
Staging-Test die App **lokal** öffnen und in `supabase_local.js` das Staging-Ziel eintragen:

```javascript
window.__SB_LOCAL = {
  url: 'https://<staging-ref>.supabase.co',
  key: '<staging-anon-key>',
};
```

Der Loader lädt `supabase_local.js` nur auf `localhost`/`127.0.0.1`, also läuft die App lokal gegen
die Staging-**Cloud**. **Keine CSP-Änderung nötig** — `connect-src` erlaubt `https://*.supabase.co`
bereits (Staging ist eine `*.supabase.co`-URL; die localhost-Erweiterung aus FAMROOTS-36 stört nicht).
Der **Prod-Default in `stammbaum.html` bleibt byte-identisch** (AC1); auf GitHub Pages wird
`supabase_local.js` nie geladen.

### Promotion-Regeln (Datenfluss nur aufwärts)

`lokal → staging → prod`. Eine Migration/Edge-Function wird **erst lokal** verprobt (Stufe 1),
**dann** auf Staging gegen echte Cloud-Eigenheiten, **erst dann** auf Prod. **Code wandert aufwärts,
echte Familiendaten wandern nie abwärts.** Staging bekommt **nur synthetische/anonymisierte** Daten
(Kinderschutz) — ein Prod-Restore scheitert ohnehin an fehlendem `auth.users` im Backup.

### Bewusste Grenzen (Stufe 2)

- Doppelte Betriebskosten/Wartung (zweites Projekt, Secrets-Rotation, Resend) — akzeptiert fürs
  Schutzziel „Prod-Daten unberührt".
- Lokal ≠ Staging ≠ Prod nur noch minimal: Staging bildet Cloud-Verhalten real ab; die letzte
  Instanz bleibt Prod.

## Verbindliche Workflow-Stufe (DB-Test)

Ab FAMROOTS-36 gilt in [workflow-branching-versionierung.md](workflow-branching-versionierung.md):
Jede `.sql`-Änderung wird **real gegen den lokalen Stack ausgeführt** (Idempotenz + FK-Reihenfolge),
nicht mehr nur gegengelesen. CLAUDE.md verweist unter „erst lokal, dann prod" darauf. Ab Staging-Cloud
(FAMROOTS-37) folgt die Kette `lokal → staging → prod` (Promotion-Regeln oben).

## Bewusste Grenzen

- **CLI-Install/-Start ist Nutzer-ToDo** (Defender/EDR) — der Agent liefert nur die exakten Befehle.
- **Edge Functions** bleiben in dieser Stufe außen vor (Deploy übers Dashboard); ihr lokaler/
  Staging-Betrieb gehört zu FAMROOTS-37.
- **Basis-Schema** kommt authoritativ aus dem Prod-Dump — kein Handnachbau, sonst Drift.
- **Prod-Deploy-Weg unverändert:** GitHub Pages von `main`; die lokale Umschaltung berührt Prod nicht.
