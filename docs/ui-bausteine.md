# UI-Bausteine & Frontend-Konventionen

**Status:** verbindlich. Ausgelagert aus `CLAUDE.md` (Token-Entlastung) — der Regelrang ist
unverändert. Die Kurzform der Muss-Regeln steht weiterhin in `CLAUDE.md`; hier stehen die
Begründungen, Funktionsnamen und Details.

**Vor jeder UI-Änderung diese Datei lesen.**

---

## 1. Styleguide-Pflicht — KEINE nativen Browser-Dialoge (ab v14.34)

Jede UI eines neuen oder geänderten Features MUSS dem bestehenden App-Design entsprechen
(edel/dunkel/Serif/Gold, edle Overlays) — **niemals** die nativen Browser-Dialoge
`alert()` / `confirm()` / `prompt()`. Grund: sie zeigen „127.0.0.1 enthält …", brechen Optik,
i18n und Mobile.

Verbindliche Bausteine stattdessen:

| Zweck | Baustein |
|---|---|
| Reine Info/Fehler (nur OK) | `zeigeHinweis(text)` |
| Ja/Nein-Rückfrage | `zeigeBestaetigung(text, {gefahr, jaText})` → `Promise<boolean>` |
| Feldbezogener Validierungsfehler | `feldFehler(feldId, text)` (siehe §5) |
| Nebenläufige Rückmeldung | Toast / Status-Zeile |

Gleiches gilt für alle sichtbaren Elemente: bestehende CSS-Klassen/Muster wiederverwenden statt
Ad-hoc-Styles; i18n in allen 5 Sprachen; Mobile-/Touch-Regeln (≥16px, `pointerdown`, `overscroll`).

**Prüfung vor jedem Commit:**
```
grep -nE "\bconfirm\(|[^.\w]alert\(|\bprompt\(" stammbaum.html chat.js pdf_export.js
```
muss **leer** sein.

## 2. Overlays/Modals schließen NUR per Button (ab v9.2)

Jedes Voll-Overlay (`.modal`) wird ausschließlich über seinen Schließen-Button (× / „Abbrechen")
bzw. die zugehörige `schliesse…()`-Funktion geschlossen — **NICHT** durch Klick auf den
Hintergrund/daneben.

- KEIN `onclick="schliesse…()"` auf dem `.modal`-Backdrop.
- KEIN generischer Außenklick-/`pointerdown`-Schließer für Modals.
- Gilt **NICHT** für kleine Dropdown-/Such-/Presence-Panels — die schließen weiterhin per
  `pointerdown` außerhalb (siehe §3).

## 3. Dropdowns (suchbare Selects)

Jedes `<select>` wird automatisch zu einem suchbaren Dropdown (`macheAlleSelectsSuchbar` / `init`).
Nach dynamischem Befüllen in einem Overlay ggf. `macheAlleSelectsSuchbar(overlay)` aufrufen.

**Touch-sicher (Android/iOS) — nicht zurückbauen:**
- Außerhalb-Schließen über `pointerdown` (**nicht** `click` — sonst schließt der Ghost-Click sofort).
- Auswahl in scrollbaren Listen über `tippAuswahl` (Tap selektiert, Wischen scrollt).
- `resize`/`scroll` schließen Panels **nicht**, sondern positionieren neu
  (mobile Tastatur = Resize-Event).

## 4. Datumsfelder

`<input class="login-feld dp-input">` → eigener Vanilla-Kalender. Werte über
`datumWert` / `datumSetzen`, Anzeige über `formatDatumLang`. Speicherung kanonisch als ISO
`YYYY-MM-DD` (siehe Backend-/Daten-Regeln in `CLAUDE.md`).

**Kurz-/Eingabeformat = REIHENFOLGE-Präferenz (ab v14.30, kontogebunden):**
- Eigene Nutzer-Einstellung `datumsFormat` ∈ { `tmj` = Tag zuerst (Standard) / `mtj` = Monat zuerst }.
- Gespeichert in `profile.einstellungen.datumsformat` (+ localStorage `vidovic_datumsformat`).
- Im Profil-Overlay wählbar (`fuelleProfilDatumsformat` / `setzeDatumsFormat`, instant via `onchange`).
- Die Reihenfolge ist **von der Sprache ENTKOPPELT**. Bugfix-Hintergrund: früher zwang `en` das
  US-`MM/DD` auf, das der Parser nicht verstand → Eingaben wurden abgelehnt.
- Das **Trennzeichen** bleibt sprachüblich (`datumTrenner`: `en` → `/`, sonst `.`),
  Platzhalter über `datumPlatzhalter`.

**Parser `parseDatumZuIso` ist ordnungs- UND fehlertolerant:**
- akzeptiert ISO, `.` / `/` / `-` und **trennerlos** (8 Ziffern, z. B. `01011999`);
- `dpAusPaar` deutet die Reihenfolge per Präferenz, erkennt aber **automatisch** den Tag,
  wenn eine Position > 12 ist.

Umschalten/Sprachwechsel rendert alle offenen Felder neu (`aktualisiereDatumsfelder`).
i18n-Schlüssel `prof_datumsformat` / `prof_df_*` in allen 5 Blöcken.

## 5. Pflichtfelder & Feld-Fehler (app-weit, ab v11)

- Jedes Pflichtfeld bekommt am Label die Klasse **`.pflicht`** → rotes „ *" hinter der Beschriftung
  (rein per CSS, sprachneutral — KEINE hartcodierten `*` mehr). Dynamisch umschaltbar über
  `pflichtMarkierung` (z. B. Mädchenname nur bei `geschlecht='F'`).
- **Validierungsfehler werden DIREKT am Feld angezeigt**, nicht (nur) unten im Overlay:
  `feldFehler(feldId, t('…'))` setzt roten Rahmen (`.input-fehler`) + Hinweis (`.feld-fehler-text`)
  unter das Feld, **scrollt es in den Blick und fokussiert** es. Der Helfer gibt `false` zurück
  → Muster: `return feldFehler(...)`.
- Bei **searchable Selects** (`_ssControl`) wird automatisch das sichtbare Steuerelement
  markiert/fokussiert (nicht das `display:none`-`<select>`).
- `feldFokus(feldId)` = nur scrollen + fokussieren (wenn der Hinweis schon am Feld steht,
  z. B. E-Mail-Check `markiereEmailFehler`).
- `feldFehlerReset(overlayId)` am Anfang jeder Validierung **und** beim Öffnen aufräumen.
- Generische Meldung `feld_pflicht` in allen 5 Blöcken.

**Bewusste Ausnahmen:**
- **Reine Auswahl-/Picker-Overlays** (etn/dub/vb/gp/mv/uk: „mind. eine Person wählen") behalten
  bewusst die Sammel-Box — es gibt kein einzelnes Feld zum Anheften.
- **Server-/Zustandsfehler ohne Feldbezug** bleiben in der Box; feldbezogene Serverfehler
  (z. B. „Name existiert", „aktuelles Passwort falsch") werden ans Feld gehängt.

**Person-Editor:** Vorname + Nachname Pflicht; **Mädchenname Pflicht nur bei (ehemals)
verheirateten Frauen** (Beziehungsstatus verheiratet/getrennt/geschieden/verwitwet), bei
ledig/verlobt/Partnerschaft/unbekannt/sonstige optional (Voraussetzung für die Blutlinien-Kappung
bei verheirateten Frauen, siehe [baum-struktur-blutlinie.md](baum-struktur-blutlinie.md);
Entscheidung FAMROOTS-50, 28.07.2026 — vorher pauschal Pflicht bei jeder Frau).

## 6. Sprachwechsel

`wechselSprache` MUSS dynamisch gerenderte Inhalte/Dropdowns neu aufbauen — u. a.
Stammbaum-Dropdown, Orientierungs-Banner, offene Overlays (Mitglieder, Kosten, Obavještenja).
**Neue dynamische Listen dort einhängen** — sonst bleiben sie nach Sprachwechsel in der alten Sprache.

## 7. Session & Aktualität

- Auto-Logout nach 30 Min Inaktivität (Warnung 1 Min vorher).
- Nach Re-Login harter Reload (`hardReload` = `?v=timestamp`, umgeht den HTML-Cache).
- Update-Banner bei neuer `app-version`.
- Live-Reload behält den Fokus und setzt den Auto-Logout-Timer **nicht** zurück.

Diese Logik bei UI-Änderungen nicht brechen.

## 8. Mobile-/Geräte-Checkliste (Android + iOS, Pflicht bei jeder UI-Änderung)

- **Felder:** korrekter `type`/`inputmode` (Mobile-Tastatur), `autocomplete` sinnvoll;
  **iOS-Input-Zoom vermeiden** — fokussierbare Felder dürfen mobil NICHT < 16px sein (sonst zoomt
  iOS Safari rein und nicht zurück; die Regel am Ende des CSS gewinnt).
- **Touch/UX:** Tap-Targets groß genug; Schließen/Auswahl über `pointerdown`/`tippAuswahl`
  (nicht `click`); `overscroll-behavior: contain` auf scrollbaren Overlays (kein
  Hintergrund-Scroll-Durchgriff); offene Panels bei `resize`/`scroll` neu positionieren statt schließen.
- **Viewport/Layout:** Hoch- UND Querformat < 480px; keine `vh`-Falle/erzwungener Überlauf;
  fixe Elemente nicht von Notch/Tastatur verdeckt.
- **Funktional:** Flow mit Touch end-to-end; i18n in allen 5 Sprachen sichtbar.

Im Ergebnis benennen, was am Code geprüft wurde und was nur am echten Gerät verifizierbar ist (🔬).
