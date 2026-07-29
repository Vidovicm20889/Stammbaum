# Board-Modus (Miro-artig: frei verschieben + per Linie verknüpfen)

> **Status: P2 UMGESETZT (ab v14.62) · P3 offen.** Entscheidungen (unten) sind festgelegt.
> **P2 (Verschieben)** ist implementiert: Tabelle/RPC `supabase_board_layout.sql`, Umschalter
> `#board-modus-btn`, Renderer `zeichneBoard`, Drag (nur `istAdmin`), Persistenz
> `karte_board_pos_setzen`. **P3 (Linie → Beziehung)** folgt als eigener Schritt.
> 🔬 Drag-Geste/SVG nur am echten Gerät final verifizierbar.

## Zweck
Ein optionaler Ansichtsmodus, in dem der Baum wie ein Whiteboard/Miro-Board funktioniert:
- Karten werden **frei** an beliebige x/y-Positionen gezogen (kein Auto-Layout).
- Zwischen zwei Karten wird eine **Linie gezogen** → das System **erkennt** den
  wahrscheinlichen Beziehungstyp (Eltern / Partner / Kind / ggf. Geschwister) und legt
  ihn **nach Bestätigung** über die bestehende RPC an.
- Bestehende Beziehungen erscheinen als (typisierte) Linien.

## Abgrenzung zu den bestehenden Ansichten (wichtig)
Die normalen Ansichten werden von **d3** automatisch gelayoutet:
- `zeichneBaum` → `d3.hierarchy` → `d3.tree()`; die Graph-Ansichten (`zeichneGraph`,
  `zeichneGraph2`) berechnen Ränge/Barycenter. Positionen sind **berechnet**, nicht frei.
- `ansichtModus` kennt heute: `standard`, `erweitert`, `zweig`, `voll`, `verbund`.

Freies Verschieben widerspricht dem Auto-Layout → **kein Umbau** der bestehenden Renderer.
Stattdessen ein **eigener, klar getrennter Modus** `ansichtModus = 'board'`, der einen
eigenen Zeichenpfad nutzt und **keine** `d3.tree()`/Rang-Berechnung anwendet.

**Invariante:** Der Board-Modus ändert nur **Positionen** und **legt Beziehungen an** —
er ändert **nie die Beziehungssemantik**. Die echten Daten bleiben in `beziehungen`;
Standard-/Blutlinien-/Verbund-Ansicht stimmen unverändert weiter.

---

## (a) Rendering
- **Ein eigener Zeichenpfad** `zeichneBoard()`, der in denselben Transform-Layer `baumG`
  zeichnet wie die übrigen Renderer (`baumSvg` = SVG, `baumG` = `<g>` mit Zoom-Transform,
  gesetzt in `initBaum`). Dadurch **erben wir Zoom/Pan gratis**: die bestehende
  `d3.zoom()`-Mechanik (`baumSvg.call(zoom)`, `zoom.on('zoom', …)` transformiert `baumG`)
  wirkt unverändert; Positionen sind **Welt-Koordinaten** in `baumG`.
- **Karten** über das vorhandene `zeichneKnotenBox(g, p, xOffset, istFokus, istBlutlinie,
  istUebergang)` zeichnen — je Karte eine `<g class="board-knoten" transform="translate(x,y)">`.
  Aussehen (Schatten, Feldwahl, Avatar, Blutlinien-Markierung) bleibt **konsistent**.
- **Linien** in einer **eigenen `<g class="board-linien">` VOR den Karten** (unter den
  Karten, wie gewünscht). Ankerpunkte = Kartenränder (Geometrie aus `KARTE_HALB`/
  `aktualisiereKartenGeometrie`, wie die anderen Renderer).
- **Auto-Fit / Pan-Grenze:** analog zu `zeichneGraph` `baumPanGrenze` = Bounding-Box aller
  Board-Positionen setzen (damit die vorhandene `zoom.constrain`-Pan-Begrenzung greift) und
  einen initialen Fit setzen. **Doppelklick-Reset** (`baumSvg.on('dblclick', …)` in
  `initBaum`) bleibt aktiv → zentriert das Board.

## (b) Persistenz der Positionen — ENTSCHIEDEN: eigene Tabelle `board_layout`
> Entscheidung (Nutzer): **neue Tabelle** `board_layout`, **ein gemeinsames Board pro Baum**
> (kein Pro-Nutzer-Layout). Die schlafenden `personen.pos_x/pos_y` werden bewusst **nicht**
> verwendet — die eigene Tabelle hält das Board-Layout sauber vom Personendatensatz getrennt
> und lässt eine spätere Pro-Nutzer-Erweiterung (user_id im PK) offen.

**Schema (idempotent, im Repo als `supabase_board_layout.sql`):**
```sql
CREATE TABLE IF NOT EXISTS public.board_layout (
  person_id    uuid PRIMARY KEY REFERENCES public.personen(id) ON DELETE CASCADE,
  stammbaum_id uuid NOT NULL REFERENCES public.stammbaeume(id) ON DELETE CASCADE,
  x            numeric NOT NULL,
  y            numeric NOT NULL,
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS board_layout_baum_idx ON public.board_layout(stammbaum_id);
```
- **PK = `person_id`** (eine `personen`-Zeile = eine Karte in genau einem Baum → gemeinsam
  pro Baum, ohne `user_id`). `stammbaum_id` redundant mitgeführt → günstiger Baum-Filter +
  RLS ohne Join-Kaskade. **`ON DELETE CASCADE`** hält die **referenzielle Integrität**
  (Karte/Baum gelöscht → Layout-Zeile weg; keine verwaisten Positionen — CLAUDE.md).

**RLS (rekursionsfrei, SECURITY-DEFINER-Helfer wiederverwenden):**
- **SELECT** (Baum-Berechtigte, auch Leser → Board statisch sichtbar):
  `USING (public.ist_super_admin() OR public.sieht_familie((SELECT p.familie_id FROM public.personen p WHERE p.id = person_id)))`
- **Schreiben nur über RPC** (keine direkte INSERT/UPDATE-Policy für den Client):
```
karte_board_pos_setzen(p_person uuid, p_x numeric, p_y numeric)  -- SECURITY DEFINER
  -- Rechteprüfung: public.kann_familie_bearbeiten(familie) OR public.ist_super_admin()
  -- INSERT ... ON CONFLICT (person_id) DO UPDATE SET x, y, stammbaum_id, updated_at
```
Debounced aus dem Frontend, optimistisch rendern; Position ist unkritisch → Fehler still
loggen, bei echtem Fehler dezenter Hinweis (`board_fehler_speichern`).

**Ladepfad:** beim Aktivieren des Board-Modus einmal
`board_layout.select('person_id,x,y').eq('stammbaum_id', aktuellerStammbaumId)` (RLS-begrenzt),
in eine Map `person_id → {x,y}` ziehen; fehlende Karten sinnvoll vorbelegen (Renderer-Position
oder Raster) und beim ersten Verschieben persistieren.

## (c) Linie ziehen → Beziehung (Auto-Erkennung mit Bestätigung)
**Geste:** an jeder Karte ein kleiner **Verbindungs-Anker** (z. B. Punkt am Kartenrand,
nur für Bearbeiter). Von A auf B ziehen → beim Loslassen über B öffnet ein **Popover**.
Reine Kartenbewegung (Drag am Kartenkörper) bleibt davon getrennt (Anker ≠ Körper).

**Kernproblem:** Aus einer bloßen Linie ist Eltern/Partner/Kind **nicht** eindeutig →
**keine stille Automatik**, sondern **Vorauswahl + Bestätigung**.

**Auto-Erkennungs-Regeln** (genutzte Felder: `birth_date` bzw. `stammbaum_daten->>'birth_date'`,
`sex`/Geschlecht, vorhandene `families_child`/`families_spouse`/`_ident`):
- **Partner:** Geburtsjahr-Differenz **klein** (Vorschlag: ≤ 15 Jahre), **keine**
  bestehende Eltern-Kind-Kette zwischen A und B, Geschlechter (falls gepflegt) kompatibel
  → Vorauswahl **„Partner"**.
- **Eltern / Kind:** **deutliche** Generationsdifferenz (Vorschlag: ≥ 16 Jahre) → **ältere**
  Karte ist Elternteil der jüngeren. **Richtung aus dem Geburtsdatum**, NICHT aus der
  Ziehrichtung. Fehlt ein Datum → Richtung **offen** (Nutzer wählt Eltern/Kind selbst).
- **Geschwister (optional):** gemeinsame/naheliegende Eltern → als **Alternative** anbieten.
- Fehlen beide Daten → keine Vorauswahl, alle Optionen gleichrangig anbieten.

Das Popover zeigt den **erkannten Typ vorausgewählt** + die **Alternativen**
(Eltern / Partner / **Ex-Partner** / Kind / ggf. Geschwister). **Erst nach Bestätigung** wird angelegt.

**Anlegen** über den **bestehenden** Pfad (keine Umgehung der Server-Prüfungen):
```
verknuepfung_anfragen({ p_modus:'beziehung', p_kontext, p_ziel, p_typ, p_zweiter, p_art })
  p_typ ∈ { 'kind', 'elternteil', 'partner', 'geschwister' }
  p_art ∈ { null, 'ehe', 'partner', 'ex_ehe', 'ex_partner' }   (nur für p_typ='partner')
  Rückgabe: 'sofort' | 'angefragt' | Fehler (vkn_zyklus, vkn_kante_existiert, vkn_selbst)
```

**Sofort vs. Genehmigung (FAMROOTS-45):** `verknuepfung_anfragen` verknüpft **sofort** (`'sofort'`),
wenn der Nutzer die **Ziel-Familie ohnehin bearbeiten darf** — Super-Admin, **gleiche Familie**
(`v_qf=v_zf`, eigener Baum) ODER `kann_familie_bearbeiten(ziel)`. Der Genehmigungs-Weg (`'angefragt'`,
Zustimmung des Ziel-Admins über Obavještenja) bleibt **nur** für den echten **Cross-Tree-Fall**
(fremde, nicht bearbeitbare Ziel-Familie — Datenschutz/Kinderschutz). Vorher verknüpfte **nur**
Super-Admin sofort → ein Owner/Admin bekam selbst im eigenen Baum fälschlich „Antrag gesendet". Fix
in der Migration `supabase_verknuepfung_partner_art.sql` (idempotent, `p_art`-Signatur bleibt). Der
Board-Flow (`boardPopoverBestaetigen`) wertet `'sofort'`/`'angefragt'` unverändert korrekt aus.

**Ex-Partner beim Verknüpfen (FAMROOTS-43):** Das Popover bietet neben „Partner" auch **„Ex-Partner"**
(`board_typ_ex`, i18n 5 Sprachen). Die Wahl ist **keine** eigene Kante — `boardBeziehungAnlegen`
bildet `ex_partner` auf `p_typ:'partner'` + `p_art:'ex_partner'` ab; die `'ehepartner'`-Kante bekommt
`partner_art` direkt beim Anlegen. **Atomar & genehmigungsfest:** `p_art` wird durch
`verknuepfung_anfragen` → Antragszeile (`verknuepfungs_anfragen.partner_art`) → `_vkn_ausfuehren`
gereicht (Migration `supabase_verknuepfung_partner_art.sql`), sodass die Art auch im **'angefragt'**-Fall
(Kante entsteht erst bei `verknuepfung_entscheiden`) korrekt gesetzt wird — **kein** zweiter RPC-Aufruf
`partner_art_setzen` nötig. Für das **Undo** wird `ex_partner` auf `partner` normalisiert (dieselbe
`ehepartner`-Trennung, `boardUndoLink` kennt nur partner/kind/elternteil). Die **Ex-Linie im Board**
wird **immer** gezeichnet — auch **ohne** gemeinsame Kinder (FAMROOTS-46; das manuelle Board zeigt
jede angelegte Beziehung), und zwar **grau/dezent** (`.ehe-linie-ex`) statt golden. **Auto-Diagramm
(FAMROOTS-47):** Ex-ohne-Kinder wird jetzt auch dort **verbunden** gezeigt — über einen separaten
**`nebenPartner`**-Index in `baueGraphModell` (getrennt von `partners`, damit die Ko-Elternschaft/Rang-
Logik unberührt bleibt) und einen **Post-Layout-Pass** in `zeichneGraph2`, der den Ex neben die bereits
platzierte Person setzt (freier Slot in derselben Reihe) + graue Ex-Linie. **Rein additiv → keine Karte
kann verdrängt werden** (der frühere Versuch, den Ex in `partners` aufzunehmen, ließ das Kind
verschwinden — siehe `docs/lessons.md`). Feinere Arten (ex_ehe, ehe vs. partner) bleiben über das ✎ der
Detailkarte (`partnerArtDialog`) einstellbar.
Mapping der Popover-Wahl → `p_typ`/Richtung exakt wie in `vbVerknuepfe` (inkl. Geschwister-
Sonderweg über Platzhalter-Elternteil). **Zyklus-/Dubletten-/Rollen-Prüfung bleibt
serverseitig.** Fehler werden **am Board verständlich** angezeigt (Wiederverwendung
`vbFehlerText`); die Linie wird **nur bei Erfolg** dauerhaft gezeichnet.

**Zweiter Elternteil automatisch (FAMROOTS-41):** Bei einer **Eltern↔Kind**-Verknüpfung wird der
**Partner** des verknüpften Elternteils als **zweiter Elternteil** des Kindes ergänzt —
`boardPartnerVon` (aus `families_spouse`, **Ex zählen mit**, `partner_art`-`ex_*` wird als
„(früher)" gekennzeichnet), `boardZweitElternteilErmitteln`: **0** Partner → nichts, **1** →
automatisch, **mehrere** → app-eigenes Auswahl-Overlay `boardZweitEltWahl` (kein natives
`confirm`/`prompt`; i18n `board_zweitelt_*` in 5 Sprachen) mit Option „keiner / später". Der zweite
Eintrag läuft über **denselben** `verknuepfung_anfragen`-Pfad (`p_typ:'kind'`) und ist eigenständig
atomar — schlägt er fehl (z. B. Kante existiert schon), bleibt die erste, gültige Elternschaft
bestehen (keine halbe Kante). Deckt sich mit dem Render-Fix FAMROOTS-40 (beide Eltern-Linien sichtbar).

## (d) Verhältnis zu bestehenden Ansichten & Blutlinie
- Board zeigt **frei angeordnete** Karten; die **Beziehungen** sind die **echten Daten**.
- Nach dem Anlegen einer Beziehung: `reloadBaumBehalteFokus` / `kind_baeume_sync` wie im
  bestehenden Flow, damit Standard-/Blutlinien-/Verbund-Ansicht sofort stimmen.
- **Bestehende Beziehungen als Linien** darstellen, optisch unterscheidbar:
  Eltern-Kind (durchgezogen), Partner (z. B. gestrichelt/andere Farbe), Geschwister (falls
  gezeigt: dezent). Stil in `stammbaum.css` (`.board-linie-*`).

## (e) Löschen einer Beziehung per Board (nur Konzept, Phase 3+)
Linie anwählen → „Beziehung entfernen" **mit Sicherheitsabfrage** (`zeigeBestaetigung`,
kein natives `confirm`). **Nicht** ungefragt scharf schalten. Serverseitiger Lösch-Pfad
(bestehende Beziehungs-Lösch-RPC/`beziehungLoesen`) — Details bei Umsetzung.

---

## Risiken / offene Entscheidungen
- **Performance (ganzer Baum — entschieden):** Das Board zeigt **alle** Karten des Baums.
  Bei sehr großen Bäumen sind das viele SVG-Knoten. Mitigation: kein Re-Layout je Frame
  (nur Transform der gezogenen Karte + betroffene Linien neu); ab einer Schwelle
  (z. B. > 300 Karten) eine **Warnung/Bestätigung** vor dem Öffnen (`board_gross_warnung`)
  und ggf. `.daten-text`-Ausblendung bei kleinem Zoom (wie in `zeichneGraph`).
- **Gleichzeitige Verschiebungen (Realtime):** gemeinsames Board → zwei Nutzer ziehen
  dieselbe Karte. Vorschlag P2: „letzter Upsert gewinnt", optional später Presence/Soft-Lock
  (Muster `startRealtimeSync`). Für den ersten Wurf **kein** Live-Push der Positionen.
- **Touch vs. Maus:** Drag über `d3.drag()` mit `e.sourceEvent.stopPropagation()` im
  `start` (sonst pant `d3.zoom` gleichzeitig); Position beim Ziehen durch `transform.k`
  teilen (Welt- vs. Bildschirm-Koordinaten). Anker-Ziehen vs. Karten-Ziehen sauber trennen
  (getrennte Handles), Tap-Targets ≥ 16 px, `pointer`-Events.
  - **⚠️ Touch-Griffe (FAMROOTS-49):** `stopPropagation()` allein reicht auf Touch NICHT — `d3.zoom`
    v7 hört auf Touch-Geräten über **eigene `touchstart`-Listener** (nicht Pointer-Events), die der
    `zoom.filter` bisher nur für `mousedown`/`pointerdown` aushebelte → Griff-Drag pant das Board /
    „verlässt" den Edit-Modus. Fix dreiteilig: (1) `zoom.filter` gibt für `ev.type==='touchstart'` auf
    einem Griff/Verbindungs-Punkt (`BOARD_GRIFF_SEL` = `.board-anker-griff-grp, .board-linie-griff-grp,
    .board-anker-hit, .board-linie-hit, .board-connect`; **ohne** `.board-knoten`) `false` zurück — nur
    Griffe, damit Ein-Finger-Pan (freie Fläche) + Pinch-Zoom (Karten) unberührt bleiben; (2) die Griff-
    `d3.drag`-`start`-Handler rufen zusätzlich `e.sourceEvent.preventDefault()` (wenn `cancelable`); (3)
    CSS `touch-action: none` explizit auf die Griff-/Connect-Elemente (nicht auf Vererbung von
    `#baum-svg` verlassen). `BOARD_GRIFF_SEL` bewusst getrennt von `BOARD_GESTE_SEL` (Long-Press, das
    AUCH Karten ausschließt).
- **Mobile Bedienbarkeit:** freies Board auf < 480 px ist eng; Board eher als
  Desktop-/Tablet-Feature bewerben, auf dem Handy funktionsfähig aber nicht primär.
- **Nur Bearbeiter bearbeiten:** Verschieben/Verknüpfen nur bei `istAdmin()`; **Leser sehen
  das Board statisch** (Karten + Beziehungslinien, keine Drag-/Anker-Handles).

### Getroffene Entscheidungen (festgelegt — Basis für P2/P3)
1. **Speicherort:** eigene Tabelle **`board_layout`** (nicht `pos_x/pos_y`).
2. **Layout-Sichtbarkeit:** **ein gemeinsames Board pro Baum** (kein Pro-Nutzer-Layout;
   PK ohne `user_id`).
3. **Leser (Viewer):** sehen das Board **statisch**.
4. **Board-Umfang:** **ganzer Baum** (mit Performance-Schwelle/Warnung, s. Risiken).

---

## Umsetzungsplan (nach Freigabe)
- **Startanordnung = Blutlinie (ab v14.64):** Das Board übernimmt beim Öffnen die Positionen der
  **Blutlinien-Vollansicht** (`zeichneGraph2`/`blutScope`, wie „Ganzer Baum") statt eines Rang-Layouts.
  Technik: `zeichneGraph2` schreibt seine finalen Kartenpositionen über `opts.sammlePos`
  (canon → {x,y,uuid}) heraus; `boardBerechnePositionen` nutzt sie als Default, `board_layout`
  überschreibt gespeicherte Positionen. Der Blutlinien-Render ist ein synchroner Zwischenschritt
  (kein Flackern). Ausbau der Blutlinien-Logik später geplant.
- **Bearbeiten-Schalter (ab v14.64):** Das „Board"-Segment zeigt das Board zunächst **statisch**;
  ein zusätzliches **„Bearbeiten" (`#board-edit-btn`)** — nur im Board + für `istAdmin` — schaltet
  das **Ziehen** an/aus (`boardEdit`). Ohne Edit ist das Board unbeweglich (auch für Admins).
- **P2 — Verschieben ✅ UMGESETZT (v14.62–14.64):** `ansichtModus='board'`, Umschalter in der Ansicht-Pille,
  `zeichneBoard()` (**ganzer Baum**, alle Karten via `zeichneKnotenBox`), `d3.drag`
  (Maus+Touch, **nur `istAdmin`** — Leser statisch), Vorbelegung fehlender Positionen
  (Renderer-Position oder Raster), Positionen aus **`board_layout`** laden, debounced
  `karte_board_pos_setzen`-Upsert, Linien der bestehenden Beziehungen, Performance-Warnung
  ab Schwelle. **SQL:** `supabase_board_layout.sql` (Tabelle `board_layout` + RLS-SELECT +
  RPC `karte_board_pos_setzen`, idempotent). **i18n:** Umschalter/Tooltip/Warnung.
  **Deploy:** `app-version` + alle `?v=` erhöhen.
- **P3 — Verknüpfen:** Verbindungs-Anker + Ziehgeste, Auto-Erkennung + Popover (Vorauswahl
  + Alternativen), Anlegen über `verknuepfung_anfragen`, Fehleranzeige am Board, typisierte
  Linienstile. **i18n:** Menü/Meldungen. Optional **P3+**: Beziehung löschen (mit Abfrage).

## Phase-1-Fortschritt (Miro-Ausbau, ab v14.68)
- **3.1 Dot-Grid ✅ (v14.68):** `#baum-container.board-edit-grid` (weißes Punktraster) nur im
  `boardEdit`; `boardGridAnwenden()` toggelt, beim Verlassen `aktualisiereBaumHintergrund()`.
- **3.2 Beziehung per Linie ✅ (v14.69):** Connection-Point (`.board-connect`) an jeder ziehbaren
  Karte → Ziehgeste (`d3.drag`, eigene Geste) → Popover `#board-verkn-popover` mit Auto-Erkennung
  (`boardTypVorschlag`: Alter/Generation aus `birth_date`, Richtung aus Datum). Anlegen über
  `verknuepfung_anfragen` (`boardBeziehungAnlegen`); Fehler via `vbFehlerText` im Popover.
- **3.4 Alle Karten sichtbar ✅ (v14.69):** `boardBerechnePositionen` ergänzt unverbundene Karten
  (`_tree===aktuellerStammbaumId`, ohne Platzhalter) im Raster links; `board_layout` hat Vorrang.
- **3.3 Karte anlegen ✅ (v14.70):** `person_anlegen_atomar` erlaubt `edges:[]` (verifiziert an der
  RPC-Quelle) → **lose** Karte möglich. Doppelklick auf freie Board-Fläche (Edit) →
  `boardOeffneLoseAnlage` öffnet den bestehenden Dialog ohne Beziehungs-Auswahl; **isolierter**
  Speicher-Pfad `boardLoseSpeichern` (Guard in `speichereNeuePerson`, kritische Anlage unberührt)
  baut op mit `edges:[]` + Familie/Baum des aktuellen Baums, speichert danach die Klickposition via
  `karte_board_pos_setzen`. Klickkoordinaten via `d3.pointer(ev, baumG.node())` (Zoom/Pan korrekt).

**Phase 1 (3.1–3.4) vollständig.**

## Phase-2-Fortschritt (ab v14.71)
- **4.1 Kontextmenü ✅ (v14.71):** `#board-ctx-menu`; Rechtsklick (`contextmenu`) + Touch-Long-Press
  (500 ms) nur im `boardEdit`+Admin. Auf Karte: Öffnen (`zeigeDetails`) / Kopieren / Löschen
  (`loeschePerson`, eigene Abfrage). Auf freier Fläche: Neue Karte (`boardOeffneLoseAnlage`) /
  Einfügen (deaktiviert ohne Clipboard). Renderzustand in `boardState` (in `zeichneBoard` gesetzt).
- **4.2 Kopieren/Einfügen ✅ (v14.71):** `boardKopieren` = **Snapshot** der Anzeigedaten (kein
  `identitaet_id`/`_uuid`), `boardEinfuegen` legt eine **NEUE eigene Person** via
  `person_anlegen_atomar` (`edges:[]`) mit „(Kopie)"-Suffix an und speichert die Position.
- **4.3 Mehrfachauswahl/Undo-Redo/Shortcuts ✅ (v14.72):**
  - **Auswahl:** Marquee (Rahmen aufziehen auf freier Fläche, `zoom.filter` schaltet im Edit-Modus
    von Pan auf Marquee), Shift = additiv; gezogene Karte wird selektiert (`.selektiert`-Highlight).
  - **Gemeinsam verschieben:** ganze Auswahl folgt der gezogenen Karte (`boardState.gruppen`),
    jede Position via `karte_board_pos_setzen`.
  - **Undo/Redo (inkl. Server-Inverse):** generischer Stack `{undo,redo}`. Verschieben ↔ alte/neue
    board_layout; Anlegen/Kopie ↔ `person_papierkorb`↔`papierkorb_wiederherstellen(batch)`; Löschen
    ↔ `papierkorb_wiederherstellen`↔`person_papierkorb`; Verknüpfen ↔ `beziehung_papierkorb`↔restore
    (geschwister: kein Undo). `boardLoeschen` holt den `loesch_batch` für Undo.
  - **Shortcuts (nur Edit):** Entf (Auswahl löschen, mit Abfrage), Esc (Auswahl/Menüs schließen),
    Strg/Cmd+Z/Y (Undo/Redo), Strg/Cmd+C/V (Kopieren/Einfügen).

**Phase 2 (4.1–4.3) vollständig.**

## Phase-4-Fortschritt (ab v14.73)
- **„Als Baum ordnen" ✅ (v14.73):** RPC `board_layout_reset(p_stammbaum)` (SECURITY DEFINER,
  Rechteprüfung) verwirft alle freien Positionen → Board startet wieder aus der Blutlinie.
  Aufruf über das Freiflächen-Kontextmenü (`boardOrdnen`).
- **Kartenpositionen: EINE Quelle (SCRUM-20).** `zeichneGraph2` ist die **alleinige** Quelle für
  Kartenpositionen **und** die `los`-Klassifikation; `boardBerechnePositionen` **rechnet nichts
  selbst**, sondern konsumiert nur `opts.sammlePos` (`{ x, y, uuid, los }` je gezeichneter Karte).
  Die frühere zweite Raster-Schleife im Board ist ersatzlos entfallen.
  **Warum das keine Kosmetik war:** Die beiden Schleifen waren nur durch einen Kommentar
  („Formel … BEWUSST identisch") gekoppelt — und diese Kopplung ist **nachweislich gedriftet**:
  nach SCRUM-8 lief die Board-Schleife bedingungslos, die in `zeichneGraph2` weiterhin nur im
  `blutScope`-Zweig. Ein Kommentar trägt als Kopplungsmechanismus nicht. Jetzt gibt es strukturell
  nichts mehr, was auseinanderlaufen könnte: wer die Ablage ändert, ändert sie für beide Modi.
  **Folge für die Ausschnitt-Presets:** Die Frage „ergänzt das Board dort lose Karten?" stellt sich
  nicht mehr — das Board läuft seit SCRUM-8 immer über `blutScope` (Preset stets `voll`).
  **Bewusste Grenze:** Liefert `zeichneGraph2` gar nichts (früher Abbruch bei unauffindbarem Fokus),
  bleibt das Board leer und meldet `board_leer`, statt dass eine zweite Schleife still einspringt —
  ein sichtbarer Hinweis ist einem halb gefüllten Board vorzuziehen.
- **Minimap ✅ (v14.73):** `#board-minimap` — Übersicht aller Kartenpunkte + Viewport-Rechteck,
  Klick zentriert dorthin (`boardMinimap`, Update im Zoom-Handler).
- **Minimap: Ziehen statt nur Klicken (SCRUM-11):** Die ganze Minimapfläche ist Ziehfläche —
  gedrückt halten und bewegen verschiebt den Ausschnitt **kontinuierlich** (Maus **und** ein
  Finger). Umsetzung mit **Pointer-Events + `setPointerCapture`** (Muster wie `logoCropDown/Move/Up`),
  kein `d3.drag()`: der Wrapper wird pro Frame per `innerHTML` neu befüllt, eine d3-Bindung müsste
  ständig erneuert werden.
  - **Zustand liegt auf Modulebene** (`boardMinimapDrag`, `boardMinimapGeo`, `boardMinimapKlickAus`),
    NICHT in `boardMinimap()`. Die Render-Funktion läuft bei jedem Zoom-/Pan-Frame erneut und würde
    einen laufenden Zug sonst abreißen — das ist die zentrale Fehlerquelle dieser Mechanik.
  - **Handler als Eigenschaften** (`wrap.onpointerdown` …), nie `addEventListener` — sonst stapeln
    sie sich bei ~60 Renders/s.
  - **Klick bleibt erhalten:** unter 3 px Bewegung gilt es als Klick und zentriert weiterhin weich
    (400 ms). Ab 3 px zählt es als Zug und zentriert **ohne** Transition — `boardZentriereAufWelt`
    hat dafür einen zweiten Parameter `sofort`; der Default lässt bestehende Aufrufer
    (`boardZentriereAuf`, `boardSucheWaehle`) unverändert animiert. Der `click` nach einem Zug wird
    einmalig unterdrückt (kein Doppelsprung).
  - **Pixel → Welt** liegt in `boardMinimapZuWelt` (eine Formel für Klick und Zug, isoliert testbar)
    und liest `boardMinimapGeo`, das `boardMinimap()` je Render setzt.
  - **Mobile Position (SCRUM-30):** Auf ≤480px sitzt das Suchfeld auf **`top: 60px`** — **nicht**
    auf 69px: dort steht `.anlaesse-btn`, und genau diese Überlappung war die Regression aus
    SCRUM-4. Die Minimap rückt auf `bottom: 125px`, weil darunter zwei belegte Zeilen liegen
    (Rundbuttons bei 15px, Preset-Pille bei 73px). Im **Querformat** (`orientation: landscape`,
    `max-height: 500px`) ist das Suchfeld **linksbündig** statt mittig — mittig kreuzt es auf
    schmaleren Landscape-Geräten die Layout-Pille — und die Minimap schrumpft auf 110×74.
    Die mobilen Overlay-Zeilen sind in `stammbaum.css` am Mobilblock dokumentiert; wer ein neues
    Overlay ergänzt, ordnet es dort ein, statt eine weitere Ecke zu belegen.
  - **CSS zwingend:** `.board-minimap { touch-action: none; user-select: none; cursor: grab }` +
    `.zieht { cursor: grabbing }`. Ohne `touch-action: none` nimmt der Browser den Wisch als
    Seiten-Scroll und die App sieht keine `pointermove`-Ereignisse.
  - **Bewusste Grenze:** nur Verschieben, **kein** Zoomen über die Minimap; die Zoomstufe `k` und
    die bestehende Pan-Begrenzung (`zoom.constrain`) bleiben unangetastet.
- **Suche „zu Karte springen" ✅ (v14.73):** `#board-tools` Suchfeld → Treffer im Renderzustand →
  `boardZentriereAuf` zentriert + selektiert (`boardSucheInput`/`boardSucheWaehle`).
- **Treffer eindeutig machen (SCRUM-18):** Bei häufigen Namen lieferte die Liste mehrere optisch
  identische Einträge („dreimal Mila Vidović"). Jeder Treffer ist deshalb **zweizeilig**: Name +
  gedämpfte Zusatzzeile aus dem gemeinsamen Helfer **`personSuchZusatz(p, eltern)`**
  (DOM-frei ⇒ per Node testbar). Rangfolge bewusst **knapp** (Liste ~260 px, max. 12 Einträge):
  `* JJJJ` → `* JJJJ † JJJJ` → `† JJJJ` → `Kind von <Elternteil>` (i18n `such_kind_von`, Name über
  `nm()`) → **leerer String ⇒ die Zeile wird gar nicht gerendert** (kein leerer Platzhalter).
  - **Jahre immer per `/\d{4}/`** (`personSuchJahr`) — `birth_date`/`death_date` sind kanonisch ISO,
    nicht-parsebare **Freitext-Altwerte** sind laut CLAUDE.md möglich und dürfen nicht abstürzen.
  - **Eltern-Rückfall** kommt aus dem geladenen Modell (`personElternNamen` über
    `families_child` → `aktuelleDaten.families`/`.persons`, **keine RPC**). **Platzhalter-Karten**
    (`platzhalter: true`) werden übersprungen — „Unbekannt" unterscheidet nichts. Bei zwei Eltern
    **stabil sortiert**, damit die Anzeige nicht von der Ladereihenfolge abhängt.
  - **Klickfläche bleibt der ganze `<button>`** (`.board-suche-item`) — das Tap-Target wird durch die
    zweite Zeile größer, nicht kleiner. Zusatzzeile: `.board-suche-item-sub` (12 px, `#6b5c3e`,
    Ellipsis), Optik an `.bi-text` der Kopfzeilen-Suche angeglichen.
  - **Geburtsdatum ist mitdurchsuchbar** (wie `ansichtPickSuche`): „1901" findet den Jahrgang;
    Platzhalter `board_suche_ph` entsprechend in allen 5 Sprachen angepasst.
  - **Kopfzeilen-Suche nutzt denselben Helfer** (`navSuchVerbundItem`, Format `[Baum] · [Zusatz]`;
    `eltern` kommt dort fertig aus dem RPC `personen_suche`). ⚠️ **Datenschutz-Grenze:** die Gruppe
    **„andere Familie"** wird in `navSuchPanelRender` **separat** gerendert und bekommt **bewusst
    keine** Lebensdaten — `personen_entdecken` liefert nur die vier Discovery-Minimalfelder
    (`person_id`, `name`, `familienname`, `avatar_url`). Diese Trennung nicht „vereinheitlichen".
  - **Sprachwechsel:** `wechselSprache` baut eine **offene** Trefferliste neu auf (Board-Liste rein
    lokal, Kopfzeilen-Panel per erneutem `navSuchPanel`) — sonst bliebe „Kind von …" in der alten
    Sprache stehen.
  - **Bewusst nicht Teil davon:** `ansichtPickSuche`/`ansichtPersonLabel` (dritte Suche, dort reicht
    die Unterscheidung), Geburts**ort**, Avatare in der Board-Trefferliste, Relevanz-Sortierung.
- **Platzierung der Werkzeuge (SCRUM-4):** `#board-tools` und `#board-minimap` sind **Kinder von
  `#baum-container`** — nicht auf Body-Ebene. Beide sind `position: absolute` und brauchen den
  Container (`position: relative`) als Bezugsrahmen; auf Body-Ebene fielen sie auf den Initial
  Containing Block zurück und landeten **neben** dem Baumbild. Sichtbarkeit: das **Suchfeld** ist im
  **gesamten** Board-Modus da (Springen ist auch beim reinen Ansehen nützlich), die **Minimap nur bei
  `boardEdit`** — sie ist ein Anordnungs-Werkzeug. Die Bedingung steht an **zwei** Stellen
  (`boardWerkzeugeSync` und der Frühabbruch in `boardMinimap`), damit kein Aufrufpfad (z. B. der
  Zoom-Handler) daran vorbeikommt. Die Minimap **misst ihren eigenen Kasten**
  (`clientWidth`/`clientHeight`, erst einblenden, dann messen) statt fixer 176×116 — dadurch darf CSS
  sie auf < 480 px verkleinern (132×88), ohne dass die Klick-Umrechnung auf Weltkoordinaten
  verrutscht. `#board-ctx-menu` und `#board-verkn-popover` bleiben bewusst `position: fixed` auf
  Body-Ebene.
  - **Popover-Position an der echten Höhe (FAMROOTS-44):** Die frühere Positionierung nahm eine
    **feste Höhe von 240px** an (`top = min(y, innerHeight - 240)`) — mit 5 Typen (inkl. Ex-Partner,
    FAMROOTS-43) **plus** Fehlertext ist das Popover höher → unterer Teil abgeschnitten. Jetzt wird
    nach `display:block` die **echte** `offsetHeight` gemessen und geklemmt (`boardPopoverPositionieren`,
    Anker = Bildschirm-Koordinate der Drop-Stelle in `boardPopoverAnker`): passt es unterhalb nicht,
    öffnet es **oberhalb** der Drop-Stelle, sonst am unteren Rand; CSS `.board-popover`
    `max-height: calc(100vh - 16px)` + `overflow-y:auto` (+`box-sizing:border-box`) lässt es auf sehr
    niedrigen Viewports **intern** scrollen statt abzuschneiden. Zusätzlich global registrierte
    `scroll`(capture)/`resize`-Handler (Muster wie `dpPositioniere`/`ssPositioniere`) positionieren
    **neu** statt hängen zu lassen (CLAUDE.md-Panel-Regel); no-op solange das Popover zu ist
    (`boardPopoverAnker=null` in `boardPopoverSchliessen`). Nach dem Einblenden des Fehlertexts wird
    erneut geklemmt. `#board-ctx-menu` bleibt unverändert (keine Regression).
- **Board-PDF ✅ (SCRUM-7):** Der Export-Dialog hat eine **Layout-Quelle** (`#pdf-quelle`):
  „Autosortierung (berechnet)" oder „Tabla — wie von mir angeordnet". Bei `tabla` wird **kein**
  Layout gerechnet; `pdfBoardSvg()` (in `pdf_export.js`) klont den live gezeichneten `#baum-svg`,
  entfernt den Zoom-`transform` (→ Weltkoordinaten), rahmt die belegte Fläche per `viewBox` (pad 120)
  und bettet die same-origin CSS ein. Ergebnis geht durch **dieselbe** Ausgabekette wie das
  berechnete Layout → PDF (Vektor via `svg2pdf`, Raster-Fallback), PNG, SVG, Browser-Druck, inkl.
  Papier-/Poster-/Titelblatt-Optionen. Positionen (`board_layout`) **und** manuelle Linien-Wegpunkte/
  Anker (`board_linie`) stimmen dadurch exakt mit dem Bildschirm überein.
  Die Quelle ist nach `ansichtModus` vorbelegt; bei `tabla` werden alle Optionen, die nur das
  berechnete Layout steuern (`.pdf-nur-auto`), **sichtbar deaktiviert** statt still ignoriert.
  `boardPdfExport()` (Freiflächen-Kontextmenü) enthält **keine** eigene Export-Implementierung mehr,
  sondern öffnet nur noch den Dialog mit `oeffnePdfExport('tabla')`.
  **Edit-Artefakte** werden über `PDF_BOARD_WEG` entfernt (Connection-Points, Anker-/Wegpunkt-Griffe
  inkl. Fasskreise, Lösch-Trefferlinien, Presence-Cursor, Marquee) — vorher deckte der Filter nur
  `.board-connect`/`.board-connect-temp`/`image` ab, Griffe landeten im PDF.
  **Bewusste Grenze:** `image`-Elemente (Storage-Avatare) werden weiterhin entfernt — sie sind
  cross-origin und würden die Canvas tainten. Avatare im Tabla-PDF bräuchten CORS am Bucket oder
  data-URI-Einbettung (offen, siehe SCRUM-7 §4.2).
- ~~**Board-PDF ⏳ offen:**~~ *(erledigt, s. o.)* Der bestehende PDF-Export baut das SVG NEU (Baum-Layout), erfasst die
  freien Board-Positionen nicht → braucht einen eigenen Export (Board-`baumG` serialisieren +
  Styles inlinen, `ladePdfLib`/`svg2pdf`).
- **Linien-Wegpunkte ⏳ offen:** braucht Persistenz (z. B. `board_layout`-Erweiterung oder
  `beziehungen.linie_wegpunkte jsonb`) + RLS + Wegpunkt-Drag + gebogene Linienführung.

- **Board-PDF ✅ (v14.75):** `boardPdfExport` (Freiflächen-Kontextmenü) klont den Board-SVG,
  bettet die same-origin CSS ein, rastert über `pdfSvgZuCanvas` und legt via jsPDF ab (Avatare/
  Handles vorher entfernt gegen Canvas-Taint).
- **Linien-Wegpunkte ✅ (v14.77):** Griff (`.board-linie-griff`, Edit+Admin) am Knick jeder
  Eltern→Kind-Linie ziehen → orthogonaler Verlauf durch den Wegpunkt; Doppelklick = Auto-Verlauf.
  Persistenz: **`supabase_board_linie.sql`** (Tabelle `board_linie` + RPCs `board_linie_setzen`/
  `board_linie_reset` + RLS + Realtime).

## Phase 3 — Echtzeit ✅ (v14.76 / v14.78)
- **Positions-Live-Sync ✅:** `boardRealtimeStart/Stop` abonniert `board_layout` (+ `board_linie`)
  gefiltert auf den Baum; fremde Bewegungen/Wegpunkte erscheinen live (eigenes Ziehen via
  `boardZieht` ungestört).
- **Beziehungs-Live-Sync ✅ (bestehende Infra):** `startRealtimeSync` abonniert bereits
  `beziehungen`/`personen` → debounced Reload → `rendereAktuelleAnsicht` → Board neu. Verknüpfen/
  Löschen anderer erscheint also automatisch.
- **Presence-Cursor ✅ (v14.78):** eigene Cursor-Position (Welt-Koord.) wird über den Board-Channel
  gebroadcastet (`boardCursorSenden`, throttled), fremde Cursor werden als beschrifteter Pfeil im
  `baumG` gerendert (`boardCursorRender`, Auto-Ablauf nach 6 s).
- **Wegpunkt-Live-Sync ✅ (v14.78):** `board_linie`-Änderungen live (`boardLinieRealtime`).

## Feature 7 — Neuer Baum aus einer Person ✅ (v14.74)
Eigene RPC **`person_neuer_baum`** (`supabase_person_neuer_baum.sql`): legt Familie **im selben
Verbund** (verbund_id explizit → co-sichtbar, Isolation gewahrt) + Baum + Owner an, spiegelt die
Person als Wurzel über `identitaet_id` (dieselbe reale Person, keine Dublette), optional direkte
Eltern/Kinder als weitere Spiegel + Beziehungen. Button „🌳" in der Detailkarte → Modal mit
**Umfang** (person/eltern/kinder/beides) **und Tiefe** (direkt / ganze Linie, v14.78 — rekursiver
Ahnen-/Nachkommen-Closure in der RPC). **Board-Modus (Phase 1–4) + Feature 7 vollständig.**

> **Hinweis:** `person_neuer_baum` hat jetzt 5 Parameter (+`p_tiefe`) → `supabase_person_neuer_baum.sql`
> **erneut ausführen** (droppt die alte 4-arg-Version, legt die neue an).

## 4.2 — Kopie als Identitäts-Spiegel (bewusst NICHT umgesetzt)
Eine „Einfügen als Spiegel"-Option auf dem Board wäre semantisch ungültig: dasselbe `identitaet_id`
darf pro Baum nur EINMAL vorkommen. Board-Copy/Paste bleibt daher „neue eigene Person". Der
Identitäts-Spiegel über Bäume ist Feature 7 (`person_neuer_baum`).

## i18n-Schlüssel (anzulegen, alle 5 Sprachen — bei Umsetzung)
`board_modus` (Umschalter), `board_tooltip`, `board_verschieben_hinweis`,
`board_gross_warnung` (Performance-Schwelle), `board_fehler_speichern`,
`board_verkn_titel`, `board_typ_eltern`/`_partner`/`_ex`/`_kind`/`_geschwister`,
`board_typ_erkannt`, `board_bestaetigen`, `board_bez_entfernen`.
(Bestehende Fehlertexte `vkn_*` werden wiederverwendet.)

## Layout-Umschalter „Autosortierung / Tabla" (v14.83)
Der Board-Modus ist ab v14.83 kein eigenes Ansicht-Preset mehr, sondern ein **Layout-Modus**,
entkoppelt vom inhaltlichen Preset:
- **Layout-Pille oben rechts** (`#baum-layout-modus`, Buttons `lm-auto`/`lm-tabla`):
  `layoutModus ∈ {'auto','tabla'}`. `auto` = Diagramm/Autosortierung (d3-Ränge), `tabla` = freies
  Board (`zeigeBoardAnsicht`). Umschalten über `layoutModusWaehle(m)` → `rendereLayout()`.
- **Preset-Pille unten links** (`#baum-ansicht-modus`): nur noch `standard`/`kreis`/`voll`
  (`aktuellesPreset`), der `am-board`-Button ist entfernt. `baumAnsichtWaehle(v)` behält den
  Layout-Modus.
- ~~**Presets wirken in BEIDEN Layout-Modi (v14.84):**~~ **ZURÜCKGENOMMEN mit SCRUM-8.**
  v14.84 ließ `boardBerechnePositionen` das Preset auswerten und für `standard`/`kreis` einen
  eigenen `zeichneGraph2`-Lauf mit der **eigenen Karte als Fokus** fahren. Das erzeugte einen
  **Koordinaten-Konflikt**: Positionen aus dem Preset-Lauf (Ursprung = eigene Karte, zusätzlich
  andere Reihen-Y wegen der `upN`-Spiegelung) landeten zusammen mit gespeicherten
  `board_layout`-Positionen (Ursprung = Blut-Wurzel) in **einer** Bounding-Box. `boardAutoFit`
  spannte über beide Cluster → Karten briefmarkenklein in der Ecke, riesiges leeres
  Viewport-Rechteck. Verstärkend: `loseDefault` blieb im Ausschnitt-Zweig leer, wodurch die
  Ausschluss-Logik in `boardAutoFit` — genau gegen aufgeblähte Boxen gebaut — wirkungslos war.
- **Neu (SCRUM-8): Presets erzwingen die Autosortierung.** Das Board zeigt wieder **immer den
  ganzen Baum**, konsistent zu „Board-Umfang: ganzer Baum" weiter oben.
  - `baumAnsichtWaehle('standard'|'kreis')` setzt zusätzlich `layoutModus = 'auto'` (inkl.
    `localStorage 'vidovic_layoutmodus'`). Die Buttons bleiben **immer klickbar** und liefern
    **immer** die versprochene Ansicht — statt deaktiviert zu sein (erklärt dem Nutzer nichts)
    oder etwas anderes zu zeigen als sie behaupten.
  - `layoutModusWaehle('tabla')` setzt `aktuellesPreset = 'voll'`; die Preset-Pille springt
    sichtbar auf „Ganzer Baum". Damit ist der Zustand „Ausschnitt-Preset aktiv markiert, während
    der ganze Baum gerendert wird" **nicht mehr erreichbar**.
  - `boardBerechnePositionen` hat nur noch **einen** `zeichneGraph2`-Aufruf (voll/`blutScope`) →
    ein einziges Koordinatensystem. Der stille Fallback über `meineKarteImBaum()` entfällt damit
    ersatzlos: es gibt nichts mehr, worauf still zurückgefallen werden könnte.
  - Die „unverbundene Karten ergänzen"-Schleife läuft wieder **immer** → `loseDefault` gefüllt,
    `boardAutoFit`-Ausschluss greift.
  - `zeichneBoard` bricht bei leerem `visible` nicht mehr **stumm** ab, sondern meldet
    `board_leer` über `zeigeHinweis` — **einmal je Board-Eintritt** (`boardLeerGemeldet`, Reset in
    `zeigeBoardAnsicht`), weil `zeichneBoard` bei jedem Zoom-/Realtime-Redraw läuft.
  - **Bewusste Grenze:** Wer im Board einen Ausschnitt sehen will, landet in der Autosortierung.
    Ein Preset-Klick ändert also **zwei** sichtbare Zustände (Preset **und** Layout-Pille) — das
    ist beabsichtigt und durch das sichtbare Umspringen beider Pillen nachvollziehbar.
  - `board_layout` wird dabei **nur gelesen**: keine Position wird verschoben oder gelöscht, keine
    Datenmigration nötig — die gespeicherten Werte waren immer schon `voll`-Koordinaten.
  `rendereLayout` zeichnet bei einem Preset-Wechsel im Board weiterhin nur **neu** (`zeichneBoard`)
  statt `zeigeBoardAnsicht` — sonst ginge bei jedem Preset-Klick der Bearbeitungsmodus verloren.
- **Fremder Baum** (keine eigene Karte, `eigenerBaum()===false`): `standard`/`kreis` sind
  deaktiviert und das Preset wird auf `voll` gezwungen (persönliche Presets brauchen die eigene
  Person). `tabla` bleibt nutzbar, aber ohne Admin-Rechte statisch (kein `board-edit-btn`).
- **„celo stablo" = kompakte Blutlinien-Ansicht (Auto), ALLE Karten nur in Tabla (D, revidiert
  v14.84):** Ursprünglich sollte `vollGraphRender()` den Forest-Renderer
  `zeichneGraph(w, 99, 99, {erlaubt: netzErlaubtSet(baum)})` nutzen (alle Karten). Das ist optisch
  die früher **auf Nutzerwunsch entfernte** „Netz"-Ansicht (zu viel Abstand, Karten winzig) →
  deshalb `VOLL_ALLE_KARTEN=false`: die Autosortierung nutzt wieder `zeichneGraph2 … blutScope`
  (kompakt). Der Forest-Pfad bleibt als Backup im Code (`true`), wird aber NICHT empfohlen. ALLE
  Karten (eingeheiratet/lose) bleiben über den **Tabla**-Modus sichtbar (`boardBerechnePositionen`:
  Blutlinien-Seed + alle unverbundenen Karten des Baums). Die Blutlinien-**Färbung**
  (`BLUTLINIE_IDS`) bleibt in beiden Fällen.
- **Edit-Zustand sichtbar (v14.84):** Der Bearbeiten-Button (jetzt in der Layout-Pille oben rechts)
  wechselt im Edit-Modus die Beschriftung `board_edit` → `board_fertig` (Уреди → Готово) und wird
  `.aktiv`; zusätzlich weißes Dot-Grid (`board-edit-grid`).
- i18n: `layout_auto` („Autosortierung"), `layout_tabla` („Tabla"), `layout_titel` (aria) — 5 Sprachen.
- `baumAnsichtSync()` synchronisiert BEIDE Pillen (aktiver Button, Gating) und zeigt
  `board-edit-btn` nur bei `layoutModus==='tabla' && istAdmin()`.

## Löschen im Board = dieselbe „nur dieser Baum / alle Bäume"-Wahl wie im Editor (v14.84, Bugfix)
Zuvor rief `boardLoeschen` blind `person_papierkorb` (identitätsbewusst) → eine reale Person mit
Spiegelkarten (`identitaet_id`) wurde aus ALLEN Bäumen gelöscht, nur mit simpler Ja/Nein-Frage
(**Datenverlust**). Ab v14.84 nutzen ALLE Lösch-Einstiege dieselbe zentrale Abfrage:
- `personBaeumeMap(p)` — alle aktiven Bäume der Identität (aus dem geladenen Verbund).
- `personLoeschWahl(p)` — `>1 Baum` → 3-Wege-Dialog (`loesch_mehrere_frage`: nur dieser / alle);
  `1 Baum` → einfache Bestätigung. Rückgabe `'dieser'|'alle'|null`.
- `'dieser'` → `person_karte_papierkorb` (nur diese Spiegelkarte, Zwilling bleibt);
  `'alle'` → `person_papierkorb`. Beides mit Undo (`loesch_batch` → `papierkorb_wiederherstellen`);
  Redo hängt an der TATSÄCHLICH benutzten RPC.
- **Mehrfach-Löschung (Del-Taste):** fragt EINMAL vorab (`loesch_mehrere_frage_n`), wenn irgendeine
  Auswahl mehrere Bäume betrifft, und wendet die Wahl auf alle an (single-Baum-Personen fallen
  automatisch auf `'alle'` zurück, damit `person_karte_papierkorb` nicht „kein_zwilling" wirft).

## Linien-ANKER: Endpunkte manuell an eine Kartenseite ziehen (v14.84)
Vorher docken alle Board-Linien fix an Ober-/Unterkante-Mitte an, und die **Geschwister-Klammer**
war als einzige Linienart gar nicht editierbar (kein Griff) → „rechte Seite A → linke Seite B" war
unmöglich. Neu:
- **DB** (`supabase_board_linie_seiten.sql`): `board_linie` bekommt `von_seite`/`nach_seite`
  (`'l'|'r'|'t'|'b'`, NULL = automatisch) + CHECK; `wx/wy` werden NULLABLE (Anker ohne Wegpunkt).
  Neue RPC `board_linie_seiten_setzen(baum, von, nach, von_seite, nach_seite)` (Rechte wie
  `board_linie_setzen`, das die Anker jetzt NICHT mehr überschreibt). `board_linie_reset` löscht
  weiterhin die ganze Zeile = Anker UND Wegpunkt zurück auf automatisch.
- **Geometrie** (rein, getestet): `boardAnker` (Kantenpunkt je Seite), `boardAutoSeiten`
  (zugewandte Kanten als Default), `boardSeiteAusPunkt` (Einrasten beim Ziehen),
  `boardOrthoPunkte` (orthogonaler Verlauf: waagerecht↔waagerecht = Zwischenspalte,
  senkrecht↔senkrecht = Zwischenzeile, gemischt = L).
- **Bedienung:** Im Board-Edit hat jede editierbare Linie an BEIDEN Enden einen goldenen Griff
  (`.board-anker-griff`). Ziehen rastet auf die nächste Kartenseite ein und speichert;
  **Doppelklick** setzt die Linie auf automatisch zurück.
- **Trefferflächen (v14.84, Bugfix „Linien nicht änder-/löschbar"):** Zwei Ursachen, beide behoben:
  1. *Ändern ging nicht* — die Griffe lagen exakt auf der Kartenkante (`±76, 0`), also **deckungsgleich
     mit den ⊕-Schnellzugriff-Buttons** (`knoten-plus`, r=9), und die Kartengruppe wird NACH `linienG`
     gezeichnet → der Klick traf immer den ⊕-Button. Griffe sitzen jetzt `OFF = 24px` **nach außen
     versetzt** (9px Luft zum Button) und werden am Ende von `boardZeichneLinien` per `.raise()` über
     die Trefferlinien gehoben.
  2. *Löschen ging nicht* — eine SVG-`<line>` ist nur auf **Strichbreite (~2px)** klickbar. Je Segment
     liegt jetzt eine unsichtbare `.board-linie-hit` (stroke-width 16, `stroke: transparent`,
     `pointer-events: stroke`) darüber, die den Klick trägt und die sichtbare Linie beim Hover rot
     hervorhebt (`.board-linie-hover`).
  Beide Griffarten haben zusätzlich einen unsichtbaren Fasskreis `.board-anker-hit` (r=16 → 32px
  Durchmesser, erfüllt die Touch-Regel). Wichtig: `fill: transparent` (hit-testbar), NICHT `fill: none`.
  3. *Griffe sichtbar, aber trotzdem nicht ziehbar* — die eigentliche Ursache: `boardMarqueeStart`
     brach nur bei `.board-knoten` ab. Beim Pointerdown auf einen Linien-Griff startete deshalb die
     **Marquee-Rahmenauswahl** (mit `ev.preventDefault()` + `window`-`pointermove`/`pointerup`) und
     riss die Zieh-Geste an sich. Genau das erklärte die Asymmetrie „Karten ziehen geht, Griffe nicht".
     Neu gibt es EINEN zentralen Selektor **`BOARD_GESTE_SEL`** + Helfer `boardEigeneGeste(target)`
     (`.board-knoten, .board-anker-griff-grp, .board-linie-griff-grp, .board-linie-hit`), den sowohl
     `boardMarqueeStart` als auch der Touch-**Long-Press** (Kontextmenü) prüfen. Der **Zoom-Filter**
     bleibt bewusst auf `.board-knoten`: er schaltet Zoom/Pan auf allem außer Karten ab — für Griffe
     genau richtig (kein Pan-Diebstahl).
  4. *Elternpaar→Kind ließ sich nicht löschen, Partner/Geschwister schon* (SCRUM-5) — der
     `twoParents`-Zweig von `boardZeichneLinien` zeichnet seine Segmente **von Hand** (statt über
     `boardVerbindung`) und hängte `klick(...)` nur an das **letzte, kurze Stück** an der Kindkarte.
     Genau dieses Stück ist oben vom Wegpunkt-Griff (`boardLinienHandle`, Fasskreis r=16) und unten
     vom ⊕-Schnellzugriff verdeckt → bei üblichen Generationsabständen blieb keine klickbare
     Restlänge. Neu trägt **jedes** Segment beider Verläufe (Auto = 3, Wegpunkt = 4) eine
     Trefferlinie, wie `boardVerbindung` es ohnehin tut. Die Zuordnung bleibt eindeutig, weil jedes
     Kind seinen **eigenen** Verbinder ab dem Rauten-Joint hat (kein gemeinsamer Bus). Das `.raise()`
     der Griffe am Funktionsende ist dadurch **zwingend** — sonst fangen die neuen Trefferlinien das
     Ziehen ab.
  5. *Fehlschlag blieb stumm* (SCRUM-5) — `beziehung_papierkorb` meldet Fehlschläge **ohne**
     `error`: `{ok:false,grund:…}` bei fehlenden Rechten, `{ok:true,beziehungen:0}` wenn keine Kante
     getroffen wurde. `boardBezLoeschen` wertete nur `error` aus → stummer Reload, Linie noch da,
     „Fehlschlag" nicht von „danebengeklickt" unterscheidbar. Jetzt wird die Antwort echt ausgewertet
     (übersetzter Grund über `fehler_*`-Schlüssel bzw. `board_bez_nichts`).
- **Editierbar (Verbindung zwischen ZWEI Karten):** Partnerlinien, Geschwister (benachbarte Paare,
  nach x sortiert — ersetzt die starre Klammer) und Einzelelternteil→Kind.
- **Bewusste Grenze:** Elternpaar→Kind startet am Rauten-Joint (Paar-Mittelpunkt), das ist keine
  Kartenseite → dort bleibt der bestehende **Wegpunkt**-Griff (`boardLinienHandle`).

## Drei Griffe je Linie: Anfang, Ende, Knick (SCRUM-10, v14.9x)
Vorher war die Bedienung je Linienart verschieden: `boardVerbindung`-Linien (Partner, Geschwister,
Einzelelternteil→Kind) hatten **nur** die zwei Endpunkt-Anker, Elternpaar→Kind **nur** den Wegpunkt.
Keine Linie hatte alle drei. Jetzt einheitlich:

| Linienart | Anfang | Ende | Knick/Mitte |
|---|---|---|---|
| Partner (`ehe-linie`) | ✅ | ✅ | ✅ ab `BOARD_GRIFF_MIN` |
| Geschwister | ✅ | ✅ | ✅ ab `BOARD_GRIFF_MIN` |
| Einzelelternteil→Kind | ✅ | ✅ | ✅ ab `BOARD_GRIFF_MIN` |
| Elternpaar→Kind | ❌ (Rauten-Joint) | ✅ **neu** | ✅ |

**Umsetzung (rein additiv):**
- **`boardOrthoPunkte(A, sa, B, sb, wp)`** — neuer **optionaler** Wegpunkt. Mit `wp` läuft der
  orthogonale Verlauf **durch** diesen Punkt: von A in Richtung der Start-Seite weg, durch `wp`,
  passend zur Ziel-Seite in B einlaufen; aufeinanderfolgende identische Punkte werden entfernt
  (keine Null-Segmente). **Ohne `wp` exakt das bisherige Verhalten** (per Test abgesichert).
- **`boardGriffPunkt(pts)`** (neu, rein/DOM-frei) — Default-Position des dritten Griffs:
  genau **eine Ecke** → auf der Ecke; **mehrere Ecken** → die der **Pfadmitte** (halbe Manhattan-
  Gesamtlänge) nächstgelegene; **gerader Verlauf** → Streckenmitte.
- **`boardPfadLaenge(pts)`** (neu, rein) + **`BOARD_GRIFF_MIN = 64`** — s. u.
- **Elternpaar→Kind** nutzt jetzt **dieselbe** Geometrie (`boardAnker` + `boardOrthoPunkte`) statt
  fest berechneter Segmente. Da `sa`/`sb` dort beide vertikal sind, liefert `boardOrthoPunkte`
  `[A, {A.x,midY}, {B.x,midY}, B]` mit `midY = (startY+endY)/2` — **punktgenau der alte Verlauf**
  (an 6 Layout-Fällen verifiziert, inkl. Kind oberhalb). Der Endpunkt kommt jetzt aus
  `boardAnker(sb)`, deshalb ist die Andockseite an der Kindkarte per Griff wählbar; die frühere
  feste Kante `endY` entfällt.

⚠️ **Mindestlänge für den Knick-Griff (`BOARD_GRIFF_MIN = 64px`) — vom Nutzer ausdrücklich
bestätigt (21.07.2026), bewusste Abweichung vom Wortlaut „jede Linie zeigt drei Griffe":** Partner stehen im Standard-Layout
`G2_PAAR = 162px` auseinander bei `2*HW = 152px` Kartenbreite → die Linie ist nur **10px** lang. Die
Anker-Griffe sitzen `OFF = 24px` nach außen und **überkreuzen sich dort bereits um 38px**; ein
Mittelgriff (Fasskreis r=16) läge genau dazwischen und wäre nicht treffbar. Unterhalb der Schwelle
bleiben daher die zwei Anker-Griffe zuständig — zieht der Nutzer die Karten auseinander, erscheint
der dritte Griff automatisch. **Ausnahme:** Ist bereits ein Wegpunkt gespeichert, wird der Griff
**immer** gezeichnet, sonst ließe sich ein verschobener Verlauf nicht mehr zurücksetzen (Doppelklick).

**Keine SQL-Änderung:** `board_linie` hält `wx`/`wy` (NULLABLE seit `supabase_board_linie_seiten.sql`)
und `von_seite`/`nach_seite`; `board_linie_setzen` (Wegpunkt) fasst die Anker nicht an,
`board_linie_seiten_setzen` (Anker) nicht den Wegpunkt → beide sind unabhängig, wie gefordert.
`BOARD_GESTE_SEL` deckt `.board-linie-griff-grp` bereits ab → Marquee/Long-Press starten nicht auf
dem neuen Griff; das abschließende `.raise()` in `boardZeichneLinien` bleibt zwingend.
- Realtime (`boardLinieRealtime`) und der Wegpunkt-Griff **mergen** jetzt in `boardLinien[key]`,
  statt zu überschreiben — sonst gingen die Anker verloren.

## Vollständigkeit: Tabla ⊇ Autosortierung (v14.84)
Kurzzeitig filterte `boardBerechnePositionen` den Seed auf Knoten mit einer Karte im aktuellen Baum
(`n.trees.has(...)`), um eine nur-hier-gelöschte Karte auszublenden. Das war **zu grob**: im Board
fehlten dadurch baumübergreifend verbundene Verwandte (Tabla zeigte WENIGER als die Autosortierung).
**Zurückgenommen** — der Board-Seed wird nicht mehr gefiltert. Invariante: **Tabla zeigt mindestens
alles, was die Autosortierung zeigt** (Seed identisch) plus alle unverbundenen Karten des Baums.

**Offen (bewusst):** `baueGraphModell` führt Identitäts-Zwillinge baumübergreifend zu EINEM Knoten
zusammen (`canonOf → 'grp:'+_ident`). Wird eine Karte nur aus DIESEM Baum gelöscht
(`person_karte_papierkorb`), hält der Zwilling im anderen Baum den Knoten am Leben → die Person
bleibt sichtbar. Das sauber zu trennen erfordert baum-skopierte Kanten im kanonischen Modell
(`graphBlutScope`) und ist NICHT über einen Sichtbarkeitsfilter lösbar, ohne echte Verwandte zu
verlieren.

### Kanten-Regel: Tabla zeichnet NUR Kanten der Autosortierung (SCRUM-6, v14.8x)
Die Invariante „Tabla ⊇ Autosortierung" gilt für **Karten**, für **Kanten** gilt Gleichstand.

**Problem:** Dieselbe Identitäts-Verschmelzung erzeugt für EIN Kind **mehrere Unions** — je Baumkarte
eine eigene Elternschaft (Beispiel aus den echten Daten: Svetozar hat im einen Baum die Elternschaft
`{Đoko}`, im anderen `{Đoko, Stanislava}`). `zeichneGraph2` folgt beim Abstieg **genau einer** davon,
`boardZeichneLinien` iterierte **alle** → Tabla zeigte Linien, die die Autosortierung nicht zeichnet.
Sichtbar wurden sie als **lange Waagerechte quer über den Baum**, weil der Eltern→Kind-Verbinder am
Paar-Mittelpunkt `px` ansetzt: liegt ein Elternteil ohne Karte im aktuellen Baum weit entfernt, wandert
dieser Mittelpunkt ins Leere. Gemessen: 77 Überschuss-Kanten über alle Bäume (Pisarević 9, Jovanović 12).

**Lösung (umgesetzt):** `zeichneGraph2` gibt die **tatsächlich gezeichneten** Kanten über
`opts.sammleKanten` heraus (analog `sammlePos`, rein additiv — ohne den Hook exakt bisheriges
Verhalten aller Ansichten). `boardBerechnePositionen` reicht das Set durch und liefert es als `kanten`
zurück; `boardZeichneLinien(model, visible, X, Y, g, autoKanten)` zeichnet ausschließlich Kanten
daraus. Schlüsselformat (**muss auf beiden Seiten identisch bleiben**):
- Ehe: `[a,b].sort().join('|') + '|ehe'`
- Eltern→Kind: `'P:' + eltern.sort().join('&') + '>' + kind` (Elternmenge, **nicht** je Elternteil —
  Eltern→Kind ist EINE Linie ab dem Paar-Mittelpunkt)

**Warum kein Nachbau im Board:** Die Union-Wahl der Autosortierung hängt an ihrer
Traversierungsreihenfolge (`unionsByParent`) und ist von außen nicht reproduzierbar. Eine Heuristik
(„Elternteil mit Karte im aktuellen Baum gewinnt") wurde gemessen: behebt Pisarević, **verliert aber
20 echte Kanten in 8 anderen Bäumen** → verworfen. Das Set ist die einzige Wahrheit.

⚠️ **Redraw-Pfade:** Karten-Drag, Anker-/Wegpunkt-Drag und `boardLinieReset` rufen `boardZeichneLinien`
**ohne** Set auf und haben es nicht im Scope → Rückfall auf **`boardState.kanten`** (in `zeichneBoard`
mitgesetzt). Ohne diesen Rückfall kämen beim ersten Ziehen alle gefilterten Linien zurück.

**Der Geschwister-Fallback bleibt ungefiltert** (`stammbaum.html`, Union ohne sichtbare Eltern, ≥2
Kinder): Er ist der einzige Weg, eine Geschwister-Beziehung am Board zu lösen. Messung an echten
Daten: Er feuert in **keinem** der 48 Bäume, weil Platzhalter-Eltern im Auto-Scope sichtbar sind und
gezeichnet werden — er ist also keine Überschuss-Quelle.

**Verifikation:** Diff Auto ↔ Tabla über alle Bäume aus `render_snapshot.json` — Überschuss **77 → 0**
und **0 verlorene** Auto-Kanten (Schutz gegen Über-Filtern, die gefährlichere Regression, siehe v14.84).

**Ausnahmen vom Autosort-Filter — reale Kanten zwischen sichtbaren Karten (FAMROOTS-40, FAMROOTS-42):**
Der Filter unterdrückt Kanten, die die blutScope-Autosortierung nicht zieht. Ein **frisch eingeheirateter
/ nicht-blutlinien** Partner bzw. Elternteil steht außerhalb blutScope → sein Schlüssel (`…|ehe` bzw.
`P:…>kind`) fehlt komplett → die reale Kante wird stumm unterdrückt (leere Detailkarte + keine Linie).
Da eine Identitäts-Spiegelkarte **kein Phantom** erzeugen kann, wenn die Kante real zwischen zwei
**sichtbaren** Karten besteht, gelten zwei gezielte Ausnahmen:
- **`zeigeElt` (FAMROOTS-40):** Ein **Ein-Eltern**-Kante immer zeichnen (ein einzelner Elternteil hat
  keinen Paar-Mittelpunkt `px` → kann die lange Phantom-Waagerechte gar nicht erzeugen).
- **`zeigeEhe` (FAMROOTS-42/46):** Partner-Linie zeichnen, wenn beide sich eine **echte** Ehe-/Partner-
  Familie teilen (`husband`/`wife` = genau diese beiden ext-IDs, `echtesPaar`). Der Autosort-Schlüssel
  behält Vorrang; der Datencheck greift nur, wenn er fehlt. **FAMROOTS-46:** `echtesPaar` schließt Ex
  **ohne** gemeinsame Kinder NICHT mehr aus — `boardZeichneLinien` ist board-only und das manuelle Board
  zeigt jede angelegte Beziehung. Ex-Linien werden im Board grau gezeichnet (`.ehe-linie-ex`, aus
  `u.partner_art`). **Auto-Diagramm (FAMROOTS-47):** Ex-ohne-Kinder wird über den separaten
  `nebenPartner`-Index + Post-Layout-Pass in `zeichneGraph2` neben die Person gesetzt (rein additiv,
  verdrängt keinen echten Ko-Elternteil). NICHT in `partners` aufnehmen — das bricht die Anordnung
  (Kind verschwindet, siehe `docs/lessons.md`).

**Leeres Partner-/Verwandten-Chip (FAMROOTS-42, Weg A+B):** Ursache war zweistufig — (A) `ladeBaumAusSupabase`
spreadet `stammbaum_daten.name` nur (kein Compose), also blieb `person.name` leer, wenn Altdaten/
bestimmte Anlagepfade nur `given`/`surname` gesetzt hatten → `nm(name)` leer → Chip nur mit ⇄/✕.
Behoben an der Quelle (Compose `given+surname`, echte Platzhalter bleiben `lokalisierePlatzhalterNamen`
überlassen) **und** defensiv in `relChip` (Fallback `name → given+surname → given → surname →
`t('ohne_namen')`) — es entsteht nie mehr ein komplett leeres Chip.

### Karten-Gleichstand: Autosortierung zeigt jetzt AUCH die losen Karten (SCRUM-6, v14.8x)
**Nutzerentscheidung:** *Alle Ansichten zeigen alle Karten des Baums; lose Karten oben links gruppiert.*
Damit entfällt die bisherige Grenze „Unverbundene Inseln bleiben der ‚Lose Karten'-Leiste vorbehalten"
(Abschnitt „Autosortierung zeigt alle EIGENEN Karten", v14.84).

> **Folge für SCRUM-9:** Weil die Autosortierung die losen Karten seit SCRUM-6 selbst zeichnet,
> waren die beiden Leisten unter dem Baum gegenstandslos und wurden mit **SCRUM-9** entfernt —
> samt „Im Baum anzeigen" (`forceGezeigt`, Tabelle `baum_sichtbarkeit`, RPC `karte_sichtbar_setzen`).
> Waisen sind erreichbar über **Tabla** (immer alle Karten), die **Autosortierung im Preset
> „celo stablo"** und die **Suche**. Nur in den Ausschnitt-Presets `standard`/`kreis` bleiben sie
> außen vor — das ist der Zweck eines Ausschnitts, kein Verlust.

`zeichneGraph2` ergänzt nach dem Zeichnen von Nachkommen/Vorfahren/Geschwistern alle Karten mit
`_tree === opts.blutScope` (ohne Platzhalter), die die Traversierung nicht erreicht hat — der Renderer
läuft vom Fokus aus und findet unverbundene Inseln nie. Ablage im Raster **oben links**:
`randX = min(x) − 420 − Spalte·190`, `randY = min(y) + Zeile·120`, 4 pro Zeile.

* **Nur im `blutScope`-Zweig** („celo stablo"). In `standard`/`kreis` würde die Ergänzung den
  Ausschnitt-Filter aushebeln — dieselbe Bedingung wie im Board (`!_ausschnitt`).
* **Formel, Iterationsreihenfolge und Rasterschritte sind bewusst identisch zu
  `boardBerechnePositionen`** → eine Karte springt beim Umschalten Auto ↔ Tabla nicht.
* **Auto-Fit:** Ablage-Karten zählen **nicht** in die Bounding-Box (`ptsLos` statt `pts`) — sonst zieht
  das 420px-Raster den Fit auf und der ganze Baum wird kleingezoomt (exakt der v14.84-Effekt im Board).
  **Die Pan-Grenze umfasst sie aber weiterhin**, sonst wären sie sichtbar, aber nicht anfahrbar.
  Fallback: Hat ein Baum NUR Ablage-Karten, zählen doch alle (sonst bliebe die Ansicht leer).
* **Board-Seite:** `sammlePos` markiert diese Karten mit `los: true`; `boardBerechnePositionen`
  übernimmt daraus `loseDefault` (nur ohne gespeicherte `board_layout`-Position). Die dortige
  Ergänzungsschleife findet dadurch im Regelfall nichts mehr und bleibt als Sicherheitsnetz stehen.

**Bewusste Folge:** Eine lose Karte mit echter Beziehung (deren Kante die Autosortierung nicht zeichnet)
erscheint in **beiden** Ansichten als Karte **ohne Linie**. Das ist gewollt — die Alternative wäre genau
die gemeldete lange Querlinie. Beide Ansichten sind damit konsistent.

**Verifikation:** Kartenzahl Auto == Tabla in **allen 47** Bäumen (19 ergänzte lose Karten, u. a.
Tadić +7, Jovanović +4, Vidović +3, Knežević +3); zusätzlich geprüft: **keine** Linie hängt an einer
losen Karte.

## Autosortierung zeigt alle EIGENEN Karten (v14.84)
`zeichneGraph2(..., blutScope)` nutzte ausschließlich `graphBlutScope.visible` → eingeheiratete
Personen, abweichende Nachnamen und Seitenlinien fielen weg (Karten „verschwanden" beim Umschalten
von Tabla auf Autosortierung). Neu wird `visible` um **alle Knoten mit einer Karte im aktuellen Baum**
ergänzt (und diese aus `cut` entfernt, damit kein falsches „setzt sich in anderem Baum fort"-Kennzeichen
erscheint). Die Kappung verhindert weiterhin den Bleed in FREMDE Familien; das Layout bleibt der
kompakte fokus-zentrierte Renderer (kein Forest/„Netz"). ~~Unverbundene Inseln bleiben der
„Lose Karten"-Leiste vorbehalten~~ — überholt: seit SCRUM-6 ergänzt `zeichneGraph2` die
unverbundenen Karten selbst (Raster oben links, s. o.), und die Leiste ist mit **SCRUM-9**
entfallen.

## Layout-Modus: Standard Tabla + Baumwechsel-Sync (v14.84)
- `layoutModus` startet auf **`'tabla'`**; die Nutzerwahl wird in `localStorage('vidovic_layoutmodus')`
  gemerkt und schlägt den Standard (`layoutModusWaehle` speichert; defekter/blockierter Storage
  fällt sauber auf `'tabla'` zurück).
- `waehleStammbaum` rendert bei `layoutModus === 'tabla'` über **`rendereLayout()`** statt über den
  Auto-Pfad. Vorher setzte der Baumwechsel `ansichtModus = null` und rendete das Diagramm, während
  die Pille weiter „Tabla" zeigte → `boardGridAnwenden` (verlangt `ansichtModus === 'board'`) griff
  nicht mehr: Edit-Button sagte „Fertig", der Hintergrund blieb aber das Baumbild.
  Da der Erstlade-Pfad ebenfalls über `waehleStammbaum` läuft, gilt der Tabla-Standard auch beim Login.

## Unberührtes Tabla sieht aus wie die Autosortierung (v14.84)
Solange der Nutzer keine Karte verschoben hat, kommen die Board-Positionen ohnehin aus dem
`sammlePos`-Hook von `zeichneGraph2` — trotzdem sah Tabla deutlich anders aus. Zwei Ursachen:
1. **Ablage-Raster in der Bounding-Box:** unverbundene Karten ohne `board_layout`-Eintrag werden
   420px+ LINKS neben dem Baum abgelegt. `boardAutoFit` rechnete sie mit → Bounding-Box massiv
   breiter → alles kleingezoomt (bei „Vidović" ein schmales Band statt eines Baums).
   Neu sammelt `boardBerechnePositionen` diese Karten in **`loseDefault`** (nur Karten OHNE
   gespeicherte Position) und `boardAutoFit(PX, PY, ausschluss)` lässt sie aus der Box heraus.
   Sie bleiben **sichtbar**, und die **Pan-Grenze umfasst weiterhin ALLE** Karten — sonst wären sie
   sichtbar, aber nicht anfahrbar. Fallback: gibt es NUR Ablage-Karten, zählen doch alle.
2. **Abweichende Fit-Werte:** `boardAutoFit` nutzte `pad 0.04` / max-Skala `1.4`, `zeichneGraph2`
   aber `pad 0.03` / `2.5`. Jetzt identisch → ein unberührtes Board ist bildgleich zur Autosortierung.

Sobald der Nutzer Karten verschiebt, gewinnen wie bisher die `board_layout`-Positionen; verschobene
Karten sind nicht mehr in `loseDefault` und zählen normal in den Fit.

## Bewusste Grenzen (v1)
- Kein Live-Push der Positionen (kein Realtime-Cursor), „letzter Upsert gewinnt".
- Keine Auto-Vermeidung von Überlapp (freies Board erlaubt Überlapp bewusst).
- Auto-Erkennung ist ein **Vorschlag**, nie stille Automatik; ohne Datum bleibt die
  Richtung offen.
- Mobile funktionsfähig, aber Desktop/Tablet ist die primäre Zielplattform.

## Gleichmäßige Strichstärke im Tabla-Modus (SCRUM-14, 2. Anlauf)
Der erste Anlauf behob Overdraw nur in `zeichneGraph2` (Autosortierung) — der **Standard-Layoutmodus
ist aber `tabla`**, und `boardZeichneLinien` war nicht angefasst. Test entsprechend NOK.

**Ursache im Board:** Jedes Kind bekommt einen **eigenen** Verbinder ab dem Rauten-Joint
(`A = {x: px, y: startY}`). Liegen die Kinder auf gleicher Höhe (Normalfall), ist das erste
senkrechte Stück für **alle** Kinder identisch und wurde n-fach übereinander gezeichnet. Da
`.verbindung` halbtransparent ist (`rgba(255,248,220,0.88)`), addiert sich die Deckkraft
(0,88 → 0,986 → 0,998) und die Antialiasing-Ränder verbreitern sich → die Linie **wirkt** dicker.

**Lösung — `segZeichnen(gg, x1, y1, x2, y2, klass, paare, name)`** in `boardZeichneLinien`:
* Die **sichtbare** Linie wird je Segment nur **einmal** gezeichnet (Map, Schlüssel = sortierte
  Endpunkte auf 0,5 px gerundet + Klasse).
* Die **Trefferfläche** (`.board-linie-hit`) entsteht weiterhin **je Beziehung** — sonst wäre die
  zuletzt gezeichnete Kante nicht mehr löschbar. Das Löschverhalten bleibt damit unverändert.
* Der Helfer wird über `ctx` an `boardVerbindung` durchgereicht, sodass **alle vier** Linienarten
  (Partner, Geschwister, Einzelelternteil→Kind, Elternpaar→Kind) dieselbe Map teilen.

⚠️ **Wichtig bei künftigen Änderungen:** Neue Board-Linien immer über `segZeichnen` zeichnen, nicht
über `g.append('line')` — sonst kehrt das Overdraw zurück. `boardVerbindung` hat einen Fallback auf
den alten Pfad, falls `segZeichnen` im `ctx` fehlt.

**Verifiziert:** 3× dasselbe Segment → **1** sichtbare Linie, aber **3** Trefferflächen.

**Logische Entdopplung ergänzt (FAMROOTS-48):** `segZeichnen`/`_segMap` ist rein **geometrisch** (0,5px +
Klasse) — dieselbe LOGISCHE Beziehung aus zwei Unions (Identitäts-Spiegelkarten / Subset-Union `{M}` vs
`{M,F}` fürs selbe Kind) liefert minimal andere Geometrie (> 0,5px) → beide Striche bleiben. Ergänzt um
ein **`_logGez`-Set** in `boardZeichneLinien`, das je **kanonischer** Beziehung nur einmal zeichnet:
`E|a|b` (Ehe), `P|elternteil|kind` (je Elternteil-Kind-Paar), `G|a|b` (Geschwister). Die Unions werden
**mehr-Eltern-zuerst** verarbeitet, damit die **Paar-Kante** (Superset) die (Elternteil,Kind)-Schlüssel
VOR der Subset-Einzelkante belegt und diese entfällt — die Paar-Kante trägt beide Elternschaften im
`bezPaare`, **Löschen bleibt** also möglich. Echte, VERSCHIEDENE Beziehungen (andere Endpunkte/Typ)
haben andere Schlüssel → **keine** Falsch-Verschmelzung. `_segMap` bleibt als Overdraw-Schutz.

## Rückgängig/Wiederholen-Bedienung (SCRUM-26)
Die Undo/Redo-**Mechanik** existiert seit v14.72 (Phase 2, 4.3). SCRUM-26 ergänzt die **Bedienoberfläche**:
- **Pille `#board-undo-tools`** oben links (Kind von `#baum-container`), zwei Buttons ↶/↷ → rufen die
  bestehenden `boardUndo()`/`boardRedo()`. Sichtbar nur bei `ansichtModus==='board' && boardEdit &&
  istAdmin()` — **zeichengleich** zum Tastatur-Gate in `boardTastatur`.
- **`boardUndoSync()`** setzt Sichtbarkeit + `disabled`/`aria-disabled` der Buttons anhand der
  Stack-Längen. Aufgerufen aus `boardPushUndo`, `boardUndo`, `boardRedo`, `boardWerkzeugeSync`.
- **`#baum-info` weicht im Edit-Modus** per CSS (`#baum-container.board-edit-grid .baum-info { display:none }`)
  — ein Zustandspfad über `boardGridAnwenden`, kein zweiter, der driften kann.
- **„Als Baum ordnen" ist jetzt rücknehmbar** (`boardOrdnen`): sichert die Positionen vor dem
  `board_layout_reset` und leert den Stack **nicht** mehr, sondern legt selbst einen Undo-Eintrag an.
- Tastenkürzel (Strg+Z / Strg+Shift+Z / Strg+Y) unverändert; der Schutz in Eingabefeldern
  (INPUT/TEXTAREA/SELECT/contentEditable) bleibt bestehen.
- i18n: `board_undo`, `board_redo`, `board_undo_titel`, `board_redo_titel`, `board_undo_konflikt`,
  `board_ordnen_undo` (5 Sprachen).

**Linien-Wegpunkte/-Anker rücknehmbar (AK9/AK10):** `board_linie_reset` löscht **Wegpunkt UND Anker
gemeinsam** — es gibt keine RPC nur für den Wegpunkt. Gelöst über `boardLinieZustandSetzen(von,nach,z)`:
setzt erst auf Null (`reset`), dann die vorhandenen Teile neu (Anker via `seiten_setzen`, Wegpunkt via
`setzen`). So kann ein Wegpunkt-Undo keinen vorhandenen Anker mitlöschen. Snapshot des kompletten
`boardLinien[key]` am Drag-Start, Push am Drag-Ende (`boardLiniePushUndo`).

**Schutz vor Überschreiben fremder Arbeit (AK12):** Zentraler Hook — `boardUndo`/`boardRedo` prüfen
vor der Ausführung (`boardUndoKonfliktfrei(e, richtung)`), bei Konflikt Hinweis
(`board_undo_konflikt`) + Eintrag verworfen (nicht auf den Gegenstapel). Für **Positions-Undos**
(Verschieben, „Als Baum ordnen") über `boardPosPruef(erwartet)`: vergleicht **direkt die aktuellen
x/y** in `board_layout` mit den erwarteten (robuster als `updated_at`, das am 500ms-Speicher-Debounce
hängt). Steht eine Karte anderswo → jemand hat sie inzwischen verschoben → Rücknahme blockiert.

⚠️ **Die Prüfung ist RICHTUNGSABHÄNGIG (FAMROOTS-26-Nachbesserung):** vor **Undo** müssen die Karten
auf den **neuen** (zuletzt selbst gesetzten) Positionen stehen (`pruefUndo`), vor **Redo** auf den
**alten** (durchs Undo hergestellten) (`pruefRedo`). Ein einziger fixer `pruef` blockierte sonst
**jedes Redo** fälschlich als Fremdänderung — „Wiederholen"/„ponovi" ging nie. Einträge ohne
Richtungs-Prüfung (Anlegen/Löschen/Verknüpfen) sind unverändert nie blockiert.

⚠️ **AK12 — Reichweite (erweitert durch SCRUM-33):** Der Konfliktschutz gilt für **Positions-Undos**
(Verschieben, „Als Baum ordnen") **und** für **Anlage-Undos** (Karte anlegen, Kopie einfügen — beide
über `boardUndoAnlage`). Bei der Anlage wird `personen.updated_at` direkt nach dem Anlegen erfasst
(`boardPersonStempel`) und beim Undo verglichen; hat jemand die Person seither geändert, wird das
Löschen blockiert (Ticket-Beispiel „A legt an, B ändert, A drückt Strg+Z"). **Weiterhin OHNE Schutz**
(bewusste Grenze): der **Lösch**-Undo — die Person ist bereits im Papierkorb, ihr `updated_at` wurde
durch das Löschen selbst verändert, ein Vorher-Vergleich ist dort nicht sinnvoll — und der
**Verknüpfen**-Undo — Beziehungen haben keinen `updated_at`-Stempel wie Personen; Geschwister-
Verknüpfungen haben ohnehin kein Undo (`boardUndoLink`). Das winzige TOCTOU-Fenster ist dieselbe
bewusste Grenze wie bei P5 (`docs/realtime-kollaboration.md`).

## Linien-Wegpunkte beim Verschieben mitführen (SCRUM-28)
Wechselwirkung „Mehrfach-Verschieben (v14.72) × Linien-Wegpunkte (v14.77)", die bisher an keiner
Stelle behandelt war: Ein von Hand verstellter Knick blieb beim Verschieben einer Auswahl an seiner
alten Weltkoordinate hängen (Wegpunkte werden absolut in `board_linie.wx/wy` gespeichert, der
Karten-Drag verschob nur `PX/PY`). Betraf auch das Verschieben **einer** Karte.

**Lösung (A, ohne Datenmodell-Änderung):** `boardMacheZiehbar` führt beim Ziehen die Wegpunkte um
dasselbe `dx/dy` mit — aber **nur**, wenn **beide** Endkarten in der Auswahl liegen (starrer Körper).
Liegt nur eine Seite in der Auswahl, bleibt der Wegpunkt stehen (bewusst: die Anker-Seiten passen sich
ohnehin an, ein blind mitgezogener Knick läge oft schlechter). Persistenz je bewegtem Wegpunkt über
das bestehende `board_linie_setzen`; Undo/Redo führt Positionen **und** Wegpunkte gemeinsam zurück.

**Bewusste Grenzen / Fallen (im Test abgedeckt):**
- **Kein Wegpunkt entsteht neu** — nur Einträge mit `x/y != null` werden mitgeführt.
- **Anker-Seiten (`vs`/`ns`) bleiben unberührt** — sie sind kartenrelativ.
- `x` gesetzt / `y` null → übersprungen (kein `NaN`); Verschiebung um 0 → keine Schreibvorgänge.
- **Noch offen (eigener Vorgang):** `boardOrdnen`/`board_layout_reset` verwirft Kartenpositionen, lässt
  `board_linie` aber stehen → Wegpunkte hängen danach im Nichts. Gleiche Ursache (entkoppelte Tabellen).
- **Struktureller Rest (Variante B):** Solange Wegpunkte absolut gespeichert sind, muss jeder künftige
  Karten-Bewegungs-Pfad an die Mitführung denken.

## Long-Press-Kontextmenü nur mit EINEM Finger (SCRUM-31)
Auf dem Handy öffnete der **Zwei-Finger-Zoom** im Board-Edit-Modus das Kontextmenü. Ursache war ein
Timer-Leak: `pointerdown` feuert je Finger, der Long-Press-Timer `_lpT` wurde vom zweiten Finger
**überschrieben ohne `clearTimeout`** → der Timer des ersten Fingers blieb scharf und öffnete nach
500 ms das Menü. Zusätzlich fehlte `pointercancel`, und die 8-px-Bewegungsschwelle verglich gegen die
Koordinaten des *zuletzt* aufgesetzten Fingers.

**Behoben (Lösung A):** Aktive Touch-Pointer werden in einem `Set` (`_lpTouches`) verfolgt.
- Long-Press startet **nur bei genau einem** Finger (`_lpTouches.size === 1`, zusätzlich `isPrimary`).
- Jeder **weitere** `pointerdown` bricht einen laufenden Long-Press sofort ab (Pinch erkannt).
- `_lpStop()` **vor** jedem `setTimeout` — kein Timer wird je überschrieben.
- `pointercancel` räumt wie `pointerup` (Browser hat die Geste übernommen).
- Bewegungsschwelle gegen den Startpunkt **desselben** Fingers (`_lpId`).

Der Rechtsklick am Desktop (`contextmenu`-Handler) und `boardEigeneGeste` (kein Menü auf Karten/Griffen)
bleiben unberührt. Verifiziert per Zustandsmaschine (10 Ereignisfolgen inkl. Kern-Leak-Test).
