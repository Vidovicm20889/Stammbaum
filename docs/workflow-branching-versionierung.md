# Arbeits-Workflow: Branch pro Änderung, Test-Freigabe, Versionierung

**Status:** verbindlich (ab v14.86). Gilt für JEDE Änderung am Repo — Frontend, SQL, Edge Functions, Doku.

## Zweck
Bis v14.86 wurde direkt auf `main` gearbeitet und gesammelt committet. Das macht einzelne Änderungen
schwer isoliert testbar und schwer zurückrollbar. Ab sofort: **eine Änderung = ein Branch = ein
lokaler Test = eine ausdrückliche Freigabe = ein Commit.**

---

## 1. Branch pro Änderung (verbindlich)

- **Jede** Änderung (Bug oder Story) wird auf einem **eigenen Branch** umgesetzt — nie direkt auf `main`.
- Branch wird **vor** der ersten Code-Änderung von aktuellem `main` abgezweigt.
- Namensschema:
  - `bugfix/<kurz-slug>` — z. B. `bugfix/kalender-jahr-1000`
  - `feature/<kurz-slug>` — z. B. `feature/board-modus-verschieben`
  - `docs/<kurz-slug>` — reine Doku-/Spec-Änderungen
- Ein Branch enthält **genau eine** fachliche Änderung. Fällt unterwegs ein unabhängiger Bug auf:
  eigener Branch, nicht mit anschieben.
- Branch wird nach dem Merge gelöscht.

## 2. Lokal testen — VOR jedem Commit (verbindlich)

Auf dem Branch wird **zuerst getestet**, dann erst gefragt. Der Test ist derselbe wie in der
Test-Pflicht der `CLAUDE.md` (Abschnitt „Dein Arbeitsablauf"), mindestens:

| Prüfung | Wann | Werkzeug |
|---|---|---|
| Inline-/Datei-JS syntaktisch fehlerfrei | bei JS-Änderungen | `node --check` bzw. Inline-Script-Check |
| i18n-Schlüsselparität (5 Sprachen) | bei Textänderungen | `node i18n_lint.js` |
| CSS-Klammerbilanz | bei CSS-Änderungen | Balance-Check |
| SQL idempotent + FK-Reihenfolge | bei `.sql` | Gegenlesen |
| Fachlogik mit echten Ein-/Grenzwerten | bei Parser/Berechnung | Node-Durchlauf |
| UX-/Mobile-Durchgang (Android + iOS, <480px) | bei UI | Code-Prüfung, real wo möglich |

**Ergebnis wird dem User kurz vorgestellt** (PASS/FAIL je Fall). Was nur am echten Gerät oder nach
Deploy final verifizierbar ist, wird als 🔬 gekennzeichnet.

**Schlägt ein Test fehl → kein Commit.** Fehler wird zuerst behoben.

## 3. Commit erst nach ausdrücklicher Freigabe (verbindlich)

- Nach erfolgreichem Test wird dem User das Ergebnis vorgelegt und **auf seine Freigabe gewartet**.
- **Ohne ein ausdrückliches „ja / commit / deploy" wird nicht committet und nicht gepusht.**
- „Test war grün" ist **keine** Freigabe. Auch nicht „sieht gut aus" ohne Commit-Auftrag.
- Erst mit Freigabe: Version-Bump (Abschnitt 4), Commit auf dem Branch, Merge nach `main`, Push.
- Es wird **nur der zur Aufgabe gehörende Hunk** gestaged — nie blind ganze Dateien
  (parallele WIP-Änderungen des Users bleiben unangetastet).

---

## 4. Versionierung

**Format:** `XX.XX` — z. B. `14.86`. Die beiden Nachkommastellen sind zwei getrennte Zähler:

```
   14   .   8      6
   ^^       ^      ^
 MAJOR   STORY   BUG
```

Gepflegt wird die Nummer an **einer** Stelle als Quelle der Wahrheit:
`<meta name="app-version" content="XX.XX">` in [stammbaum.html](../stammbaum.html) — und synchron
das `?v=XX.XX` an **allen** ausgelagerten Dateien (`stammbaum.css`, `i18n.js`, `pdf_export.js`,
`chat.js`). Commit-Message: `Version XX.XX - <Kurzbeschreibung>`.

### 4.1 BUG → letzte Stelle +1

```
14.86  →  14.87
```

Bei Überlauf (Bug-Stelle steht auf 9) trägt die Story-Stelle mit:

```
14.89  →  14.90
```

### 4.2 STORY → vorletzte Stelle +1, letzte Stelle auf 0

```
14.86  →  14.90        (nicht 14.96)
14.90  →  14.a0 ✗      Überlauf, siehe unten
```

Bei Überlauf (Story-Stelle steht auf 9) trägt MAJOR mit und der Nachkommateil wird zurückgesetzt:

```
14.96  →  15.00
```

### 4.3 MAJOR → erste zwei Stellen +1, Rest auf 00

Ausgelöst, sobald **mehr als 2 Storys ohne Deployment dazwischen** umgesetzt werden — also
**ab der 3. Story** seit dem letzten Deploy:

```
Deploy bei 14.80
  Story 1        →  14.90
  Story 2        →  15.00   (Story-Überlauf, s. 4.2)
  Story 3        →  16.00   (>2 Storys ohne Deploy)
```

Ohne Überlauf gelesen:

```
Deploy bei 14.20
  Story 1        →  14.30
  Story 2        →  14.40
  Story 3        →  15.00   (>2 Storys ohne Deploy)
```

Der Zähler „Storys seit letztem Deployment" wird bei **jedem** Deployment auf 0 zurückgesetzt.

### 4.4 Merksatz

| Anlass | Regel | Beispiel ab 14.86 |
|---|---|---|
| Bug | letzte +1 | 14.87 |
| Bug bei …x9 | Übertrag in Story-Stelle | 14.89 → 14.90 |
| Story | vorletzte +1, letzte = 0 | 14.90 |
| Story bei …9x | Übertrag in MAJOR, Rest = 00 | 14.96 → 15.00 |
| 3. Story ohne Deploy | MAJOR +1, Rest = 00 | 15.00 |

---

## 5. Bewusste Grenzen

- **Kein Pull-Request-Zwang.** Branch → lokaler Test → Freigabe → Merge nach `main` genügt;
  GitHub Pages deployt weiterhin von `main`.
- **Keine automatischen Merges/Pushes.** Auch ein grüner Test löst nichts aus (Abschnitt 3).
- **Kein Version-Bump auf dem Branch vor der Freigabe** — sonst kollidieren parallele Branches.
  Die Nummer wird erst im Freigabe-Schritt vergeben, nach dem tatsächlichen Stand von `main`.
- **Hotfix-Ausnahme gibt es nicht.** Auch dringende Fixes laufen über Branch + Test + Freigabe.
- Die Historie **vor** v14.86 folgt diesen Regeln nicht (Sammel-Commits auf `main`); der Stand
  bei v14.86 wurde einmalig als Abschluss-Commit auf `main` geschlossen, danach gilt diese Spec.
