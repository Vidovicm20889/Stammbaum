# Profil, Konten & Mitglieder-Verwaltung

> Teil der FamilyRoots-Doku. Dauerregeln stehen in `CLAUDE.md`; hier stehen die Feature-Details.
> Benutzerprofil, Meine Person, Profil-Karte-Sync, Mitglieder- und Benutzer-Karte-Verwaltung.

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
