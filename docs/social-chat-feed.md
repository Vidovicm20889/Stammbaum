# Soziale Schicht: Chat, Discovery, Feed & Engagement

> Teil der FamilyRoots-Doku. Dauerregeln stehen in `CLAUDE.md`; hier stehen die Feature-Details.
> Chat, verbundübergreifende Kontakte, Reaktionen/Kommentare, Feed/Aktivitäten, Tagging, Fragen, Kochbuch-Bewertungen.

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
  KONTAKT — Chat ist FREI (Regel gelockert ab v14.43, Betreiber-/Nutzerentscheidung „Instagram-DM"):**
  Ein 1:1-Chat mit einer entdeckten Person (fremder Verbund) braucht KEINE Admin-Genehmigung mehr — die
  RPC **`entdeckte_person_anschreiben(p_ziel_person)`** (SECURITY DEFINER, DB-Datei
  `supabase_direktchat_discovery.sql`) prüft `_person_entdeckbar` (fremder Verbund, KEIN Minderjähriger,
  Konto vorhanden/Opt-in) und legt sofort die `kontakt_verbindungen`-Zeile (sortiertes Paar,
  `ON CONFLICT DO NOTHING`) an → Helfer `darf_chatten` erlaubt den verbundübergreifenden 1:1-Chat
  (`chats.verbund_id` für solche Chats nullable; Picker via `meine_kontakte`); Empfänger kann den Chat
  einfach ignorieren. Der frühere genehmigungspflichtige `kontakt_anfrage_stellen(...,'kontakt')`-Pfad
  bleibt als Code erhalten, wird vom Frontend aber nicht mehr aufgerufen. **Kindesschutz unverändert:**
  Minderjährige (lebend) sind über `_person_entdeckbar` NIE entdeck- oder anschreibbar. **Stufe 3
  BAUMZUGRIFF (weiterhin genehmigungspflichtig):** SEPARATE Anfrage `typ='baumzugriff'`
  (`kontakt_anfrage_stellen`, optionale Nachricht; legt eine noch fehlende `kontakt_verbindung` selbst an,
  da Chat ja frei ist; Zielbaum = Baum der entdeckten Person), Admin-Genehmigung durch
  `kann_familie_bearbeiten` der Zielfamilie → Zeile in `baum_freigaben`.
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
