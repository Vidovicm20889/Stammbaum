# Externe Libraries, Assets & CSP

**Status:** verbindlich. Ausgelagert aus `CLAUDE.md` (Token-Entlastung) — Regelrang unverändert.

**Grundregel (steht auch in `CLAUDE.md`): KEINE neuen externen Libraries/Dienste ohne
ausdrückliche Absprache.** Diese Datei listet, was freigegeben ist, wofür — und welche
CSP-/Betriebs-Auflagen daran hängen.

---

## 1. Freigegebene Abhängigkeiten

| Abhängigkeit | Bezug | Ausschließlich für |
|---|---|---|
| Supabase (Postgres/Auth/Storage/Edge Functions) | Dienst | Backend |
| Resend | Dienst | E-Mail-Versand |
| `@supabase/supabase-js@2` | CDN jsdelivr | Backend-Client |
| `d3.js` | CDN jsdelivr | Baum-Rendering |
| `jspdf` + `svg2pdf.js` | CDN jsdelivr, **lazy** | PDF-/Druck-Export |
| `marked` | CDN jsdelivr | Markdown der mehrsprachigen Lebensgeschichten |
| `leaflet@1.9.4` | CDN jsdelivr | Ereignis-/Migrationskarte |
| `Noto Serif` (Schrift-Subset) | **aus dem Repo** (`pdf_font.js`) | Vektor-PDF-Export |

Alle CDN-Bezüge: exakt **versions-gepinnt + SRI**, Quelle `cdn.jsdelivr.net`
(von der CSP `script-src` bereits abgedeckt).

Das Frontend bleibt **Vanilla** — kein Framework, kein Build-Tool in der Auslieferung.

## 2. Noto Serif (SCRUM-27, freigegeben am 21.07.2026)

- **Warum:** jsPDFs WinAnsi-Standardschriften können č/ć/š/ž/đ, Kyrillisch und `→` nicht.
- **Umfang:** Subset (Latin + Latin-Extended-A + Kyrillisch, Regular + Bold), Lizenz **SIL OFL 1.1**.
- **Auslieferung:** aus dem Repo als Base64-VFS in [pdf_font.js](../pdf_font.js) → **same-origin,
  deshalb KEINE CSP-Änderung**. Laden **lazy** über `ladePdfLib()`.
- **Subsetting läuft einmalig offline** (`pyftsubset`); nur das fertige Base64-Ergebnis wird
  committet — kein Build-Schritt beim Deploy. Anleitung im Kopf von `pdf_font.js`.
- ⚠️ `pdf_font.js` ist eine reine Base64-Datei (~354 KB) — **niemals am Stück lesen**.

## 3. Leaflet: zusätzliche CSP-Quellen

In [stammbaum.html](../stammbaum.html) bereits gesetzt — beim Anfassen der CSP nicht verlieren:

| Direktive | Quelle | Wofür |
|---|---|---|
| `style-src` | `cdn.jsdelivr.net` | `leaflet.css` |
| `img-src` | `*.tile.openstreetmap.org` | OSM-Kacheln |
| `connect-src` | `nominatim.openstreetmap.org` | Geocoding-`fetch` |

- **Karten-Tiles = OpenStreetMap, Geocoding = Nominatim — beide ohne API-Key** (passt zu GitHub Pages).
- Nominatim ist **rate-limit-gebunden** (max ~1 Anfrage/s) → Aufrufe IMMER debounced + Mindestabstand
  (siehe `geoSucheAusfuehren`).
- **Marker sind CSS-DivIcons** (kein externes Marker-Bild) → keine weitere `img-src`-Quelle nötig.
  **Nicht** auf Leaflets Standard-PNG-Icons zurückbauen.

## 4. Markdown-Ausgabe immer nachsäubern

`marked`-Output geht **nie ungefiltert** ins DOM. Nachgesäubert wird serverfrei mit
`geschCleanElement` (Whitelist-Sanitizer im Haupt-Script) — **kein** zweites Dependency
wie DOMPurify.
