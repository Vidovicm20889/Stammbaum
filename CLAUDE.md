# FamilyRoots — Projektkontext für Claude Code

## Projekt
Interaktive Familienstammbaum-Webapp **FamilyRoots** (früher „Vidović AI"), zunächst für die Familie Vidović.
Live: https://familyroots.club/stammbaum.html (Custom Domain auf GitHub Pages; Repo „Stammbaum")
Frontend: Vanilla HTML/CSS/JS in einer Datei (`stammbaum.html`), kein Framework, kein Build-Tool.
Backend: **Supabase** (Postgres + RLS, Auth, Edge Functions, Storage). E-Mail-Versand über **Resend**.
Die Stammbaum-Daten liegen in Supabase (mehrmandantenfähig), nicht mehr statisch im Code
(eingebettetes `FAMILY_DATA` ist nur noch Fallback, wenn Supabase nichts liefert).

## Umgang mit diesen Regeln (Governance) — ZUERST lesen
- Diese CLAUDE.md ist **verbindlich** und wird bei JEDEM neuen Feature/jeder Änderung berücksichtigt.
- Weicht ein Wunsch von den Regeln ab oder ist nicht abgedeckt, **weise ich VOR der Umsetzung
  ausdrücklich darauf hin** und erkläre den Konflikt.
- Danach entscheidest **du**:
  - (a) Feature ablehnen bzw. so anpassen, dass es den Regeln entspricht, **oder**
  - (b) CLAUDE.md um die neue/geänderte Regel ergänzen — **erst danach** wird umgesetzt.
- Dauerhafte Konventionen, die aus einem Feature entstehen, werden hier festgehalten,
  damit die Datei den realen Stand widerspiegelt.

## Doku-Struktur & Spec-Dateien (verbindlich)
- Diese CLAUDE.md enthält NUR dauerhaft gültige Regeln (Governance, Architektur-Kern, Design-/UI-Konventionen, Backend/RLS, Sicherheit, Deploy, Loop). **Feature-Details** stehen in eigenen Dateien unter `docs/` (Index am Ende dieser Datei).
- **Vor Arbeit an einem bestehenden Feature ZUERST** die zugehörige `docs/…`-Datei lesen (siehe Index) — nicht aus dem Gedächtnis raten.
- **Neue Feature-Spec automatisch anlegen (verbindlich):** Wird ein umfangreicheres neues Feature umgesetzt (eigene Tabellen/RPCs, eigener UI-Bereich, mehr als eine triviale Änderung), lege ich dafür — nach der Umsetzung — eine eigene **`docs/<feature>.md`** an (gleiche Struktur wie die bestehenden: Zweck, Datenmodell/RLS, Frontend, i18n, bewusste Grenzen) und trage sie in den Feature-Index dieser CLAUDE.md ein — **statt die CLAUDE.md weiter aufzublähen**. Passt das Feature thematisch in eine bestehende `docs/`-Datei, ergänze ich dort. Ich weise VOR dem Anlegen kurz darauf hin, welche Datei entsteht bzw. ergänzt wird.
- **Kleine Änderungen** an einem bestehenden Feature werden in dessen `docs/`-Datei nachgezogen (Datei bleibt der reale Stand).
- Nur **dauerhafte, feature-übergreifende** Konventionen (nicht feature-spezifisch) gehören direkt in diese CLAUDE.md.
- **Confluence bei JEDEM Feature/Bug aktualisieren (verbindlich, SCRUM-3):** Das **Repo ist und bleibt
  die Quelle der Wahrheit**; Confluence ist die gespiegelte Lese-Ansicht für Nicht-Entwickler.
  Space **„FamilyRoots"** (Key `FamilyRoot`, ID `589828`) auf `milanvidovic89.atlassian.net/wiki`.
  Nach JEDER umgesetzten Änderung — vor der Fertigmeldung — ist zu pflegen:
  1. **App-Dokumentation** (Seite `App-Dokumentation`): betroffene Feature-Seite nachziehen, sobald
     sich Verhalten/Datenmodell/Grenzen geändert haben. Neues Feature → neue Unterseite (Spiegel der
     zugehörigen `docs/<feature>.md`).
  2. **Testfälle** (Seite `Testing → Testfälle`): Soll-Verhalten je Feature/Bugfix ergänzen —
     ID-Schema `TF-<Bereich>-<Nr>`, prüfbar formuliert, mit Jira-Key.
  3. **Testprotokoll** (Seite `Testing → Testprotokolle`): das TATSÄCHLICHE Testergebnis des
     Durchlaufs mit PASS/FAIL eintragen; Fehlschläge ehrlich protokollieren, 🔬-Punkte kennzeichnen.
  Reihenfolge: erst Code + Tests, dann Confluence, dann Jira-Kommentar/Status. Ist Confluence nicht
  erreichbar (403/fehlende Freigabe), wird das im Jira-Kommentar ausdrücklich vermerkt statt
  stillschweigend übersprungen.

## Umgang mit Anweisungen/Prompts (Ideenphase ZUERST) — verbindlich
- **Jede Anweisung/jeder Prompt wird ZUERST analysiert und als Ideen ausgearbeitet — NICHT
  sofort umgesetzt.** Bevor ich Code schreibe oder Dateien ändere, lege ich dar:
  - kurze **Analyse** des Wunsches (Ziel, betroffene Komponenten, Konflikte mit CLAUDE.md,
    offene Fragen/Annahmen);
  - **mehrere Vorschläge/Lösungswege** (in der Regel 2–3) mit **Vor-/Nachteilen**, Aufwand,
    Auswirkungen auf Architektur/RLS/Mobile/i18n und einer **Empfehlung**.
- **Erst nach deiner Entscheidung** für einen Weg wird umgesetzt. Ich beginne die Umsetzung
  nicht eigenmächtig, solange du keinen Vorschlag gewählt (oder eigene Vorgabe gemacht) hast.
- **Ausnahmen** (direkt umsetzbar ohne Ideenphase): triviale/eindeutige Aufgaben ohne
  Gestaltungsspielraum (z. B. Tippfehler, exakt spezifizierte Einzeländerung, reine Nachfrage/
  Analyse ohne Umsetzung) — im Zweifel lege ich lieber Vorschläge vor.

## Architektur-Kern (IMMER einhalten)
- Datenmodell: `familien` = Konto/Mandant; `stammbaeume` = Bäume (familie_id); `personen`/
  `beziehungen` referenzieren `stammbaum_id`/`familie_id`. Rollen liegen in `mitgliedschaften`
  (user_id + familie_id + rolle). Sichtbarkeit/Verknüpfung über `verbund_id` der Familie.
- Familien-Isolation: jede Familie sieht nur eigene Daten (verbundweit), außer Super-Admin.
- **Keine NEUEN externen Libraries/Dienste ohne ausdrückliche Absprache.**
  Bereits abgestimmt und erlaubt: Supabase (Backend), Resend (Mail), per CDN
  `@supabase/supabase-js@2`, d3.js, **`jspdf` + `svg2pdf.js`** (ausschließlich für den
  PDF-/Druck-Export), **`marked`** (ausschließlich für das Markdown-Rendering der
  mehrsprachigen Lebensgeschichten; vom User ausdrücklich freigegeben) sowie **`leaflet@1.9.4`**
  (ausschließlich für die Ereignis-Karte / Migrationskarte; vom User ausdrücklich freigegeben).
  Alle von `cdn.jsdelivr.net` (CSP `script-src` deckt das bereits ab), exakt versions-gepinnt + SRI.
  **Leaflet braucht zusätzliche CSP-Quellen** (in [stammbaum.html] bereits gesetzt): `style-src`
  → `cdn.jsdelivr.net` (leaflet.css), `img-src` → `*.tile.openstreetmap.org` (OSM-Tiles),
  `connect-src` → `nominatim.openstreetmap.org` (Geocoding-`fetch`). **Karten-Tiles =
  OpenStreetMap, Geocoding = Nominatim — beide KEIN API-Key** (passt zu GitHub Pages); Nominatim
  ist **rate-limit-gebunden** (max ~1 Anfrage/s) → Aufrufe IMMER debounced + Mindestabstand
  (siehe `geoSucheAusfuehren`). **Marker sind CSS-DivIcons** (kein externes Marker-Bild) — daher
  KEINE weitere `img-src`-Quelle nötig; nicht auf Leaflets Standard-PNG-Icons zurückbauen.
  **Markdown-Ausgabe wird IMMER serverfrei nachgesäubert** (`geschCleanElement`, Whitelist-
  Sanitizer im Haupt-Script) — KEIN zweites Dependency wie DOMPurify; `marked`-Output nie
  ungefiltert ins DOM. Frontend bleibt Vanilla (kein Framework/Build-Tool).
- Direkte Blutlinie (Tanasije → Simo → Marko) ist immer der zentrale vertikale Hauptstrang
- **Aktuellen Stammbaum NIE automatisch wechseln:** Nach Speichern/Bearbeiten/Hochladen/Löschen
  bleibt der Nutzer im aktuell geöffneten Baum. `ladeBaumDaten` behält `aktuellerStammbaumId`
  (statt auf `groessterStammbaum()` zu springen); nur wenn keiner gewählt ist, wird der zuletzt
  geöffnete aus `localStorage('vidovic_tree')` wiederhergestellt (Reload), sonst der größte Baum.
  `waehleStammbaum` persistiert die Auswahl in `localStorage`.
- Rollen-System: **Super-Admin / Familien-Owner / Familien-Admin / Familienmitglied (nur Lesezugriff)**
  - `super_admin`: Betrieb/Wartung, Vollzugriff. **In der GUI für normale Nutzer unsichtbar**
    (nur im eigenen Login-Badge erkennbar).
  - `familien_owner`: Eigentümer eines Stammbaums (der Ersteller). Admin-Rechte + EXKLUSIV
    Stammbaum löschen/anlegen. Nicht über normale Rollenänderung vergeb-/entfernbar.
    **Ausnahme – Owner-Übertragung durch Super-Admin:** Nur der `super_admin` kann den
    `familien_owner` gezielt übertragen (Abschnitt „Vlasnik porodičnog stabla / Familien-Owner"
    in „Podešavanje porodice", für normale Nutzer/Admins/Mitglieder unsichtbar). Über
    RPC `stammbaum_owner_wechseln`: neuer Nutzer → `familien_owner` (Mitgliedschaft wird bei
    Bedarf angelegt, `auto=false`); bisheriger Owner → automatisch `familien_admin`
    (`auto=false`). Owner hängt an der **Familie** → ein Wechsel gilt für ALLE Bäume der
    Familie. Protokollierung in `familien_audit` (`aktion='owner_wechsel'`: Stammbaum, alter/
    neuer Owner, Datum, ausführender Super-Admin). Kandidaten: aktive Mitglieder des
    **gesamten Verbunds** (verwandte Familien, ohne super_admin & aktuellen Owner) ODER per
    E-Mail gesuchte registrierte Nutzer (RPCs `stammbaum_owner_kandidaten`/`owner_nutzer_suche`).
    DB-Datei: `supabase_owner_wechsel.sql`.
  - `familien_admin`: verwaltet Baum/Mitglieder, darf NICHT löschen, keinen Owner ändern.
  - `familien_mitglied`: nur Lesen.
- **Blutlinien-Rechte (additiv, auto):** Wird ein Konto mit einer Baum-Person verknüpft
  (`personen.user_id`, z. B. bei Anfrage-Genehmigung), bekommen automatisch ALLE Familien der
  **direkten Blutlinie** (Vorfahren + Nachkommen über `elternteil`-Kanten, **nur eigener Verbund**)
  die Rolle `familien_admin`. Streng **additiv**: `familien_owner` und **manuell** gesetzte Rollen
  (`mitgliedschaften.auto = false`) werden NIE überschrieben/herabgestuft; nur `auto = true`-Rollen
  werden neu berechnet/entzogen. Neuberechnung läuft **automatisch** bei Baumänderungen (DB-Trigger
  auf `personen`/`beziehungen`) sowie bei Verknüpfung. „Familie" = `familien`-Zeile (Nachnamen-Baum),
  NICHT konto-/verbundübergreifend (Isolation bleibt gewahrt).

## Design-Regeln (IMMER einhalten)
- Edles, nobles Design — dunkles Farbschema, Serifenschriften, Gold-Akzente
- Konsistent mit bestehendem Stil (Bild4.jpg als Hintergrundbild auf #baum-container)
- Mobile-first: jede Änderung muss auf Smartphone funktionieren (< 480px)
- Mehrsprachig: DE / SR / HR / BA / EN — Texte nie hardcoden, immer i18n verwenden.
  Technisch: Schlüssel in ALLEN 5 `TEXTE`-Blöcken pflegen; Zugriff über `t(key, vars)`;
  Personennamen über `nm()` (wird bei 'sr' nach Kyrillisch transliteriert).
- Bei der Umsetzung immer sicherstellen, dass alle sichtbaren Inhalte korrekt in alle Sprachen übersetzt werden
- **UX-Perspektive IMMER aktiv mitdenken (verbindlich):** Jede Umsetzung (neu ODER Änderung) wird aus
  Nutzersicht bewertet, nicht nur „funktioniert es". Konkret: **visuelle Ordnung** (saubere Ausrichtung/
  Raster statt ragged wrap, gleichmäßige Abstände), **logische Gruppierung + sinnvolle Reihenfolge**
  zusammengehöriger Elemente, **verständliche Beschriftung/Hinweise**, ausreichend **Kontrast + Tap-
  Targets** (≥16px/Touch), keine gedrängten/„technisch korrekt aber unaufgeräumt"-Ergebnisse. Wirkt ein
  Ergebnis unübersichtlich/unordentlich, wird es VOR dem Abschluss aufgeräumt (Layout/Gruppierung/
  Sortierung) — auch ohne expliziten Auftrag. Im Zweifel eine kurze, aufgeräumte Variante vorschlagen.

## Frontend-Komponenten & UI-Konventionen (IMMER einhalten)
- **Styleguide-Pflicht — KEINE nativen Browser-Dialoge (ab v14.34):** Jede UI eines neuen oder
  geänderten Features MUSS dem bestehenden App-Design entsprechen (edel/dunkel/Serif/Gold, edle
  Overlays) — **niemals** die nativen Browser-Dialoge `alert()`/`confirm()`/`prompt()` (sie zeigen
  „127.0.0.1 enthält …", brechen Optik, i18n und Mobile). Verbindliche Bausteine stattdessen:
  **`zeigeHinweis(text)`** (reine Info/Fehler, nur OK), **`zeigeBestaetigung(text, {gefahr, jaText})`**
  (Ja/Nein-Rückfrage, gibt `Promise<boolean>`), Feld-Fehler über `feldFehler(...)`, Toasts/Status-
  Zeilen für nebenläufige Rückmeldungen. Gleiches gilt für alle sichtbaren Elemente: bestehende
  CSS-Klassen/Muster wiederverwenden statt Ad-hoc-Styles; i18n in allen 5 Sprachen; Mobile-/Touch-
  Regeln (≥16px, `pointerdown`, `overscroll`). Vor jedem Commit prüfen: `grep -nE "\bconfirm\(|[^.\w]alert\(|\bprompt\("` liefert im Frontend **nichts**.
- **Overlays/Modals schließen NUR per Button (ab v9.2):** Jedes Voll-Overlay (`.modal`) wird
  ausschließlich über seinen Schließen-Button (× / „Abbrechen") bzw. die zugehörige
  `schliesse…()`-Funktion geschlossen — **NICHT** durch Klick auf den Hintergrund/daneben.
  Daher KEIN `onclick="schliesse…()"` auf dem `.modal`-Backdrop und KEIN generischer
  Außenklick-/`pointerdown`-Schließer für Modals. (Gilt NICHT für kleine Dropdown-/Such-/
  Presence-Panels — die schließen weiterhin per `pointerdown` außerhalb, siehe Dropdowns-Regel.)
- **Dropdowns**: Jedes `<select>` wird automatisch zu einem suchbaren Dropdown
  (`macheAlleSelectsSuchbar`/`init`). Nach dynamischem Befüllen in einem Overlay ggf.
  `macheAlleSelectsSuchbar(overlay)` aufrufen. **Touch-sicher (Android/iOS) — nicht zurückbauen:**
  Außerhalb-Schließen über `pointerdown` (NICHT `click`, sonst schließt der Ghost-Click sofort);
  Auswahl in scrollbaren Listen über `tippAuswahl` (Tap selektiert, Wischen scrollt);
  `resize`/`scroll` schließen Panels NICHT, sondern positionieren neu (mobile Tastatur = Resize).
- **Datumsfelder**: `<input class="login-feld dp-input">` → eigener Vanilla-Kalender. Werte über
  `datumWert`/`datumSetzen`, Anzeige `formatDatumLang` (Speicherung als ISO, siehe Backend-/Daten-
  Regeln). **Kurz-/Eingabeformat = REIHENFOLGE-Präferenz (ab v14.30, kontogebunden):** eigene
  Nutzer-Einstellung `datumsFormat` ∈ {`tmj` = Tag zuerst (Standard) / `mtj` = Monat zuerst},
  gespeichert in `profile.einstellungen.datumsformat` (+ localStorage `vidovic_datumsformat`), im
  Profil-Overlay wählbar (`fuelleProfilDatumsformat`/`setzeDatumsFormat`, instant via onchange). Die
  Reihenfolge ist **von der Sprache ENTKOPPELT** (Bugfix: früher zwang `en` das US-`MM/DD` auf, das
  der Parser nicht verstand → Eingaben abgelehnt). Das **Trennzeichen** bleibt sprachüblich
  (`datumTrenner`: en `/`, sonst `.`), Platzhalter über `datumPlatzhalter`. **Parser
  (`parseDatumZuIso`) ist ordnungs- UND fehlertolerant:** akzeptiert ISO, `.`/`/`/`-` und
  **trennerlos** (8 Ziffern, z. B. `01011999`); `dpAusPaar` deutet die Reihenfolge per Präferenz,
  erkennt aber **automatisch** den Tag, wenn eine Position > 12 ist. Umschalten/Sprachwechsel rendert
  alle offenen Felder neu (`aktualisiereDatumsfelder`). i18n `prof_datumsformat`/`prof_df_*` in allen
  5 Blöcken.
- **Pflichtfelder & Feld-Fehler (app-weit, ab v11):** Jedes Pflichtfeld bekommt am Label die
  Klasse **`.pflicht`** → rotes „ *" hinter der Beschriftung (CSS, sprachneutral — KEINE
  hartcodierten `*` mehr; dynamisch umschaltbar, z. B. Mädchenname nur bei `geschlecht='F'` über
  `pflichtMarkierung`). **Validierungsfehler werden DIREKT am Feld angezeigt, nicht (nur) unten im
  Overlay:** `feldFehler(feldId, t('…'))` setzt roten Rahmen (`.input-fehler`) + Hinweis
  (`.feld-fehler-text`) unter das Feld, **scrollt es in den Blick und fokussiert** es; Helfer geben
  `false` zurück (Muster: `return feldFehler(...)`). Bei **searchable Selects** (`_ssControl`) wird
  automatisch das sichtbare Steuerelement markiert/fokussiert (nicht das `display:none`-`<select>`).
  `feldFokus(feldId)` = nur scrollen+fokussieren (wenn der Hinweis schon am Feld steht, z. B.
  E-Mail-Check `markiereEmailFehler`). `feldFehlerReset(overlayId)` am Anfang jeder Validierung +
  beim Öffnen aufräumen. Generische Meldung `feld_pflicht` in allen 5 Blöcken. **Reine Auswahl-/
  Picker-Overlays** (etn/dub/vb/gp/mv/uk: „mind. eine Person wählen") behalten bewusst die Sammel-
  Box (kein einzelnes Feld zum Anheften). **Server-/Zustandsfehler** ohne Feldbezug bleiben in der
  Box; feldbezogene Serverfehler (z. B. „Name existiert", „aktuelles Passwort falsch") werden ans
  Feld gehängt. Person-Editor: Vorname+Nachname Pflicht; **Mädchenname Pflicht bei Frauen**
  (für [[project_blutlinie_kappung]]).
- **Sprachwechsel**: `wechselSprache` MUSS dynamisch gerenderte Inhalte/Dropdowns neu aufbauen
  (Stammbaum-Dropdown, Orientierungs-Banner, offene Overlays wie Mitglieder/Kosten/Obavještenja).
  Neue dynamische Listen dort einhängen — sonst bleiben sie nach Sprachwechsel in der alten Sprache.
- **Session/Aktualität**: Auto-Logout nach 30 Min Inaktivität (Warnung 1 Min vorher); nach
  Re-Login harter Reload (`hardReload` = `?v=timestamp`, umgeht den HTML-Cache); Update-Banner bei
  neuer `app-version`. Diese Logik bei UI-Änderungen nicht brechen.
## Backend- & Daten-Regeln (Supabase) — IMMER einhalten
- **Referenzielle Integrität bei Anlegen UND Löschen.** Jede Aktion, die Daten erzeugt oder
  entfernt, muss ALLE betroffenen Tabellen konsistent halten — keine verwaisten Zeilen:
  - **Löschen** (Person/Stammbaum/Mitglied/Familie): zugehörige Zeilen in
    `beziehungen`, `personen`, `stammbaeume`, `mitgliedschaften`, `familien`,
    `registrierungs_anfragen` (und ggf. `auth.users`) in FK-sicherer Reihenfolge mit
    abräumen (Kinder vor Eltern). Referenz: `stammbaum_loeschen` löscht den letzten Baum
    samt Familie + Mitgliedschaften. Event-Daten (`events`, `event_teilnehmer`, `event_kosten`)
    hängen per `ON DELETE CASCADE` am Event/Baum.
  - **Nicht-DB-Stores nicht vergessen:** Event-**Medien** liegen im **Storage-Bucket `events`**
    (Ordner je Event-id) und werden NICHT per CASCADE entfernt → beim Event-/Baum-Löschen im
    Frontend mit `loescheEventMedien` mit-abräumen (sonst verwaiste Storage-Dateien).
  - **Anlegen**: alle Pflicht-Verknüpfungen setzen (`familie_id`, `stammbaum_id`,
    Owner-/Mitgliedschaft), damit nichts „losgelöst" entsteht (z. B. Person ohne
    `stammbaum_id` taucht sonst nicht im Baum-Dropdown auf).
  - **Schutz**: Familien mit `super_admin`-Mitgliedschaft (Haupt-Account) nie automatisch löschen.
- Schreib-/Lösch-Logik bevorzugt über **SECURITY-DEFINER-RPCs** mit expliziter Rechteprüfung.
  RLS auf `mitgliedschaften` muss **rekursionsfrei** bleiben (SELECT-Policy ohne Subquery auf
  dieselbe Tabelle). Frontend prüft den Erfolg echt (RPC-Rückgabe/Fehler) und zeigt nie
  Änderungen an, die nicht gespeichert wurden.
- Kein Hardcode-Check auf eine bestimmte Wurzelperson (z. B. I500009) — sonst sehen fremde
  Konten ihre eigenen Daten nicht.
- Datumswerte gehören in `stammbaum_daten` (jsonb), **kanonisch als ISO `YYYY-MM-DD`** (Eingabe
  über Datumsfelder mit Klasse `dp-input` = Vanilla-Kalender; Lesen/Schreiben via
  `datumWert`/`datumSetzen`, Anzeige via `formatDatumLang`; nicht-parsebare Altwerte bleiben
  Freitext, Migration lazy beim nächsten Speichern). Die `date`-Spalte `geburtsdatum` bleibt NULL
  (sonst Fehler 22008). `geschlecht`-Spalte bleibt NULL (CHECK); sex in `stammbaum_daten`.
- `supabase/.env` (RESEND_API_KEY etc.) ist gitignored und darf NIE committet werden.

## Arbeitsumgebung & Sicherheit (Unternehmens-Defender) — IMMER einhalten
- Dies ist ein **Unternehmensrechner mit aktivem Defender/EDR**. Bestimmte Shell-Muster
  lösen **Sicherheitsalarme** aus und sind daher zu **vermeiden**:
  - **Keine** PowerShell-Aufrufe mit `-EncodedCommand`/`-enc`, `-NoProfile`, `-NonInteractive`,
    `-WindowStyle Hidden`, `-ExecutionPolicy Bypass` o. ä. „verschleiernden"/non-interaktiven Flags.
  - **Keine** Befehle als **versteckte Hintergrund-Prozesse** starten, wenn nicht nötig.
  - Base64-/verschleierte Kommandos, Remote-Download-und-Ausführen-Einzeiler etc. **nicht** verwenden.
- Stattdessen: **dedizierte Tools** nutzen (Read/Write/Edit/Glob/Grep statt cat/sed/find/echo),
  einfache, lesbare, **interaktiv nachvollziehbare** Befehle. Für POSIX-Skripte das Bash-Tool
  bevorzugen. Git/npm/gh normal und sichtbar ausführen.
- Wenn eine Aufgabe sich nur mit einem solchen geflaggten Muster lösen ließe: **NICHT selbst
  ausführen**. Stattdessen dem User die **exakten Befehle/Schritte** bereitstellen — **er führt
  sie manuell aus**. (Claude führt solche Aufgaben grundsätzlich nicht im Hintergrund/automatisch aus.)

## Deploy & Versionierung
- **Branch pro Änderung + Test-Freigabe (verbindlich ab v14.86) — Details: `docs/workflow-branching-versionierung.md`:**
  1. **Jede** Änderung (Bug ODER Story) läuft auf einem **eigenen Branch** (`bugfix/…`, `feature/…`,
     `docs/…`), abgezweigt von aktuellem `main` — **nie direkt auf `main` arbeiten**.
  2. Auf dem Branch wird **zuerst lokal getestet** (Test-Pflicht aus „Dein Arbeitsablauf"),
     Ergebnis dem User als PASS/FAIL vorgelegt. Test rot → kein Commit, erst beheben.
  3. **Commit/Merge/Push NUR nach ausdrücklicher Freigabe des Users.** „Test grün" ist keine
     Freigabe. Nur den zur Aufgabe gehörenden Hunk stagen, nie blind ganze Dateien.
- **Versions-Schema `XX.XX` = MAJOR.STORY.BUG** (zwei Nachkommastellen = zwei Zähler):
  **Bug** → letzte Stelle +1 (`14.86`→`14.87`; bei `…x9` Übertrag: `14.89`→`14.90`).
  **Story** → vorletzte Stelle +1, letzte auf 0 (`14.86`→`14.90`; bei `…9x` Übertrag: `14.96`→`15.00`).
  **Ab der 3. Story ohne Deployment dazwischen** → MAJOR +1, Rest auf `00` (`14.40`→`15.00`).
  Zähler „Storys seit Deploy" bei jedem Deployment zurücksetzen. Version erst im Freigabe-Schritt
  vergeben (nicht vorab auf dem Branch — sonst kollidieren parallele Branches).
- **Frontend**: Commit nach `main` → automatisch live auf GitHub Pages. Commits als „Version X.Y - …".
- **Bei JEDEM Frontend-Deploy `<meta name="app-version" content="X.Y">` im `<head>` hochzählen**
  (passend zur Commit-Versionsnummer). Die App vergleicht diese Version regelmäßig mit der
  Server-Version und zeigt sonst KEIN „neue Version verfügbar"-Banner. Vergisst man das Hochzählen,
  bemerken Nutzer neue Releases nicht aktiv.
- **Ausgelagerte Dateien Cache-Busting (ab Phase-2…4-Refactor):** Aus `stammbaum.html` wurden
  ausgelagert (jeweils als gleichrangige Datei im selben Verzeichnis, eingebunden mit `?v=X.Y`):
  - **`stammbaum.css`** — der frühere `<style>`-Block (`<link rel="stylesheet" href="stammbaum.css?v=X.Y">`).
  - **`i18n.js`** — `TEXTE` + `RECHTSTEXTE` als globale `const`, **vor** dem Haupt-Script geladen.
    i18n-Texte werden jetzt hier gepflegt (weiterhin alle 5 Sprachen). **Schlüssel-Parität prüfen:**
    `node i18n_lint.js` (meldet je Sprache fehlende Keys; idealerweise vor jedem Commit).
  - **`pdf_export.js`** — **AUSGELAGERT ab v14.3.** Kompletter Stammbaum-PDF-/Druck-Export
    (`pdf*`-Funktionen + `PDF_*`-Konstanten) als eigene Datei, eingebunden mit
    `<script src="pdf_export.js?v=X.Y">` **vor** dem Haupt-Inline-`<script>` (definiert globale
    `pdf*`/`PDF_*`; der **Kosten-/Troskovi-PDF** im Haupt-Script nutzt `pdfEl`/`pdfSvgZuCanvas`/
    `pdfDownloadBlob`/`PDF_SVG_NS` daraus). Ruft Haupt-Globals (`t`, `d3`, `aktuelleWurzel`, …) erst
    zur Laufzeit auf. **`jsPDF`/`svg2pdf` werden LAZY** über `ladePdfLib()` geladen (ab v14.2 nicht
    mehr eager im `<head>`); `pdf_export.js` selbst lädt eager (klein, ~30 KB), da der Kosten-PDF
    dessen Helfer jederzeit braucht.
  - **`chat.js`** — **AUSGELAGERT ab v14.4.** 1:1-/Gruppen-Chat (alle `chat*`-Funktionen + -State),
    `<script src="chat.js?v=X.Y">` **vor** dem Haupt-Script. `startChat()`/`stopChat()` werden im
    Login-/Logout-Flow gerufen, `chatSpracheUpdate()` aus `wechselSprache` (typeof-Guard); ruft
    Haupt-Globals (`sbClient`, `aktuellerUser`, `t`, `nm`, …) erst zur Laufzeit auf.
  - **Beim Deploy IMMER zusätzlich zur `app-version` auch das `?v=` an ALLEN ausgelagerten Dateien
    (`stammbaum.css`, `i18n.js`, `pdf_export.js`, `chat.js`)** auf dieselbe Version ziehen — sonst
    liefert GitHub Pages die ausgelagerte Datei veraltet aus (`hardReload`/`?v=timestamp` bricht nur
    den HTML-Cache, nicht die Sub-Ressourcen).
  - Reihenfolge: die ausgelagerten `<script>` (i18n.js, pdf_export.js) müssen **vor** dem
    Haupt-Inline-`<script>` stehen (globale `const`/Funktionen). Der `init();`-Bootstrap bleibt am
    Ende des Haupt-Scripts. `split_i18n.js`/`split_css.js`/`split_pdf.js` waren Einmal-Auslagerungs-
    werkzeuge (können entfallen); `i18n_lint.js` bleibt nützlich.
- **DB-Änderungen**: als idempotente `.sql`-Datei im Repo ablegen → im Supabase SQL-Editor ausführen.
  **SQL-Index/Reihenfolge für eine frische DB:** siehe `SCHEMA.md`. Einmal-/Vorfall-Skripte
  (Diagnose/Reparatur/Restore/konto-spezifisch) liegen unter `sql_archiv/` und gehören NICHT
  zum Neuaufbau.
- **Edge Functions**: über das Supabase-Dashboard deployen (Supabase-CLI durch Citrix-Firewall blockiert).
- **Code-Review + Code-Test VOR JEDEM Deployment (PFLICHT):** Bevor committet/veröffentlicht wird,
  IMMER zuerst
  1. **Code-Review** der anstehenden Änderung (Diff): Korrektheit, Seiteneffekte auf andere
     Komponenten, Einhaltung aller CLAUDE.md-Regeln (i18n in allen 5 Sprachen, RLS/Rechte,
     referenzielle Integrität, Mobile/Touch, Realtime-Invarianten). Findbare Bugs/Schwachstellen
     werden VOR dem Deploy behoben, nicht danach.
  2. **Code-Test**: die Änderung tatsächlich prüfen — `node i18n_lint.js` bei Textänderungen,
     betroffene Flows am Code (und wo möglich real) durchspielen, DB-`.sql` auf Idempotenz/FK-
     Reihenfolge gegenlesen. Ergebnis explizit benennen (was geprüft, was nur 🔬 am Gerät final
     verifizierbar). Schlägt ein Test fehl, wird das ehrlich gemeldet und NICHT deployt.
  Erst wenn Review UND Test sauber sind, wird der Deploy (Commit/Version-Bump/`?v=`) vorbereitet.
- **Push/Commit nur auf ausdrückliche Anweisung** des Users; vorher kein Veröffentlichen.

## Dein Arbeitsablauf (Loop)

- **TEST-PFLICHT bei JEDER Änderung (verbindlich, keine Ausnahme):** Jede Änderung wird VOR der
  Fertigmeldung **sowohl aus UX- als auch aus technischer Sicht gründlich geprüft UND getestet** —
  nicht nur „sieht plausibel aus". Konkret:
  - **Testfälle wirklich AUSFÜHREN, nicht nur beschreiben:** die relevanten Prüfungen tatsächlich
    laufen lassen (`node --check` des Hauptskripts bei JS-Änderungen, `node i18n_lint.js` bei
    Textänderungen, ausführbare Logik per Node/Script durchspielen — z. B. Token-/Parser-/Berechnungs-
    Logik mit echten Eingaben und Grenz-/Fehlerfällen, SQL auf Idempotenz/FK-Reihenfolge gegenlesen).
    Was nur auf echtem Gerät/nach Deploy final verifizierbar ist, wird als 🔬 gekennzeichnet.
  - **UX-Test:** der Flow wird aus Nutzersicht durchgespielt (Bedienbarkeit, Ordnung/Gruppierung,
    Beschriftung, Kontrast/Tap-Targets, Mobile Android+iOS, i18n in allen 5 Sprachen) — siehe Schritt 3.
  - **Ergebnis KURZ vorstellen:** Am Ende jeder Änderung dem Nutzer knapp präsentieren, **welche
    Testfälle ausgeführt wurden und mit welchem Ergebnis** (PASS/FAIL je Fall, kurze Tabelle/Liste),
    was am Code geprüft und was nur 🔬 am Gerät/Deploy verifizierbar ist. Schlägt ein Test fehl, wird
    das ehrlich gemeldet und der Fehler VOR der Fertigmeldung behoben — kein „grün gemeldet, ungetestet".

Nach JEDER Änderung:
1. Prüfe selbst: Gibt es Seiteneffekte auf andere Komponenten?
2. Prüfe: Hält die Lösung alle Design-Regeln ein (inkl. i18n in allen 5 Sprachen)?
3. **Mobile-/Geräte-Test (PFLICHT bei JEDER Featureumsetzung):** Jedes neue oder geänderte
   Feature wird virtuell auf **Android UND iOS** durchgetestet — Felder, UX und Funktion. Mindestens
   am Code abzuprüfen (echtes Gerät wo möglich zusätzlich):
   - **Felder:** korrekter `type`/`inputmode` (Mobile-Tastatur), `autocomplete` sinnvoll;
     **iOS-Input-Zoom vermeiden** — fokussierbare Felder dürfen mobil NICHT < 16px sein
     (sonst zoomt iOS Safari rein und nicht zurück; Regel am Ende des `<style>`-Blocks gewinnt).
   - **Touch/UX:** Tap-Targets groß genug; Schließen/Auswahl über `pointerdown`/`tippAuswahl`
     (nicht `click`); `overscroll-behavior: contain` auf scrollbaren Overlays (kein Hintergrund-
     Scroll-Durchgriff); offene Panels bei resize/scroll neu positionieren statt schließen
     (mobile Tastatur = Resize).
   - **Viewport/Layout:** Hoch- UND Querformat < 480px; keine `vh`-Falle/erzwungener Überlauf;
     fixe Elemente nicht von Notch/Tastatur verdeckt.
   - **Funktional:** der Flow funktioniert mit Touch end-to-end; i18n in allen 5 Sprachen sichtbar.
   Im Ergebnis explizit benennen, was am Code geprüft wurde und welche Punkte nur auf echtem Gerät
   endgültig verifizierbar sind (🔬).
4. Prüfe (bei Daten): Sind nach Anlegen/Löschen alle Tabellen konsistent (keine verwaisten Zeilen)?
5. Prüfe (Governance): Weicht etwas von CLAUDE.md ab? Falls ja, Hinweis geben (siehe Governance).
6. Gib Selbsteinschätzung: ✅ alles ok / ⚠️ Kompromiss nötig / ❌ Problem gefunden
7. Schlage den logisch nächsten Schritt vor
8. **ToDo-Liste „Was DU noch erledigen musst" (verbindlich, am ENDE jeder Antwort):** Alles, was
   ich **nicht selbst ausführen kann oder darf**, wird am Schluss als **eigener Abschnitt**
   aufgelistet — nie nur im Fließtext erwähnt und nie stillschweigend vorausgesetzt. Pflicht-Inhalte:
   - **SQL-Dateien**, die im **Supabase SQL-Editor** auszuführen sind (DB-Änderungen laufen nie
     automatisch) — inkl. Hinweis, ob idempotent/wiederholbar und in welcher **Reihenfolge**.
   - **Edge Functions**, die übers **Supabase-Dashboard** zu deployen sind (CLI ist durch die
     Citrix-Firewall blockiert).
   - **Commit/Merge/Push + Version-Bump** (`app-version` **und** alle `?v=`), da nur auf
     ausdrückliche Freigabe.
   - **Befehle, die ich wegen Defender/EDR nicht ausführe** (siehe „Arbeitsumgebung & Sicherheit") —
     exakt in ausführbarer Form.
   - **🔬-Punkte**, die nur am echten Gerät/nach Deploy verifizierbar sind.
   - Sonstige manuelle Schritte (Storage-Buckets/Policies, Confluence/Jira, Secrets/`.env`,
     Rechte-/Rollen-Änderungen, externe Dienste wie Resend).
   **Jeder Punkt verlinkt die betroffene(n) Datei(en)** als klickbaren relativen Pfad im
   Markdown-Format `[datei.sql](datei.sql)` (bei Bedarf mit Zeilenangabe `[datei.js:42](datei.js#L42)`)
   — damit sofort auffindbar ist, worauf sich der Schritt bezieht. Ist **nichts** offen, wird das
   ausdrücklich vermerkt („Keine offenen ToDos für dich") statt den Abschnitt wegzulassen.

## Gilt für ALLE Prompts (Claude Code automatisch beachten)

- **Architektur:** Single-File-Stack (stammbaum.html/.css/i18n.js; PDF-Export derzeit inline in
  stammbaum.html), Supabase
  (Postgres + Auth + Storage + Edge Functions + RLS). Mandanten: `familien` → `stammbaeume` →
  `personen`, Föderation über `verbund_id`. Rollen in `mitgliedschaften`
  (super_admin/familien_owner/familien_admin/familien_mitglied). Konto↔Person über `_userId`.
- **Vor jedem Feature ZUERST** den vorhandenen ähnlichen Code inspizieren und dessen Muster
  übernehmen: `benachrichtigungen`, `registrierungs_anfragen`, Event-System (`event_*`),
  Media-Upload/Storage-Policies, Presence/Realtime (`startRealtimeSync`), `verbund_nutzer()`,
  die rekursionsfreien SECURITY-DEFINER-RLS-Helfer.
- **DATENSCHUTZ/KINDERSCHUTZ (hart, für jedes Social-Feature):** Alle sozialen Inhalte (Feed,
  Beiträge, Kommentare, Reaktionen, Markierungen, Fragen, Aufnahmen) sind STRIKT verbund-gebunden –
  niemals verbundübergreifend sichtbar, außer es existiert eine ausdrückliche Freigabe aus dem
  Kontakt-/Baumzugriff-Feature. **Soziale Inhalte** über lebende Personen und Minderjährige werden NIE
  außerhalb des Verbunds exponiert — **einzige Ausnahme:** die vier Discovery-Minimalfelder
  (`personen_entdecken`) einer ausdrücklich opt-in-freigegebenen, **volljährigen** lebenden Person
  bzw. eine freigegebene Kontakt-/Baumzugriff-Verbindung (v13.1). Minderjährige bleiben IMMER
  ausgeschlossen. Reaktionen/Kommentare erben die Lese-Grenze ihres Zielobjekts.
- **CLAUDE.md durchgängig:** keine neue Library ohne Freigabe; idempotente `.sql` im Repo (Supabase
  SQL-Editor), Edge Functions übers Dashboard; RLS rekursionsfrei (SECURITY DEFINER); Modal nur per
  Button, kleine Panels via pointerdown; i18n alle neuen Texte in ALLEN 5 Sprachen (DE/SR/HR/BA/EN)
  + `node i18n_lint.js`; mobile-first (≥16px, Touch, overscroll); Live-Reload behält Fokus und
  setzt den Auto-Logout-Timer NICHT zurück; Deploy = app-version + `?v=` an i18n.js/CSS; Push/Commit
  nur auf Anweisung. Jeden Loop mit Selbsteinschätzung ✅/⚠️/❌ + nächstem Schritt abschließen.

## Feature-Dokumentation (Details unter docs/)
Vor der Arbeit an einem Feature die passende Datei lesen; neue Features nach obiger Regel als eigene Datei ergänzen.

- `docs/realtime-kollaboration.md` — Live-Sync der Baumdaten, Presence/Live-Indikator, Soft-Lock, Konflikterkennung (P1–P5), Obavještenja-Polling.
- `docs/profil-konten-mitglieder.md` — Benutzerprofil (Phase 1/2, Sicherheitsbereich), „Meine Person" (Konto↔Karte, Self-Service), Profil↔Karte-Sync, Mitglieder-Verwaltung & Benutzer↔Karte-Zuweisung.
- `docs/baum-struktur-blutlinie.md` — Beziehung ändern/umhängen, Auto-Zweigbaum bei Heirat, abweichender Nachname, Geschwister-Platzhalter, Kind-Sichtbarkeit, Blutlinien-Kappung, Baum-Name/Zusatz, Gleiche-Person/Dubletten-Merge, Auto-Löschung leerer Bäume.
- `docs/ansichten-pdf.md` — personalisierte Standard-/Ausschnitts-Ansicht, „Alle Verwandten / Netz", PDF-/Druck-Export.
- `docs/medien-galerie-dokumente.md` — Karten-Avatar aus Profilbild, Foto-Galerie, Dokumente & Quellen, Sprach-/Video-Aufnahmen, mehrsprachige Lebensgeschichten.
- `docs/ereignisse-anlaesse.md` — Geburtstags-/Gedenktag-Erinnerungen (In-App + E-Mail), Ereignis-Bereich (Liste/Zeitstrahl/Karte + Migrationspfad).
- `docs/social-chat-feed.md` — Kochbuch-Bewertungen, Chat (1:1/Gruppe), verbundübergreifende Personensuche/Kontakte, Reaktionen & Kommentare, Familien-Feed/Aktivitäten, Foto-Tagging, Familien-Fragen.
- `docs/board-modus.md` — **KONZEPT/SPEC (noch nicht implementiert)**: Miro-artiger Board-Modus (`ansichtModus='board'`) zum freien Verschieben von Karten (Persistenz via eigener Tabelle `board_layout`, ein gemeinsames Board pro Baum, Leser statisch, ganzer Baum) + Verknüpfen per Linie mit Auto-Erkennung (Eltern/Partner/Kind/Geschwister) über `verknuepfung_anfragen`. Entscheidungen festgelegt; Umsetzungsplan P2 (Verschieben)/P3 (Verknüpfen).
- `docs/jira-anbindung.md` — Jira/Atlassian-MCP-Anbindung: Einrichtung (`claude mcp add --scope user`, OAuth NUR im Terminal), Projekt `SCRUM`, Workflow-Spalten + Transition-IDs (Backlog/Zu erledigen/In Bearbeitung/Test/Erledigt), verbindlicher Ablauf je Vorgang (max. 1 pro Durchlauf, „nicht raten → Rückfrage als Jira-Kommentar"), die drei Modi **A Jira-Dev** (`.claude/agents/jira-dev.md`, umsetzen) / **B Ticket-Autor** (Idee → Vorgang) / **C Story-Refiner** (`.claude/agents/story-refiner.md`, Backlog ausarbeiten → „Zu erledigen", ohne Code), Commit-Politik, bewusste Grenzen.
- `docs/workflow-branching-versionierung.md` — **Arbeits-Workflow (verbindlich ab v14.86):** Branch pro Änderung (`bugfix/`/`feature/`/`docs/`), lokaler Test VOR jedem Commit (Testmatrix + PASS/FAIL-Vorlage), Commit/Merge/Push nur nach ausdrücklicher Freigabe, Versions-Schema `XX.XX` (Bug = letzte Stelle, Story = vorletzte + Reset, 3. Story ohne Deploy = MAJOR) inkl. Überlauf-Beispielen.
- `ROADMAP.md` — Roadmap-Kontext & Ausblick.
