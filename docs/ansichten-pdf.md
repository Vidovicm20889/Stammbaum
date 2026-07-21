# Ansichten & PDF-/Druck-Export

> Teil der FamilyRoots-Doku. Dauerregeln stehen in `CLAUDE.md`; hier stehen die Feature-Details.
> Personalisierte/Netz-Ansichten und der PDF-/Druck-Export.

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
- **Ansichtsmodus „Alle Verwandten / Netz" (Multi-Root, opt-in, ab v14.43):** Vierter Preset im
  Ansicht-Overlay (`ansicht-radio-netz`, `ansichtModus='netz'`) neben Standard/Kreis/Voll/Zweig.
  **Bewusste Ausnahme zur Regel „ein Stammbaum = eine Blutlinie":** zeigt **JEDE** Person des AKTUELLEN
  Baums (`_tree === aktueller Baum`) **+ deren Ehepartner als Blätter** — auch die Geschwister/Herkunfts-
  familie **echt eingeheirateter** Personen (Nachname ≠ Baum, die die Blutlinien-Ansicht + Platzhalter-
  Aufstieg NICHT erfasst) und **lose Insel-Karten**. Technik: `zeigeNetzAnsicht`/`netzErlaubtSet` →
  bestehender **Multi-Root-Renderer `zeichneGraph`** (`graphRaenge`/`graphLayout`/`zeichneGraphKanten`,
  rang-basiert, NICHT fokus-zentriert — reaktiviert, war seit v14.10 abgeschaltet) via `opts.erlaubt`
  (ext-ID-Set aller Baum-Mitglieder + Partner). **KEINE Blutlinien-Kappung.** **Baum-BEGRENZT** (nur
  `_tree`-Mitglieder + direkte Partner) → **kein Cross-Tree-Bleed** in fremde Verbünde (Isolation
  gewahrt). In `rendereAktuelleAnsicht`/`ansichtAnwenden`/`wendeGespeicherteAnsichtAn`/`oeffneAnsichtModal`/
  `ansichtModusWahl` eingehängt; pro Nutzer gemerkt (`speichereAnsichtPref('netz')`, wie die anderen
  Presets). i18n `ansicht_opt_netz`/`ansicht_opt_netz_sub` in allen 5 Blöcken. **Bewusste Grenze:** der
  reaktivierte `zeichneGraph`-Layout war früher als „falsche Darstellung" markiert → die **visuelle
  Qualität bei großen/komplexen Bäumen ist am Gerät zu verifizieren** (🔬); der Standard bleibt die
  aufgeräumte Blutlinien-Ansicht, das Netz ist die opt-in Vollsicht.
- **Layout-Quelle: Autosortierung ODER Tabla (SCRUM-7):** Der Dialog hat oben eine Auswahl
  `#pdf-quelle` mit zwei Werten. **`auto`** = bisheriges Verhalten, das Layout wird gerechnet
  (`pdfBaueModell` → `pdfFiltere` → `pdfLayout` → `pdfBaueSvg`). **`tabla`** = der im Board-Modus
  frei angeordnete Zustand: `pdfBoardSvg()` klont den live gezeichneten `#baum-svg`, entfernt den
  Zoom-`transform` (→ Weltkoordinaten), rahmt die belegte Fläche per `viewBox` (pad 120), bettet die
  same-origin CSS ein und entfernt alle Edit-Artefakte (`PDF_BOARD_WEG`: Connection-Points,
  Anker-/Wegpunkt-Griffe, Lösch-Trefferlinien, Presence-Cursor, Marquee, `image`).
  **Beide Quellen laufen durch dieselbe Ausgabekette** — PDF/PNG/SVG/Druck, Papier, Poster,
  Titelblatt funktionieren identisch. Dafür liefert `pdfBoardSvg` ein Ersatz-`layout`
  (`personen`, `cardW: 152`), aus dem `pdfExportPdf` nur die Papierwahl und die Poster-Kachelung
  ableitet; die Metadaten kommen aus `pdfMetaTabla` (Baum = der offene Board, keine Wurzel/Generationen).
  Die Quelle ist nach `ansichtModus` **vorbelegt**, bleibt aber frei umstellbar. Bei `tabla` werden
  alle Optionen, die nur das berechnete Layout steuern (`.pdf-nur-auto` → Wurzel, Umfang,
  Generationen, verknüpfte Bäume, Filter, Layout, Inhalt), **sichtbar deaktiviert** (`disabled` +
  `.aus` mit `pointer-events: none`, weil die suchbaren Selects das `disabled` des versteckten
  `<select>` nicht erben) — nicht still ignoriert. Ist `tabla` gewählt, ohne dass der Board offen
  ist, warnt der Dialog (`pdf_quelle_kein_board`) statt leer zu exportieren.
  **Grenze:** Avatare (`image`) bleiben im Tabla-PDF außen vor — Storage-Bilder sind cross-origin
  und würden die Canvas tainten; das bräuchte CORS am Bucket oder data-URI-Einbettung.
- **PDF-/Druck-Export des Stammbaums (ab v9.2):** Button „Stammbaum als PDF exportieren"
  (`#pdf-export-btn`, schwebend im `#baum-container`) öffnet den Konfig-Dialog `#pdf-export-modal`
  (`oeffnePdfExport`/`schliessePdfExport`). **Bibliotheken:** `jspdf` + `svg2pdf.js` von jsDelivr
  (siehe Architektur-Regeln). Optionen: **Umfang** (nur Person / Eltern / +Großeltern /
  +Urgroßeltern / X Generationen zurück / ganzer Baum) + **X Generationen nach vorne**; **verknüpfte
  Bäume** (über `_ident`-Brücken im Verbund) optional einbeziehen + farblich kennzeichnen;
  **Personenfilter** (lebend/verstorben/beide; private/unbestätigte ausblenden); **Layout**
  (vertikal/horizontal/Ahnen/Nachkommen/kompakt); **Layout-Quelle** (siehe unten); **Papiergröße** mit Auto-Empfehlung
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

## Gleichmäßige Strichstärke: kein Overdraw mehr (SCRUM-14)
Einzelne Eltern-Kind-Linien wirkten **dicker** als andere und wurden als Bedeutungsunterschied
(„Hauptstrang?") gelesen. Es gibt jedoch **keine** Regel, die Blutlinien-Kanten dicker zeichnet —
die Blutlinie wird ausschließlich über den **Kartenrahmen** hervorgehoben
(`.knoten.blutlinie rect { stroke-width: 3 }`). Es war ein reiner Zeichenfehler:

**Ursache — Overdraw bei halbtransparenter Linie.** `.verbindung` hat `stroke: rgba(255,248,220,0.88)`.
Werden zwei identische Segmente übereinander gezeichnet, addiert sich die Deckkraft
(0,88 → 0,986 → 0,998) und die Antialiasing-Ränder verbreitern sich → die Linie **wirkt** dicker,
obwohl `stroke-width` identisch ist.

**Zwei Gegenmaßnahmen in `zeichneGraph2` (rein zeichnerisch, kein Layout-Eingriff):**
1. **Entdoppelung** — Helfer `linie(x1, y1, x2, y2, klasse)` ersetzt die direkten
   `baumG.append('line')`-Aufrufe für **alle** `.verbindung`-Segmente. Er merkt sich je
   Render-Durchlauf die gezeichneten Segmente (`Set`, Schlüssel = sortierte Endpunkte auf 0,5px
   gerundet + Klasse) und überspringt Wiederholungen. Trifft u. a. den Fall „0/1 Partner":
   dort ist `descX` für **jede** Kindergruppe gleich `px`, die Abstiegs- und Sammellinie wurden
   je Gruppe deckungsgleich neu gezeichnet.
2. **Geschwister-Sammellinie zusammengefasst** — sie wurde bisher **je Geschwister** von `pm`
   (Elternmitte) bis `sx` gezogen. Auf derselben Seite überdecken sich diese Teilstücke: das Stück
   neben der Elternmitte lag so oft übereinander, wie es Geschwister auf dieser Seite gibt (dick),
   das äußerste nur einmal (dünn) — genau die gemeldete Beobachtung. Jetzt sammelt die Schleife nur
   die x-Positionen (`sibSx`) und zieht **eine** Linie von `min(pm, …sibSx)` bis `max(pm, …sibSx)`.
   Ein reines Endpunkt-`Set` genügt hier nicht, weil sich die Segmente nur **teilweise** überlappen.

**Bewusste Unterschiede bleiben:** `.ehe-linie-ex` (dünner/grau/fein gestrichelt) und die
Board-Edit-Sonderstärke (`#baum-container.board-edit-grid .verbindung`) sind unverändert.
**PDF-Export unberührt** — er zeichnet aus einer eigenen Layout-Liste mit deckenden Farben.

**Verifikation:** Überdeckungs-Simulation mit 4 Geschwistern — vorher wurde der mittlere Bereich
**2-fach** übermalt (bei n Geschwistern auf einer Seite entsprechend n-fach), nachher genau 1×, bei
**identischer** Abdeckung (`[-600, 450]` in beiden Fällen, es fehlt also keine Linie). Entdoppelung
per Node getestet (7 Fälle: identisch, umgekehrte Richtung, andere Klasse, Rundung, klar verschieden).

## Titelblatt bei Quelle „Tabla": nur PDF (SCRUM-21)
Die Option „Titelblatt" war bei **Quelle Tabla + Format PNG/SVG/Druck** *still wirkungslos* — angehakt,
bedienbar, ohne jede Wirkung. Das verletzte AK5 von SCRUM-7 („nicht unterstützte Formate sind sichtbar
deaktiviert mit Begründung, **nicht still wirkungslos**").

**Ursache:** Den Header zeichnet ausschließlich `pdfBaueSvg` — und die läuft im Tabla-Zweig gar nicht,
weil dort der Board-SVG **selbst** das Ergebnis ist (`layout/svg/meta` kommen aus `pdfBoardSvg`).
Für `format === 'pdf'` ist das folgenlos, weil `pdfExportPdf` das Titelblatt separat aus `meta` baut.
Betroffen war deshalb genau `tabla && format !== 'pdf'`.

**Lösung:** `pdfTitelblattSync()` deaktiviert die Checkbox sichtbar (`disabled` + `.aus` am
`#pdf-titelblatt-wrap`) und blendet den Grund als Text ein (`pdf_titelblatt_nur_pdf`, 5 Sprachen).

⚠️ **Bewusst NICHT über `.pdf-nur-auto`:** Diese Klasse deaktiviert generell bei Tabla — die
Titelblatt-Option ist dort aber bei **PDF gültig**. Mit der Klasse hätte man eine funktionierende
Option grundlos gesperrt (neuer Fehler statt Korrektur). Deshalb eine eigene, **formatabhängige** Regel.

⚠️ **Neuer Handler `pdfFormatChange()`:** Das Format-`<select>` hatte bisher **gar kein** `onchange` —
der Zustand wäre erst beim nächsten Quellenwechsel nachgezogen (AK6, „kein Nachhinken um einen
Schritt"). Der Sync hängt jetzt an **beiden** Auslösern.

**Bewusste Grenze:** Titelblätter für Board-**Bild**exporte gibt es damit weiterhin nicht — die
Erwartung wird korrigiert, nicht die Funktion erweitert. Der Dialog sagt das jetzt ausdrücklich.
Die vollständigere Variante (Header über den Board-SVG legen) berührt Zuschnitt und Skalierung aller
drei Ausgabewege und wäre eine eigene Story mit visuellem Vorher-/Nachher-Vergleich.

**Verifiziert:** vollständige Matrix {Autosortierung, Tabla} × {PDF, PNG, SVG, Druck} — **8/8** korrekt;
genau diese Matrix fehlte im ursprünglichen SCRUM-7-Test.

## Avatare im Tabla-Export: nur bei Canvas-Wegen entfernt (SCRUM-23)
`PDF_BOARD_WEG` entfernte beim Klonen des Board-SVG **pauschal alle** `image`-Elemente — auch dort,
wo gar keine Canvas im Spiel ist. Ergebnis: Tabla-Exporte hatten **nie** Avatare, Auto-Exporte schon.

**Zwei Listen statt einer:**
- `PDF_BOARD_WEG` — Edit-Artefakte (⊕-Punkte, Anker-/Wegpunkt-Griffe, Fasskreise, Trefferlinien,
  Presence-Cursor, Marquee). Fliegen **immer** raus.
- `PDF_BOARD_WEG_CANVAS = 'image'` — nur bei Canvas-Wegen (Cross-Origin-Taint: `toDataURL`/`toBlob`
  würfen sonst `SecurityError` und der Export **bricht ab**).

**`pdfNutztCanvas(opts, svgText)`** beantwortet die Frage an **einer** Stelle (AK7 — Lehre aus SCRUM-20,
keine Doppelpflege). `pdfWinAnsiSafe` wird von `pdfExportPdf` **mitbenutzt**, nicht nachgebaut:

| Weg | Canvas? | Avatare |
|---|---|---|
| SVG-Download, Druck | nein | **bleiben** |
| PDF einseitig, Latin-1-sicher (echter Vektor über `doc.svg()`) | nein | **bleiben** |
| PDF einseitig, Raster-Fallback (`!winAnsiSafe`) | ja | entfernt |
| PDF Poster/mehrseitig | ja | entfernt |
| PNG | ja | entfernt |

⚠️ **Zeitpunkt:** Die Entfernung passiert **nicht** mehr in `pdfBoardSvg`, sondern erst in
`pdfExportStart` kurz vor der Format-Verzweigung — vorher steht `winAnsiSafe` gar nicht fest, das
hängt am fertigen SVG-Text. Ohne `svgText` nimmt `pdfNutztCanvas` konservativ `true` an: lieber ein
Avatar zu wenig als ein abgebrochener Export.

**Bewusste Grenze:** In PNG und Poster gibt es weiterhin keine Avatare. Das bräuchte data-URI-Einbettung
oder CORS am Storage-Bucket (eigenes Ticket). Wegen `winAnsiSafe` greift der echte Vektor-Fall bei
südslawischen Namen (`ć/č/š/ž/đ`, kyrillisch) ohnehin selten — spürbar ist die Verbesserung vor allem
bei **SVG** und **Druck**.

## Board-Export braucht eigene Druckfarben (SCRUM-24)
Die Bildschirmfarben sind für den **dunklen** Hintergrund (`Bild4.jpg`) gebaut: `.verbindung` ist
cremeweiß (`rgba(255,248,220,.88)`). Der Export legt aber `#fbfaf7` darunter → Kontrast **1,02:1**,
die Linien sind physisch vorhanden, aber unsichtbar; auf Papier komplett weg.

Die dunkle Edit-Variante (`#baum-container.board-edit-grid .verbindung`) rettet das **nicht**: Der Klon
stammt aus `#baum-svg`, verliert den Vorfahren `#baum-container` und wird zusätzlich entklassifiziert
(`clone.removeAttribute('class')`) — der Nachfahren-Selektor matcht nicht mehr.

**Lösung:** `pdfBoardSvg` hängt **nach** dem eingebetteten Dokument-CSS eine druckfeste Regelmenge an
(`!important`, damit sie auch gegen die Edit-Regel gewinnt, falls die je matcht):

| Element | Bildschirm | Export | Kontrast auf `#fbfaf7` |
|---|---|---|---|
| `.verbindung` | `rgba(255,248,220,.88)` | `#9c7c3c` | 1,02 → **3,75:1** |
| `.ehe-linie` | `#d4a030` | `#b07d15` | → **3,47:1** |
| `.ehe-linie-ex` | `#9aa0a6` | `#7a7f85` | → **3,87:1** |
| `.ehe-ex-label` | `#d9cfb6` | `#5c5346` | 1,48 → **7,24:1** |
| `.verbindung-text` | `#c8a840` | `#7a5f18` | → **5,79:1** |
| `.paar-knoten` | hell | `#9c7c3c` | — |

Wie in SCRUM-24 §9 gefordert wurden **alle** hell-auf-dunkel gedachten Elemente geprüft, nicht nur die
gemeldete `.verbindung`. Mindestwert 3:1 (WCAG 1.4.11, grafische Elemente); Graustufendruck gegengeprüft
(alle ≥ 3,78:1).

⚠️ **`#c08a1e` bewusst NICHT übernommen:** Das ist die Ehelinien-Farbe des **Auto-Exports**, sie erreicht
auf `#fbfaf7` aber nur **2,92:1**. Deshalb `#b07d15` — optisch praktisch identisch, aber über der
Schwelle. **Der Auto-Export hat diesen Mangel weiterhin** (eigener Vorgang).

⚠️ **Zweite Farbquelle:** Linienfarben stehen jetzt an zwei Stellen — `stammbaum.css` (Bildschirm) und
`pdfBoardSvg` (Druck). Bei Design-Änderungen **beide** anfassen. Die Bildschirmoptik wurde bewusst
nicht angetastet: das warm-weiße Leuchten ist auf dem Hintergrundbild richtig.
