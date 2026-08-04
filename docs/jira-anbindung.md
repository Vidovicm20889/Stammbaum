# Jira-Anbindung (Atlassian MCP) — Ticket-Abarbeitung durch Claude Code

## Zweck
Claude Code liest das Jira-Board des Projekts **FamilyRoots (Key: `FAMROOTS`)** direkt über den
**offiziellen Atlassian-MCP-Server**, übernimmt Vorgänge aus der Spalte „Zu erledigen" automatisch
in Bearbeitung, setzt sie um, dokumentiert das Ergebnis als Jira-Kommentar und schiebt sie nach
„Test". Kein Copy-&-Paste von Ticketinhalten mehr, kein manuelles Statuspflegen.

---

## Einrichtung (einmalig, pro Entwicklerrechner)

**1) MCP-Server registrieren** — im normalen Terminal (PowerShell), NICHT in Claude Code:
```powershell
claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp --scope user
```
- `--scope user` ist **verbindlich**: die Verbindung landet in `C:\Users\<user>\.claude.json`.
  Mit `--scope project` entstünde eine **`.mcp.json` im Repo**, die beim nächsten Commit
  mitginge — unerwünscht.
- Fallback (Legacy-SSE), falls der HTTP-Endpoint scheitert:
  `claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse --scope user`

**2) OAuth NUR im Terminal** — ⚠️ die wichtigste Stolperfalle:
Die **VSCode-Erweiterung kann den OAuth-Flow nicht ausführen** (`/mcp` dort kann nur
`reconnect|enable|disable`, die Ausgabe verweist selbst auf „Use `/mcp` in the terminal"). Also:
```powershell
cd C:\VidovicAi\Stammbaum-repo\Stammbaum-main
claude
```
Dann in dieser Terminal-Session `/mcp` → **atlassian** → **Authenticate** → Browser-Login →
Site `milanvidovic89.atlassian.net` wählen → Jira-Rechte bestätigen → `connected`.
Terminal-Session kann danach geschlossen werden (Token liegt global).

**3) In der VSCode-Session aktivieren:** `/mcp reconnect all`.
Reicht das nicht: `Strg+Shift+P` → **Developer: Reload Window** (hat in der Praxis den Ausschlag
gegeben — die Tools erschienen erst nach dem vollständigen Reload).

---

## Projekt- & Workflow-Daten (Stand der Einrichtung)

| | Wert |
|---|---|
| Site / cloudId | `milanvidovic89.atlassian.net` (funktioniert direkt als `cloudId`) |
| Projekt | `FAMROOTS` — „FamilyRoots" (Team-managed / `simplified: true`) |
| Board | https://milanvidovic89.atlassian.net/jira/software/projects/FAMROOTS/boards/1 |

⚠️ **Key-Wechsel am 22.07.2026: `SCRUM` → `FAMROOTS`.** Jira führt den alten Key als **Alias** weiter
— bestehende Vorgänge behalten ihre Nummer (`SCRUM-27` → `FAMROOTS-27`), alte Links und Keys leiten
weiter. **Historische Referenzen werden bewusst NICHT umgeschrieben:** die `SCRUM-n`-Nennungen in
Code-Kommentaren (`stammbaum.html`, `stammbaum.css`, `pdf_font.js`), in der CLAUDE.md, in den übrigen
`docs/`-Dateien und in der Commit-Historie bleiben stehen — sie dokumentieren den Stand zum jeweiligen
Zeitpunkt und bleiben über den Alias klickbar. Umgestellt wurden nur die **funktional wirksamen**
Stellen: die JQLs und Projekt-Angaben in den drei Agent-Dateien unter `.claude/agents/` sowie diese
Datei.

**Workflow-Spalten und Transition-IDs** (global, für alle Vorgangstypen):

| Status | Status-ID | Transition-ID |
|---|---|---|
| Backlog | 10000 | **`2`** ⚠️ (nicht `11` — s. u.) |
| Zu erledigen | 10001 | `21` |
| **In Bearbeitung** | 10002 | `31` |
| **Test** | 10003 | `41` |
| **Dokumentation** | **10180** | **`4`** |
| **Erledigt für Deployment** (bis 2026-08-04: „Bereit für Deployment") | **10108** | **`3`** |
| Erledigt | 10004 | `51` |

**Labels `-offen`** (Konvention seit 21.07./23.07.2026, um `frage-offen`/
`merge-offen` erweitert seit 2026-08-04): `frage-offen` (Rückfrage an den
Nutzer), `merge-offen` (Stand nicht auf `main`, betrifft FamilyRoots aktuell
nicht direkt, da `jira-dev` ohne Worktree im Hauptbaum arbeitet),
`review-offen` (Befund des `review-agent`, siehe Modus E), `test-offen`
(Befund des `test-agent`, siehe Modus F).

⚠️ **Spalte „Erledigt für Deployment" (nachgetragen 23.07.2026, umbenannt 2026-08-04):** Sie
existierte im Jira-Workflow bereits, war aber in keiner Doku und in keiner Agent-Datei erfasst.
Belegt per `getTransitionsForJiraIssue` an FAMROOTS-35: Status-ID **`10108`**, Transition-ID
**`3`**, `statusCategory` **„Zu erledigen" (blau-grau)** — die Kategorie ist also auch hier
**nicht** zum Filtern geeignet, immer über den **Status-Namen** gehen. Die Spalte trennt
„fertig geprüft und dokumentiert" von „live": `jira-dev` endet weiterhin in **„Test"**, seit
2026-08-04 laufen dort automatisch `review-agent` → `test-agent` → `doku-agent` (Modi E/F/G)
durch bis **„Erledigt für Deployment"**, und nur von dort holt der **`deploy-manager`**
(Modus D). Der Statusname wurde am 2026-08-04 von „Bereit für Deployment" auf „Erledigt für
Deployment" geändert (Angleichung an StockFlow) — **die Status-ID `10108` blieb dieselbe**, nur
JQL/Prosa, die den Namen wörtlich nennen, mussten nachgezogen werden.

⚠️ **Transition-ID-Falle (belegt am 22.07.2026):** Die Transition nach **Backlog** hat die ID **`2`**,
nicht `11`. Diese Tabelle nannte lange `11`; ein `createJiraIssue` mit `transition: { id: "11" }`
scheitert mit *„Die Workflow-Funktion mit der Aktions-ID '11' existiert nicht im Workflow"* — der
Vorgang wird zwar **angelegt**, bleibt aber im Standard-Status liegen (still, ohne Abbruch).
Aufgefallen beim Anlegen von SCRUM-32; die SCRUM-16-Umstellung von Modus B auf das Backlog wäre damit
wirkungslos geblieben. Die übrigen IDs (21/31/41/51) stimmen.
**Im Zweifel `getTransitionsForJiraIssue` fragen, statt dieser Tabelle zu vertrauen** — die IDs sind
workflowspezifisch und ändern sich, sobald der Workflow angefasst wird.

⚠️ **Namensfallen:**
- Die „In Arbeit"-Spalte heißt in diesem Board tatsächlich **„In Bearbeitung"**.
- Der Status **„Zu erledigen"** hat die `statusCategory` **„In Arbeit" (gelb)**, nicht „Zu erledigen"
  (blau) — die Kategorie ist also NICHT zum Filtern geeignet. Immer über den **Status-Namen** filtern.
- **Backlog ≠ Zu erledigen.** Modus A fasst Vorgänge im Backlog bewusst nicht an — dort ist
  ausschließlich **Modus C (Story-Refiner)** zuständig, und der ändert nur das Ticket, nie Code.

**JQL für den Durchlauf:**
```sql
project = FAMROOTS AND status = "Zu erledigen" ORDER BY rank ASC
```

---

## Reihenfolge = Priorität (verbindlich, ab 23.07.2026)

**Das Board ist nach Priorität sortiert: oben = wichtigste Aufgabe, unten = unwichtigste.**
Die Reihenfolge innerhalb einer Spalte (Jira-**Rank**) pflegt der Nutzer per Drag & Drop — sie ist
eine bewusste Entscheidung, keine zufällige Sortierung.

Daraus folgt für **alle** Modi (A Jira-Dev, C Story-Refiner, D Deploy-Manager) und für beide Loops:

1. **Immer von oben nehmen.** Der jeweils **oberste** Vorgang der Spalte wird zuerst bearbeitet —
   nie ein weiter unten stehender, weil er einfacher/schneller/interessanter wirkt.
2. **Jede JQL endet auf `ORDER BY rank ASC`** — das ist genau die Board-Reihenfolge von oben nach
   unten. Ohne diese Klausel liefert Jira eine beliebige Reihenfolge, und die Priorität geht
   verloren.
3. **Nicht selbst umsortieren.** Rank/Board-Reihenfolge ändert ausschließlich der Nutzer; Claude
   kann das ohnehin nicht (Agile-API fehlt, siehe „Bewusste Grenzen").
4. **Überspringen nur mit Grund und Ansage.** Ein oberster Vorgang darf nur übersprungen werden,
   wenn er blockiert ist (unklar → Rückfrage als Jira-Kommentar; Code-Kollision mit einem Vorgang
   in „In Bearbeitung"/„Test"; bereits von einem anderen Agenten beansprucht). Das wird dem Nutzer
   **ausdrücklich gemeldet** („FAMROOTS-x übersprungen, weil …, stattdessen FAMROOTS-y") — nie
   still weitergehen.
5. **Das Feld `priority`** am Vorgang (Highest…Lowest) ist zusätzliche Information, ersetzt die
   Board-Reihenfolge aber **nicht**. Bei Widerspruch gilt die **Position von oben nach unten**.
6. **Modus D** deployt ohnehin die **ganze** Spalte „Erledigt für Deployment" — dort bestimmt die
   Reihenfolge nur, in welcher Folge Review/Doku/Release-Einträge abgearbeitet werden, nicht die
   Auswahl.

---

## Arbeitsablauf je Vorgang (verbindlich)

Pro Durchlauf wird **maximal EIN** Vorgang bearbeitet; danach kurze Zusammenfassung an den Nutzer,
erst dann der nächste.

1. **Lesen** — Titel, Typ, Priorität, Beschreibung, Akzeptanzkriterien.
2. **Status → „In Bearbeitung"** (Transition `31`).
3. **Unklar/mehrdeutig? → NICHT raten.** Stattdessen Rückfrage als **Jira-Kommentar** ans Ticket,
   Status bleibt auf **„Zu erledigen"**, weiter zum nächsten Vorgang.
4. **Ideen/Prompt ausarbeiten** und dem Nutzer vorstellen (CLAUDE.md-Ideenphase).
5. **Umsetzen** nach bestehender Projektstruktur und allen CLAUDE.md-Regeln
   (i18n in 5 Sprachen, RLS, Mobile, referenzielle Integrität …).
6. **Testen** gemäß TEST-PFLICHT: `node --check` (Hauptskript + i18n.js), `node i18n_lint.js`,
   ausführbare Logik-Testfälle; Ergebnis mit PASS/FAIL vorstellen.
7. **Jira-Kommentar** mit dem, was gemacht wurde (inkl. Testergebnis).
8. **Status → „Test"** (Transition `41`) — der Nutzer reviewt dort. **Dort endet Modus A**:
   kein Merge, kein Push, kein Version-Bump, keine Confluence-Pflege (seit 23.07.2026 alles
   beim **Deploy-Agent**, Modus D).

**Betroffene Vorgangstypen:** Stories und Bugs. Tasks nur nach ausdrücklicher Ansage.

---

## Mehr-Agenten-Betrieb — Vorgänge beanspruchen (verbindlich)

Am Projekt arbeiten mehrere Agenten: **Story-Ersteller** (Modus B), **Rafiner** (verfeinert
Vorgänge) und **DEV** (Modus A, setzt um). Alle schreiben in **denselben Working Tree** und
committen nicht zwischendurch → eine doppelt übernommene Aufgabe bedeutet doppelte Arbeit an
denselben uncommitteten Dateien.

**Regel: „Zu erledigen" heißt frei — und nur dort wird zugegriffen.**

1. **Beanspruchen durch Statuswechsel.** Wer einen Vorgang übernimmt, zieht ihn **sofort** auf
   **„In Bearbeitung"** (Transition `31`) — **bevor** die erste Datei geändert wird. Damit
   verschwindet er aus der JQL der anderen Agenten. Ein Vorgang, an dem gearbeitet wird und der
   auf „Zu erledigen" stehen bleibt, ist für die anderen **nicht** als belegt erkennbar.
2. **DEV greift ausschließlich auf `status = "Zu erledigen"` zu.** Backlog, In Bearbeitung, Test
   und Erledigt bleiben unangetastet — auch wenn ein Vorgang inhaltlich passt.
3. **Weitere Belegt-Signale respektieren:** gesetzter `assignee`, ein Kommentar eines anderen
   Agenten, der den Vorgang beansprucht, oder ein entsprechendes Label. Im Zweifel **nicht**
   übernehmen, sondern beim Nutzer nachfragen.
4. **Claim direkt vor dem ersten Edit gegenprüfen:** Status erneut lesen; steht er nicht mehr auf
   „Zu erledigen", war jemand schneller → abbrechen.
5. **Code-Überlappung prüfen:** Fasst ein Vorgang in „In Bearbeitung"/„Test" dieselben Funktionen
   oder Dateien an, wird **nicht** parallel daran gearbeitet — der Nutzer entscheidet die
   Reihenfolge. (Praxisfall: SCRUM-8 und SCRUM-6 ändern beide `boardBerechnePositionen`.)
6. **Zurückgeben:** Kann ein übernommener Vorgang doch nicht umgesetzt werden (offener
   Entscheidungspunkt, Kollision), geht er mit erklärendem Kommentar zurück auf **„Zu erledigen"**
   (Transition `21`) — nicht stillschweigend in „In Bearbeitung" liegen lassen.

⚠️ Ohne Punkt 1 ist die Trennung **nicht durchsetzbar**: Statusfeld und Kommentare sind das
einzige Signal, das Agenten voneinander sehen. Mündliche Zurufe des Nutzers („daran arbeitet ein
anderer") erreichen die übrigen Agenten nicht.

---

## Automatischer Durchlauf (Loop)

Claude schaut **selbstständig regelmäßig** in Jira und übernimmt Aufgaben, ohne dass der Nutzer
jedes Mal anstoßen muss. Eingerichtet über die eingebaute Loop-Mechanik:

```
/loop Prüfe das Jira-Projekt FAMROOTS … (voller Auftragstext, siehe unten)
```

**Modus:** **dynamisch/selbst-getaktet** (bewusst *ohne* festes Intervall) — passend zu
„sobald der Agent frei ist, schaut er nach".

**Takt:** ~**30 Minuten** (1800 s) im Leerlauf. Begründung: Tickets entstehen im menschlichen
Tempo; häufigeres Pollen erzeugt nur Kosten ohne Nutzen.

**Warum kein `Monitor` als Wecker:** Ein neues Jira-Ticket ist ein **entfernter** Zustand.
`Monitor` kann nur Shell-Befehle beobachten; der Jira-Zugriff läuft über die MCP-OAuth-Schicht und
ist per Shell nicht erreichbar. Deshalb **zeitbasiertes** Pacing statt Ereignis-Trigger.

**Ablauf je Aufwachen:**
1. JQL `project = FAMROOTS AND status = "Zu erledigen" ORDER BY rank ASC`
2. Treffer → **genau EINEN** (obersten) nach dem Ablauf oben abarbeiten → Zusammenfassung an den Nutzer
3. Kein Treffer → **kurze Rückfrage an den Nutzer** nach neuen Aufgaben
4. Neuen Weckruf setzen (oder bei „stopp" beenden)

**Steuerung durch den Nutzer:** „**stopp**" beendet den Loop; „**weiter**"/erneutes `/loop` startet ihn.

⚠️ **Lebensdauer:** Der Loop läuft **nur, solange die Claude-Code-Session offen ist**. Wird VSCode
geschlossen, stoppt er und muss neu gestartet werden.

### Refinement-Loop (Modus C)

Der Story-Refiner läuft nach demselben Muster über die **Backlog**-Spalte:

```
/loop Prüfe Jira FAMROOTS auf Backlog-Storys und starte den Agent story-refiner …
```

- **Modus:** dynamisch/selbst-getaktet, **Takt ~30 Minuten** (1800 s) im Leerlauf — gleiche
  Begründung wie oben (Tickets entstehen im menschlichen Tempo).
- **Ablauf je Aufwachen:** JQL `project = FAMROOTS AND status = "Backlog" AND issuetype = Story
  ORDER BY rank ASC` → Treffer: Agent `story-refiner` für **genau EINE** Story starten →
  Ergebnis dem Nutzer melden. Kein Treffer: **still weiterschlafen** (keine Rückfrage — sonst
  meldet sich der Loop bei leerem Backlog alle 30 Minuten grundlos).
- **Rückfrage-Fall:** Liefert der Refiner `status: rueckfrage`, werden die offenen Fragen dem
  Nutzer vorgelegt und die Story **bleibt im Backlog** — der Loop versucht sie beim nächsten
  Aufwachen **nicht** erneut, sondern überspringt sie, bis der Nutzer geantwortet hat.
- **Übergabe bleibt manuell:** Der Loop startet **nie** selbstständig `jira-dev` — er schlägt
  den Start nur vor (Kontrollpunkt aus Modus C, siehe unten).

⚠️ **Refinement-Loop + Umsetzungs-Loop parallel:** Beide dürfen gleichzeitig laufen (Refiner
fasst nur Backlog an, DEV nur „Zu erledigen" — siehe „Mehr-Agenten-Betrieb"). **Aber:** Sobald der
Refiner eine Story nach „Zu erledigen" schiebt, zieht ein laufender DEV-Loop sie beim nächsten
Aufwachen automatisch in Bearbeitung — der Kontrollpunkt zwischen Verfeinerung und Umsetzung
entfällt dann faktisch. Wer vor jeder Umsetzung selbst draufschauen will, lässt **nur den
Refinement-Loop** laufen.

---

## Modus B — „Story-Autor" (Idee ➜ Jira-Vorgang ➜ Dev-Agent)

Zweiter, bewusst getrennter Arbeitsmodus (seit 21.07.2026). Der Nutzer gibt eine **Idee** oder
meldet ein **Fehlverhalten** in beliebiger Form; Claude schreibt daraus einen **fertigen
Jira-Vorgang** — **und ändert dabei selbst KEINE Zeile Code**.

**Als Agent hinterlegt:** `.claude/agents/story-autor.md` (Rolle, Grenzen, Ticket-Struktur,
Übergabe). Nachbarn: `story-refiner` (verfeinert **vorhandene** Backlog-Storys) und `jira-dev`
(**setzt um**). Der Story-Autor legt **neue** Vorgänge an.

**Abgrenzung zu Modus A:** Modus A (oben) holt Tickets aus „Zu erledigen" und setzt sie um.
Modus B erzeugt Tickets — und **stößt Modus A danach selbst an** (siehe „Übergabe an den
Dev-Agent").

### Vorgangstypen
| Fall | Typ | ID |
|---|---|---|
| Neues/geändertes Verhalten | **Story** | 10004 |
| Kaputtes Verhalten | **Bug** | 10006 |

⚠️ Der Typ **Bug wurde am 21.07.2026 nachträglich angelegt** — vorher gab es im Projekt nur
Epic/Story/Task/Sub-Task. Bei einem frisch aufgesetzten Projekt zuerst prüfen
(`getJiraProjectIssueTypesMetadata`), sonst schlägt `createJiraIssue` mit unbekanntem Typ fehl.

### Zielstatus — **Backlog** (geändert 21.07.2026, SCRUM-16)
Neue Vorgänge landen im **Backlog** (Transition `2`), **nicht** in „Zu erledigen".

**Warum:** „Zu erledigen" ist genau die Spalte, die der Umsetzungs-Loop (Modus A) automatisch
abarbeitet. Legte Modus B dort an, griffe ein laufender Loop den frisch geschriebenen Vorgang
**sofort** ab und setzte ihn um — obwohl Modus B ausdrücklich nur schreiben soll. Der einzige
Schutz davor war bis dahin eine **Verhaltensregel für den Menschen** („Loop stoppen"), die genau
dann versagt, wenn man sie am nötigsten braucht (vergessener Loop in einer anderen VSCode-Session).

Das Backlog ist die **bereits bestehende, dokumentierte Grenze**, die Modus A per Definition nie
überschreitet (siehe „Backlog ≠ Zu erledigen" oben). Der Schutz kommt damit aus der **Struktur**,
nicht aus einer Regel, an die sich alle erinnern müssen — und kostet **null** Jira-Konfiguration.

**Freigabe = Refiner-Pflichtstufe (verbindlich seit FAMROOTS-38):** Eine vom Story-Autor angelegte
Story ist im Backlog eine **Rohstory** und gelangt **ausschließlich über den Story-Refiner**
(Modus C) nach „Zu erledigen". Der frühere Shortcut „der Nutzer zieht sie selbst direkt nach
‚Zu erledigen'" gilt für **Story-Autor-Storys nicht mehr** — jede muss zuvor vom Refiner geprüft,
am Repo belegt und umsetzungsreif ergänzt werden. Erst danach darf Modus A sie übernehmen.
(Für bereits ausgearbeitete Vorgänge, die **nicht** vom Story-Autor stammen, kann der Nutzer
weiterhin selbst nach „Zu erledigen" freigeben.)

*Verworfen:* Label `neu-ungeprueft` + JQL-Ausschluss (Schutz hängt daran, dass **jeder** Schreibpfad
das Label setzt und **jede** JQL es ausschließt → dieselbe Fehlerklasse, nur schwerer zu bemerken);
eigene Spalte „Bereit" (Workflow-Änderung im Projekt, neue Status-/Transition-IDs, höchster Aufwand
für einen Nutzen, den das Backlog mit vorhandenen Mitteln erreicht).

⚠️ **Board-Zugehörigkeit ist NICHT der Status** (Erkenntnis 21.07.2026): In einem team-managed
Kanban-Projekt mit aktivem **Backlog** ist „liegt auf dem Board" eine **eigene, vom Status
unabhängige** Eigenschaft. Per API erstellte Vorgänge landen dann **immer** zuerst im Backlog —
auch mit korrektem Status `Zu erledigen`. Atlassian dazu: *„If it's enabled, all issues you create
end up there, and there's no configuration or settings you can apply to change that behaviour."*
Es gibt **kein** Sprint-/Board-Feld in der Create-/Edit-Metadata (geprüft für Typ `Bug`/10006), und
der MCP-Server bietet die Agile-API (`/rest/agile/1.0/board/{id}/issue`) nicht an → **Claude kann
einen Vorgang nicht aufs Board schieben.**

**Lösung (umgesetzt 21.07.2026): Backlog-Ansicht im Projekt entfernt.** Damit liegen alle Vorgänge
direkt auf dem Board in der Spalte ihres Status — neu erstellte erscheinen sofort in „Zu erledigen".
Geschaltet wird das **nicht** unter *Bereichseinstellungen → Funktionen* (dort gibt es den Schalter
in der neuen „Bereiche"-Oberfläche nicht mehr), sondern über die **Ansichten-Leiste**
(`Backlog | Board | Entwicklung | …`): Tab-Kontextmenü → Ansicht aus der Navigation entfernen
(Hinzufügen umgekehrt über `+` → *Backlog*). Beim Entfernen wandern vorhandene Backlog-Vorgänge
automatisch in die Spalte ihres Status. Zum Parken von „später mal" bleibt der **Status „Backlog"**
(10000, Transition `2`) als Board-Spalte erhalten. *Sprints* braucht laut Jira einen Backlog und
ist in diesem Projekt bewusst aus.

✅ **Seit SCRUM-16 (21.07.2026):** Modus B legt hier **nicht** mehr an, sondern im **Backlog** —
genau weil „Zu erledigen" die Spalte ist, die Modus A abarbeitet. Der frühere Zusatz („gewollt, der
Story-Autor startet `jira-dev` selbst") ist damit hinfällig. Ein **parallel laufender `/loop`** ist
für Modus B jetzt ungefährlich; er bleibt nur beim **Refiner** (Modus C) ein Thema, weil dieser
weiterhin nach „Zu erledigen" schiebt.

### Aufbau jedes Vorgangs (verbindlich)
1. **Titel** — knapp, ergebnisorientiert (kein „irgendwas geht nicht").
2. **Ziel / Problem** aus Nutzersicht.
3. **Ist-Zustand MIT Code-Bezug** — vor dem Schreiben im Repo nachsehen und **konkrete Funktionen,
   Dateien und Zeilennummern** nennen. **Nicht aus dem Gedächtnis raten.**
4. **Lösungsvorschlag** inkl. Alternativen und begründeter Empfehlung.
5. **Betroffene Komponenten** — Frontend (`stammbaum.html`), `stammbaum.css`, `i18n.js`,
   SQL/RPC/RLS, Storage, Realtime.
6. **Akzeptanzkriterien** — prüfbar formuliert, nicht „funktioniert gut".
7. **Testplan** — was per `node --check` / `node i18n_lint.js` / ausführbarem Logiktest prüfbar ist
   und was nur 🔬 am Gerät verifizierbar bleibt.
8. **CLAUDE.md-Auflagen**, die für diese Umsetzung gelten (i18n in ALLEN 5 Sprachen, Mobile ≥16px +
   Touch, RLS rekursionsfrei/SECURITY DEFINER, referenzielle Integrität, keine nativen Browser-
   Dialoge, keine neuen Libraries ohne Freigabe, Branch + Test vor Commit).
9. **Risiken / bewusste Grenzen**.

### Regeln
- **Unklare Idee → VORHER beim Nutzer nachfragen**, nicht raten und nicht „halb" anlegen.
  (Die Rückfrage-per-Jira-Kommentar-Regel aus Modus A greift hier nicht — der Vorgang existiert ja
  noch nicht.)
- **Ein Vorgang je Idee.** Zerfällt eine Idee klar in mehrere unabhängige Ergebnisse, schlägt Claude
  die Aufteilung vor und lässt den Nutzer entscheiden.
- Nach dem Anlegen: **Key + Link** an den Nutzer zurückmelden.
- **Kein Code, keine Commits** durch den Story-Autor selbst; keine Statuswechsel an **fremden**
  Vorgängen.

### Übergabe an den Dev-Agent — **entfällt** (SCRUM-16, 21.07.2026)
Der Story-Autor startet **keinen** Dev-Agent mehr. Er endet mit dem angelegten Vorgang im
**Backlog** und meldet **Key + Link** zurück. Punkt.

*Zuvor* (Entscheidung vom selben Tag, wieder zurückgenommen): Nach dem Anlegen startete er selbst
`jira-dev` mit dem neuen Key, die Umsetzung begann ohne weiteren Anstoß. Das widersprach dem Zweck
von Modus B („nur schreiben") und nahm dem Nutzer den Kontrollpunkt — der Vorgang war umgesetzt,
bevor er die Beschreibung gelesen hatte.

**Wer die Umsetzung startet:** ausschließlich der Nutzer — indem er den Vorgang nach
„Zu erledigen" zieht (ggf. nach dem Refiner-Lauf) und `jira-dev` startet.

**Unverändert gültig:** Commit/Merge/Push bleiben freigabepflichtig; die Regeln aus
`docs/workflow-branching-versionierung.md` gelten unabhängig davon.

✅ **Seit SCRUM-16 (21.07.2026) aufgehoben.** Diese Stelle beschrieb den früheren Zustand: Modus B
legte in „Zu erledigen" an und startete `jira-dev` selbst → der Vorgang wurde umgesetzt, **bevor**
der Nutzer die Beschreibung gelesen hatte. Der ursprüngliche Modus-B-Zweck „nur schreiben, Nutzer
reviewt zuerst" ist damit **wiederhergestellt**: Modus B endet im **Backlog** und startet nichts.
Die Regel „Unklare Idee → VORHER nachfragen" bleibt trotzdem gültig — sie spart eine Runde, auch
wenn eine falsch verstandene Idee jetzt nicht mehr ungefragt gebaut wird.

## Modus C — „Story-Refiner" (Backlog ausarbeiten ➜ „Zu erledigen")

Dritter Arbeitsmodus (seit 21.07.2026). Agent-Datei: **`.claude/agents/story-refiner.md`**.
Er nimmt **eine** Story aus der Spalte **Backlog**, analysiert sie, belegt den Ist-Zustand im
Repo, schreibt sie **auf Deutsch** umsetzungsreif fertig und schiebt sie nach **„Zu erledigen"**
(Transition `21`). Den Dev-Agent startet er **nicht** — dort entscheidet der Nutzer (s. u.).

**Der Refiner ist die verbindliche Qualitätsstufe für Story-Autor-Storys (FAMROOTS-38):** Jede vom
Story-Autor (Modus B) im Backlog angelegte Rohstory MUSS diese Stufe durchlaufen, bevor sie umgesetzt
wird — sie ist der einzige zulässige Weg vom Backlog nach „Zu erledigen" für solche Storys.

**Abgrenzung der sieben Modi:**
| Modus | Agent | Quelle | Ergebnis | Ändert Code? | Startet danach |
|---|---|---|---|---|---|
| **B** Story-Autor | `story-autor` | Idee des Nutzers | neuer Vorgang im **Backlog** | nein | **nichts** — der Nutzer gibt frei |
| **C** Story-Refiner | `story-refiner` | Spalte **Backlog** | fertige Story in „Zu erledigen" | **nein** | Vorschlag an den Nutzer |
| **A** Jira-Dev | `jira-dev` | Spalte „Zu erledigen" | Umsetzung, Vorgang in „Test" | ja | Vorschlag: `review-agent` |
| **E** Review-Agent | `review-agent` | Spalte „Test" | Code-Review, bleibt in „Test" oder zurück „In Bearbeitung" (`review-offen`) | nein | Vorschlag: `test-agent` |
| **F** Test-Agent | `test-agent` | Spalte „Test" (ohne `review-offen`) | Klicktest, „Dokumentation" oder zurück „In Bearbeitung" (`test-offen`) | nein | Vorschlag: `doku-agent` |
| **G** Doku-Agent | `doku-agent` | Spalte „Dokumentation" | Confluence-Fachdoku, „Erledigt für Deployment" | nein | — |
| **D** Deploy-Manager | `deploy-manager` | Spalte **„Erledigt für Deployment"** | Release live, Vorgänge in „Erledigt" | nur Version/Doku/Kleinfix | — |

**Fluss:** `Idee → B → Backlog → C (PFLICHT: verfeinert) → Zu erledigen → A → Test → E (Review) →
F (Klicktest) → Dokumentation → G (Fachdoku) → Erledigt für Deployment → D → Erledigt/live`. Die
Refiner-Stufe **C ist für Story-Autor-Storys verbindlich** (FAMROOTS-38), nicht optional. **E, F
und G sind seit 2026-08-04 die neuen, automatisierten Stationen** anstelle der bisherigen
persönlichen Abnahme durch den Nutzer in „Test" — analog zum Schwesterprojekt StockFlow/
LedgerFlow (dortige Agenten `review-agent`/`test-agent`/`doku-agent`), inklusive der neuen Spalte
„Dokumentation" und der Umbenennung „Bereit für Deployment" → „Erledigt für Deployment" (beide
2026-08-04 am Board nachgezogen). Zwischen „geschrieben" und „wird umgesetzt" liegt weiterhin ein
menschlicher Freigabeschritt (Refiner → Nutzer entscheidet, ob `jira-dev` startet); zwischen
„dokumentiert" und „live" bleibt der Kontrollpunkt vor `deploy-manager` seit 23.07.2026
unverändert bestehen — **E, F und G starten sich nur gegenseitig per Vorschlag, nie automatisch,
und keines von beiden startet jemals den `deploy-manager`.**

⚠️ **Geändert am 21.07.2026 (SCRUM-16):** Zuvor legte der Story-Autor direkt in „Zu erledigen" an
**und startete `jira-dev` automatisch** — ein frisch geschriebenes Ticket konnte dadurch umgesetzt
werden, bevor der Nutzer es überhaupt gelesen hatte. Beides ist entfallen: Modus B endet mit dem
angelegten Vorgang im Backlog und meldet Key + Link zurück. **Weder B noch C starten den Dev-Agent
selbst** — das entscheidet ausschließlich der Nutzer.

**JQL:** `project = FAMROOTS AND status = "Backlog" AND issuetype = Story ORDER BY rank ASC`

### Regeln
- **Genau EIN Vorgang pro Durchlauf** (oberster nach Rank) — analog Modus A.
- **Kein Write/Edit-Zugriff** — die Agent-Definition erlaubt bewusst nur `Read`/`Grep`/`Glob`.
  Repo-Zugriff dient allein dem Beleg des Ist-Zustands (Datei + Funktion + **Zeilennummer**,
  nicht aus dem Gedächtnis geraten).
- **Alle Ergänzungen auf Deutsch**, auch bei anderssprachigem Original.
- **Originaltext bleibt erhalten** unter „## Ursprüngliche Anforderung (unverändert)".
- **Struktur der fertigen Beschreibung** = die 9 Abschnitte aus Modus B (Ziel, Ist-Zustand mit
  Code-Bezug, Soll, Lösungsvorschlag, betroffene Komponenten, Akzeptanzkriterien, Testplan,
  CLAUDE.md-Auflagen, Risiken).
- **Unklar → Abbruch statt Raten:** Beschreibung nicht überschreiben, Status nicht ändern,
  offene Fragen als entscheidbare Optionen im Abschlussbericht an den Hauptagenten, der sie dem
  Nutzer vorlegt. (Ein Subagent kann den Nutzer nicht selbst fragen.)
- **Kommentar-Präfix:** „**Automatisch verfeinert von Claude Code (Story-Refiner)**".

### Übergabe an den Dev-Agent
Gewählt wurde die **explizite Übergabe**: Der Refiner startet **selbst keinen** Dev-Agent, sondern
liefert `status: bereit` + Key + Zusammenfassung zurück; der Hauptagent schlägt dem Nutzer den
Start von **`jira-dev`** (`.claude/agents/jira-dev.md`) mit diesem Key vor. So liegt zwischen
Verfeinerung und Umsetzung ein Kontrollpunkt — der billigste Zeitpunkt, ein falsch verstandenes
Ticket zu korrigieren.

⚠️ **Kollision mit dem Modus-A-Loop — gilt NUR noch für Modus C:** „Zu erledigen" ist die Spalte,
die ein laufender Umsetzungs-Loop automatisch abarbeitet. Läuft er parallel, zieht er die frisch
verfeinerte Story sofort in Bearbeitung und der Kontrollpunkt entfällt. Beim Refinen also
**Modus-A-Loop stoppen**.

Für **Modus B besteht diese Gefahr seit SCRUM-16 nicht mehr** — er legt im Backlog an, das Modus A
per Definition nicht anfasst. Der Refiner ist damit die **einzige** verbleibende Stelle, an der ein
Vorgang ohne menschlichen Zwischenschritt in der Umsetzungs-Spalte landet. Das ist vertretbar, weil
der Refiner **gezielt** vom Nutzer gestartet wird (kein Hintergrund-Automatismus) — die verbleibende
Restgefahr ist ausschließlich der **parallel laufende Loop**.

---

## Modus E — „Review-Agent" („Test" ➜ „Test" bleibt oder „In Bearbeitung")

Fünfter Arbeitsmodus (seit 2026-08-04). Agent-Datei:
**`.claude/agents/review-agent.md`**. Er nimmt **einen** Vorgang aus der
Spalte **Test**, liest den (meist noch uncommitteten) Code-Stand mit
frischem Kontext gegen Akzeptanzkriterien, Familien-/Verbund-Isolation,
RLS-Rekursionsfreiheit, referenzielle Integrität, i18n (alle 5 Sprachen),
verbotene native Dialoge und Mobile-Markup (`docs/ui-bausteine.md` §8).
Ändert **keinen** Code.

**Warum es das gibt:** Bisher prüfte niemand außer dem Nutzer persönlich den
Code eines Vorgangs vor „Bereit für Deployment" — analog zu StockFlow/
LedgerFlow (dortige Lektion: der Umsetzende sieht seine eigene Begründungskette
nicht als Fehlerquelle).

**JQL:** `project = FAMROOTS AND status = "Test" ORDER BY rank ASC`
(Treffer mit Label `review-offen`, die schon einmal zurückgeschickt wurden,
überspringt der Agent selbst).

**Ohne Befund:** Vorgang bleibt in `Test`, der Agent schlägt dem Nutzer den
Start von `test-agent` vor (startet ihn nicht selbst).
**Mit schwerem Befund/Akzeptanzkriterium verletzt:** Label `review-offen`,
Transition nach `In Bearbeitung` (`31`), Zeile in
`.claude/agent-inbox/dev.md`.

## Modus F — „Test-Agent" („Test" ➜ „Dokumentation" oder „In Bearbeitung")

Sechster Arbeitsmodus (seit 2026-08-04). Agent-Datei:
**`.claude/agents/test-agent.md`**. Er nimmt **einen** Vorgang aus „Test",
auf dem `review-agent` keine Befunde hatte, und bedient die **laufende**
Anwendung im echten Browser (Playwright MCP) auf einem eigenen, dauerhaften
Test-Worktree (`C:/VidovicAi/WorkTreeFamilyRoots/FamilyRoots-test`) gegen
die eine bestehende lokale Supabase-Instanz — kein eigenes
Instanz-Pooling je Vorgang wie bei StockFlow (dafür ist FamilyRoots als
Ein-Entwickler-Projekt ohne parallele Story-Worktrees zu klein). Prüft
Akzeptanzkriterien per echtem Klickweg, Handy hoch/quer (< 480 px, kein
separates Tablet-Format), und greift die Familien-/Verbund-Isolation aktiv
an (eigene Fremdfamilie registrieren, fremde Daten-URL aufrufen).

**JQL:** `project = FAMROOTS AND status = "Test" ORDER BY rank ASC`, Treffer
mit Label `review-offen` werden übersprungen.

**Bestanden:** Transition nach `Dokumentation` (`4`) — der Vorgang liegt dort
für den `doku-agent` bereit (Vorschlag, kein Selbststart). **Durchgefallen:**
Label `test-offen`, Transition nach `In Bearbeitung` (`31`), Zeile in
`.claude/agent-inbox/dev.md`.

⚠️ **Kein Loop für E/F/G** — analog zur Begründung bei Modus D: Ein
zeitgesteuerter Review/Test/Doku würde faktisch denselben menschlichen
Kontrollpunkt entfernen, den die manuelle Vorschlags-Kette (A schlägt E vor,
E schlägt F vor, F schlägt G vor) bewusst erhält. Alle drei Modi starten
**nur** auf Kommando des Nutzers oder als Vorschlag, dem der Nutzer
zustimmt — nie automatisch.

## Modus G — „Doku-Agent" („Dokumentation" ➜ „Erledigt für Deployment")

Siebter Arbeitsmodus (seit 2026-08-04). Agent-Datei:
**`.claude/agents/doku-agent.md`**. Er nimmt **einen** Vorgang aus
„Dokumentation" (auf dem `test-agent` bestanden hat) und schreibt die
Fachdokumentation in Confluence, Space „FamilyRoots" (ID `589828`), unter
der Elternseite „App-Dokumentation" (`622594`) — **ausschließlich** dort;
„Testing"/„Releases" bleiben unverändert beim `deploy-manager`, dessen
release-übergreifende Regressionsprüfung etwas anderes leistet als eine
Einzelvorgang-Dokumentation. Ändert **keinen** Code, committet nichts.

**JQL:** `project = FAMROOTS AND status = "Dokumentation" ORDER BY rank ASC`.

**Abschluss:** Transition nach `Erledigt für Deployment` (`3`) — dort holt
ihn der `deploy-manager` ab (Start bleibt ausschließlich manuell). Fehlt ein
Nachweis (Review- oder Testergebnis als Jira-Kommentar): Vorgang bleibt in
`Dokumentation`, Label `frage-offen`.

---

## Modus D — „Deploy-Manager" („Erledigt für Deployment" ➜ live ➜ „Erledigt")

Vierter Arbeitsmodus (seit 23.07.2026, Quellspalte umbenannt 2026-08-04). Agent-Datei:
**`.claude/agents/deploy-manager.md`**. Er ist der **einzige** Agent, der deployen darf —
Modus A endet ausdrücklich in „Test", die Modi E/F/G liegen dazwischen.

**JQL:** `project = FAMROOTS AND status = "Erledigt für Deployment" ORDER BY rank ASC`

### Zuständigkeit
| | Modus A (`jira-dev`) | Modus D (`deploy-manager`) |
|---|---|---|
| Umsetzung | ✅ | ❌ (nur kleine, eindeutige Review-Korrekturen) |
| `docs/<feature>.md` im Repo | ✅ | ergänzt, wo beim Review nötig |
| **Confluence** (App-Doku, Testfälle, Testprotokoll, Release) | ❌ (seit 23.07.2026) | ✅ |
| Version-Bump (`app-version` + **alle** `?v=`) | ❌ | ✅ |
| Merge nach `main` + Push | ❌ | ✅ |
| Jira-Zielstatus | „Test" | „Erledigt" (Transition `51`) |

### Umfang eines Laufs
Anders als die Modi A–C arbeitet Modus D **nicht** ein einzelnes Ticket ab, sondern **alle**
Vorgänge der Spalte zusammen: ein Lauf = ein Release = **eine** Versionsnummer. Genau daraus
zieht der Modus seinen Wert — nur hier fällt auf, wenn **zwei** Tickets dieselbe Funktion
angefasst haben und sich gegenseitig aufheben. Ein `jira-dev`-Lauf kann das per Konstruktion
nicht sehen; er kennt nur sein eigenes Ticket.

### Ablauf (Kurzfassung, Details in der Agent-Datei)
1. Umfang aus der Spalte lesen (leer → Ende, nichts wird gepusht).
2. **Code-Review** über den gesamten Umfang, inkl. Wechselwirkungen zwischen den Tickets und
   der Akzeptanzkriterien jedes Vorgangs.
3. **Gesamttest der Anwendung** (nicht nur des Diffs): `node --check`, `node i18n_lint.js`,
   Verbotsmuster-Grep (`alert`/`confirm`/`prompt`), **Cache-Busting-Prüfung** (`app-version`
   == jedes `?v=`), Logik-Testfälle, SQL-Idempotenz, Regression über die Kernflüsse,
   Mobile Android + iOS. Ergebnis als PASS/FAIL-Matrix.
4. **Version** nach `docs/workflow-branching-versionierung.md` vergeben (Schema steht dort, wird
   nicht in der Agent-Datei dupliziert), `app-version` + **alle** `?v=` ziehen.
5. **Merge nach `main` + Push** → GitHub Pages ist damit live.
6. **Confluence**: App-Doku, Testfälle (`TF-<Bereich>-<Nr>`), Testprotokoll mit dem tatsächlichen
   Ergebnis — und eine **eigene Seite je Release** unter der Elternseite **„Releases"**
   („Release X.YZ – <Datum>": Ticketliste, Änderungen in Nutzersprache, Abnahmetest, manuelle
   Schritte, Risiken). Die Elternseite wird beim ersten Lauf angelegt, falls sie fehlt.
7. **Jira**: je Vorgang Kommentar mit Version/Commit/Release-Link, dann Status → **„Erledigt"**.

### Regeln
- **Start nur auf ausdrückliches Kommando des Nutzers.** Kein `/loop`, kein Start durch einen
  anderen Agenten, kein „läuft mal eben mit". Das ist die zentrale Vorgabe des Nutzers
  (23.07.2026) — der Deploy ist der einzige unumkehrbare Schritt der Kette.
- **Start = Freigabe** für Commit/Merge/Push/Version-Bump (Entscheidung des Nutzers vom
  23.07.2026). Eine zweite Rückfrage vor dem Push gibt es bewusst nicht; das Gegengewicht ist
  die **Abbruchpflicht** bei jedem roten Ergebnis.
- **Rot = kein Deploy.** Review-Finding größer als ein Kleinfix, FAIL in der Testmatrix,
  unklarer Merge-Konflikt, fremde untrennbare Änderungen im Working Tree, fehlende DB-Migration
  → abbrechen, nichts pushen, kein Statuswechsel, Bericht mit Grund.
- **Keine SQL-Ausführung, kein Edge-Function-Deploy** durch den Agenten (SQL-Editor bzw.
  Dashboard, Citrix-Firewall) — beides landet als ToDo beim Nutzer und im Release-Eintrag.
- Er fasst **nur** „Erledigt für Deployment" an; „Test"/„Dokumentation" bleiben unberührt, damit
  der Kontrollpunkt vor dem eigentlichen Deploy erhalten bleibt.

⚠️ **Kein Loop für Modus D** — bewusst. Ein zeitgesteuerter Deploy würde genau den menschlichen
Kontrollpunkt entfernen, für den die Spalte eingeführt wurde.

---

## Commit-Politik
Ob pro Ticket committet wird, ist **nicht** pauschal geregelt, sondern wird vom Nutzer je Phase
festgelegt. Hintergrund: Wenn parallel ein anderer Agent an denselben Dateien arbeitet
(`stammbaum.html` / `i18n.js` / `stammbaum.css`), würde ein Ticket-Commit dessen **unfertiges**
Feature mit ins Repo (und beim Push live) ziehen. Modi:
- **(a)** umsetzen, Jira pflegen, **nicht** committen → sammeln für einen gemeinsamen Deploy
- **(c)** pro Ticket committen, Commit-Message enthält den Jira-Key (z. B. `FAMROOTS-12: …`)

Vor Beginn einer Ticket-Serie **immer klären, welcher Modus gilt.**

---

## Genutzte MCP-Tools
`searchJiraIssuesUsingJql` · `getJiraIssue` · `getTransitionsForJiraIssue` ·
`transitionJiraIssue` · `addCommentToJiraIssue`
(weitere verfügbar: `createJiraIssue`, `editJiraIssue`, `getVisibleJiraProjects`,
`lookupJiraAccountId`, Confluence-Tools)

**Modus D zusätzlich (Confluence):** `getPagesInConfluenceSpace` · `getConfluencePage` ·
`getConfluencePageDescendants` · `createConfluencePage` · `updateConfluencePage`.

Schemas werden in Claude Code per `ToolSearch` nachgeladen:
`select:mcp__atlassian__searchJiraIssuesUsingJql,mcp__atlassian__transitionJiraIssue,…`

---

## Bewusste Grenzen
- **OAuth nur interaktiv** — in einer nicht-interaktiven Session kann Claude die Autorisierung
  nicht durchführen; sie muss vom Nutzer im Terminal erfolgen.
- **Neue Agent-Dateien greifen erst nach Session-Neustart** (Erkenntnis 21.07.2026): Claude Code
  liest `.claude/agents/` beim **Start** der Session. Eine frisch angelegte Datei ist als
  `subagent_type` noch **nicht** wählbar (`Agent type '…' not found`) — erst nach
  `Strg+Shift+P` → *Developer: Reload Window* bzw. neuem Terminal-Start. Notbehelf bis dahin:
  generischen Agenten starten und ihn die Definitionsdatei selbst einlesen lassen. ⚠️ Dabei
  greift die **`tools:`-Whitelist der Definition nicht** — die „ändert keinen Code"-Grenze des
  Refiners steht dann nur im Prompt, nicht in der Sandbox.
- **Kommentare erscheinen unter dem Nutzerkonto** (`Milan Vidovic`), nicht unter einem Bot-Account.
  Deshalb beginnt jeder automatische Kommentar mit
  „**Automatisch bearbeitet von Claude Code (Atlassian MCP)**", damit die Herkunft erkennbar bleibt.
- **Keine Sprint-/Board-Verwaltung** (Sprints anlegen, Ranking ändern, Vorgang aufs Board schieben)
  — nur Status, Kommentare, Felder lesen. Der MCP-Server deckt die **Agile-API nicht** ab; Board-
  Zugehörigkeit ist deshalb für Claude **nicht setzbar** (siehe „Zielstatus" in Modus B). Konsequenz:
  Ein aktiver Backlog macht Modus B unbrauchbar, weil jedes neue Ticket dort versackt → Backlog-
  Ansicht bleibt im Projekt **deaktiviert**.
- Der Filter des **Umsetzungs**-Modus geht ausschließlich über die Spalte „Zu erledigen". Der
  Backlog wird ausschließlich von **Modus C** angefasst — schreibend nur an Beschreibung, Kommentar
  und Status, **nie** am Code.
- **Der Loop ist an die Session gebunden** (siehe oben) — es gibt **keine** dauerhafte
  Hintergrund-Automatik. Eine Cloud-Routine (`/schedule`) wäre sessionunabhängig, hätte dort aber
  **weder das lokale Repository noch die MCP-Autorisierung**: sie könnte Jira nur lesen/kommentieren,
  aber **keinen Code umsetzen und nicht testen**. Deshalb bewusst der Session-Loop.

---

## Nachweis der Inbetriebnahme
**SCRUM-1 „Testaufgabe" (Story)** — Anforderung: prüfen, ob Claude Code Zugriff hat und den Status
automatisch ändert. Durchlaufen am 21.07.2026:
Lesen ✓ → „Zu erledigen" → **„In Bearbeitung"** ✓ → Ergebnis-Kommentar ✓ → **„Test"** ✓.
Lese-, Schreib- und Transition-Zugriff damit bestätigt. (Kein Code geändert — der Vorgang war
ausdrücklich nur ein Zugriffstest.)
