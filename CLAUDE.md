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
  Vorname/Nachname/Telefon/Sprache/Land/Zeitzone/Avatar + `avatar_sichtbarkeit`. **RLS: nur die EIGENE
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
  `zeigeErweitertAnsicht`). **Speicherung der Ansicht: bewusst KEINE** (Standardansicht bei jedem
  Öffnen frisch — Nutzerentscheidung). Aktiver Modus (`ansichtModus` 'standard'/'erweitert'/'zweig'/
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

## Architektur-Regeln
- **Keine NEUEN externen Libraries/Dienste ohne ausdrückliche Absprache.**
  Bereits abgestimmt und erlaubt: Supabase (Backend), Resend (Mail), per CDN
  `@supabase/supabase-js@2`, d3.js sowie **`jspdf` + `svg2pdf.js`** (ausschließlich für den
  PDF-/Druck-Export, geladen von `cdn.jsdelivr.net` — CSP deckt das bereits ab). Frontend
  bleibt Vanilla (kein Framework/Build-Tool).
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
  UND Person hat noch keine baumübergreifende Verknüpfung (`identitaet_id`/`_ident`). Existiert im
  Verbund bereits ein Baum dieses Nachnamens, wird **Option 1 ausgeblendet** (Hinweis
  `abw_baum_existiert`) → nur Verknüpfen/Ohne. **Overlay `#abw-nachname-modal`**
  (`pruefeAbweichenderNachname`/`oeffneAbwNachname`/`schliesseAbwNachname`, schließt nur per Button):
  **Option 1 „Neuen Stammbaum erstellen"** (`abwNeuerBaum`) ruft die **neue generische RPC**
  `stammbaum_zweig_aus_person(p_wurzel, p_name)` (DB-Datei `supabase_stammbaum_zweig_person.sql`,
  SECURITY DEFINER) — wie die Heirat-Variante (neue Familie+Baum, gleicher Verbund, Owner=Owner der
  Ausgangsfamilie auto=false), aber OHNE Partner-Zwang: gespiegelt werden Wurzel + Nachkommen +
  Ehepartner. Aktueller Baum bleibt (`ladeBaumDaten`). **Option 2 „Mit bestehender Person
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
- **Ausgelagerte Dateien Cache-Busting (ab Phase-2…4-Refactor):** Aus `stammbaum.html` wurden
  ausgelagert (jeweils als gleichrangige Datei im selben Verzeichnis, eingebunden mit `?v=X.Y`):
  - **`stammbaum.css`** — der frühere `<style>`-Block (`<link rel="stylesheet" href="stammbaum.css?v=X.Y">`).
  - **`i18n.js`** — `TEXTE` + `RECHTSTEXTE` als globale `const`, **vor** dem Haupt-Script geladen.
    i18n-Texte werden jetzt hier gepflegt (weiterhin alle 5 Sprachen). **Schlüssel-Parität prüfen:**
    `node i18n_lint.js` (meldet je Sprache fehlende Keys; idealerweise vor jedem Commit).
  - **`pdf_export.js`** — der komplette PDF-/Druck-Export (`pdf*`-Funktionen + `PDF_*`-Konstanten),
    **vor** dem Haupt-Script geladen; ruft Haupt-Globals (`t`, `d3`, `aktuelleWurzel`, …) erst zur
    Laufzeit auf. `jsPDF`/`svg2pdf` weiterhin aus dem `<head>` (CDN).
  - **Beim Deploy IMMER zusätzlich zur `app-version` auch das `?v=` an `stammbaum.css`, `i18n.js`
    UND `pdf_export.js` auf dieselbe Version ziehen** — sonst liefert GitHub Pages die ausgelagerte
    Datei veraltet aus (`hardReload`/`?v=timestamp` bricht nur den HTML-Cache, nicht die Sub-Ressourcen).
  - Reihenfolge: die ausgelagerten `<script>` (i18n.js, pdf_export.js) müssen **vor** dem
    Haupt-Inline-`<script>` stehen (globale `const`/Funktionen). Der `init();`-Bootstrap bleibt am
    Ende des Haupt-Scripts. `split_i18n.js`/`split_css.js`/`split_pdf.js` waren Einmal-Auslagerungs-
    werkzeuge (können entfallen); `i18n_lint.js` bleibt nützlich.
- **DB-Änderungen**: als idempotente `.sql`-Datei im Repo ablegen → im Supabase SQL-Editor ausführen.
  **SQL-Index/Reihenfolge für eine frische DB:** siehe `SCHEMA.md`. Einmal-/Vorfall-Skripte
  (Diagnose/Reparatur/Restore/konto-spezifisch) liegen unter `sql_archiv/` und gehören NICHT
  zum Neuaufbau.
- **Edge Functions**: über das Supabase-Dashboard deployen (Supabase-CLI durch Citrix-Firewall blockiert).
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
  Pflichtfelder: Naziv stabla + Država + Grad/selo + Opština (+ E-Mail). Eine Hintergrundprüfung
  (`familie_finden_exakt`, **strikter 4-Felder-Match**, diakritik-/groß-klein-unempfindlich über
  `merge_norm`) erkennt einen vorhandenen Baum: Treffer → Info + Rollen-Dropdown → Zugriffsanfrage
  (Entscheidung in der App). Kein Treffer → bisheriger Self-Service: `neue-familie-anlegen` legt
  Konto + Baum sofort an (User = `familien_owner`, sofortige Passwort-Mail, KEINE Freigabe).
  Beim Self-Service-Anlegen werden `land`/`stadt`/`gemeinde` in `familien` gespeichert, damit das
  strikte Matching künftiger Anfragen greift.
- Offen/Ausblick: Abo-Modell (Stripe); weitere Admin-Funktionen (Familieneinstellungen).
