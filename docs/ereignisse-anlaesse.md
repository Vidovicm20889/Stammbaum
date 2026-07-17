# Ereignisse, Karte & Anlässe

> Teil der FamilyRoots-Doku. Dauerregeln stehen in `CLAUDE.md`; hier stehen die Feature-Details.
> Erinnerungen (Geburtstag/Gedenktag) und der Ereignis-Bereich (Liste/Zeitstrahl/Karte).

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
