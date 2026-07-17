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
