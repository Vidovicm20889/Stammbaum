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

## Architektur-Regeln
- **Keine NEUEN externen Libraries/Dienste ohne ausdrückliche Absprache.**
  Bereits abgestimmt und erlaubt: Supabase (Backend), Resend (Mail), per CDN
  `@supabase/supabase-js@2` und d3.js. Frontend bleibt Vanilla (kein Framework/Build-Tool).
- Direkte Blutlinie (Tanasije → Simo → Marko) ist immer der zentrale vertikale Hauptstrang
- Rollen-System: **Super-Admin / Familien-Owner / Familien-Admin / Familienmitglied (nur Lesezugriff)**
  - `super_admin`: Betrieb/Wartung, Vollzugriff. **In der GUI für normale Nutzer unsichtbar**
    (nur im eigenen Login-Badge erkennbar).
  - `familien_owner`: Eigentümer eines Stammbaums (der Ersteller). Admin-Rechte + EXKLUSIV
    Stammbaum löschen/anlegen. Nicht über normale Rollenänderung vergeb-/entfernbar.
  - `familien_admin`: verwaltet Baum/Mitglieder, darf NICHT löschen, keinen Owner ändern.
  - `familien_mitglied`: nur Lesen.
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
    samt Familie + Mitgliedschaften.
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
- Datums-Freitext gehört in `stammbaum_daten` (jsonb); die `date`-Spalte `geburtsdatum`
  bleibt NULL (sonst Fehler 22008). `geschlecht`-Spalte bleibt NULL (CHECK); sex in `stammbaum_daten`.
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
  Self-Service-Stammbäume, Owner-Konzept) sind umgesetzt bzw. laufend.
- Offen/Ausblick: Abo-Modell (Stripe), weitere Admin-Funktionen (Benachrichtigungen,
  Familieneinstellungen).
