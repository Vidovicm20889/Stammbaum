# FamilyRoots — Projektkontext für Claude Code

## Projekt
Interaktive Familienstammbaum-Webapp **FamilyRoots** (früher „Vidović AI"), zunächst für die Familie Vidović.
Live: https://familyroots.club/stammbaum.html (Custom Domain auf GitHub Pages; Repo „Stammbaum")
Frontend: Vanilla HTML/CSS/JS (`stammbaum.html` + ausgelagerte `stammbaum.css`, `i18n.js`,
`pdf_export.js`, `chat.js`), kein Framework, kein Build-Tool.
Backend: **Supabase** (Postgres + RLS, Auth, Edge Functions, Storage). E-Mail über **Resend**.
Die Stammbaum-Daten liegen in Supabase (mehrmandantenfähig); eingebettetes `FAMILY_DATA` ist nur
noch Fallback, wenn Supabase nichts liefert.

## Umgang mit diesen Regeln (Governance) — ZUERST lesen
- Diese CLAUDE.md ist **verbindlich** und wird bei JEDEM Feature/jeder Änderung berücksichtigt.
  Die Dateien unter `docs/` sind **gleichrangig verbindlich** — sie enthalten die Details zu den
  hier verkürzten Regeln.
- Weicht ein Wunsch von den Regeln ab oder ist nicht abgedeckt, **weise ich VOR der Umsetzung
  ausdrücklich darauf hin** und erkläre den Konflikt. Danach entscheidest **du**:
  (a) Feature ablehnen/anpassen, **oder** (b) Regel hier ergänzen — **erst danach** wird umgesetzt.
- Dauerhafte Konventionen aus einem Feature werden festgehalten (feature-spezifisch in `docs/`,
  feature-übergreifend hier), damit die Doku den realen Stand widerspiegelt.

## Doku-Struktur & Spec-Dateien (verbindlich)
- Diese CLAUDE.md enthält **nur** dauerhaft gültige, feature-übergreifende Regeln in Kurzform.
  **Feature-Details und Begründungen** stehen unter `docs/` (Index am Ende).
- **Vor Arbeit an einem bestehenden Feature ZUERST** die zugehörige `docs/…`-Datei lesen —
  nicht aus dem Gedächtnis raten. Ebenso: vorhandenen ähnlichen Code inspizieren und dessen
  Muster übernehmen (`benachrichtigungen`, `registrierungs_anfragen`, `event_*`, Media-Upload/
  Storage-Policies, `startRealtimeSync`, `verbund_nutzer()`, die SECURITY-DEFINER-RLS-Helfer).
- **Neue Feature-Spec automatisch anlegen:** Bei einem umfangreicheren neuen Feature (eigene
  Tabellen/RPCs, eigener UI-Bereich, mehr als trivial) lege ich nach der Umsetzung eine eigene
  **`docs/<feature>.md`** an (Struktur: Zweck, Datenmodell/RLS, Frontend, i18n, bewusste Grenzen)
  und trage sie in den Index ein — **statt die CLAUDE.md aufzublähen**. Passt es thematisch in eine
  bestehende Datei, ergänze ich dort. Ich sage VORHER kurz, welche Datei entsteht/ergänzt wird.
- **Kleine Änderungen** werden in der `docs/`-Datei des Features nachgezogen.
- **Confluence** wird bei jedem Deployment gepflegt — **ausschließlich vom Deploy-Agenten**.
  Ablauf, Space-Daten und Seitenstruktur: `docs/confluence-pflege.md`.

## Umgang mit Anweisungen/Prompts (Ideenphase ZUERST) — verbindlich
- **Jeder Prompt wird ZUERST analysiert und als Ideen ausgearbeitet — NICHT sofort umgesetzt.**
  Vor Code-/Dateiänderungen lege ich dar: kurze **Analyse** (Ziel, betroffene Komponenten,
  Konflikte mit den Regeln, Annahmen) und **2–3 Lösungswege** mit Vor-/Nachteilen, Aufwand,
  Auswirkung auf Architektur/RLS/Mobile/i18n — plus **Empfehlung**.
- **Erst nach deiner Entscheidung** wird umgesetzt.
- **Ausnahmen** (direkt umsetzbar): triviale/eindeutige Aufgaben ohne Gestaltungsspielraum
  (Tippfehler, exakt spezifizierte Einzeländerung, reine Analyse/Nachfrage). Im Zweifel Vorschläge.

## Architektur-Kern (IMMER einhalten)
- Datenmodell: `familien` = Konto/Mandant → `stammbaeume` (familie_id) → `personen`/`beziehungen`
  (`stammbaum_id`/`familie_id`). Rollen in `mitgliedschaften` (user_id + familie_id + rolle).
  Sichtbarkeit/Föderation über `verbund_id` der Familie. Konto↔Person über `_userId`.
- **Familien-Isolation:** jede Familie sieht nur eigene Daten (verbundweit), außer Super-Admin.
- **Keine NEUEN externen Libraries/Dienste ohne ausdrückliche Absprache.** Freigegeben sind
  ausschließlich: Supabase, Resend, `@supabase/supabase-js@2`, `d3.js`, `jspdf`+`svg2pdf.js`,
  `marked`, `leaflet@1.9.4` (alle CDN jsdelivr, versions-gepinnt + SRI) sowie das Schrift-Asset
  `Noto Serif` aus dem Repo. Frontend bleibt Vanilla (kein Framework/Build-Tool).
  **Verwendungszweck, CSP-Quellen (Leaflet/OSM/Nominatim), Rate-Limits und die
  Markdown-Sanitizer-Pflicht: `docs/externe-libraries-csp.md` — vor jedem Eingriff an CSP,
  Karte oder PDF-Schrift lesen.**
- Direkte Blutlinie (Tanasije → Simo → Marko) ist immer der zentrale vertikale Hauptstrang.
- **Aktuellen Stammbaum NIE automatisch wechseln:** Nach Speichern/Bearbeiten/Hochladen/Löschen
  bleibt der Nutzer im aktuell geöffneten Baum. `ladeBaumDaten` behält `aktuellerStammbaumId`;
  nur wenn keiner gewählt ist, wird der zuletzt geöffnete aus `localStorage('vidovic_tree')`
  wiederhergestellt, sonst der größte Baum. `waehleStammbaum` persistiert die Auswahl.
- **Rollen:** `super_admin` (unsichtbar für normale Nutzer) / `familien_owner` (exklusiv Baum
  löschen+anlegen) / `familien_admin` (verwalten, nicht löschen) / `familien_mitglied` (nur lesen).
  Owner-Übertragung nur durch Super-Admin. Blutlinien-Rechte werden **automatisch und streng
  additiv** vergeben (`auto = true`); Owner und manuelle Rollen (`auto = false`) werden NIE
  überschrieben. **Details: `docs/rollen-rechte.md`.**

## Design-Regeln (IMMER einhalten)
- Edles, nobles Design — dunkles Farbschema, Serifenschriften, Gold-Akzente; konsistent mit dem
  bestehenden Stil (Bild4.jpg als Hintergrund auf `#baum-container`).
- **Mobile-first:** jede Änderung muss auf dem Smartphone funktionieren (< 480px).
- **Mehrsprachig DE / SR / HR / BA / EN — Texte nie hardcoden.** Schlüssel in ALLEN 5
  `TEXTE`-Blöcken pflegen; Zugriff über `t(key, vars)`; Personennamen über `nm()` (bei `sr`
  Transliteration nach Kyrillisch). Alle sichtbaren Inhalte müssen in allen 5 Sprachen korrekt sein.
- **UX-Perspektive IMMER aktiv mitdenken:** visuelle Ordnung (Raster statt ragged wrap, gleichmäßige
  Abstände), logische Gruppierung + sinnvolle Reihenfolge, verständliche Beschriftung, ausreichend
  Kontrast + Tap-Targets (≥16px/Touch). Wirkt ein Ergebnis unaufgeräumt, wird es VOR dem Abschluss
  aufgeräumt — auch ohne expliziten Auftrag.

## Frontend-Komponenten & UI-Konventionen (Kurzform — Details: `docs/ui-bausteine.md`)
Vor jeder UI-Änderung `docs/ui-bausteine.md` lesen. Die harten Invarianten:
- **KEINE nativen Browser-Dialoge.** Statt `alert()`/`confirm()`/`prompt()` immer
  `zeigeHinweis(text)` bzw. `zeigeBestaetigung(text, {gefahr, jaText})`. Vor jedem Commit prüfen:
  `grep -nE "\bconfirm\(|[^.\w]alert\(|\bprompt\("` liefert im Frontend **nichts**.
- **Voll-Overlays (`.modal`) schließen NUR per Button** — kein Backdrop-/Außenklick-Schließer.
  Kleine Dropdown-/Such-/Presence-Panels schließen weiterhin per `pointerdown` außerhalb.
- **Dropdowns**: `<select>` wird automatisch suchbar (`macheAlleSelectsSuchbar`); nach dynamischem
  Befüllen im Overlay erneut aufrufen. Touch-Regeln (`pointerdown`, `tippAuswahl`, Reposition
  statt Schließen bei resize) **nicht zurückbauen**.
- **Datumsfelder**: `class="login-feld dp-input"`, Werte über `datumWert`/`datumSetzen`, Anzeige
  `formatDatumLang`. Eingabe-Reihenfolge ist eine **Nutzer-Präferenz, entkoppelt von der Sprache**.
- **Pflichtfelder & Feld-Fehler**: Label-Klasse `.pflicht`; Validierungsfehler **direkt am Feld**
  über `feldFehler(feldId, t('…'))`, `feldFehlerReset(overlayId)` zu Beginn jeder Validierung.
- **Sprachwechsel**: `wechselSprache` MUSS dynamisch gerenderte Inhalte/Dropdowns/offene Overlays
  neu aufbauen — neue dynamische Listen dort einhängen.
- **Session**: Auto-Logout nach 30 Min (Warnung 1 Min vorher), harter Reload nach Re-Login,
  Update-Banner bei neuer `app-version`. Live-Reload behält Fokus und setzt den Logout-Timer
  **nicht** zurück. Diese Logik nicht brechen.

## Backend- & Daten-Regeln (Supabase) — IMMER einhalten
- **Referenzielle Integrität bei Anlegen UND Löschen** — keine verwaisten Zeilen:
  - **Löschen** (Person/Stammbaum/Mitglied/Familie): `beziehungen`, `personen`, `stammbaeume`,
    `mitgliedschaften`, `familien`, `registrierungs_anfragen` (und ggf. `auth.users`) in
    FK-sicherer Reihenfolge mitabräumen (Kinder vor Eltern). Referenz: `stammbaum_loeschen`.
    Event-Daten (`events`, `event_teilnehmer`, `event_kosten`) hängen per `ON DELETE CASCADE`.
  - **Nicht-DB-Stores nicht vergessen:** Event-**Medien** liegen im Storage-Bucket `events` und
    werden NICHT per CASCADE entfernt → im Frontend mit `loescheEventMedien` mitabräumen.
  - **Anlegen**: alle Pflicht-Verknüpfungen setzen (`familie_id`, `stammbaum_id`,
    Owner-/Mitgliedschaft) — sonst entsteht Losgelöstes (Person ohne `stammbaum_id` fehlt im Baum).
  - **Schutz**: Familien mit `super_admin`-Mitgliedschaft nie automatisch löschen.
- Schreib-/Lösch-Logik bevorzugt über **SECURITY-DEFINER-RPCs** mit expliziter Rechteprüfung.
  RLS auf `mitgliedschaften` muss **rekursionsfrei** bleiben (SELECT-Policy ohne Subquery auf
  dieselbe Tabelle). Das Frontend prüft den Erfolg echt (RPC-Rückgabe/Fehler) und zeigt nie
  Änderungen an, die nicht gespeichert wurden.
- Kein Hardcode-Check auf eine bestimmte Wurzelperson (z. B. I500009) — sonst sehen fremde Konten
  ihre eigenen Daten nicht.
- Datumswerte gehören in `stammbaum_daten` (jsonb), **kanonisch ISO `YYYY-MM-DD`**; nicht-parsebare
  Altwerte bleiben Freitext (Migration lazy beim nächsten Speichern). Die `date`-Spalte
  `geburtsdatum` bleibt NULL (sonst Fehler 22008), `geschlecht` bleibt NULL (CHECK) — sex liegt
  in `stammbaum_daten`.
- **DATENSCHUTZ/KINDERSCHUTZ (hart, für jedes Social-Feature):** Alle sozialen Inhalte (Feed,
  Beiträge, Kommentare, Reaktionen, Markierungen, Fragen, Aufnahmen) sind STRIKT verbund-gebunden —
  niemals verbundübergreifend sichtbar, außer bei ausdrücklicher Freigabe aus dem Kontakt-/
  Baumzugriff-Feature. Soziale Inhalte über lebende Personen und Minderjährige werden NIE außerhalb
  des Verbunds exponiert; **einzige Ausnahme:** die vier Discovery-Minimalfelder
  (`personen_entdecken`) einer opt-in-freigegebenen, **volljährigen** lebenden Person bzw. eine
  freigegebene Kontakt-/Baumzugriff-Verbindung. **Minderjährige bleiben IMMER ausgeschlossen.**
  Reaktionen/Kommentare erben die Lese-Grenze ihres Zielobjekts.
- `supabase/.env` (RESEND_API_KEY etc.) ist gitignored und darf NIE committet werden.

## Arbeitsumgebung & Sicherheit (Windows Defender) — IMMER einhalten
- **Milans privater Rechner** (keine Firma, kein EDR — frühere Notiz „Unternehmensrechner"
  war veraltet, korrigiert 2026-08-03). Aktiv ist der reguläre Windows Defender; `C:\VidovicAi`
  (alle drei Apps) ist per Pfad-Ausnahme von Echtzeit-Scans befreit (Performance, siehe
  `../CLAUDE.md`, Abschnitt „Windows Defender"). Die folgenden Vorsichtsregeln bleiben davon
  **unberührt** — sie gelten wegen Defenders Verhaltenserkennung (AMSI) auf ausgeführte
  PowerShell-Befehle, nicht wegen gescannter Dateien, und sind unabhängig von der Ausnahme:
  - **Keine** PowerShell-Flags wie `-EncodedCommand`/`-enc`, `-NoProfile`, `-NonInteractive`,
    `-WindowStyle Hidden`, `-ExecutionPolicy Bypass`.
  - **Keine** versteckten Hintergrund-Prozesse ohne Not; keine Base64-/verschleierten Kommandos,
    keine Remote-Download-und-Ausführen-Einzeiler.
- Stattdessen **dedizierte Tools** (Read/Write/Edit/Glob/Grep statt cat/sed/find/echo), einfache,
  interaktiv nachvollziehbare Befehle; für POSIX-Skripte das Bash-Tool. Git/npm/gh normal ausführen.
- Ließe sich eine Aufgabe nur mit einem geflaggten Muster lösen: **nicht selbst ausführen**,
  sondern dem User die exakten Befehle geben — er führt sie manuell aus.

## Werkzeuge & große Dateien
- `stammbaum.html` (~25.000 Zeilen) und `i18n.js` (~8.000 Zeilen) werden **nie am Stück gelesen** —
  erst `Grep`, dann `Read` mit `offset`/`limit`. Orientierung: **`docs/karte.md`** (Funktions-/
  Abschnitts-Index mit Zeilennummern, neu erzeugbar mit `node scripts/karte_bauen.mjs`).
- Generierte/archivierte Dateien nie am Stück lesen: `pdf_font.js` (Base64), `rezepte_pool.js`,
  `render_snapshot.json`, `supabase_prod_schema.sql`, `CLAUDEArchiv.md`. `pdf_font.js` und
  `render_snapshot.json` sind in `.claude/settings.json` hart gesperrt (dort taugt auch ein
  Grep-Treffer nichts); die übrigen bleiben **gezielt per Grep** erreichbar — eine `Read`-Deny-Regel
  sperrt die Datei komplett, auch für Grep (siehe `docs/lessons.md`).
- **Neue i18n-Schlüssel** über `node scripts/i18n_add.mjs` anlegen (schreibt in alle 5 Blöcke),
  danach `node i18n_lint.js`.

## Deploy & Versionierung (Kurzform — Details: `docs/workflow-branching-versionierung.md`)
- **Branch pro Änderung:** jede Änderung (Bug ODER Story) auf eigenem Branch (`bugfix/…`,
  `feature/…`, `docs/…`) von aktuellem `main` — **nie direkt auf `main`**.
- **Zuerst lokal testen**, Ergebnis als PASS/FAIL vorlegen. Test rot → kein Commit.
- **Commit/Merge/Push NUR nach ausdrücklicher Freigabe.** „Test grün" ist keine Freigabe.
  Nur den zur Aufgabe gehörenden Hunk stagen, nie blind ganze Dateien.
- **Versions-Schema `XX.XX` = MAJOR.STORY.BUG:** Bug → letzte Stelle +1; Story → vorletzte +1 und
  letzte auf 0; ab der 3. Story ohne Deployment → MAJOR +1, Rest `00`. Version erst im
  Freigabe-Schritt vergeben (sonst kollidieren parallele Branches).
- **Bei JEDEM Frontend-Deploy** `<meta name="app-version" content="X.Y">` hochzählen **und** das
  `?v=` an `stammbaum.css`, `i18n.js`, `pdf_export.js`, `chat.js` auf dieselbe Version ziehen —
  sonst liefert GitHub Pages veraltete Sub-Ressourcen aus und Nutzer sehen kein Update-Banner.
- **DB-Änderungen**: als idempotente `.sql`-Datei im Repo. **Erst lokal, dann prod:** neue
  Migration zuerst gegen die lokale DB verproben (`supabase db reset` →
  `node scripts/lokal_db_aufbau.mjs` → neue `.sql`), erst danach im Prod-SQL-Editor ausführen
  (`docs/staging-umgebung.md`). Frischer DB-Aufbau **nicht** über die Alt-`.sql` replayen, sondern
  über `supabase_prod_schema.sql`. Im Wurzelverzeichnis liegen nur der Dump und `.sql`, die **noch
  nicht in Prod** sind; bereits eingespielte Migrationen stehen unter `sql_archiv/` (Historie, Index
  in `SCHEMA.md`) — dort auch die Einmal-/Vorfall-Skripte.
- **Edge Functions** über das Supabase-Dashboard deployen (CLI durch Citrix-Firewall blockiert).
- **Code-Review + Code-Test VOR JEDEM Deployment (Pflicht):** erst Diff-Review (Korrektheit,
  Seiteneffekte, alle Regeln: i18n × 5, RLS/Rechte, referenzielle Integrität, Mobile/Touch,
  Realtime), dann echter Test (`node i18n_lint.js`, `node --check`, Flows durchspielen, `.sql` auf
  Idempotenz/FK-Reihenfolge). Erst wenn beides sauber ist, wird der Deploy vorbereitet.

## Dein Arbeitsablauf (Loop)

**TEST-PFLICHT bei jeder Änderung an Code, Daten oder Konfiguration** (nicht bei reinen
Analyse-/Auskunftsantworten):
- **Testfälle wirklich AUSFÜHREN, nicht nur beschreiben:** `node --check` bei JS-Änderungen,
  `node i18n_lint.js` bei Textänderungen, ausführbare Logik (Parser/Berechnung) mit echten
  Eingaben und Grenz-/Fehlerfällen durchspielen, SQL auf Idempotenz/FK-Reihenfolge gegenlesen.
  Nur am Gerät/nach Deploy Verifizierbares wird als 🔬 gekennzeichnet.
- **UX-/Mobile-Test:** Flow aus Nutzersicht durchspielen — Bedienbarkeit, Ordnung/Gruppierung,
  Beschriftung, Kontrast/Tap-Targets, **Android + iOS < 480px**, i18n in allen 5 Sprachen.
  Checkliste: `docs/ui-bausteine.md` §8.
- **Ergebnis KURZ vorstellen:** welche Testfälle liefen, mit welchem Ergebnis (PASS/FAIL, knappe
  Liste), was nur 🔬 verifizierbar ist. Fehlschlag wird ehrlich gemeldet und VOR der Fertigmeldung
  behoben — kein „grün gemeldet, ungetestet".

**FEHLER-/LERN-LOOP bei Problemen (verbindlich):**
1. **Ursache verstehen** — Symptom genau lesen, Root Cause benennen, nicht am Symptom doktern.
2. **Gezielt beheben** — eine begründete, kleine Änderung, die die Ursache adressiert.
3. **Erneut testen** — bringt ein Versuch keinen Fortschritt, wird er **verworfen** (nicht darauf
   aufbauen); nächster Versuch mit **neuer** Hypothese.
4. **Abbruchgrenze:** nach **3 ernsthaft verschiedenen Ansätzen** ohne tragbare Lösung nicht weiter
   raten, sondern **nachfragen** — mit Zusammenfassung: was versucht, was passierte, welche
   Hypothesen ausgeschlossen, welche Optionen bleiben. Sofortiger Stopp, wenn eine Lösung eine
   Regel brechen würde (dann Hinweis statt Umsetzung, siehe Governance).
5. **Lehre festhalten:** War das Problem **nicht trivial**, kommt die Lehre nach der Lösung in
   **`docs/lessons.md`** (Symptom → Ursache → Lösung → Merksatz). **VOR** dem Angehen eines Problems
   in einem bekannten Bereich (PDF-Export, RLS/Rekursion, Realtime, Datumsparser, i18n, Mobile/
   iOS-Zoom, Storage-Cleanup …) **zuerst dort nachschauen**. Triviale Fehler nicht protokollieren.

**Nach jeder Änderung an Code/Daten** (bei reinen Auskünften entfällt dieser Block):
1. Seiteneffekte auf andere Komponenten geprüft?
2. Design-Regeln eingehalten (inkl. i18n in allen 5 Sprachen)?
3. Mobile-/Geräte-Test Android + iOS durchgeführt (`docs/ui-bausteine.md` §8)?
4. Bei Daten: alle Tabellen konsistent, keine verwaisten Zeilen (inkl. Storage)?
5. Governance: weicht etwas von den Regeln ab? Falls ja → Hinweis.
6. **Lokaler Docker-Stack nach dem Verproben aufgeräumt** (nicht dauerhaft
   nebenbei weiterlaufen lassen): `supabase stop`, sobald die Migration/der
   Test gegen den lokalen Stack abgeschlossen ist – Daten/Migrationsstand
   bleiben erhalten, siehe [`docs/staging-umgebung.md`](docs/staging-umgebung.md#geteilte-docker-kapazität-mit-stockflow-und-ledgerflow).
7. Selbsteinschätzung: ✅ alles ok / ⚠️ Kompromiss nötig / ❌ Problem gefunden.
8. Logisch nächsten Schritt vorschlagen.
9. **ToDo-Liste „Was DU noch erledigen musst"** als eigener Abschnitt am Ende — alles, was ich
   nicht selbst ausführen kann oder darf, nie nur im Fließtext: **SQL im Supabase-Editor**
   (mit Reihenfolge + Idempotenz-Hinweis), **Edge Functions übers Dashboard**, **Commit/Merge/Push
   + Version-Bump** (`app-version` **und** alle `?v=`), **Defender-kritische Befehle** in exakt
   ausführbarer Form, **🔬-Punkte**, sonstige manuelle Schritte (Storage-Buckets/Policies,
   Confluence/Jira, Secrets/`.env`, Rollen, Resend). **Jeder Punkt verlinkt die betroffene(n)
   Datei(en)** als relativen Pfad (`[datei.sql](datei.sql)`, ggf. mit Zeile `[datei.js:42](datei.js#L42)`).
   Ist nichts offen: ausdrücklich „Keine offenen ToDos für dich" schreiben.

## Feature-Dokumentation (Details unter docs/)
Vor der Arbeit an einem Feature die passende Datei lesen; neue Features nach obiger Regel ergänzen.

**Regel-Details (aus dieser Datei ausgelagert, gleichrangig verbindlich):**
- `docs/ui-bausteine.md` — Styleguide/keine nativen Dialoge, Overlays, Dropdowns, Datumsfelder, Pflichtfelder & Feld-Fehler, Sprachwechsel, Session, Mobile-Checkliste.
- `docs/rollen-rechte.md` — die vier Rollen im Detail, Owner-Übertragung durch Super-Admin, Blutlinien-Rechte (additiv/auto).
- `docs/externe-libraries-csp.md` — freigegebene Libraries + Verwendungszweck, Noto-Serif-Subset, Leaflet/OSM/Nominatim-CSP & Rate-Limit, Markdown-Sanitizer.
- `docs/confluence-pflege.md` — Confluence-Spiegelung beim Deployment (nur Deploy-Agent).
- `docs/workflow-branching-versionierung.md` — Branch pro Änderung, Testmatrix, Freigabe, Versions-Schema mit Überlauf-Beispielen, ausgelagerte Dateien & Cache-Busting.
- `docs/staging-umgebung.md` — „erst lokal, dann prod": lokaler Supabase-Stack, Aufbau als Prod-Spiegel über den Dump, Seed, Frontend-Umschaltung, geteilte Docker-Kapazität mit StockFlow/LedgerFlow (stoppen statt laufen lassen, Cleanup alter Container). Staging-Cloud = FAMROOTS-37.
- `docs/lessons.md` — Fehler-/Lern-Log (Symptom → Ursache → Lösung → Merksatz).
- `docs/karte.md` — Zeilen-Index von `stammbaum.html` (generiert, nicht von Hand pflegen).

**Features:**
- `docs/realtime-kollaboration.md` — Live-Sync der Baumdaten, Presence/Live-Indikator, Soft-Lock, Konflikterkennung (P1–P5), Obavještenja-Polling.
- `docs/profil-konten-mitglieder.md` — Benutzerprofil (Phase 1/2, Sicherheitsbereich), „Meine Person" (Konto↔Karte, Self-Service), Profil↔Karte-Sync, Mitglieder-Verwaltung & Benutzer↔Karte-Zuweisung.
- `docs/baum-struktur-blutlinie.md` — Beziehung ändern/umhängen, Auto-Zweigbaum bei Heirat, abweichender Nachname, Geschwister-Platzhalter, Kind-Sichtbarkeit, Blutlinien-Kappung, Baum-Name/Zusatz, Gleiche-Person/Dubletten-Merge, Auto-Löschung leerer Bäume.
- `docs/ansichten-pdf.md` — personalisierte Standard-/Ausschnitts-Ansicht, „Alle Verwandten / Netz", PDF-/Druck-Export.
- `docs/medien-galerie-dokumente.md` — Karten-Avatar aus Profilbild, Foto-Galerie, Dokumente & Quellen, Sprach-/Video-Aufnahmen, mehrsprachige Lebensgeschichten.
- `docs/ereignisse-anlaesse.md` — Geburtstags-/Gedenktag-Erinnerungen (In-App + E-Mail), Ereignis-Bereich (Liste/Zeitstrahl/Karte + Migrationspfad).
- `docs/social-chat-feed.md` — Kochbuch-Bewertungen, Chat (1:1/Gruppe), verbundübergreifende Personensuche/Kontakte, Reaktionen & Kommentare, Familien-Feed/Aktivitäten, Foto-Tagging, Familien-Fragen.
- `docs/board-modus.md` — Board-Modus (`ansichtModus='board'`): freies Verschieben von Karten (`board_layout`, ein Board pro Baum) + Verknüpfen per Linie mit Auto-Erkennung über `verknuepfung_anfragen`.
- `docs/jira-anbindung.md` — Jira/Atlassian-MCP: Einrichtung, Projekt `FAMROOTS`, Workflow-Spalten + Transition-IDs (inkl. neuer Spalte „Dokumentation" + Umbenennung „Bereit"→„Erledigt für Deployment", 2026-08-04), Ablauf je Vorgang (max. 1 pro Durchlauf), die sieben Modi A Jira-Dev / B Story-Autor / C Story-Refiner (Pflichtstufe für Story-Autor-Storys, FAMROOTS-38) / E Review-Agent / F Test-Agent / G Doku-Agent (E/F/G seit 2026-08-04, analog StockFlow/LedgerFlow) / D Deploy-Manager, Commit-Politik.
- `ROADMAP.md` — Roadmap-Kontext & Ausblick.
