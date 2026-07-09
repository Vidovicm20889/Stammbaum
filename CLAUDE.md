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
- **Obavještenja Live-Updates**: Badge + Liste aktualisieren sich ohne Reload per **Polling**
  (`startObavPolling`/`stopObavPolling`/`obavLivePoll`, ~12 s; pausiert bei verstecktem Tab,
  sofort-Refresh bei `visibilitychange`). Polling läuft NUR für eingeloggte Admins und darf den
  Inaktivitäts-Timer NICHT zurücksetzen (sonst kein Auto-Logout). Bewusst Polling statt Supabase
  Realtime: `registrierungs_anfragen` wird über SECURITY-DEFINER-RPCs gelesen (kein direktes
  RLS-SELECT) → Realtime würde solche Zeilen nicht ausliefern.
- **Live-Sync der Baumdaten (Supabase Realtime, ab v8.6):** Baumdaten (`personen`,
  `beziehungen`, `stammbaeume`) werden – anders als `registrierungs_anfragen` – über **echte
  RLS-SELECT-Policies** gelesen ([supabase_rls_setup.sql], [supabase_multitree_phase5.sql]), daher
  ist **Supabase Realtime** hier der gewählte Transport (kein eigener WebSocket-Server, kein
  SignalR — beides nicht stack-konform). Ein Channel (`startRealtimeSync`/`stopRealtimeSync`,
  Channel `stammbaum-sync`) abonniert `postgres_changes` (`event:'*'`) dieser drei Tabellen; bei
  einem Event wird **debounced** (~700 ms) `ladeBaumDaten()` aufgerufen → Karten/Beziehungen/
  Dropdown/Statistiken aktualisieren sich ohne Reload (kein F5). **Invarianten — nicht zurückbauen:**
  (a) Live-Sync darf den **Inaktivitäts-/Auto-Logout-Timer NICHT** zurücksetzen (analog Obav-Polling)
  — also NIE `resetInaktivTimer`/`sessAktivitaet` aus dem Realtime-Callback; (b) gilt für **alle
  eingeloggten Nutzer** (auch lesende Mitglieder), nicht nur Admins; (c) bei verstecktem Tab wird der
  Reload aufgeschoben und bei `visibilitychange` nachgeholt; (d) Start nach `ladeBaumDaten()` im
  Login-Flow, Stop in `loescheUser()` (wie `stopObavPolling`). DB-Voraussetzung: die drei Tabellen
  müssen in der Publication `supabase_realtime` liegen (idempotente DB-Datei
  `supabase_realtime_publication.sql`). **Bewusste P1-Grenze:** v1 macht bei jedem Event einen
  debounced **Vollreload des In-Memory-Modells** (kein echtes Client-seitiges Delta-Merge).
- **Live-Indikator / Presence (P2, ab v8.6):** Zeigt im Header (`#presence-indikator`), wer
  gerade DENSELBEN Stammbaum geöffnet hat („{n} aktiv" + aufklappbare Namensliste). Technik:
  **Supabase Realtime Presence** über einen **eigenen Channel je Baum** (`presence:tree:<id>`,
  `startPresence`/`stopPresence`, Key = `user.id`) — **kein** DB-/Publication-Bedarf (rein
  channel-basiert). Beim Baumwechsel (`waehleStammbaum`) wird umgeklinkt, Stop in `loescheUser`.
  Anzeige nur, wenn AUSSER einem selbst noch jemand da ist (n≥2). Anzeigename best-effort aus der
  E-Mail (`nutzerAnzeigeName`), via `nm()` SR-transliteriert; Panel touch-sicher per `pointerdown`
  außerhalb geschlossen; `wechselSprache` ruft `renderPresenceIndikator` (i18n-Keys
  `presence_aktiv`/`presence_titel`/`presence_sie` in allen 5 Blöcken). Invarianten wie Live-Sync:
  **kein** Zurücksetzen des Inaktivitäts-Timers, gilt für ALLE eingeloggten Nutzer.
- **Live-Aktualisierung offener Personen-Overlays (P3, ab v8.6):** Hat ein Nutzer das Detail-
  (`#modal`) oder Bearbeiten-Overlay (`#person-edit-modal`) einer Person offen und ein anderer
  Nutzer speichert/löscht diese Person, blendet `pruefeOverlayAktualitaet` (Aufruf nach jedem
  Live-Reload in `realtimeReloadAusfuehren`) ein **goldenes Hinweis-Banner** `.sync-hinweis` ein
  („Diese Person wurde soeben aktualisiert/entfernt") mit Button **„Neueste Änderungen übernehmen"**
  (`detailUebernehmen`/`editUebernehmen` rendern das Overlay frisch). **Wichtig:** Im **Editor**
  werden laufende Eingaben NIE automatisch überschrieben — nur auf Klick. Änderungserkennung über
  `personSignatur` (eigene Felder + Beziehungen via **stabile externe IDs**; FAM-IDs/Positionen
  bewusst ausgeklammert, da je Reload neu bzw. inhaltlich irrelevant). Watch-State
  (`detailWatchId`/`editWatchId` + Signatur) wird beim Öffnen gesetzt, beim Schließen geleert; i18n
  `sync_*` in allen 5 Blöcken; `wechselSprache` beschriftet offene Banner neu
  (`aktualisiereSyncBannerSprache`).
- **Soft-Lock / exklusive Bearbeitung (P4, ab v8.6):** Öffnet ein Admin den Personen-Editor, setzt
  er über den **Presence-Channel** (`presenceTrack(personId)`, Feld `editing` in der Presence-
  Nutzlast) eine **Bearbeitungssperre** — **kein SQL/keine Tabelle**. Andere sehen die fremde Sperre
  in `presenceLocks` (aus `presenceState`); in der Detailkarte erscheint live „🔒 Wird gerade von X
  bearbeitet" (`pruefeLockBanner`, `.sync-hinweis.lock-hinweis`). Beim Öffnen-Versuch gilt **Modus 2
  (exklusiv):** normale `familien_admin` werden geblockt (Toast `lock_blockiert`); **nur
  `super_admin`/`familien_owner` der Familie** dürfen die Sperre mit Warnung übernehmen
  (`darfSperreUebernehmen` + `zeigeBestaetigung`). Freigabe in `schliessePersonEdit` (deckt
  Speichern, da der Save-Flow den Editor schließt). **Auto-Freigabe** ohne Heartbeat: Tab zu /
  Logout / Crash → Presence-`leave` entfernt die Nutzlast → Sperre fällt automatisch weg (löst das
  „hängende Lock"-Risiko von Modus 2). i18n `lock_*` in allen 5 Blöcken. **Bewusste Grenze:** rein
  Presence-broadcastbasiert (keine harte DB-Arbitrierung bei exakt gleichzeitigem Öffnen) — echte
  Konfliktauflösung folgt in P5.
- **Konflikterkennung / Optimistic Locking (P5, ab v8.6):** `personen` hat eine **`updated_at`**-
  Spalte (BEFORE-UPDATE-Trigger `personen_touch_updated`, DB-Datei `supabase_personen_updated_at.sql`
  — **muss VOR dem Frontend-Deploy ausgeführt werden**, da `ladeBaumAusSupabase` die Spalte selektiert;
  fehlt sie, schlägt der Select fehl → Fallback auf eingebettete Daten). Beim Öffnen des Editors
  merkt sich das Frontend den Stand (`editBaselineUpdated = p._updated`); `speicherePerson` liest vor
  dem Schreiben das aktuelle `updated_at` und zeigt bei Abweichung den **Konflikt-Dialog**
  (`zeigeKonfliktDialog`): **Meine überschreiben** (`speicherePerson(true)` = Force), **Aktuelle
  übernehmen** (verwerfen + Editor mit frischen Werten neu öffnen) oder **Unterschiede vergleichen**
  (`konfliktVergleich` = Feld-für-Feld-Tabelle Meine/Aktuell über `KONFLIKT_FELDER`). i18n `konflikt_*`
  in allen 5 Blöcken. Nach erfolgreichem Speichern wird `editBaselineUpdated` neutralisiert.
  **Bewusste Grenze:** Vergleich über JS-Re-Select (kein DB-conditional-update); kleines TOCTOU-
  Fenster bei extrem zeitgleichem Speichern — für die Nutzerzahl unkritisch.
- **Noch offen (geplant, NICHT umgesetzt):** echtes Client-seitiges Delta-Merge (statt Vollreload bei
  jedem Live-Sync-Event). Damit ist die Echtzeit-Kollaboration (P1–P5) funktional vollständig.
- **Mitglieder-Verwaltung – Familien-Dropdown**: Die Familienliste im „Upravljanje članovima"-
  Overlay UND im „Dodaj člana"-Overlay (`ladeMitglieder`/`ladeAddFamilien`) kommt aus der
  rollenbasierten RPC `verwaltbare_familien` (super_admin = ALLE Familien, owner/admin = eigene)
  — NICHT aus den Mitglieder-Zeilen ableiten (sonst fehlen Familien ohne Mitglieder). Das Frontend
  filtert die gelieferte Liste nicht zusätzlich. **Findbar über BAUM-Namen (ab v10.1):** Rollen
  sind familien-gebunden, ein Stammbaum kann aber anders heißen als seine Familie (z. B. ein bei
  Heirat entstandener Zweigbaum „Stojanović" in der Familie „Vidović"). Damit der Admin die Familie
  auch über den Baum-Namen findet, liefert `verwaltbare_familien` zusätzlich `baum_namen`
  (string_agg der `stammbaeume.name` je Familie); das Frontend hängt diese über `familienSuchLabel`
  ans sichtbare Optionslabel (Such-Match läuft über `ssRender`→`o.textContent`). Der gespeicherte
  Wert bleibt die `familie_id`.
- **Benutzer ↔ Namenskarte zuweisen (Admin/Super-Admin, ab v10.9):** Erweitert die Konto↔Karte-
  Verknüpfung (`personen.user_id`) um einen **baumübergreifenden Admin-Pfad** (zusätzlich zu
  Anfrage-Genehmigung und Self-Service „Meine Person"). DB-Datei
  `supabase_user_karte_zuweisung.sql`. **Teil 1 – Such-Overlay `#uk-modal`:** Der 🔗-Button je
  Mitglied (`renderMitglieder`) öffnet `oeffneUserKarte(userId)` → Live-Suche
  `karten_suche_admin` (wie `personen_suche`, aber NUR zuweisbare Karten: `ist_super_admin() OR
  kann_familie_bearbeiten` → Super-Admin alle Bäume, Familien-Admin eigene/Verbund; liefert
  zusätzlich `belegt_user`/`belegt_email`). Treffer zeigen Belegt-Badge „🔗 belegt von {email}" /
  „frei". Zuweisen über `karte_user_zuweisen(p_person,p_user,p_force)` (jsonb): hält **1 Karte pro
  Konto** (löst die bisherige Karte des Kontos) UND **1 Konto pro Karte**; eine **belegte** (fremde)
  Karte wird nur nach Warnung (`zeigeBestaetigung`, mit E-Mail) mit `p_force=true` übernommen und
  rechnet die Auto-Rechte **beider** betroffener Konten neu (`rechte_neu_berechnen`). Entfernen über
  bestehende `person_user_loesen`. Die Mitgliederzeile zeigt die zugeordnete Karte bzw.
  „noch keine Person zugewiesen" (`mitglieder_verwaltbar` um `verknuepfte_person_*`/`verknuepfte_baum`
  erweitert → DROP+CREATE). **Teil 2 – „Dodaj člana":** Felder Vorname/Nachname + Abschnitt
  „Namenskarte zuweisen" mit Modus **keine / bestehende (Suche) / neue (Baum-Auswahl der Familie via
  `stammbaeume_der_familie`)**. Möglich, weil `mitglied-einladen` (Edge Function) den Auth-User SOFORT
  anlegt und `user_id` zurückgibt → das Frontend verknüpft danach via `karte_user_zuweisen` (neue
  Karte zuerst per `namenskarte_anlegen`). **Teil 3:** Profil (`renderMeinePersonBereich`) zeigt bei
  Verknüpfung zusätzlich die **Familie** (`meine_person_status` um `person_familie` erweitert).
  **Teil 4 – Sync:** kein neuer Code — die bestehenden Profil↔Karte-Trigger
  ([[project_realtime_kollaboration]]/`supabase_profil_person_sync.sql`) greifen, sobald `user_id`
  gesetzt ist. i18n `uk_*`/`ma_karte_*`/`mp_in_familie`/`mv_keine_person` in allen 5 Blöcken;
  `wechselSprache` ruft `ukSpracheUpdate` + rendert den Add-Modal-Kartenabschnitt neu. **Bewusste
  Grenze:** „1 Konto pro Karte"/„1 Karte pro Konto" werden per RPC gehalten (KEIN DB-UNIQUE auf
  `personen.user_id`, um Spiegel-/Bestandsdaten-Flows nicht zu brechen); E-Mail-Anzeige nur im
  Admin-Overlay. Die alte familien-interne `mvVerknuepfung*`/`personen_fuer_verknuepfung`-Inline-
  Auswahl ist durch das Overlay ersetzt (`personen_fuer_verknuepfung` bleibt nur noch im
  Obavještenja-Genehmigungs-Flow im Einsatz).
- **Profileinstellungen / Benutzer-Profil (Phase 1, ab v8.9):** Konto-Stammdaten des EINGELOGGTEN
  Nutzers — bewusst getrennt von der „Stammbaum-Person" (`registrierungs_anfragen`/`personen`). Eigene
  Tabelle **`profile`** (1 Zeile je `auth.users`, PK=`user_id`; DB-Datei [supabase_profile.sql]) mit
  Vorname/Nachname/Telefon/Sprache/Land/Zeitzone/Avatar + `avatar_sichtbarkeit` (Stufen
  `verbund`/`familie`/`privat`; ab v13.1 zusätzlich `oeffentlich` für die verbundübergreifende
  Discovery). **RLS: nur die EIGENE
  Zeile** (`auth.uid() = user_id`, rekursionsfrei, Isolation gewahrt) — Cross-User-Avatare laufen NICHT
  über DB-SELECT, sondern über den **Presence-Broadcast** (Feld `avatar` in der Nutzlast, nur wenn
  Sichtbarkeit ≠ `privat`). Erreichbar über das ⚙-Menü (`#profil-bereich`, Button `prof_menu`) — sichtbar
  für **ALLE eingeloggten Nutzer** (auch lesende Mitglieder; `zeigeMenu` ist daher bei Login immer true).
  Modal `#profil-modal` (`oeffneProfil`/`schliesseProfil`/`speichereProfil`): Profilkopf (Avatar, Name,
  E-Mail, „Mitglied seit {datum}" aus `aktuellerUser.created_at`), Stammdatenfelder, Datenschutz-
  Dropdown. **E-Mail ist read-only** (Login-/Matching-Schlüssel; Änderung bewusst NICHT in Phase 1).
  **Profil-Sprache steuert die App-Sprache** (`wechselSprache` beim Speichern UND beim Login via
  `ladeMeinProfil`). **Avatar**: neuer **Storage-Bucket `avatars`** (public; im Rahmen von Supabase →
  keine neue Library/Dienst), Bildverarbeitung clientseitig per **Canvas** (zentrierter Quadrat-Zuschnitt
  → 1024 px Haupt + 128 px Thumb, WEBP/JPEG-Fallback q≈0.9, `imageSmoothingQuality:'high'`; das
  Haupt-Bild speist die Namenskarten-Avatare, daher 1024 statt früher 512 für Retina/große Karten);
  Pfad `<user_id>/avatar.*` + `<user_id>/thumb.*`
  (Storage-Policy: nur eigener Ordner). **Passwort ändern**: aktuelles PW per Re-Login
  (`signInWithPassword`, gleiche User-ID → KEIN Baum-Reload) verifiziert, dann `updateUser({password})`;
  Validierung ≥ 8 Zeichen + Buchstabe & Ziffer + Übereinstimmung. **Live-Update** (kein Reload):
  `nutzerAnzeigeName()` bevorzugt den Profilnamen → Badge und Presence (`presenceTrack`) aktualisieren
  sofort. **Benutzer-Leiste (`aktualisiereBadgeProfil`):** zeigt **Vor-/Nachname + Rolle**; die **E-Mail
  nur**, wenn WEDER Vor- NOCH Nachname gesetzt ist. Rechts ein **runder Profil-Button** (`#profil-icon-btn`
  mit `#user-avatar`: eigenes Bild ODER Platzhalter-SVG) mit Tooltip `prof_menu`, der das Profil öffnet.
  Der **Abmelden-Button sitzt im Profil-Overlay** (Profilkopf), NICHT mehr in der Leiste. i18n `prof_*`
  in allen 5 Blöcken; `wechselSprache`
  baut Sprache/Zeitzone-Selects + Kopf des offenen Modals neu auf.
- **Profil – Sicherheitsbereich (Phase 2, ab v8.9):** Eingeklappter Abschnitt im Profil-Overlay
  (`#prof-sec-box`, Toggle wie Passwort; lädt **lazy** beim Aufklappen) zeigt **Letzter Login**,
  **Letzte Passwortänderung** und **aktive Sitzungen** (Gerät best-effort aus User-Agent, letzte
  Aktivität, „diese Sitzung"-Badge) + Button **„Andere Sitzungen abmelden"**. **Bewusst OHNE Edge
  Function:** `auth.users`/`auth.sessions` sind client-/RLS-seitig nicht lesbar, daher zwei
  **SECURITY-DEFINER-RPCs** (Owner=postgres, geben NUR Daten des Aufrufers via `auth.uid()` zurück;
  DB-Datei [supabase_profil_sicherheit.sql]): `meine_sicherheit_info()` (liest auth.users +
  auth.sessions, markiert die aktuelle Session über `auth.jwt()->>'session_id'`) und
  `andere_sitzungen_abmelden()` (DELETE der übrigen `auth.sessions`-Zeilen ≠ aktuelle → deren
  Refresh-Token wird ungültig; bricht ab, falls die aktuelle Session unbekannt ist, um Selbst-Logout
  zu verhindern). **„Letzte Passwortänderung" hat Supabase nicht nativ** → wird selbst getrackt in
  `profile.pw_geaendert_am` (Frontend setzt es per upsert nach erfolgreichem `updateUser`); für
  Alt-Konten bis zur nächsten In-App-Änderung „—". Frontend: `ladeSicherheit`/`renderSicherheit`/
  `profilAndereAbmelden`, i18n `sec_*` in allen 5 Blöcken, `wechselSprache` rendert den offenen
  Bereich neu.
- **PDF-/Druck-Export des Stammbaums (ab v9.2):** Button „Stammbaum als PDF exportieren"
  (`#pdf-export-btn`, schwebend im `#baum-container`) öffnet den Konfig-Dialog `#pdf-export-modal`
  (`oeffnePdfExport`/`schliessePdfExport`). **Bibliotheken:** `jspdf` + `svg2pdf.js` von jsDelivr
  (siehe Architektur-Regeln). Optionen: **Umfang** (nur Person / Eltern / +Großeltern /
  +Urgroßeltern / X Generationen zurück / ganzer Baum) + **X Generationen nach vorne**; **verknüpfte
  Bäume** (über `_ident`-Brücken im Verbund) optional einbeziehen + farblich kennzeichnen;
  **Personenfilter** (lebend/verstorben/beide; private/unbestätigte ausblenden); **Layout**
  (vertikal/horizontal/Ahnen/Nachkommen/kompakt); **Papiergröße** mit Auto-Empfehlung
  (≤25→A4, ≤100→A3, ≤250→A2, ≤500→A1, >500→A0/Poster; **A4 = Minimum**); **Poster/Mehrseiten**
  mit Seitenzahlen + Überlappung; **Formate** PDF/PNG/SVG/Browser-Druck. **Technik:** Der Export
  baut ein **eigenständiges, in sich gestyltes SVG** (kein Zugriff auf die externe CSS — Stile inline,
  damit Canvas/Druck es ohne Stylesheet rendern), reuse der d3-`tree()`-Layoutlogik aus `zeichneBaum`.
  Einseitiges PDF = **vektorbasiert via svg2pdf** (scharf) — **aber nur, wenn der SVG-Text
  WinAnsi-sicher ist** (`!/[^ -ÿ]/`); da Personennamen i. d. R. südslawische Diakritika (č/ć/đ/ž/š)
  bzw. Kyrillisch enthalten (nicht in den jsPDF-Core-Fonts), ist der **De-facto-Standard
  hochauflösendes Raster** (SVG→Image→Canvas→`addImage`), das alle 5 Sprachen glyph-treu rendert.
  Poster/Mehrseiten + PNG = immer **Canvas-Tiles** (robust für beliebige Größen). Titelblatt +
  Seitenzahlen werden bewusst **per Canvas** (Browser-Font) gezeichnet, NICHT per `doc.text`
  (sonst Kyrillisch/Diakritika kaputt). **Design:** **hell/druckoptimiert** (weißer Hintergrund,
  akzent-rote Titel `#722f37`, goldene Verbindungslinien `#9c7c3c`, dunkle Texte, helle Karten mit
  farbigem Rand) — vom User so gewünscht (zunächst dunkel geplant, dann auf hell umgestellt, weil der
  dunkle Hintergrund im PDF nicht gut aussah). **Datengrenzen (ehrlich dokumentiert):** Es gibt KEIN echtes Pro-Person-Foto,
  kein „privat"- und kein „bestätigt"-Flag im Personenmodell → „Profilbild" rendert nur, wenn ein
  `foto`/`avatar`-Feld in `stammbaum_daten` vorhanden ist; „private/unbestätigte ausblenden" greifen
  nur auf vorhandene Felder (`privat` bzw. fehlende Kerndaten) und sind sonst No-Ops. Lebend/Verstorben
  aus `deceased`/`death_date`. **Performance:** Generierung mit Fortschrittsanzeige, schwere Schritte
  asynchron (kein UI-Block); sehr große Bäume → Poster/Mehrseiten. i18n `pdf_*` in allen 5 Blöcken;
  `wechselSprache` baut den offenen Dialog neu auf.
- **„Meine Person im Stammbaum" — Konto↔Karte Self-Service (ab v9.4):** Die Verknüpfung Konto↔
  Personenkarte ist die bestehende Spalte **`personen.user_id`** (Flag `_hatKonto`, jetzt zusätzlich
  `_userId` im Modell) — **kein separates `linkedPersonId`-Feld**. Bisher nur über Admin-Genehmigung
  (`anfrage-bearbeiten`) gesetzt; neu gibt es einen **Selbstbedienungs-Pfad** im Profil-Overlay
  (Bereich `#mp-bereich`, `renderMeinePersonBereich`). **Bedingter Login-Hinweis**
  (`pruefeMeinePersonHinweis` am Ende des Login-Flows; Modal `#mp-hinweis-modal`): erscheint NUR wenn
  *Zugriff auf ≥1 Baum* **und** *≥1 Personenkarte sichtbar* **und** *Konto noch nicht verknüpft*
  (Super-Admin ausgenommen). Buttons **Bestehende auswählen / Neue erstellen / Später erinnern**
  (Snooze 24 h je Nutzer via `localStorage('mp_snooze_<uid>')`). Steuerung serverseitig über
  SECURITY-DEFINER-RPCs (Datei `supabase_meine_person.sql`): `meine_person_status` (Bedingung),
  `meine_person_kandidaten` (kontolose Karten in sichtbaren Bäumen), `meine_karte_verknuepfen`
  (Self-Link), `meine_karte_erstellen` (eigene Karte anlegen + verknüpfen, funktioniert auch für reine
  Lesemitglieder). **Betreiber-Entscheidung (bewusst):** Self-Link erfolgt **OHNE Admin-Genehmigung**,
  aber nur auf Karten in einem **sichtbaren** Baum (`sieht_familie`) und nur auf **kontolose** Karten
  (**1 Nutzer pro Karte**). **Dokumentierte Folge:** Das Setzen von `user_id` triggert die
  **Blutlinien-Auto-Rechte** ([[project_blutlinie_rechte]]) → der Nutzer wird `familien_admin` entlang
  der Blutlinie der Karte. Anlegen-Flow: bei mehreren zugänglichen Bäumen erst **Ziel-Baum wählen**
  (`#mp-create-modal`), Formular **vorbefüllt aus dem Profil** (Vor-/Nachname/E-Mail/optional Avatar →
  `stammbaum_daten.foto`), **Duplikatsprüfung** vor Anlage über bestehende `dubletten_check_global`
  (greift nur bei allen 4 Kriterien inkl. **Geburtsland** → Pflichtfeld im Formular) → Treffer-Dialog
  *Vorhandene verknüpfen / Trotzdem neu*. Auswahl-Picker touch-sicher via `tippAuswahl`. i18n `mp_*` in
  allen 5 Blöcken; `wechselSprache` rendert offenen Bereich/Pick/Create neu. **v1-Grenzen:** eine
  standalone angelegte Karte ohne Eltern-/Partner-Kanten ist im Baum-Diagramm zunächst „lose" (über den
  normalen Editor verknüpfbar); Duplikatsprüfung nutzt nur die 4 vorhandenen Kriterien (Eltern/
  Ehepartner aus der Spec sind im RPC nicht abgebildet).
- **Profil ↔ Personenkarte: bidirektionale Stammdaten-Sync (ab v9.5):** Nach Verknüpfung
  (`personen.user_id`) werden gemeinsame Stammdaten **bidirektional synchronisiert** — bewusst über
  **DB-Trigger** (Datei `supabase_profil_person_sync.sql`), NICHT im Frontend: Spec verlangt „Admin
  ändert Karte → Profil aktualisiert sich", aber ein Admin darf die fremde `profile`-Zeile per RLS
  nicht schreiben → nur SECURITY-DEFINER-Trigger erfüllen beide Richtungen (auch für read-only-
  Selbstverknüpfte). Trigger `personen_sync_to_profile_trg` (Karte→Profil, legt profile-Zeile bei
  Bedarf an) und `profile_sync_to_personen_trg` (Profil→alle verknüpften Karten; `ident_sync` spiegelt
  weiter auf Zwillinge). **Loop-Schutz:** GUC `app.pp_sync` (propagierendes UPDATE setzt '1', der
  Gegen-Trigger bricht dann ab). **Synced-Felder** (profile-Spalte ↔ stammbaum_daten-Key): vorname↔given,
  nachname↔surname, geburtsname↔ehename, geschlecht↔sex, geburtsdatum↔birth_date, sterbedatum↔death_date,
  biografie↔beschreibung, avatar_url↔foto/avatar (Karten-Foto überschreibt Profil-Avatar nur, wenn
  gesetzt). **Erstverknüpfung = „Karte gewinnt"** (kein Dialog): ergibt sich automatisch, weil das
  Setzen von user_id ein personen-UPDATE ist, das Karte→Profil feuert; einmaliger **Backfill** in der
  DB-Datei (Trigger dafür kurz deaktiviert). **Nur Profil** (nie in die Karte): E-Mail, Passwort,
  Sprache, Land, Zeitzone, Telefon, Datenschutz, Rollen. **Nur Karte** (nie ins Profil): Beziehungen/
  Blutlinie/Baum/Events. **Profilfelder** (editierbar, ab v9.5): Geburtsname/Geschlecht/Geburtsdatum
  (`dp-input`)/Biografie ergänzen das Profil-Modal; `speichereProfil`/`oeffneProfil` lesen/schreiben sie;
  Hinweis `prof_sync_hint` nur bei Verknüpfung sichtbar. **Verknüpfung aufheben** (`meine_karte_loesen`,
  Button in `#mp-bereich`): setzt user_id→NULL, Sync endet, **beide Datensätze bleiben** (Blutlinien-
  Rechte werden neu berechnet). **Live:** offene Baum-Ansichten aktualisiert der bestehende Live-Sync;
  das eigene Badge/Profil zieht `aktualisiereProfilLeise` im Realtime-Reload nach (ohne Sprachumschaltung,
  ohne offene Eingabefelder zu überschreiben). i18n `prof_*`/`mp_loesen*` in allen 5 Blöcken. **Ehrliche
  Grenze:** fremde offene PROFIL-Ansichten anderer Nutzer updaten nicht live (profile-RLS = nur eigene
  Zeile, nicht in der Realtime-Publication).
- **Personalisierte Standard-/Ausschnitts-Ansicht für große Bäume (ab v9.6):** Bei Bäumen mit
  vielen Personen wird **nicht der ganze Baum** gezeichnet, sondern ein relevanter Ausschnitt um die
  **eigene Personenkarte** (`personen.user_id` = eingeloggter Nutzer, `meineKarteImBaum()`).
  **Wichtige Architektur-Entscheidung (bewusst):** KEIN DB-Lazy-Loading/keine Virtualisierung —
  alle Daten bleiben wie bisher komplett im Speicher (RLS-begrenzt, stack-konform, kompatibel mit
  Realtime-Vollreload/`identitaet_id`-Brücken/Blutlinie); der Performance-Gewinn kommt rein aus dem
  **render-seitigen Ausschnitt** (weniger DOM-Knoten). Technik: `baueBaumDaten`/`zeichneBaum` nehmen
  optional `opts.erlaubt` (Set erlaubter ext-IDs inkl. aller Zwillinge → Pruning in `zeigeKind`/
  Partner-Anzeige) und `opts.fokusId` (Hervorhebung der fokussierten Karte statt der Render-Wurzel;
  rückwärtskompatibel — ohne opts volles Altverhalten). **Standardansicht** (`zeigeStandardAnsicht`,
  aufgerufen in `waehleStammbaum`): eigene Person + Eltern + (Voll-/Halb-)Geschwister **inkl. deren
  Familien (Ehepartner + Kinder = Neffen/Nichten, Kategorie `geschwister_familie`)** + eigene Kinder +
  Partner; Wurzel = oberster im Set enthaltener Vorfahr entlang des aufsteigenden Strangs
  (`_renderWurzelImSet`). **„Stammbaum zentrieren"** (`zentriereBaumAnsicht`) stellt jetzt diese
  Standardansicht wieder her (Fokus eigene Karte, Standardzoom durch Neuzeichnen, erweiterte Bereiche
  eingeklappt); **ohne eigene Karte** das bisherige Fit-Verhalten. **Neuer Button „Erweiterte Ansicht"**
  (`#ansicht-erweitern-btn`, links neben Zentrieren) öffnet Overlay `#ansicht-modal`
  (`oeffneAnsichtModal`) mit 3 Optionen: (1) **Gesamten Stammbaum** (`aktuelleWurzel`, 12/0),
  (2) **Familienzweig ab Person** — lokale Suche über ALLE geladenen Personen (aktueller + verknüpfte
  Bäume), Picker touch-sicher via `tippAuswahl`, dann 1/2/3/5/unbegrenzt Generationen nach unten
  (`zeigeZweigAbPerson`), (3) **Erweiterte Ansicht um meine Person** — Checkboxen Großeltern/
  Urgroßeltern/Cousins/Nachkommen additiv auf den Standardumfang (`verwandtschaftsSet`/
  `zeigeErweitertAnsicht`). **Speicherung der Ansicht (ab v14.x, Nutzerwunsch — kehrt die frühere
  „keine Speicherung"-Entscheidung um):** Die im Ansicht-Overlay (`ansichtAnwenden`) angewandte Wahl
  wird PRO NUTZER in `localStorage` (`vidovic_ansicht_<uid>`) gemerkt (`speichereAnsichtPref`) und beim
  nächsten Öffnen eines Baums (`waehleStammbaum` → `wendeGespeicherteAnsichtAn`, ersetzt den früheren
  festen `zeigeStandardAnsicht`-Aufruf) als Standard angewandt — statt immer „Moja porodica". Gilt für
  alle Öffnungspfade (Login/Reload/Baumwechsel/Dropdown). **Fallback-Kette:** `voll`→Vollansicht (wenn
  Wurzel da), `kreis`→erweiterter Kreis, `standard`→personalisierte Ansicht, jeweils sonst
  Standard→Vollansicht (wie bisher, wenn keine eigene Karte im Baum). **`zweig` ist person-/baumgebunden**
  → nur im GLEICHEN Baum wiederhergestellt und nur, wenn die Person noch existiert, sonst Standard.
  „Stammbaum zentrieren" (`zentriereBaumAnsicht`) bleibt bewusst eine eigene Aktion (setzt auf die
  personalisierte Standardansicht, ohne die gespeicherte Präferenz zu ändern). Aktiver Modus (`ansichtModus` 'standard'/'erweitert'/'zweig'/
  'voll') wird nach Edit/Realtime-Reload über `rendereAktuelleAnsicht` (in `zeichneBaumNeu`) erhalten;
  Suche setzt den Modus zurück (klassischer 2-auf-2-Fokus). i18n `ansicht_*` in allen 5 Blöcken;
  `wechselSprache` ruft `ansichtModalSprachUpdate`. **v1-Grenze (bewusst, wie der übrige Renderer):**
  Single-Root-d3-Baum = EINE aufsteigende Blutlinie (ein Elternteil je Ebene als Wurzel-Strang, der
  andere nur als Partnerkarte) → Großeltern/Urgroßeltern + **mütterliche** Halbgeschwister werden nur
  entlang des gerenderten Strangs gezeichnet; das `verwandtschaftsSet` erfasst sie korrekt, die
  *Darstellung* ist durch den Single-Root begrenzt (echte beidseitige Ahnen-Spitzen = späteres
  Renderer-Rework).
- **Namenskarten-Avatar zeigt Profilbild (ab v9.6):** Die Karten im „Familienmitglieder"-Grid
  (`zeigeKarten`, `.person .avatar`) zeigen das hochgeladene **Profilbild** (`stammbaum_daten.foto`
  bzw. `avatar`/`bild`, dieselben Felder wie PDF-Export), sonst wie bisher die **Initialen** als
  Fallback (Bild liegt per `position:absolute; inset:0; object-fit:cover` über den Initialen; bei
  Ladefehler `onerror=this.remove()` → Initial erscheint wieder). Alle Datenfelder bleiben unverändert.
  **Schärfe:** Avatar-Upload erzeugt jetzt **1024 px** Haupt (+128 Thumb) statt 512, und das
  Familienmitglieder-Grid nutzt **`auto-fill`** statt `auto-fit` — sonst streckt ein einzelner
  Suchtreffer die Karte auf volle Breite und skaliert den Avatar unscharf hoch. **Bestandsavatare**
  bleiben in alter Auflösung, bis sie im Profil **neu hochgeladen** werden.
- **Geburtstags- & Gedenktag-Erinnerungen — „Anstehende Anlässe" (Stufe A, ab v11.8):** Wertet die
  `birth_date`/`death_date` der Personen des **AKTIVEN Baums** (`aktuelleDaten.persons`) aus und zeigt
  Anlässe der **nächsten 30 Tage**. **Rein clientseitig — KEIN Backend** (kein neuer Tabellen-/
  RPC-/Realtime-Bedarf): `berechneAnlaesse` (lebende Person → **Geburtstag**, verstorbene
  (`deceased`/`death_date`) → **Gedenktag/Todestag**; über `identitaet_id`-Spiegelkarten entdoppelt,
  Platzhalter-Eltern übersprungen), `naechsterJahrestag` (nächstes Monat+Tag-Vorkommen ab heute aus
  **ISO**-Datum; Freitext/ungefähre Altwerte ohne Monat/Tag werden übersprungen; 29.02. rollt auf
  01.03.). **Zwei Oberflächen, gemeinsamer Item-Bau** (`anlItemHtml`, fügt sich ins
  Benachrichtigungs-Muster ein = gleiche `.benachr-liste`/`.benachr-item`-Optik): (1) **Dashboard-
  Widget** = schwebender Button oben rechts im `#baum-container` (`#anlaesse-btn`, Tortensymbol +
  Zähl-Badge, nur sichtbar bei eingeloggtem Nutzer + offenem Baum + ≥1 Anlass) → öffnet
  `#anlaesse-modal`; (2) **eingemischt in die vereinte Obavještenja-Liste** (ab v14.29 EINE chronologische Liste ohne feste
  Abschnitte — persönliche Benachrichtigungen + Anlässe + Admin-Anfragen gemischt, neueste/anstehende
  oben; Anlässe erhalten den synthetischen Sortierwert `jetzt − Tage`; Container `#obav-liste`, via
  `renderObavZentral`). **Klick auf einen Eintrag öffnet die Personenkarte** (`anlaesseOeffne` →
  `zeigeDetails`, schließt offene Modals). `aktualisiereAnlaesse` (zentrale Neuberechnung) wird in
  **`waehleStammbaum`** (Baumwechsel/Login/Realtime-Reload), **`wechselSprache`** (Neu-Beschriftung)
  und **`loescheUser`** (Logout → Widget verbergen) aufgerufen; setzt **NICHT** den Inaktivitäts-Timer
  zurück (rein lesend). i18n `anl_*` in allen 5 Blöcken. **Bewusst NICHT** in den Avatar-Ungelesen-Badge
  gemischt (Anlässe sind wiederkehrend/ambient, kein „ungelesen").
- **Geburtstags-/Gedenktag-Erinnerungen — Stufe B (Backend, In-App-Persistenz, ab v11.8):** Ergänzt
  Stufe A um **persistente** Benachrichtigungen (sichtbar auch ohne offene Client-Berechnung, Basis
  für späteren E-Mail-Versand). DB-Datei **`supabase_benachrichtigungen_anlaesse.sql`** (idempotent):
  (a) Idempotenz-Spalten `ref_person`(FK→personen, CASCADE)/`ref_jahr` an **`benachrichtigungen`** +
  partieller `UNIQUE`-Index (betrifft NICHT die `event_einladung`-Zeilen mit `ref_person IS NULL`);
  (b) Tabelle **`benachrichtigungs_einstellungen`** (`familie_id`,`user_id`,`email_geburtstage`,
  `email_gedenktage`,`vorlauf_tage`) mit **RLS analog mitgliedschaften** (eigene Zeile bearbeitbar,
  Admin/Verbund lesend); (c) **SECURITY-DEFINER-RPC `anlaesse_taeglich_erzeugen()`** (läuft im
  Cron-/Service-Kontext OHNE `auth.uid()` → Sichtbarkeit explizit über den **Verbund** der
  Einstellungs-Familie; schreibt je anstehendem Anlass [Monat+Tag = heute+`vorlauf_tage`] eine
  `benachrichtigungen`-Zeile; lebende→Geburtstag, verstorbene→Gedenktag; über `identitaet_id`
  entdoppelt, Platzhalter/Nicht-ISO übersprungen; `ON CONFLICT DO NOTHING` = idempotent; `GRANT` nur
  `service_role`). **Trigger via pg_cron** ruft die Funktion DIREKT auf (**kein** pg_net/Edge nötig
  für In-App) — auskommentiertes Snippet in der Datei (Nutzer aktiviert pg_cron + führt es EINMAL aus
  = abstimmungspflichtig). **Frontend:** Schalter im Profil-Overlay (`#anl-pref-geb`/`#anl-pref-ged`,
  `ladeAnlassEinstellungen`/`speichereAnlassEinstellungen` → Upsert je Familie aus
  `meineRollenProFamilie`, RLS = nur eigene Zeilen); `renderBenachrichtigungen` beschriftet die neuen
  Typen `anlass_geburtstag`/`anlass_gedenktag` (🎂/🕯️ + Name), Klick öffnet best-effort die
  Personenkarte (`ref_person`→`_uuid` im geladenen Modell). **Vorlauf** (`#anl-pref-vorlauf`, Tage
  vorher, 0–30, DB-Default 3) je Familie editierbar (UI zeigt/speichert den kleinsten Wert). i18n
  `anl_pref_*` in allen 5 Blöcken.
- **Geburtstags-/Gedenktag-Erinnerungen — E-Mail-Versand (ab v12.0):** Baut auf Stufe B auf. DB-Datei
  **`supabase_benachrichtigungen_anlaesse_email.sql`** (idempotent): Spalte
  `benachrichtigungen.email_gesendet` (Doppel-Mail-Schutz) + SECURITY-DEFINER-RPCs (nur `service_role`)
  **`anlaesse_email_offen()`** (liefert noch nicht gemailte Anlass-Zeilen der letzten 2 Tage inkl.
  E-Mail aus `auth.users`/Name+Sprache aus `profile`) und **`anlaesse_email_erledigt(uuid[])`**
  (markiert gesendet). **Edge Function `anlaesse-erinnerung`** (`supabase/functions/anlaesse-erinnerung/`,
  Deploy via Dashboard; Resend-Muster wie `event-einladung-senden`): ruft `anlaesse_taeglich_erzeugen()`
  (In-App sicherstellen) → `anlaesse_email_offen()` → **eine gebündelte Digest-Mail je Empfänger**
  (alle Anlässe, Sprache aus `profile`, Deep-Link `?obav=1`) → `anlaesse_email_erledigt()`. **Auth-Guard:**
  nur Aufruf mit Service-Role-Bearer (Cron). **Aktivierung (abstimmungs-/setup-pflichtig):** pg_cron +
  **pg_net** aktivieren, Function deployen (Secrets RESEND_API_KEY etc.), den reinen In-App-Cron
  `anlaesse-taeglich` durch den pg_net-Cron `anlaesse-erinnerung` ersetzen (Snippet in der DB-Datei).
  Idempotent: `email_gesendet`-Flag + 2-Tage-Fenster → kein Versand von Altbestand/Doppel-Mails.
- **Ereignis-Bereich = EIN Bereich, zwei Ansichten (Liste + Zeitstrahl, ab v12.1):** Der Events-Tab
  (`tab-shorts`, Sektion `#ansicht-shorts`) hat oben einen **segmented control** (`#ev-modus`,
  `evSetModus`/`evApplyModusUI`, Zustand `evModus` 'liste'|'zeit'): **(A) „Liste"** = der bisherige
  **Verwaltungs**-Modus (Event-Karten `#ev-liste-wrap`/`#shorts-grid`, Bearbeiten/Teilnehmer/Kosten/
  Medien, „Neues Event") — **unverändert**; **(B) „Zeitstrahl"** = neue, **rein LESENDE** chronologische
  Ansicht (`#ev-zeit-wrap`). **KEINE neue Tabelle/RPC/Library** — beide Ansichten teilen DIESELBE
  Quelle: `zeigeShorts` lädt `events_fuer_mich` EINMAL in `eventsCache` und rendert beide; der
  Zeitstrahl liest daraus mit (kein separater Call) und ergänzt clientseitig abgeleitete Lebensdaten
  aus `aktuelleDaten`. **Marker (`zsBaueMarker`), Scope = aktiver Baum (`aktuellerStammbaumId`):**
  (1) **organisierte Events** aus `eventsCache` — klickbar → bestehendes Event-Detail (`zsOeffneEvent`
  → `zeigeEventDetail`, mit Kosten/Teilnehmern/Medien), Badge „Organisiertes Event" + Akzent-Rand;
  (2) **Lebensdaten** aus den geladenen Personen (`p._tree === aktuellerStammbaumId`, Platzhalter
  übersprungen): **Geburt** (`birth_date`), **Tod** (`death_date`, nur wenn `deceased`/Datum),
  **Heirat** aus `families_spouse` **nur wenn ein Heiratsdatum vorhanden** ist
  (`hochzeit_standesamt`/`hochzeit_kirchlich` liegt auf der PERSON, NICHT an `beziehungen`; je Paar
  ein Marker via Dedupe-Schlüssel) — klickbar → Personenkarte (`zsOeffnePerson` → `zeigeDetails`,
  `#modal`), rein lesend. **Nur Marker mit PARSEBAREM ISO-Datum** erscheinen (`zsIso`; nicht-parsebare
  Freitext-Altwerte werden ignoriert); chronologisch sortiert, **nach Jahr gruppiert** (`.zs-jahr`).
  **Filter** (`zsFuelleFilter`): Person, Art (organisierte Events / Geburt / Heirat / Tod), Jahrzehnt.
  **„Lebenslauf einer Person"** = Person-Filter gesetzt → nur Marker dieser Person (+ Kopf
  `zs_bio_titel`). Live: läuft über `zeigeShorts` (von `ladeBaumDaten`/`waehleStammbaum`/`wechselSprache`
  aufgerufen) → Live-Sync-Reload aktualisiert die Achse mit, `evModus` bleibt erhalten; setzt den
  Inaktivitäts-Timer NICHT zurück. Suchfeld im ganzen Bereich deaktiviert (wie bisher). i18n
  `ev_modus_*`/`zs_*` in allen 5 Blöcken. **v1-Grenzen (bewusst):** Lebensdaten ohne parsebares Datum
  erscheinen nicht; Heiraten nur mit Datum; keine baumübergreifende Chronik (nur aktiver Baum).
- **Ereignis-Bereich = DRITTE Ansicht „Karte" (Migrationskarte, Leaflet, ab v12.3):** Der segmented
  control (`#ev-modus`, `evModus` jetzt 'liste'|'zeit'|'karte') hat ein drittes Segment **(C) „Karte"**
  (`#ev-karte-wrap`, **rein LESEND**) — Leaflet/OpenStreetMap, **KEIN API-Key** (siehe Library-Regel).
  **Datenmodell:** `events` hat **`latitude`/`longitude`** (double precision, nullable) + **`bezugsperson_id`**
  (→ `personen.id`, `ON DELETE SET NULL`); DB-Datei [supabase_event_geo.sql], `event_speichern` um 3
  Parameter (12 Args) erweitert. `events_fuer_stammbaum`/`events_fuer_mich` liefern `SETOF events` →
  die neuen Spalten erscheinen automatisch (kein RPC-Rewrite). **KEINE neue Tabelle** — die Karte teilt
  `eventsCache` (wie Liste/Zeitstrahl). **Zwei Karten-Modi** (`karteModus`, `karteSetModus`): **(a) „Alle
  Orte"** = alle verorteten Events des aktiven Baums als Marker (Popup: Titel/Datum/Typ/Ort + „Details
  öffnen" → `zeigeEventDetail`); **(b) „Migrationspfad"** = Events EINER **Bezugsperson** chronologisch
  (ISO-Datum), per **Polyline** verbunden, **Start grün / Ende rot** (Zwischenpunkte Gold, nummeriert).
  Personen-Filter = Bezugspersonen mit ≥1 verortetem Event. Scope = aktiver Baum
  (`aktuellerStammbaumId`). **Leaflet lazy** (`karteInit`, erst wenn Segment sichtbar; `invalidateSize`
  nach Anzeige), **Marker = CSS-DivIcons** (`karteIcon`, `.karte-pin` — kein externes Bild, CSP-schonend).
  **Geocoding-Editor** im Event-Modal (`#ev-geo-block`): **Nominatim-Ortssuche** (`geoSucheAusfuehren`,
  **debounced + min. ~1.1 s Abstand** = Rate-Limit) **plus Klick-auf-Karte** als manueller Fallback
  (`geoSetze`/`geoEditOeffnen`, eigene kleine Leaflet-Karte `#ev-geo-map`); Treffer-Wahl übernimmt
  optional den Ortsnamen ins leere `ev-ort`-Feld. **Bezugsperson-Dropdown** (`bezugspersonOptionen`,
  Personen des aktiven Baums, Wert = `_uuid`). Live über `zeigeShorts`
  (`karteFuelleFilter` immer, `karteRender` wenn aktiv) → Live-Sync/Sprachwechsel aktualisieren mit;
  setzt den Inaktivitäts-Timer NICHT zurück. i18n `ev_modus_karte`/`karte_*`/`geo_*`/`ev_bezugsperson*`
  in allen 5 Blöcken. **v1-Grenzen (bewusst):** Migrationspfad nur über Events mit **gesetzter
  Bezugsperson + Koordinaten + parsebarem Datum** (keine Ableitung aus Geburts-/Sterbeort der Person —
  Personenfelder bleiben unverortet); nur aktiver Baum; manuelle Geokodierung pro Event (keine
  Massen-/Auto-Geokodierung von Altbestand).
  **UMBAU ab v14.25 — Karte ist ein EIGENER Top-Level-Tab „Mapa/Karte" (nicht mehr Events-Untermodus):**
  Das dritte Segment „Karte" wurde aus dem Ereignis-`#ev-modus` **entfernt** (`evModus` jetzt nur noch
  'liste'|'zeit'|'kalender'|'termin'); der komplette Block **`#ev-karte-wrap` wurde physisch in eine neue
  Sektion `#ansicht-mape` verschoben** (Karte + Toolbar bleiben IDENTISCH, `karteInit`/`karteRender`/
  `karteSetModus`/`karteFuelleFilter` unverändert — kein Code-Duplikat, keine zweite Leaflet-Instanz).
  Neuer Tab in der Tab-Leiste (`data-ansicht="mape"`, i18n `tab_mape`) an der Stelle, wo vorher der
  Karten-/Mitglieder-Tab „Članovi porodice" war. `wechselAnsicht('mape')` → **`zeigeMape()`** lädt
  `eventsCache` (wie `zeigeShorts`, RPC `events_fuer_mich`) und zeichnet die Karte (Leaflet lazy +
  `invalidateSize`); Vollhöhe via CSS `#ansicht-mape .event-karte { height: calc(100vh − …) }`. Live-
  Refresh in `waehleStammbaum` (`aktuelleAnsicht==='mape' → zeigeMape()`); Suche im Mape-Tab deaktiviert
  (wie Events/Feed); Inaktivitäts-Timer wird NICHT zurückgesetzt. **„Članovi porodice" (Tab `karten`)
  wanderte ins Avatar-Menü** (Button `menu-clanovi-btn` direkt unter „Papierkorb", `oeffneClanoviAusMenu`
  → `wechselAnsicht('karten')`); kein Zugriffsverlust, da die Tab-Leiste ohnehin nur eingeloggt sichtbar
  ist. `ev_modus_karte` als i18n-Key entfernt (ungenutzt). Deploy: stammbaum.html/.css/i18n.js + `?v=`.
- **Foto-Galerie pro Person (ab v12.1):** Baut auf dem bestehenden Medien-Upload (`feMediaUpload`/
  Avatar-Canvas-Kompression) auf — **kein zweites System**. DB-Datei `supabase_personen_fotos.sql`
  (idempotent): Tabelle **`personen_fotos`** (`person_id`→personen CASCADE, `familie_id`/`stammbaum_id`,
  `storage_pfad`, `beschriftung`, `ist_hauptbild`, `aufnahme_datum`, `sortierung`, `erstellt_am`),
  partieller `UNIQUE`-Index „**1 Hauptbild je Person**", **RLS verbund-basiert EXAKT wie `personen`**
  (SELECT `sieht_familie`, Schreiben `kann_familie_bearbeiten`). **Storage:** eigener Bucket
  **`personen-fotos`** (public-read wie `avatars`/`familien` → stabile URLs für Karten/PDF ohne
  Signatur-Ablauf), Pfadschema **`{stammbaum_id}/{person_id}/{uuid}`**; Storage-RLS prüft die
  Mitgliedschaft über das **erste Pfad-Segment** (`darf_fotoordner_bearbeiten` → `kann_familie_bearbeiten`)
  → INSERT/UPDATE/DELETE nur in eigene Baum-Ordner, SELECT authenticated + public-Flag. **Frontend
  (`stammbaum.html`):** Verwaltungs-Galerie im **Personen-Editor** (`#pe-galerie`, nur Bearbeiter über
  `istAdmin`/RLS) — Upload mit **clientseitiger Canvas-Kompression** (`galerieKomprimiere`, längste Kante
  1600 px, WEBP/JPEG, Seitenverhältnis erhalten), **„Als Hauptbild"** (`galerieHauptbild` hebt das alte
  auf), **Beschriftung**, **Reihenfolge per Drag&Drop** (`galerieDragStart`, **Pointer-Events** →
  touch-sicher, `touch-action:none`; `sortierung`), **Löschen**. **Read-only-Galerie + Lightbox** in der
  Detailkarte (`#detail-galerie`, für ALLE Nutzer; `oeffneLightbox`/`lightboxNav`, schließt per Button/
  Esc/Pfeile/Hintergrund-Tap — **bewusst KEIN `.modal`**). **Hauptbild → Karten-Avatar:** `setKarteFoto`
  spiegelt die Public-URL in `stammbaum_daten.foto` → bestehende Baum-Karten-/PDF-Avatarlogik zeigt es
  ohne weitere Änderung (erstes hochgeladene Foto wird automatisch Hauptbild); zieht die Optimistic-Lock-
  Baseline des offenen Editors nach (kein Fehl-Konflikt). **Cleanup:** `loeschePerson` ruft
  `galerieLoescheFuerPersonen` (Storage-Dateien; DB-Zeilen per CASCADE) → keine Waisen. Sprachwechsel:
  `galerieSpracheUpdate` rendert offene Grids neu. i18n `gal_*` in allen 5 Blöcken. **v1-Grenzen
  (bewusst):** Fotos hängen an EINER Karte (`person_id`) — identitäts-gespiegelte Zwillinge in anderen
  Bäumen zeigen Galerie/Hauptbild nicht; Bucket public (URL-erreichbar, konsistent mit `avatars`/
  `familien`); Touch-Drag final nur auf echtem Gerät verifizierbar.
- **Dokumente & Quellen pro Person (ab v12.3):** Eigenständiges Belegsystem (Geburts-/Heirats-
  urkunden, Kirchenbücher, Briefe, Sonstiges) parallel zur Foto-Galerie. DB-Datei
  `supabase_personen_dokumente.sql` (idempotent): Tabelle **`personen_dokumente`** (`person_id`→personen
  CASCADE **nullable**, `familie_id`/`stammbaum_id`, `storage_pfad`, `titel`, `dok_typ` CHECK
  [`geburtsurkunde|heiratsurkunde|kirchenbuch|brief|sonstiges`], `quellenangabe` text, `dok_datum` date,
  `sortierung`, `erstellt_am`), **RLS verbund-basiert EXAKT wie `personen`** (SELECT `sieht_familie`,
  Schreiben `kann_familie_bearbeiten`). **Storage — bewusste Abweichung zur Foto-Galerie:** eigener Bucket
  **`personen-dokumente`** ist **NICHT public** (Urkunden sind sensibel) → Zugriff über **signierte URLs**
  (`createSignedUrl(s)`, 1 h); Pfadschema **`{stammbaum_id}/{person_id}/{uuid}`**; Storage-RLS über das
  **erste Pfad-Segment** mit ZWEI Helfern: `darf_dokordner_sehen` (`sieht_familie`, SELECT/Signieren) und
  `darf_dokordner_bearbeiten` (`kann_familie_bearbeiten`, INSERT/UPDATE/DELETE) → dasselbe tree_id-RLS-
  Muster wie Fotos, nur **lese-gated** statt public. **Frontend (`stammbaum.html`):** Verwaltung im
  **Personen-Editor** (`#pe-dok-liste` + Upload-Formular `#pe-dok-form`, nur Bearbeiter über `istAdmin`/RLS)
  — Datei (PDF **oder** Bild, max 20 MB), Titel (Pflicht), Typ-Select, Dokumentdatum (`dp-input`, nur ISO
  in die `date`-Spalte, sonst NULL), Freitext-**Quellenangabe**; Bilder via `galerieKomprimiere`
  komprimiert, **PDFs unverändert** hochgeladen (`dokUpload`). **Read-only-Liste** in der Detailkarte
  (`#detail-dokumente`, ALLE Nutzer mit Lesezugriff): Typ-Icon, Titel, Datum, Quellenangabe, Download +
  Vorschau. **Inline-Vorschau** (`oeffneDokViewer`/`#dok-viewer`): PDF im Browser-Viewer (`<iframe>`),
  Bilder als `<img>`; schließt per Button/Esc/Hintergrund-Tap (**bewusst KEIN `.modal`**, wie die Foto-
  Lightbox). **Löschen** nur für Bearbeiter (`dokLoeschen`, RLS-gated). **Cleanup:** `loeschePerson` ruft
  `dokLoescheFuerPersonen` (Storage-Dateien; DB-Zeilen per CASCADE) → keine Waisen. Sprachwechsel:
  `dokSpracheUpdate` rendert offene Listen neu. i18n `dok_*` in allen 5 Blöcken. **v1-Grenzen (bewusst):**
  Dokumente hängen an EINER Karte (`person_id`) — identitäts-gespiegelte Zwillinge zeigen sie nicht; keine
  Reihenfolge-per-Drag (chronologisch über `sortierung`/`erstellt_am`); iOS-PDF-Inline-Rendering im iframe
  ist geräteabhängig (Download als Fallback) — 🔬 auf echtem Gerät zu verifizieren.
- **Sprach-/Video-Zeitzeugen pro Person (Erinnerungen & Stimmen, ab v13.5):** Stimmen/Erinnerungen
  der Älteren ans Familienarchiv binden — eine Aufnahme (Audio ODER Video) hängt an EINER Karte
  (`person_id`), analog Foto-Galerie/Dokumente. DB-Datei `supabase_person_aufnahmen.sql` (idempotent):
  Tabelle **`person_aufnahmen`** (`typ` CHECK [`audio|video`], `titel`, `transkript`, `dauer_sek`,
  `erstellt_von`, `sortierung`), **RLS verbund-basiert EXAKT wie `personen`** (SELECT `sieht_familie`,
  Schreiben `kann_familie_bearbeiten`). **Storage — wie Dokumente, NICHT wie Fotos:** eigener Bucket
  **`person-aufnahmen` ist NICHT public** (Aufnahmen lebender Personen sind sensibel → bleiben
  STRIKT verbund-intern) → Zugriff über **signierte URLs** (`createSignedUrl(s)`, 1 h); Pfadschema
  **`{stammbaum_id}/{person_id}/{uuid}.{ext}`**; Storage-RLS über das erste Pfad-Segment mit zwei
  Helfern `darf_aufnordner_sehen` (`sieht_familie`) / `darf_aufnordner_bearbeiten`
  (`kann_familie_bearbeiten`). **ABWEICHUNG vom Feature-Prompt (dokumentiert):** der Prompt nannte
  `verbund_id`; wir folgen dem etablierten Medien-RLS-Muster (`familie_id`+`stammbaum_id`,
  verbund-bewusst via `sieht_familie`) statt einer dritten Sichtbarkeits-Logik. **Frontend
  (`stammbaum.html`):** Aufnahme im Browser über die **MediaRecorder-API** (KEINE neue Library —
  Audio `getUserMedia({audio})`, Video `{audio,video}` mit Live-Vorschau, Timer; mime webm, iOS mp4)
  ODER **Datei-Upload** (`accept="audio/*,video/*"`); danach Vorschau-Player + Titel + optionales
  Transkript → Speichern. Verwaltung im **Personen-Editor** (`#pe-aufn-*`, nur Bearbeiter über
  `istAdmin`/RLS); **Abspielen direkt in der Detailkarte** (`#detail-aufnahmen`, alle Nutzer mit
  Lesezugriff, `<audio>`/`<video controls>` inline). Ohne MediaRecorder/getUserMedia bleibt nur der
  Upload (Aufnahme-Steuerung ausgeblendet + Hinweis). **Cleanup:** `loeschePerson` ruft
  `aufnLoescheFuerPersonen` (Storage-Dateien; DB-Zeilen per CASCADE). Sprachwechsel:
  `aufnSpracheUpdate`. i18n `aufn_*` in allen 5 Blöcken (in i18n.js). **PREMIUM-/LIMIT-KANDIDAT**
  (media-/egress-intensiv, Supabase-Egress!): v1 begrenzt clientseitig **50 MB** je Aufnahme; ein
  hartes Server-Quota folgt mit der späteren `abo_status`-Kopplung. **v1-Grenzen (bewusst):**
  Aufnahmen hängen an EINER Karte (identitäts-gespiegelte Zwillinge teilen sie NICHT, wie
  Galerie/Dokumente); **kein** Realtime (lädt frisch beim Öffnen); Reaktions-/Kommentarleiste
  bewusst NICHT angebunden (Engagement-`ziel_typ` kennt `aufnahme` nicht — optionale Folge-
  Erweiterung); Mikrofon/Kamera + iOS-Recording final nur auf echtem Gerät verifizierbar (🔬).
- **Mehrsprachige Lebensgeschichten pro Person (ab v12.3):** Erweitert das einfache Biografie-/Notiz-Feld
  (`stammbaum_daten.beschreibung`, **dessen Verhalten + Sync unverändert bleiben** — `ident_sync` über
  Zwillinge, `profil_person_sync` ↔ `profile.biografie`) **additiv** um strukturierte, mehrsprachige
  Geschichten mit **Markdown**. DB-Datei `supabase_personen_geschichten.sql` (idempotent): Tabelle
  **`personen_geschichten`** (`person_id`→personen CASCADE, `familie_id`/`stammbaum_id`, `sprache` CHECK
  [`de|sr|hr|ba|en`], `titel`, `text` [Markdown-Quelle], `veroeffentlicht` bool, `aktualisiert_am`,
  **UNIQUE(person_id, sprache)**), **RLS verbund-basiert wie `personen`** — SELECT `sieht_familie`, aber
  **Entwürfe** (`veroeffentlicht=false`) NUR für `kann_familie_bearbeiten`; Schreiben `kann_familie_bearbeiten`.
  **Identitäts-Sync wie beim beschreibung-Feld:** eigener Trigger **`geschichte_ident_sync`** spiegelt
  INSERT/UPDATE/DELETE einer Geschichte auf alle `identitaet_id`-Zwillinge (eigene `familie_id`/`stammbaum_id`
  je Karte, gleicher `sprache/titel/text/veroeffentlicht`; Loop-Schutz GUC `app.geschicht_sync_off` +
  `pg_trigger_depth`, exakt analog `ident_sync`). **Backfill:** bestehende `beschreibung` → `de`-Geschichte
  (Trigger während Backfill deaktiviert; jede Zwillingskarte trägt dank `ident_sync` dieselbe `beschreibung`
  und wird direkt getroffen). **Frontend:** `marked` (CDN, SRI) rendert Markdown, **immer** nachgesäubert
  durch `geschCleanElement` (Whitelist-Sanitizer, kein DOMPurify); `geschMarkdownHtml` fällt bei fehlendem
  `marked` auf escapten Klartext zurück. **Editor** (`#pe-geschichte`, nur Bearbeiter): 5 Sprach-Tabs
  (DE/SR/HR/BA/EN, Punkt-Indikator bei Inhalt), Titel-Feld, Markdown-Textarea mit **Live-Vorschau**,
  **Veröffentlicht**-Schalter (Entwurf nur für Bearbeiter); In-Memory-Puffer je Sprache → Tab-Wechsel
  verliert keine ungespeicherten Eingaben; Upsert `onConflict(person_id,sprache)`, leere Geschichte =
  löschen. **Detailkarte** (`#detail-geschichte`, alle Nutzer, read-only): zeigt die Geschichte in der
  **aktuellen App-Sprache**, sonst **Fallback** auf eine vorhandene Sprachversion mit Hinweis
  `gesch_fallback`; verbirgt dann die kurze `beschreibung`-Zeile (`#detail-beschreibung-zeile`).
  `geschEditOeffnen`/`geschDetailRender`/`geschSpracheUpdate` an `zeigePersonBearbeiten`/`zeigeDetails`/
  `wechselSprache` gehängt. i18n `gesch_*` in allen 5 Blöcken (in i18n.js). **Bewusste Grenzen:** beschreibung
  bleibt als eigenständiges Kurz-Notiz-Feld erhalten (de-Geschichte wird einmalig daraus geseedet, danach
  unabhängig); **kein Realtime** für die Tabelle (lädt frisch beim Öffnen, wie Galerie/Dokumente);
  Touch/Live final auf echtem Gerät zu verifizieren (🔬).
- **Beziehung ändern / umhängen (Admin, ab v12.9):** Eine FALSCH angelegte Beziehung lässt sich
  korrigieren, ohne eine Person zu löschen. In der Detailkarte hat jeder Verwandten-Chip neben dem
  **✕** (lösen) einen **⇄**-Button (`bezAendernOeffnen`) → Dialog **`#bez-aendern-modal`**: wählt die
  neue Rolle der Person X bezogen auf die offene Person P (**eltern/geschwister/partner/kind**).
  **Ungültige Ziele werden ausgegraut + mit verständlichem Grund** beschriftet (Client-Vorabprüfung
  `_bezVorfahre`/`_bezSibling`; verbindlich serverseitig). **Ziel = Eltern & P hat schon 2 Eltern**
  → Ersetzen-Schritt (welcher Elternteil ersetzt wird). Umsetzung über die **atomare
  SECURITY-DEFINER-RPC `beziehung_verschieben`** (DB-Datei `supabase_beziehung_verschieben.sql`,
  **vor Frontend-Deploy ausführen**): Rechteprüfung (`kann_familie_bearbeiten` beider Familien),
  **identitätsbewusst** (ganze `identitaet_id`-Gruppe, wie `beziehungLoesen`), in EINER Transaktion
  alle P↔X-Kanten lösen → neue Rollen-Kanten setzen (kein inkonsistenter Zwischenzustand). Liefert
  `sync_kind` → Frontend ruft `kind_baeume_sync`; Blutlinien-Auto-Rechte über die bestehenden Trigger.
  **Validierungsregeln (server + client):** Selbst (auch Zwilling), **kein Zyklus** (eltern: X nicht
  Nachfahre von P; kind: X nicht Vorfahre; geschwister: keins von beidem), **Geschwister können nicht
  Eltern/Partner voneinander werden**, **Partner-Inzest** (direkte Blutlinie/Geschwister) blockiert,
  **2‑Eltern-Grenze** (sonst Ersetzen-Dialog). i18n `bezv_*` in allen 5 Blöcken (in i18n.js);
  Fehlercodes der RPC → i18n-Meldung im Dialog. Dialog liegt z-index-mäßig über dem Detail-Modal und
  schließt nur per Button (UI-Regel). **Bewusste Grenze:** „Geschwister" ohne vorhandene Eltern legt
  einen Platzhalter-Elternteil an (lazy-Bereinigung wie sonst).

## Architektur-Regeln
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
- **Auto-Zweigbaum bei Heirat (neuer Nachname → neuer Stammbaum):** Entsteht beim Anlegen
  eines **Partners** ein NEUER Nachname (Partner-Nachname ≠ Nachname der heiratenden Person und
  im Verbund noch kein Baum dieses Namens), bietet die App **mit Bestätigung** („Vorschlag",
  kein Automatismus) an, für diese Linie einen eigenen Stammbaum anzulegen. **Ab v10.1
  (Nutzerwunsch „eine Familie pro Baum"):** Der neue Baum entsteht in einer **NEUEN, EIGENEN
  Familie** (eigener Owner/Verwaltung, eigener Eintrag im Familien-Dropdown) — **NICHT mehr in
  derselben Familie** wie früher. Die neue Familie liegt im **GLEICHEN VERBUND** wie die
  Ausgangsfamilie → baumübergreifende Sichtbarkeit/Bearbeitung (verbund-basierte RLS) und
  eingeheiratete Personen bleiben erhalten, Isolation gegen fremde Verbünde gewahrt. **Owner der
  neuen Familie = Owner der Ausgangsfamilie** (ersatzweise der ausführende Admin), als
  `auto=false` (geschützt). Personen
  werden **nicht verschoben/kopiert**, sondern als **gleiche Person** über `personen.identitaet_id`
  in den neuen Baum **gespiegelt** (beide Karten bleiben sichtbar; Biografie hält der Trigger
  `ident_sync` synchron). Wurzel des neuen Baums = eingeheirateter Partner; gespiegelt werden
  zudem der/die Ehepartner:in und die **zum Anlegezeitpunkt vorhandenen** gemeinsamen Nachkommen
  (rekursiv, nur Quellbaum) inkl. deren Partner; Beziehungen werden zwischen den Spiegelkarten
  neu aufgebaut. Der **aktuell geöffnete Baum wird NICHT gewechselt** (`ladeBaumDaten` behält ihn),
  nur die Baumliste/der Dropdown wird aktualisiert. RPC `stammbaum_zweig_aus_heirat(p_wurzel,
  p_partner, p_name)` (SECURITY DEFINER, Rechte-/Existenzprüfung via `kann_familie_bearbeiten`/
  `merge_norm`), DB-Datei `supabase_stammbaum_zweig_heirat.sql`. **v1-Grenze:** NACH dem Anlegen
  ergänzte Nachkommen werden NICHT physisch nachgespiegelt; ihre baumübergreifende Sichtbarkeit
  übernimmt die Render-Zusammenführung (siehe nächste Regel).
- **Abweichender Nachname → Overlay „Abweichender Nachname erkannt" (3 Optionen, ab v10.8):**
  Verallgemeinert den partner-only Auto-Zweigbaum auf **JEDE neu angelegte ODER bearbeitete Person**,
  deren Nachname vom Namen des Baums abweicht. **Trigger:** (a) Personenanlage mit abweichendem
  Nachnamen (alle Beziehungstypen, nicht nur Partner — ersetzt den früheren `pruefeHeiratsZweig`-
  Aufruf in `speichereNeuePerson`), (b) Bearbeiten+Speichern, wenn der Nachname auf einen
  abweichenden geändert wird (`speicherePerson`). **Import/automatische Anlagen lösen das Overlay
  bewusst NICHT aus** (kein Massendialog). **Bedingung:** Nachname ≠ Baumname (`zweigNachnameNorm`)
  UND Person hat noch keine baumübergreifende Verknüpfung (`identitaet_id`/`_ident`). **Option 1
  wird IMMER angeboten (ab v11.2, Nutzerwunsch).** Existiert im Verbund bereits ein Baum dieses
  Nachnamens, wird Option 1 NICHT mehr ausgeblendet, sondern nur ein Info-Hinweis darunter gezeigt
  (`abw_baum_existiert`); beim Klick warnt das Frontend ausdrücklich (`zeigeBestaetigung`,
  `abw_existiert_warnung`/`abw_trotzdem_anlegen`) und legt nur auf Bestätigung **trotzdem** einen
  weiteren, eigenständigen Baum an — **zwei verschiedene Familien dürfen denselben Nachnamen tragen**
  (z. B. zwei unabhängige „Simić"). **Overlay `#abw-nachname-modal`**
  (`pruefeAbweichenderNachname`/`oeffneAbwNachname`/`schliesseAbwNachname`, schließt nur per Button):
  **Option 1 „Neuen Stammbaum erstellen"** (`abwNeuerBaum`) ruft die **generische RPC**
  `stammbaum_zweig_aus_person(p_wurzel, p_name, p_force)` (DB-Datei
  `supabase_stammbaum_zweig_person_force.sql`, ersetzt `supabase_stammbaum_zweig_person.sql`,
  SECURITY DEFINER) — wie die Heirat-Variante (neue Familie+Baum, gleicher Verbund, Owner=Owner der
  Ausgangsfamilie auto=false), aber OHNE Partner-Zwang: gespiegelt werden Wurzel + Nachkommen +
  Ehepartner. **`p_force=true`** (gesetzt, wenn der Nutzer den Warnhinweis bei vorhandenem
  gleichnamigem Baum bestätigt) überspringt die Existenzprüfung `zweig_existiert`. Aktueller Baum
  bleibt (`ladeBaumDaten`). **Option 2 „Mit bestehender Person
  verknüpfen"** (`abwVerknuepfen`) wählt einen Beziehungstyp (`beztyp_*`) und öffnet den bestehenden
  `zeigeVerbinden`/`vbVerknuepfe`-Flow (Suche `personen_suche`, Dubletten/Zyklus via
  `verknuepfung_anfragen`, Cross-Tree-Merge greift). **Option 3 „Ohne Verknüpfung fortfahren"**
  (`abwOhne`) lässt die Person wie gespeichert. i18n `abw_*` in allen 5 Blöcken (in i18n.js);
  `wechselSprache` ruft `abwSpracheUpdate` (Titel + Beziehungs-Select). Die alte
  `pruefeHeiratsZweig`/`stammbaum_zweig_aus_heirat` bleibt als Code/RPC erhalten, wird aber vom
  neuen Flow nicht mehr aufgerufen.
- **Geschwister ohne vorhandene Eltern → Platzhalter-Elternteil (ab v10.7):** Legt man im
  „Person hinzufügen"-Overlay ein **Geschwister** zu einer Person an, die noch **keine Eltern**
  hat (bzw. verknüpft eine bestehende Person als Geschwister), wird **NICHT mehr blockiert**
  (früher Hinweis `pa_geschwister_keine_eltern`). Stattdessen legt das Frontend automatisch einen
  **Platzhalter-Elternteil** an (`erzeugePlatzhalterElternteil`, Marker `stammbaum_daten.platzhalter:true`,
  `angelegt_aus:'geschwister-platzhalter'`, ohne `user_id`) und hängt **beide Geschwister** als Kind
  daran → echte Geschwister-Verknüpfung statt loser, im Single-Root-Baum unsichtbarer Karte. Der Nutzer
  muss so keine Eltern vorab erfassen (Nutzerwunsch). Der **Anzeigename** des Platzhalters ist KEIN
  Datenwert: `lokalisierePlatzhalterNamen` setzt ihn sprachabhängig (`pa_platzhalter_name`,
  in allen 5 Blöcken; sr = „Непознато", `nm()` lässt Kyrillisch unverändert) — aufgerufen in
  `ladeBaumAusSupabase` UND in `wechselSprache` (vor dem Neu-Rendern), damit er in allen Sprachen
  stimmt. Folgende Geschwister-Adds reuse den Platzhalter automatisch (Bezugsperson hat dann Eltern).
  Aufrufstellen: `speichereNeuePerson` (geschwister-Zweig) + `vbVerknuepfe` (geschwister). Platzhalter
  ist normal editierbar (kann später mit echten Elterndaten gefüllt werden) und identitäts-frei löschbar.
  **v1-Grenzen (bewusst):** kein Cross-Tree-Mirroring des Platzhalters (lokal im aktuellen Baum); werden
  beide Kinder gelöscht, bleibt der Platzhalter als lose Karte (Auto-Leer-Bereinigung greift erst bei 0
  Personen im Baum).
- **Kind-Sichtbarkeit über beide Eltern — Vater/Mutter-Dialog + Spiegelung (ab v8.8/8.9):** Beim
  Anlegen eines Kindes (Personen-Overlay) gibt es **durchsuchbare Vater-/Mutter-Felder** (über
  aktuellen + alle Verbund-Bäume via RPC `personen_suche`; vorbelegt nach Geschlecht/eindeutigem
  Ehepartner, änder-/entfernbar). Nach Anlage/Verknüpfung ruft das Frontend die SECURITY-DEFINER-RPC
  **`kind_baeume_sync(p_kind)`** (Datei `supabase_kind_baeume_sync.sql`): sie sammelt die Bäume ALLER
  Karten BEIDER Eltern (Identitätsgruppen über `identitaet_id`) und **spiegelt das Kind** (gleiche
  `identitaet_id`, Trigger `ident_sync` synchronisiert die Biografie) in jeden dieser Bäume, in denen
  es fehlt — nur in editierbare Bäume (Isolation gewahrt), Eltern-Kanten je Baum idempotent.
  Aufrufstellen: `speichereNeuePerson`, `dubVerknuepfen`, `vbVerknuepfe`. **Hinweis:** Die
  Render-Zusammenführung in `baueBaumDaten` (identitaet_id + `bruecke`) bridged Kinder identitäts-
  verknüpfter Eltern zusätzlich; das physische Spiegeln ist die robuste Variante, wenn die Render-
  Brücke (z. B. mangels Eltern-Verknüpfung) nicht greift.
  **Render-Invariante — Kind-Entdopplung bevorzugt die Karte des AKTUELLEN Baums (ab v9.4, nicht
  zurückbauen):** Existiert dieselbe reale Person als MEHRERE Karten unter denselben Eltern (gleiche
  `identitaet_id` ODER — ohne Verknüpfung — gleicher Vorname, `childKey` in `baueBaumDaten`), wählt die
  Entdopplung (`globalKinder`) die Karte, die im **gerade gezeichneten Baum** liegt (`sameTree`).
  Sonst würde der „Entdopplungs-Sieger" in einem ANDEREN Baum liegen und anschließend vom
  `sameTree`-Filter (`zeigeKind`) verworfen → das Kind verschwände, obwohl es im aktuellen Baum eine
  gültige Karte hat (war der Bug: Mila als Kind von Slađana/Knežević + Milan/Vidović wurde im
  Knežević-Baum nicht angezeigt). Greift unabhängig von `identitaet_id` (rein render-seitig, keine
  DB-Änderung).
  **EINGESCHRÄNKT ab v11 durch die Blutlinien-Kappung (siehe nächste Regel):** Spiegelung
  (`kind_baeume_sync`) + Brücke (`bruecke`) + `globalKinder`-Entdopplung gelten weiterhin für die
  **direkten Kinder** eines Blutlinien-Mitglieds (ein Kind taucht in jedem Baum auf, in dem ein
  Elternteil liegt) — ABER der Renderer **steigt nicht mehr unbegrenzt baumübergreifend ab**: nach der
  ersten ausgeheirateten Generation endet die Darstellung an einem Übergangspunkt, damit keine
  doppelte Blutlinie entsteht.
- **Blutlinien-Kappung im Renderer — „ein Stammbaum = eine Blutlinie" (Variante B, ab v11):** Ein
  Stammbaum zeigt seine eigene Blutlinie (Vorfahren + Nachkommen entlang des Namens) **vollständig**,
  dazu **Ehepartner**, **alle Kinder eines Blutlinien-Mitglieds** (unabhängig vom Nachnamen) UND deren
  **Ehepartner + eigene Kinder** (die erste ausgeheiratete Generation bleibt komplett). Erst die
  **ZWEITE auswärtige Generation in Folge** (Kinder einer bereits auswärtigen Person) wird — sofern für
  ihren Nachnamen im Verbund ein eigener Baum existiert — als **Blatt** (Karte ohne Partner/Nachkommen)
  + **klickbares Gold-Badge „→ {Baum}"** gekappt; ihre Nachkommen leben im Ziel-Baum → **keine doppelte
  Blutlinie**. Technik (in `baueBaumDaten`): `baueKnoten` reicht `elternAuswaerts` durch; `selbstAuswaerts
  = !istBlutName(p)`; bei `selbstAuswaerts && elternAuswaerts && zielBaumFuer(nachname)` → Blatt-Knoten
  mit Flag `uebergang`. **`istBlutName` prüft Nachname UND Mädchenname (`ehename`/née) gegen den
  Baumnamen** (`zweigNachnameNorm`) — damit eine eingeheiratete Blutlinien-Frau (z. B. née „Vidović")
  NICHT fälschlich als auswärts zählt und ihre Kinder zu früh gekappt werden; **Fallback gegen leere
  Mädchennamen:** trägt der **Vater** (husband der Geburtsfamilie, `families_child`) den Baumnamen,
  gilt die Person als in die Blutlinie geboren (Geburtsname folgt dem Vater). **Daten-Pflege:** der
  Mädchenname (`ehename`) SOLLTE bei verheirateten Frauen befüllt sein (Nutzer-Vorgabe ab v11), sonst
  greift nur der Vater-Fallback. **Bewusst strukturell**
  (zählt auswärtige Generationen) statt von `identitaet_id`-Spiegelung abhängig → **konsistent über
  Geschwister** (frühere Fassung kappte nur gespiegelte Karten → inkonsistente Anzeige). `zeichneBaum`
  zeichnet das Badge (`.uebergang-badge`, i18n `bl_uebergang`/`bl_uebergang_titel` in allen 5 Blöcken;
  Klick = `waehleStammbaum(zielId)`). **Bewusste Grenze (verifiziert am Code):** Existiert für den
  Fremdnamen **kein** Ziel-Baum (Import, Overlay-Option 3 „ohne Verknüpfung" [[project_familie_pro_baum]],
  Altbestand vor v10.8), wird **NICHT** gekappt — sonst würden die Nachkommen NIRGENDWO erscheinen
  (die Linie bleibt sichtbar, bis eine Generation einen eigenen Baum hat). **Geltungsbereich:** greift
  in der **kanonischen Baum-Ansicht** (Voll-/Standardansicht) sowie im **Einzel-Baum-PDF**; bewusst
  **abgeschaltet** (`opts.uebergangCut:false`) in den expliziten Explore-Modi (`zeigeZweigAbPerson`,
  `zeigeErweitertAnsicht`) und im **PDF mit „verknüpfte Bäume einbeziehen"** (dort `aktuellerStammbaumId
  = null` → Cut automatisch aus), weil diese Modi gezielt baumübergreifend/tiefer zeigen sollen.
  **Backup vor Einführung:** Daten-Snapshot in Schema `backup_bl` (`backup_blutlinie_render_*.sql`) +
  Git-Tag `pre-blutlinie-render-*`.
- **Stammbaum-Name = REINER Nachname; Unterscheidung gleichnamiger Familien im Feld `zusatz`
  (ab v11.3):** Der Baum-/Familienname enthält NUR den Nachnamen — erlaubt sind Buchstaben (inkl.
  Diakritika/Kyrillisch), Leerzeichen, Bindestrich, Apostroph (Frontend `istGueltigerBaumName` +
  Live-Filter `filterBaumNameInput`; Fehlermeldung `name_nur_buchstaben`). Zusätze zur Unterscheidung
  (früher als Klammer im Namen, z. B. „Pisarević (Desa)", oder „Stephen - Vidović") gehören in die
  **eigene Spalte `stammbaeume.zusatz`** (DB-Datei `supabase_stammbaum_zusatz.sql`; Migration splittet
  Bestandsnamen automatisch). Anzeige überall als **„Name (Zusatz)"** über die Helfer `baumLabel(treeId)`
  / `baumLabelNZ(name, zusatz)` / `trefferBaumLabel(r)` (Dropdown, Kopf, Suche, PDF, Merge); im
  Frontend in den Maps `stammbaeumeListe` (reiner Name) + `stammbaeumeZusatz`. **Folge für die
  Blutlinien-Kappung:** `istBlutName`/`zielBaumFuer` vergleichen jetzt den SAUBEREN `name` — die
  „letztes Wort"-Heuristik in `zweigNachnameNorm` (Klammer-/„ - "-Strip) bleibt nur als Sicherheitsnetz
  für Altbestand/Fehleingaben. RPCs mit Zusatz: `stammbaum_anlegen`(+`p_zusatz`),
  `stammbaum_einstellungen_holen/speichern`, `verwaltbare_familien` (zeigt „Name (Zusatz)" für die
  Mitglieder-Suche). **Eingabe-/Editier-Stellen:** „Kreiraj novo stablo" (`bn-zusatz`) und
  Familieneinstellungen (`fe-zusatz`); „Kreiraj nalog" validiert nur den Namen (Zusatz dort nicht,
  Edge-Function-Pfad — nachträglich über Einstellungen setzbar). **Konventions-Grenze:** Regel nimmt
  als Nachname das letzte Wort → ein bewusst zweiwortiger Name (Zusatz OHNE Klammer HINTER den Namen)
  wird nicht erkannt; Zusätze daher ins Feld bzw. in Klammern.
  **Löschen ist identitätsbewusst (ab v8.9) — Invariante, nicht zurückbauen:** `loeschePerson`
  entfernt ALLE `identitaet_id`-Zwillingskarten einer Person (über alle Bäume) + deren Beziehungen
  in EINEM Schritt → eine gelöschte Person (inkl. Spiegel) taucht NIRGENDWO mehr auf, **kein „zweimal
  löschen"**. Leer gewordene Bäume werden via `auto_leere_baeume_aufraeumen` kontoschonend bereinigt
  (Owner-Exklusivrecht bleibt: nur owner/super_admin dürfen einen Baum leeren).
- **Gleiche Person / Dubletten (Super-Admin) — zwei klar getrennte Operationen je nach Baum-Wahl
  (ab v8.2):** Beide Werkzeuge sind NUR für `super_admin` sichtbar.
  - **„Gleiche Person verknüpfen" (Spiegeln, beide Karten bleiben):** Dieselbe reale Person in
    **ZWEI verschiedenen** Bäumen → gemeinsame `personen.identitaet_id` (Daten angeglichen,
    Verbünde verbunden, beide Karten bleiben sichtbar; Trigger `ident_sync` hält sie synchron).
    Auswahl per Auto-Dubletten (`offene_dubletten(baum_a,baum_b)`) ODER **manueller Personen-Wahl
    je Baum** (RPC `personen_eines_baums(p_baum)`, Datei `supabase_personen_eines_baums.sql`;
    bereits verknüpfte Karten mit 🔗 markiert). RPC `personen_verknuepfen`. Datei
    `supabase_gleiche_person_sync.sql`.
  - **Innerhalb DESSELBEN Baums → MERGE statt Spiegeln (eine Karte bleibt):** Wird im
    „Gleiche Person"-Modal links UND rechts **derselbe** Baum gewählt, ergäbe Spiegeln zwei
    identische Karten im selben Baum (sinnlos). Deshalb wird dort **zusammengeführt**: Survivor =
    vollständigere Karte, Beziehungen/`event_teilnehmer`/`user_id`/Konto wandern um, die Dublette
    wird gelöscht (Backup in `merge_log`, rückgängig via `merge_rueckgaengig`). Goldener Hinweis im
    Modal macht das transparent. Technisch über `person_merge_aufgeloest(behalten,dublette,
    aufloesung)` — dieselbe RPC wie das „Dubletten-Merge"-Werkzeug.
  - **„Dubletten-Merge"-Werkzeug erlaubt jetzt ebenfalls denselben Baum** (Within-Tree-Merge):
    der frühere Block „zwei verschiedene Bäume" ist ersetzt durch „nicht dieselbe Karte"
    (`pa ≠ pb`); bei gleichem Baum entfällt der baumübergreifende `dubletten_scan` (nur das
    explizit gewählte Paar) und Schritt 4 (Baum-Konsolidierung). `person_merge_aufgeloest` ist
    baum-unabhängig; bleibt der Survivor im Baum, greift KEINE Baum-Auto-Löschung. Datei
    `supabase_merge_gui.sql`.
- **Auto-Löschung leerer Stammbäume (kontoschonend, Owner/Super-Admin):** Sinkt ein Baum durch
  Löschen auf **0 Personen** (`personen` mit dieser `stammbaum_id` = 0), wird er automatisch
  entfernt — aber **kontoschonend**: nur die `stammbaeume`-Zeile (inkl. `einstellungen`-jsonb) +
  baum-eigene `beziehungen`; Events hängen per CASCADE, Event-**Medien** im Storage über die Queue
  `verwaiste_event_medien` (Frontend `raeumeVerwaisteMedien`). **Familie/Mitgliedschaften/Anfragen
  bleiben bestehen** — auch beim LETZTEN Baum (tree-loser Nutzer landet auf „Kreiraj novo stablo").
  **Bewusste Abweichung** zur manuellen `stammbaum_loeschen`, die beim letzten Baum das ganze Konto
  abräumt: die Auto-Löschung räumt NIE Familie/Konto ab. Das **Löschen der letzten Person** dürfen
  nur `familien_owner`/`super_admin` (Owner-Exklusivrecht bleibt) — vorher Pflicht-Warnung
  („… letztes Mitglied → gesamter Stammbaum wird entfernt", i18n in allen 5 Sprachen). Nach Erfolg:
  Navigation auf zuletzt genutzten Baum → Standard/größten → sonst „Kreiraj novo stablo".
  Orchestrierung **Frontend + SECURITY-DEFINER-RPCs** (`stammbaum_loesche_wenn_leer` für die
  Einzel-Löschung, `auto_leere_baeume_aufraeumen` als Sweep für Batch-Quellen) — **kein blinder
  DB-Trigger** (Storage-Medien sind aus Postgres nicht löschbar; das Bereinigungs-Tool verbietet
  Auto-Trigger). **Schutzregel:** läuft NICHT, solange eine `wartungs_sperren`-Zeile aktiv ist
  (Merge/Restore/Migration/Bereinigung/Massenlöschung/Import) — Batch-Tools umklammern ihre Mutation
  mit `wartung_start`/`wartung_ende`. Audit in `familien_audit` (`aktion='auto_leer_geloescht'`:
  Baum-ID, Name, Personen-vorher, Nutzer, Datum, Grund). DB-Datei `supabase_stammbaum_auto_leer.sql`.
- Familien-Isolation: jede Familie sieht nur eigene Daten (verbundweit), außer Super-Admin.
- **Kochbuch-Bewertungen = EINZIGE globale Datenart (bewusste Isolations-Ausnahme, ab v14.25):**
  Nutzer bewerten die statischen Kochbuch-Rezepte (`rezepte_pool.js`/`REZEPT_POOL`, stabile `id`)
  mit **1–5 Sternen; Aggregat GLOBAL über ALLE Nutzer/Verbünde** (vom Nutzer ausdrücklich so
  gewählt). Zulässige Ausnahme zur „strikt verbund-gebunden"-Social-Regel, weil KEINE Personen-/
  Familiendaten die Grenze überschreiten — nur ein **anonymer Aggregatwert** (Ø + Anzahl) auf
  global-öffentlichem Read-only-Inhalt. Tabelle **`kochbuch_bewertungen`**(`rezept_key`,`user_id`,
  `sterne`, PK(rezept_key,user_id) = 1 Bewertung je Nutzer je Rezept), **RLS AN, aber OHNE Policies**
  → kein direkter Client-Zugriff; ALLES über SECURITY-DEFINER-RPCs `kochbuch_bewerten(p_key,p_sterne)`
  (Upsert der eigenen Bewertung) / `kochbuch_bewertungen_holen(p_keys)` (liefert je Key NUR
  `{avg,anzahl,meine}` — Fremd-Einzelbewertungen sind NIE lesbar). DB-Datei
  `supabase_kochbuch_bewertungen.sql`. Frontend: Sterne-Widget in `kbVollHtml` (Detail + Tagesgericht)
  + Ø-Chip in den Listenkarten (`kochbuchRender`); Cache `kochbuchBewertungen` via `kochbuchBewLaden`
  (in `kochbuchInit`), Klick `kochbuchStern` → RPC → `kochbuchSterneNeu`. **Gilt NUR fürs Kochbuch**,
  NICHT für die verbund-gebundenen `familien_rezepte` (die bleiben strikt verbund-intern). i18n
  `kb_rating_*` in allen 5 Blöcken.
- Datenmodell: `familien` = Konto/Mandant; `stammbaeume` = Bäume (familie_id); `personen`/
  `beziehungen` referenzieren `stammbaum_id`/`familie_id`. Rollen liegen in `mitgliedschaften`
  (user_id + familie_id + rolle). Sichtbarkeit/Verknüpfung über `verbund_id` der Familie.
- **Chat (1:1 + Gruppen) — Geltungsbereich = VERBUND (ab v12.3):** Die Chat-Funktion ist eine
  eigene, dauerhafte Domäne. **Ein Chat gehört zu genau EINEM `familien.verbund_id`** (Ausnahme:
  verbundübergreifende Kontakt-Chats ab v13.1 → `verbund_id = NULL`, siehe Discovery-Regel unten). Chat-fähig
  (sicht-/auswählbar als Gegenüber) sind ausschließlich Nutzer, die mit dem Aufrufer **mindestens
  einen `verbund_id` teilen** (= „alle verknüpften Stammbäume" desselben Verbunds) — NICHT nur die
  eigene Familie, aber auch NICHT verbundübergreifend (Isolation gegen fremde Verbünde bleibt
  gewahrt). **AUSNAHME ab v13.1 (verbundübergreifende Kontakt-Chats):** Eine genehmigte
  `kontakt_verbindungen`-Zeile (3-Stufen-Discovery, siehe Regel unten) erlaubt einen 1:1-Chat
  zwischen genau zwei Konten OHNE gemeinsamen Verbund — der EINZIGE verbundübergreifende Chat-Pfad;
  alles andere bleibt strikt verbund-gebunden. **AUSNAHME zur Regel „super_admin ist in der GUI unsichtbar" — NUR im Chat (ab v12.5,
  ausdrücklicher Nutzerwunsch):** Im Chat nimmt `super_admin` **wie ein normaler Verbund-Nutzer**
  teil — er erscheint in `verbund_nutzer()` (für andere sicht-/anschreibbar) und kann selbst Chats
  starten, **scoped auf seinen eigenen Verbund** (kein verbundübergreifender Sonderzugriff, Isolation
  bleibt). Diese Ausnahme gilt **ausschließlich für die Chat-Domäne**; in allen anderen GUI-Bereichen
  bleibt `super_admin` für normale Nutzer unsichtbar. Weiterhin gilt: `super_admin` kann **keine
  fremden Chats** lesen (SELECT ist strikt teilnehmer-gebunden, nicht super-admin-weit). **Tabellen:**
  `chats`(verbund_id, typ `direkt`/`gruppe`, name, erstellt_von) / `chat_teilnehmer`(chat_id, user_id,
  ist_gruppen_admin, zuletzt_gelesen_am) / `chat_nachrichten`(chat_id, absender_id, text, bearbeitet_am,
  geloescht) — DB-Datei `supabase_chat.sql`. **RLS rekursionsfrei** über den SECURITY-DEFINER-Helfer
  `ist_chat_teilnehmer(p_chat)` (kein Self-Subquery in der Policy); SELECT auf alle drei Tabellen nur
  für Teilnehmer; eigene Nachricht bearbeiten/löschen (`geloescht=true`, **kein hartes DELETE**) nur
  durch `absender_id`; Teilnehmer entfernen / Gruppen-Admin setzen nur durch `ist_gruppen_admin` ODER
  `familien_owner`/`familien_admin` im Verbund (RPCs). **Transport = Supabase Realtime** (wie
  Baumdaten, NICHT Polling): `chat_nachrichten` + `chat_teilnehmer` haben echte RLS-SELECT-Policies
  und liegen in der Publication `supabase_realtime` (idempotent in `supabase_chat.sql`). **Lifecycle
  `startChat`/`stopChat`** analog `startRealtimeSync`/`startPresence`: Start nach `ladeBaumDaten` im
  Login-Flow, Stop in `loescheUser`; der Realtime-Callback setzt den **Inaktivitäts-/Auto-Logout-Timer
  NICHT** zurück (eingehende Nachrichten zählen nicht als Aktivität — nur eigenes Tippen/Senden), bei
  verstecktem Tab Update aufschieben und bei `visibilitychange` nachholen. **RPCs** (SECURITY DEFINER,
  geben nur erlaubte Daten zurück): `verbund_nutzer()`, `direkt_chat_finden_oder_anlegen(p_user2)`
  (eindeutiger 1:1-Chat, Unique über sortiertes User-Paar + verbund_id; bei verbundübergreifenden
  Kontakt-Chats Dedupe-Key OHNE Verbund `kontakt|a|b` + `verbund_id = NULL`, v13.1), `gruppen_chat_anlegen(p_name,
  p_user_ids[])`, `chat_nachricht_senden(p_chat,p_text)`, `chat_gelesen`, `chat_teilnehmer_entfernen`,
  `chat_gruppen_admin_setzen`. Erreichbar über das Avatar-/⚙-Menü für **ALLE eingeloggten Nutzer**
  (auch reine Lesemitglieder). i18n `chat_*` in allen 5 Blöcken. **Bewusste v1-Grenze:** rein
  textbasiert (keine Datei-/Bild-Anhänge → Storage-Cleanup-Aufwand), **keine** E-Mail-Benachrichtigung,
  **kein** „schreibt gerade…" — dokumentierte Folge-Erweiterungen.
- **Verbundübergreifende Personensuche + Kontaktanfragen („Instagram-Prinzip", 3 Stufen, ab v13.1):**
  Durchbricht die `verbund_id`-Isolation BEWUSST an **genau ZWEI** kontrollierten Stellen —
  sicherheitskritisch, nicht zurückbauen. DB-Dateien: `supabase_auffindbarkeit.sql`,
  `supabase_kontakt_anfragen.sql`, `supabase_baum_freigaben_rls.sql`, `supabase_chat_kontakt.sql`
  (Reihenfolge siehe SCHEMA.md §15). **Stufe 1 ENTDECKEN:** RPC `personen_entdecken(p_query)`
  (SECURITY DEFINER) liefert verbundübergreifend AUSSCHLIESSLICH **vier Minimalfelder**
  `{person_id, name, familienname, avatar_url}` — die RLS-SELECT-Policy auf `personen` bleibt
  UNVERÄNDERT (Bruch ist in der RPC gekapselt). Eignungsregel zentral im Helfer `_person_entdeckbar`
  (EINZIGE Quelle der Wahrheit, auch von `kontakt_anfrage_stellen` genutzt): nur FREMDER Verbund;
  **Minderjährige (lebend) NIE** (HARTES Tor, nicht verhandelbar); **Lebende** sind seit **v13.9
  per OPT-OUT standardmäßig auffindbar** — Bedingung: via `user_id` ein Konto verknüpft, NICHT
  versteckt (`profile.auffindbar_extern <> false`, DB-Default `true`) UND beweisbare Volljährigkeit
  (ISO-`birth_date`, Alter≥18 via `_alter_jahre`; Alter nicht berechenbar ⇒ ausgeschlossen =
  Minderjährigen-Sicherheitsnetz). Wer NICHT gefunden werden will, deaktiviert den Schalter im
  Privatsphäre-Overlay (`auffindbar_extern=false`); `_person_entdeckbar` nutzt
  `coalesce(auffindbar_extern, true)` (fehlende profile-Zeile = auffindbar). **Verstorbene** default
  auffindbar, Admin-Opt-out je Baum (`stammbaeume.einstellungen->>'discovery_verstorbene'='false'`)
  oder je Karte (`stammbaum_daten->>'nicht_auffindbar'='true'`). **Interpretation (dokumentiert):** der
  Minderjährigen-Schutz gilt für LEBENDE; jung Verstorbene fallen unter die Verstorbenen-Regel.
  Avatar nur bei NEUER `profile.avatar_sichtbarkeit`-Stufe **`'oeffentlich'`** (lebende Konten) bzw.
  Karten-Foto (Verstorbene) — die Auffindbarkeit (Name) ist Opt-out, das **Profilbild** bleibt
  bewusst Opt-in (`oeffentlich`). Steuerung NUR durch das Konto selbst (Betreiber-Entscheidung).
  **Migration v13.9:** Spalten-Default `true` (idempotent in `supabase_auffindbarkeit.sql`) +
  einmaliger Bestands-Backfill `sql_archiv/backfill_auffindbar_optout.sql` (NICHT erneut ausführen,
  sobald Nutzer sich aktiv verstecken). Konto-Anlage zeigt Hinweis `reg_auffindbar_hinweis`. **Stufe 2
  KONTAKT:** `kontakt_anfrage_stellen(...,'kontakt')` nur auf entdeckbare Karte MIT Konto
  (`personen.user_id`); Entscheider ist AUSSCHLIESSLICH der Familien-Admin/Owner/Super-Admin der
  Zielfamilie (`kann_familie_bearbeiten`) — ein `familien_mitglied` NIE. Genehmigung → Zeile in
  `kontakt_verbindungen` (sortiertes Paar) → erlaubt verbundübergreifenden 1:1-Chat (Helfer
  `darf_chatten`; `chats.verbund_id` für solche Chats nullable; Picker via `meine_kontakte`). **Stufe 3
  BAUMZUGRIFF:** SEPARATE zweite Anfrage `typ='baumzugriff'` (setzt aktive `kontakt_verbindung`
  voraus; Zielbaum = Baum der entdeckten Person), zweite Admin-Genehmigung → Zeile in `baum_freigaben`.
  **ZWEITE Bruchstelle:** `supabase_baum_freigaben_rls.sql` erweitert die SELECT-Policies auf
  `personen`/`stammbaeume` ADDITIV um `darf_baum_sehen(stammbaum_id)` und auf `beziehungen` um
  `darf_beziehung_sehen(person_a,person_b)` (da `beziehungen` KEIN `stammbaum_id` hat → Kante nur
  sichtbar, wenn BEIDE Endpunkte sichtbar). NUR LESEN; Schreiben bleibt verbund-/admin-gebunden.
  Widerruf (`baum_freigaben.status='widerrufen'` via `baum_freigabe_widerrufen`) wirkt SOFORT
  (`darf_baum_sehen` prüft live). Admin-Benachrichtigung = Polling wie `offene_anfragen()`
  (`offene_kontakt_anfragen()`, fließt in den Avatar-Obav-Badge, pausiert bei verstecktem Tab, setzt
  den Inaktiv-Timer NICHT zurück); Antragsteller-Ergebnis = `benachrichtigungen`-Zeile
  (typ `kontakt_*`/`baumzugriff_*`). Frontend: Entdecken-Overlay `#entdecken-modal` (Umschalter
  eigener Verbund [`personen_suche`] ↔ andere Familien [`personen_entdecken`]), Opt-in-Schalter +
  Avatar-Stufe im Privatnost-Overlay. **Alle neuen Helfer SECURITY DEFINER + rekursionsfrei.** i18n
  `ent_*`/`benachr_kontakt_*`/`benachr_baumzugriff_*`/`prof_sicht_oeffentlich` in allen 5 Blöcken.
  **v1-Grenze (bewusst):** Baumzugriff gilt für den Baum, in dem die entdeckte Person liegt (keine
  freie Baum-Wahl, da der Anfragende fremde Bäume nicht aufzählen darf); Kontakte sind nur für
  Direkt-Chat nutzbar (Gruppen erfordern weiterhin gemeinsamen Verbund).
- **Reaktionen & Kommentare — wiederverwendbares, POLYMORPHES Engagement-System (Social-Basis, ab
  v13.2):** Erstes Primitiv der sozialen Schicht; alle weiteren Social-Features bauen darauf auf.
  DB-Datei `supabase_reaktionen_kommentare.sql` (idempotent). **Zwei polymorphe Tabellen** mit
  denormalisiert mitgeführtem `verbund_id` (KEIN polymorpher Join in der Policy → einfache,
  rekursionsfreie RLS): `reaktionen`(verbund_id, `ziel_typ` CHECK [`foto|geschichte|beitrag|person|
  event`], `ziel_id`, user_id, `typ` CHECK [`gefaellt|herz|lachen|wow|traurig`], **UNIQUE(ziel_typ,
  ziel_id,user_id)** = 1 Reaktion je Nutzer je Objekt) und `kommentare`(…, `eltern_kommentar_id`
  = optionale Threads **auf 1 Ebene** [tiefere Antworten klappen serverseitig auf die Wurzel],
  `text`, `bearbeitet_am`, `geloescht` bool). **STRIKT VERBUND-GEBUNDEN** (Social-Regel): SELECT nur
  für `ist_in_verbund(verbund_id)` — **KEIN** `baum_freigaben`-Pfad (Baumzugriff ist read-only-
  Stammbaum, KEINE Social-Teilnahme → Isolation gewahrt). **Schreiben ausschließlich über
  SECURITY-DEFINER-RPCs** (kein direktes INSERT/UPDATE/DELETE): `verbund_id` wird serverseitig aus
  dem Zielobjekt abgeleitet (`_ziel_verbund`, DEFINER, polymorph; `'beitrag'` noch nicht vorhanden
  → liefert NULL → RPC meldet `ziel_unbekannt`) → nicht fälschbar. RPCs: `reaktion_umschalten`
  (toggle), `kommentar_schreiben`/`kommentar_bearbeiten` (nur Autor) /`kommentar_loeschen`
  (soft `geloescht=true`, Autor ODER Moderator), `engagement_holen` (EIN Roundtrip: Reaktions-Zähler
  + eigene Reaktion + Kommentar-Thread inkl. Anzeigename/Avatar aus profile/auth + `darf_*`-Flags).
  Moderation (fremde Kommentare löschen) über `darf_verbund_moderieren` (familien_owner/admin im
  Verbund + super_admin). **Transport = Supabase Realtime** (beide Tabellen in Publication
  `supabase_realtime`, REPLICA IDENTITY FULL). **Frontend:** EIN wiederverwendbares Widget
  (`engagementMount(containerId, zielTyp, zielId)` / `engagementUnmount`): Reaktionsleiste (5 Emojis,
  eigene Reaktion umschaltbar) + Kommentar-Thread (schreiben/antworten[1 Ebene]/bearbeiten/löschen).
  Eingebunden in **Person-Detail** (`#detail-engagement`, ziel=`person`,`_uuid`; NICHT für
  Platzhalter), **Event-Detail** (`#event-engagement`,`event`), **Foto-Lightbox**
  (`#lightbox-engagement`,`foto`, wechselt mit der Navigation), **Geschichte-Detail**
  (`#gesch-engagement`,`geschichte`, row.id). Lifecycle `startEngagementSync`/`stopEngagementSync`
  analog Chat (Start nach `ladeBaumDaten`, Stop + `engagementUnmountAlle` in `loescheUser`); der
  Realtime-Callback setzt den **Inaktivitäts-/Auto-Logout-Timer NICHT** zurück, bei verstecktem Tab
  aufgeschoben. `wechselSprache` ruft `engagementSpracheUpdate`. i18n `eng_*` in allen 5 Blöcken.
  **v1-Grenzen (bewusst):** `'beitrag'` ist im CHECK reserviert, aber die Beitrags-Tabelle existiert
  noch nicht (Folge-Feature); Reaktionen/Kommentare hängen an EINER Karte/Zeile (identitäts-
  gespiegelte Zwillinge teilen sie NICHT, analog Galerie/Dokumente).
- **Familien-Feed / Beiträge (Social-Schicht, ab v13.3):** Verbund-gebundene Pinnwand — Mitglieder
  posten Text (+ optionales Foto + optionale Personen-Markierung); Reaktionen/Kommentare über das
  bestehende Engagement-System (`ziel_typ='beitrag'`). DB-Datei `supabase_beitraege.sql` (idempotent,
  **NACH `supabase_reaktionen_kommentare.sql`**, weil sie `_ziel_verbund` um den `beitrag`-Zweig
  erweitert). Tabelle **`beitraege`**(`verbund_id`, `autor`, `text`, `bild_pfad`/`bild_url`,
  `ref_person`→personen [SET NULL], `geloescht`). **STRIKT VERBUND-GEBUNDEN:** SELECT nur
  `ist_in_verbund(verbund_id)` (echte RLS → Realtime); Schreiben ausschließlich über
  SECURITY-DEFINER-RPCs (`verbund_id` serverseitig aus `mein_verbund()` abgeleitet → nicht fälschbar).
  RPCs: `beitrag_erstellen` (Text und/oder Bild, Markierung nur wenn Person im EIGENEN Verbund),
  `beitrag_bearbeiten` (nur Autor, nur Text), `beitrag_loeschen` (soft; Autor ODER Moderator
  `darf_verbund_moderieren`; gibt `bild_pfad` zurück → Frontend räumt Storage). **Lesen:** der Feed
  liest NICHT mehr über ein eigenes `feed_holen` (entfernt), sondern über den allgemeinen
  Aktivitäten-Stream `aktivitaeten_holen` (siehe nächste Regel). **Storage:**
  public-Bucket **`beitraege`**, Pfad `<user_id>/<uuid>`, Schreiben nur eigener Ordner (wie `avatars`);
  Bilder clientseitig per `galerieKomprimiere` (≤1600 px). **Realtime:** `beitraege` in Publication,
  Channel `feed-sync` lädt den Feed neu (NUR wenn sichtbar), setzt den Auto-Logout-Timer NICHT zurück.
  **Frontend:** neuer **Tab „Feed"** (`#tab-feed`, nur eingeloggt) + Sektion `#ansicht-feed`
  (`wechselAnsicht('feed')`→`zeigeFeed`), Composer (`feedBeitragSenden`) + Liste (`feedRender`); je
  Beitrag ein Engagement-Widget (`feed-eng-<id>`). Suche im Feed deaktiviert (wie Events).
  `wechselSprache` ruft `feedSpracheUpdate`; Lifecycle `startFeedSync`/`stopFeedSync` analog Chat.
  i18n `feed_*`/`tab_feed` in allen 5 Blöcken. **v1-Grenzen (bewusst):** ein Beitrag gehört zu
  `mein_verbund()` (bei mehreren Verbünden der kleinste — i. d. R. genau einer); Bearbeiten nur Text
  (Bild nur über Löschen+Neu); Markierung referenziert EINE Personenkarte (keine Zwillings-Spiegelung).
- **Familien-Feed → vereinter Aktivitäten-Stream (Social-Schicht, ab v13.4):** Erweitert den Feed-Tab
  von „nur Beiträge" zu EINEM chronologischen Stream „Was ist neu in der Familie". DB-Datei
  `supabase_aktivitaeten.sql` (**NACH `supabase_reaktionen_kommentare.sql` + `supabase_beitraege.sql`**):
  Tabelle **`aktivitaeten`**(`verbund_id`, `typ` ∈ {`person_neu`,`foto_neu`,`geschichte_neu`,`event_neu`,
  `beitrag_neu`,`geburtstag`,`erinnerung`}, `ref_id`, `akteur_id`, `erstellt_am`; `UNIQUE(typ,ref_id)` =
  idempotent). Befüllung per **DB-Trigger** an `personen`/`personen_fotos`/`personen_geschichten` (nur
  veröffentlicht)/`events`/`beitraege` — **NUR wenn `auth.uid()` gesetzt** (echte Nutzer-Aktion →
  Bulk/Import via `service_role` erzeugt KEINEN Feed-Spam; Platzhalter + `identitaet_id`-Spiegelkarten
  übersprungen). SELECT verbund-RLS; Realtime in Publication. RPC **`aktivitaeten_holen`** (alle Typen;
  Akteur-Name/Avatar; bei `beitrag_neu` die VOLLEN Beitragsfelder → Frontend reused die Beitrags-Karte;
  gelöschte Zielobjekte ausgeblendet; Cursor über `erstellt_am`). **Frontend:** `feedLaden` ruft jetzt
  `aktivitaeten_holen` (das frühere `feed_holen` wurde aus `supabase_beitraege.sql` ENTFERNT/DROP);
  `feedRender` zeichnet `beitrag_neu` als volle Beitrags-Karte (`feedBeitragAusAkt` + `feedBeitragHtml`),
  andere Typen als `feedAktivitaetHtml` (Icon + Klick → Person/Event); Reaktions-/Kommentarleiste an
  Beitrag/Foto/Geschichte (`engagementMount('feed-eng-…', …)`). Realtime-Channel `feed-sync` hört jetzt
  auf `beitraege` UND `aktivitaeten` (kein Auto-Logout-Reset, bei verstecktem Tab aufgeschoben). i18n
  `akt_*` in allen 5 Blöcken. **v1-Grenzen (bewusst):** nur eigener Verbund; `geburtstag`/`erinnerung`
  sind als Typ vorgesehen, werden aber NICHT auto-erzeugt; kein Backfill (Feed füllt sich vorwärts);
  `geschichte_neu` nur beim Veröffentlichen-bei-Anlage.
- **Foto-Tagging — Personen in Fotos markieren (Social-Schicht, ab v13.5):** Markiert Personenkarten in
  Galerie-Fotos (`personen_fotos`); markierte Fotos erscheinen auf der Personenkarte der markierten
  Person. DB-Datei `supabase_foto_personen.sql` (**NACH `supabase_personen_fotos.sql` +
  `supabase_reaktionen_kommentare.sql`**): Tabelle **`foto_personen`**(`verbund_id`, `foto_id`→
  personen_fotos CASCADE, `person_id`→personen CASCADE, `x`/`y` optional, `markiert_von`;
  `UNIQUE(foto_id,person_id)`), verbund-RLS (SELECT `ist_in_verbund`). RPCs: `foto_person_markieren`
  (nur Foto-Bearbeiter `kann_familie_bearbeiten`; **markierte Person muss im SELBEN Verbund** liegen →
  KEINE verbundübergreifende Exposition Minderjähriger), `foto_person_entfernen` (Bearbeiter ODER wer
  markiert hat), `foto_tags_holen` (Foto → Chips + `darf_markieren`), `person_markierte_fotos` (Person →
  Fotos + Galerie-Besitzer). **Frontend:** in der **Foto-Lightbox** `#lightbox-tags` (Chips → Klick
  öffnet Personenkarte; Bearbeiter sehen „＋ markieren" via searchable Select der Verbund-Personen + ✕
  zum Entfernen), auf der **Detailkarte** `#detail-markiert` („Markiert in Fotos", Thumbnail-Grid →
  Besitzer-Karte). `fotoTagsRender`/`markierteFotosRender` an `lightboxRender`/`zeigeDetails` gehängt.
  i18n `ft_*` in allen 5 Blöcken. **v1-Grenzen (bewusst):** KEINE Markierungs-Position im Bild
  (`x`/`y` nullbar, ungenutzt — nur Chips); nur Galerie-Fotos (nicht Beitrags-Bilder); markierte Person
  muss zum Anklicken im geladenen Modell vorhanden sein.
- **Familien-Fragen „Wer ist das?" / Crowdsourcing (Social, ab v13.6):** Verbund-gebundene Fragen,
  die Antworten = Kommentare aus dem Engagement-System (`ziel_typ='frage'`) nutzen → Mitmachen
  produziert echte Stammbaum-Daten. DB-Datei `supabase_familien_fragen.sql` (idempotent, **NACH
  `supabase_reaktionen_kommentare.sql` UND `supabase_beitraege.sql`**). Schaltet zuerst `'frage'` im
  `ziel_typ`-CHECK von `reaktionen`/`kommentare` frei (DROP+ADD CONSTRAINT) und erweitert
  `_ziel_verbund` um den `frage`-Zweig. Tabelle **`familien_fragen`**(`verbund_id`, `steller_id`,
  `frage`, `foto_pfad`/`foto_url`, `person_id`→personen [Bezugsperson], `status` [`offen|geloest`],
  `geloest_person`→personen, `geloest_von`, `geloescht`). **STRIKT VERBUND-GEBUNDEN** (SELECT nur
  `ist_in_verbund`); Schreiben über SECURITY-DEFINER-RPCs: `frage_stellen` (Text Pflicht, optional
  Foto/Bezugsperson), `frage_loesen` (**nur Bearbeiter** `darf_verbund_moderieren`; hält die
  identifizierte Person in `geloest_person`), `frage_wieder_oeffnen`, `frage_loeschen` (Steller ODER
  Moderator, soft, gibt `foto_pfad` für Storage-Cleanup), `fragen_holen` (verbund-intern, optional
  nur offene, Antwort-Anzahl + `darf_*`). **Frontend:** der Feed-Tab hat einen segmented control
  **Wand | Fragen** (`feedModus`, `feedSetModus`); Fragen-Composer (Text + Foto via
  `galerieKomprimiere`, Bucket `beitraege` wiederverwendet + Bezugsperson) + Liste; je Frage ein
  Engagement-Widget (`frage-eng-<id>`, `ziel_typ='frage'`) für Antworten/Reaktionen. **Lösen-Dialog**
  `#frage-loesen-modal` (nur Bearbeiter): identifizierte Person wählen → `frage_loesen`, ODER
  „Personenkarte bearbeiten" (`zeigePersonBearbeiten`) zum manuellen Eintragen fehlender Daten.
  Realtime via `feed-sync` (Tabelle `familien_fragen` ergänzt), setzt den Auto-Logout-Timer NICHT
  zurück. i18n `frage_*`/`feed_modus_*` in allen 5 Blöcken. **ABGRENZUNG v1 (Datenqualität):**
  Übernahme von Antworten in echte Daten NUR durch Bearbeiter-Rollen, kein Auto-Write (Mensch
  bestätigt). **Bewusste v1-Grenzen:** Foto = hochgeladenes Bild auf der Frage (kein
  `personen_fotos`-FK), Foto-Frage hält beim Lösen `geloest_person` — die Verdrahtung zum separaten
  **Foto-Tagging (`ft_*`)** als echtes Galerie-Tag ist eine mögliche Folge-Erweiterung; Lösen ist
  frage-bezogen (kein „diese eine Antwort"-Klick auf einen einzelnen Kommentar).

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
  Pflichtfelder: Naziv stabla + Država + Opština (+ E-Mail); **Grad/selo (= Dorf) ist optional**.
  Eine Hintergrundprüfung (`familie_finden_exakt`, **strikter 3-Felder-Match Name/Land/Gemeinde**,
  diakritik-/groß-klein-unempfindlich über
  `merge_norm`; **Grad/selo/Dorf ist seit v13.9 NICHT mehr Teil des Abgleichs**) erkennt einen
  vorhandenen Baum: Treffer → Info + Rollen-Dropdown → Zugriffsanfrage
  (Entscheidung in der App). Kein Treffer → bisheriger Self-Service: `neue-familie-anlegen` legt
  Konto + Baum sofort an (User = `familien_owner`, sofortige Passwort-Mail, KEINE Freigabe).
  Beim Self-Service-Anlegen werden `land`/`stadt`/`gemeinde` in `familien` gespeichert, damit das
  strikte Matching künftiger Anfragen greift.
- Offen/Ausblick: Abo-Modell (Stripe); weitere Admin-Funktionen (Familieneinstellungen).

# Stammbaum → Familien-Netzwerk: Social-Feature-Prompts

Idee: eine **soziale Schicht** über dem bestehenden Stammbaum – die App wird vom Daten-Archiv zum
lebendigen Familien-Netzwerk (MyHeritage trifft Instagram/Facebook). Jeder Block ist ein
eigenständiger Prompt zum Kopieren in Claude Code. Reihenfolge = empfohlene Bearbeitung
(Engagement-Primitive zuerst, dann das, was darauf aufbaut).

---

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
