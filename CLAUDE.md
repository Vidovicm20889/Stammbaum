# Stammbaum Vidović — Projektkontext für Claude Code

## Projekt
Interaktive Familienstammbaum-Webapp für die Familie Vidović.
GitHub Pages: vidovicm20889.github.io/Stammbaum/stammbaum.html
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

## Design-Regeln (IMMER einhalten)
- Edles, nobles Design — dunkles Farbschema, Serifenschriften, Gold-Akzente
- Konsistent mit bestehendem Stil (Bild4.jpg als Hintergrundbild auf #baum-container)
- Mobile-first: jede Änderung muss auf Smartphone funktionieren (< 480px)
- Mehrsprachig: DE / SR / HR / BA / EN — Texte nie hardcoden, immer i18n verwenden.
  Technisch: Schlüssel in ALLEN 5 `TEXTE`-Blöcken pflegen; Zugriff über `t(key, vars)`;
  Personennamen über `nm()` (wird bei 'sr' nach Kyrillisch transliteriert).
- Bei der Umsetzung immer sicherstellen, dass alle sichtbaren Inhalte korrekt in alle Sprachen übersetzt werden

## Frontend-Komponenten & UI-Konventionen (IMMER einhalten)
- **Dropdowns**: Jedes `<select>` wird automatisch zu einem suchbaren Dropdown
  (`macheAlleSelectsSuchbar`/`init`). Nach dynamischem Befüllen in einem Overlay ggf.
  `macheAlleSelectsSuchbar(overlay)` aufrufen. **Touch-sicher (Android/iOS) — nicht zurückbauen:**
  Außerhalb-Schließen über `pointerdown` (NICHT `click`, sonst schließt der Ghost-Click sofort);
  Auswahl in scrollbaren Listen über `tippAuswahl` (Tap selektiert, Wischen scrollt);
  `resize`/`scroll` schließen Panels NICHT, sondern positionieren neu (mobile Tastatur = Resize).
- **Datumsfelder**: `<input class="login-feld dp-input">` → eigener Vanilla-Kalender,
  sprachabhängiges Format. Werte über `datumWert`/`datumSetzen`, Anzeige `formatDatumLang`
  (Speicherung als ISO, siehe Backend-/Daten-Regeln).
- **Sprachwechsel**: `wechselSprache` MUSS dynamisch gerenderte Inhalte/Dropdowns neu aufbauen
  (Stammbaum-Dropdown, Orientierungs-Banner, offene Overlays wie Mitglieder/Kosten/Obavještenja).
  Neue dynamische Listen dort einhängen — sonst bleiben sie nach Sprachwechsel in der alten Sprache.
- **Session/Aktualität**: Auto-Logout nach 30 Min Inaktivität (Warnung 1 Min vorher); nach
  Re-Login harter Reload (`hardReload` = `?v=timestamp`, umgeht den HTML-Cache); Update-Banner bei
  neuer `app-version`. Diese Logik bei UI-Änderungen nicht brechen.
- **Obavještenja Live-Updates**: Badge + Liste aktualisieren sich ohne Reload per **Polling**
  (`startObavPolling`/`stopObavPolling`/`obavLivePoll`, ~12 s; pausiert bei verstecktem Tab,
  sofort-Refresh bei `visibilitychange`). Polling läuft NUR für eingeloggte Admins und darf den
  Inaktivitäts-Timer NICHT zurücksetzen (sonst kein Auto-Logout). Bewusst Polling statt Supabase
  Realtime: `registrierungs_anfragen` wird über SECURITY-DEFINER-RPCs gelesen (kein direktes
  RLS-SELECT) → Realtime würde solche Zeilen nicht ausliefern.
- **Mitglieder-Verwaltung – Familien-Dropdown**: Die Familienliste im „Upravljanje članovima"-
  Overlay kommt aus der rollenbasierten RPC `verwaltbare_familien` (super_admin = ALLE Familien,
  owner/admin = eigene) — NICHT aus den Mitglieder-Zeilen ableiten (sonst fehlen Familien ohne
  Mitglieder). Das Frontend filtert die gelieferte Liste nicht zusätzlich.

## Architektur-Regeln
- **Keine NEUEN externen Libraries/Dienste ohne ausdrückliche Absprache.**
  Bereits abgestimmt und erlaubt: Supabase (Backend), Resend (Mail), per CDN
  `@supabase/supabase-js@2` und d3.js. Frontend bleibt Vanilla (kein Framework/Build-Tool).
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
- **Auto-Zweigbaum bei Heirat (neuer Nachname → neuer Stammbaum):** Entsteht beim Anlegen
  eines **Partners** ein NEUER Nachname (Partner-Nachname ≠ Nachname der heiratenden Person und
  im Verbund noch kein Baum dieses Namens), bietet die App **mit Bestätigung** („Vorschlag",
  kein Automatismus) an, für diese Linie einen eigenen Stammbaum anzulegen. Der neue Baum
  entsteht in **DERSELBEN Familie** (gleicher Verbund → Sichtbarkeit/Rechte automatisch,
  Isolation gewahrt; **kein separater Owner pro Baum** — Owner hängt an der Familie). Personen
  werden **nicht verschoben/kopiert**, sondern als **gleiche Person** über `personen.identitaet_id`
  in den neuen Baum **gespiegelt** (beide Karten bleiben sichtbar; Biografie hält der Trigger
  `ident_sync` synchron). Wurzel des neuen Baums = eingeheirateter Partner; gespiegelt werden
  zudem der/die Ehepartner:in und die **zum Anlegezeitpunkt vorhandenen** gemeinsamen Nachkommen
  (rekursiv, nur Quellbaum) inkl. deren Partner; Beziehungen werden zwischen den Spiegelkarten
  neu aufgebaut. Der **aktuell geöffnete Baum wird NICHT gewechselt** (`ladeBaumDaten` behält ihn),
  nur die Baumliste/der Dropdown wird aktualisiert. RPC `stammbaum_zweig_aus_heirat(p_wurzel,
  p_partner, p_name)` (SECURITY DEFINER, Rechte-/Existenzprüfung via `kann_familie_bearbeiten`/
  `merge_norm`), DB-Datei `supabase_stammbaum_zweig_heirat.sql`. **Bewusste v1-Grenze:** NACH dem
  Anlegen ergänzte Nachkommen werden (noch) nicht automatisch nachgespiegelt — Ausbauschritt wäre
  ein Sync-Trigger auf `beziehungen`.
- Familien-Isolation: jede Familie sieht nur eigene Daten (verbundweit), außer Super-Admin.
- Datenmodell: `familien` = Konto/Mandant; `stammbaeume` = Bäume (familie_id); `personen`/
  `beziehungen` referenzieren `stammbaum_id`/`familie_id`. Rollen liegen in `mitgliedschaften`
  (user_id + familie_id + rolle). Sichtbarkeit/Verknüpfung über `verbund_id` der Familie.

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
- **Frontend**: Commit nach `main` → automatisch live auf GitHub Pages. Commits als „Version X.Y - …".
- **Bei JEDEM Frontend-Deploy `<meta name="app-version" content="X.Y">` im `<head>` hochzählen**
  (passend zur Commit-Versionsnummer). Die App vergleicht diese Version regelmäßig mit der
  Server-Version und zeigt sonst KEIN „neue Version verfügbar"-Banner. Vergisst man das Hochzählen,
  bemerken Nutzer neue Releases nicht aktiv.
- **DB-Änderungen**: als idempotente `.sql`-Datei im Repo ablegen → im Supabase SQL-Editor ausführen.
- **Edge Functions**: über das Supabase-Dashboard deployen (Supabase-CLI durch Citrix-Firewall blockiert).
- **Push/Commit nur auf ausdrückliche Anweisung** des Users; vorher kein Veröffentlichen.

## Dein Arbeitsablauf (Loop)
Nach JEDER Änderung:
1. Prüfe selbst: Gibt es Seiteneffekte auf andere Komponenten?
2. Prüfe: Hält die Lösung alle Design-Regeln ein (inkl. i18n in allen 5 Sprachen)?
3. Prüfe: Funktioniert es auf Mobile (< 480px)?
4. Prüfe (bei Daten): Sind nach Anlegen/Löschen alle Tabellen konsistent (keine verwaisten Zeilen)?
5. Prüfe (Governance): Weicht etwas von CLAUDE.md ab? Falls ja, Hinweis geben (siehe Governance).
6. Gib Selbsteinschätzung: ✅ alles ok / ⚠️ Kompromiss nötig / ❌ Problem gefunden
7. Schlage den logisch nächsten Schritt vor

## Roadmap-Kontext
- Phase 1 (kostenlos/statisch) und Phase 2 (Auth/Supabase, Familien-Isolation, Rollen,
  Self-Service-Stammbäume, Owner-Konzept) sind umgesetzt.
- Umgesetzt (Frontend live bzw. lokal fertig): einheitliche Datumsfelder mit Kalender;
  Event-System (Medien Bild/Video/PDF im Storage, „Organizovano od", Kostenübersicht mit
  automatischer Aufteilung/Ausgleich/PDF); **Obavještenja** (offene Anfragen + Akzeptieren/Ablehnen
  + Mail, Badge); Sofort-Sprachwechsel; touch-sichere Dropdowns; Session-Auto-Logout +
  Update-/Versions-Erkennung.
- **Anfrage-Bearbeitung NUR in der App (kein E-Mail-Accept/Reject mehr):** Die Entscheidung über
  Zugangsanfragen trifft ein Admin ausschließlich unter „Obavještenja" (Edge Function
  `anfrage-bearbeiten`, mit Login + Rollenprüfung super_admin/familien_owner/familien_admin).
  Die Benachrichtigungs-Mail (`anfrage-senden`) enthält KEINE Annehmen/Ablehnen-Links mehr,
  sondern nur einen „App öffnen"-Deep-Link (`?obav=1` → öffnet nach Login automatisch die
  Obavještenja-Liste). Die früher öffentliche `anfrage-entscheiden` ist deaktiviert (leitet nur
  noch in die App) und sollte im Dashboard gelöscht werden.
- **„Kreiraj nalog"-Overlay (kein da/ne-Self-Service-Schalter mehr):** Ein einziger Flow.
  Pflichtfelder: Naziv stabla + Država + Grad/selo + Opština (+ E-Mail). Eine Hintergrundprüfung
  (`familie_finden_exakt`, **strikter 4-Felder-Match**, diakritik-/groß-klein-unempfindlich über
  `merge_norm`) erkennt einen vorhandenen Baum: Treffer → Info + Rollen-Dropdown → Zugriffsanfrage
  (Entscheidung in der App). Kein Treffer → bisheriger Self-Service: `neue-familie-anlegen` legt
  Konto + Baum sofort an (User = `familien_owner`, sofortige Passwort-Mail, KEINE Freigabe).
  Beim Self-Service-Anlegen werden `land`/`stadt`/`gemeinde` in `familien` gespeichert, damit das
  strikte Matching künftiger Anfragen greift.
- Offen/Ausblick: Abo-Modell (Stripe); weitere Admin-Funktionen (Familieneinstellungen).
