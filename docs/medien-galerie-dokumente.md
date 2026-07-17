# Medien: Avatare, Galerie, Dokumente, Aufnahmen, Lebensgeschichten

> Teil der FamilyRoots-Doku. Dauerregeln stehen in `CLAUDE.md`; hier stehen die Feature-Details.
> Alle personengebundenen Medien-Features.

- **Namenskarten-Avatar zeigt Profilbild (ab v9.6):** Die Karten im „Familienmitglieder"-Grid
  (`zeigeKarten`, `.person .avatar`) zeigen das hochgeladene **Profilbild** (`stammbaum_daten.foto`
  bzw. `avatar`/`bild`, dieselben Felder wie PDF-Export), sonst wie bisher die **Initialen** als
  Fallback (Bild liegt per `position:absolute; inset:0; object-fit:cover` über den Initialen; bei
  Ladefehler `onerror=this.remove()` → Initial erscheint wieder). Alle Datenfelder bleiben unverändert.
  **Schärfe:** Avatar-Upload erzeugt jetzt **1024 px** Haupt (+128 Thumb) statt 512, und das
  Familienmitglieder-Grid nutzt **`auto-fill`** statt `auto-fit` — sonst streckt ein einzelner
  Suchtreffer die Karte auf volle Breite und skaliert den Avatar unscharf hoch. **Bestandsavatare**
  bleiben in alter Auflösung, bis sie im Profil **neu hochgeladen** werden.
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
