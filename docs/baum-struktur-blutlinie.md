# Baum-Struktur, Blutlinie & Datenpflege

> Teil der FamilyRoots-Doku. Dauerregeln stehen in `CLAUDE.md`; hier stehen die Feature-Details.
> Beziehungen, Zweigbäume, Nachnamen, Blutlinien-Kappung, Dubletten, Auto-Löschung.

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
  **Invariante — Blut-Aufstieg durch Platzhalter-Elternteile (ab v14.43, nicht zurückbauen):** Der
  Blutlinien-Aufstieg zur Render-Wurzel (`graphBlutScope` UND der Fallback `baueBaumDaten`/`findeWurzel`)
  MUSS über einen namenlosen **Platzhalter-Elternteil** („Unbekannt", `stammbaum_daten.platzhalter`)
  hindurchsteigen, WENN dieser ≥1 Blutlinien-Kind hat — sonst bleiben die Blutlinien-**Geschwister der
  Wurzel** unsichtbar (Bug: zwei Schwestern teilen sich einen bei „Geschwister ohne Eltern" erzeugten
  Platzhalter → nur eine wurde gezeichnet). Ein Platzhalter zählt dabei **nie als „auswärts"**
  (blut-neutral → seine Blutlinien-Kinder werden nicht als 2. auswärtige Generation gekappt). Sicher,
  weil ein Platzhalter selbst keine Eltern hat (Aufstieg endet dort) → **kein Bleed aus fremden
  Familien**; die „eine Blutlinie"-Regel bleibt intakt (der Aufstieg startet an einem Blut-Knoten,
  eingeheiratete Herkunftsfamilien bleiben ausgeschlossen). Im Fallback läuft die Suche nach dem
  Platzhalter **vorwärts über `families.children`** (robust gegen eine fehlende `families_child`-
  Rückreferenz des Blutlinien-Kindes).
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
  **AUFGEWEICHT ab v14.43 — Blutlinien-Nachname AUS DEN DATEN (`baumBlutName`, freie Anzeigenamen):**
  Der Blutlinien-Nachname eines Baums wird NICHT mehr aus dem Anzeigenamen geraten (die „letztes Wort"-
  Heuristik brach bei beschreibenden Namen wie **„The Scicluna Family"** → „family", **„Porodica Vidović"**
  → „vidović" ok, **„Familie Müller"** → „müller"), sondern **aus den Personen des Baums abgeleitet**:
  `baumBlutName(treeId)` = häufigster echter Nachname der Nicht-Platzhalter-Personen (Tie-Breaker +
  Fallback = die alte Namens-Heuristik → rückwärtskompatibel; Cache je treeId, geleert in `blutNameCacheLeeren`
  bei jedem Daten-Load). ALLE Blutlinien-Vergleiche nutzen ihn (`istBlutName`/`istBlutBaum`/`zielBaumFuer`
  in `graphBlutScope`/`baueBaumDaten`/`findeStammbaumWurzel`, `crossTreeBaeume`, `pruefeAbweichenderNachname`/
  `pruefeHeiratsZweig`/`abwSameNameFlow`); die Person-Seite bleibt `zweigNachnameNorm(surname/ehename)`.
  **Folge:** Baum-/Familiennamen dürfen jetzt **beliebig beschreibend** sein (Nutzerwunsch — Bug „The Scicluna
  Family": eingeheiratete Geschwister unsichtbar, weil der Blutname „family" niemandem passte). `istGueltigerBaumName`
  begrenzt weiter nur die ZEICHEN (Buchstaben/Leer/Bindestrich/Apostroph), NICHT die Wortzahl.
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

## Stammbaum-Dropdown: Auswahl nach Neuaufbau erhalten (SCRUM-29)
`befuelleStammbaumAuswahl` ersetzt bei jeder Änderung `sel.innerHTML` komplett (Optionen nach Größe
sortiert, mit Kartenzahl im Label). Ein `<select>` fällt danach auf die **erste** Option zurück
(= größter Baum) → die Anzeige sprang auf einen fremden Baum, während `aktuellerStammbaumId` und der
gezeichnete Baum unverändert blieben (**Desync**, verletzt „aktuellen Stammbaum nie automatisch
wechseln"). Trat nur auf, wenn der offene Baum **nicht** der größte war — deshalb lange unbemerkt.

**Behoben (Lösung A):**
1. Nach dem `innerHTML`-Austausch `sel.value = aktuellerStammbaumId` (falls noch in der Liste) +
   `ssSyncLabel(sel)` für das **sichtbare** Label des suchbaren Dropdowns. Die Suchliste selbst wird
   beim Öffnen dynamisch aus `sel.options` gebaut (`ssRender`) — das `_ssControl` muss **nicht** neu
   aufgebaut werden.
2. `waehleStammbaum` zieht das sichtbare Label ebenfalls nach (`ssSyncLabel`) — sonst blieb es auf dem
   alten Baum stehen, obwohl der Wert stimmte („Dropdown reagiert nicht").
3. **AK6:** Fällt der offene Baum aus der Liste (letzte Karte gelöscht → Baum verschwindet), erfolgt ein
   **bewusster** Wechsel über `waehleStammbaum(ids[0])` — Zustand und Anzeige wandern gemeinsam, kein
   stiller Sprung.

Gilt für alle Aufrufer (Löschen/Anlegen/Bearbeiten/Verknüpfen über `reloadBaumBehalteFokus` **und**
Sprachwechsel). Verwandte Fehlerklasse: SCRUM-19 (Preset-Pille). Ein zentraler Helfer für **alle**
dynamisch befüllten Dropdowns (Alternative C) wäre ein eigenes Aufräum-Ticket.
