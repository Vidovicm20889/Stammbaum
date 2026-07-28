# Confluence-Pflege beim Deployment

**Status:** verbindlich (SCRUM-3; Zuständigkeit geändert am 23.07.2026). Ausgelagert aus
`CLAUDE.md` (Token-Entlastung) — Regelrang unverändert.

**Diese Datei ist Pflichtlektüre für den Deploy-Agenten** (`.claude/agents/deploy-manager.md`,
Modus D). Für alle anderen Agenten/Durchläufe irrelevant — genau deshalb steht sie nicht mehr
in der `CLAUDE.md`.

---

## Grundsatz

Das **Repo ist und bleibt die Quelle der Wahrheit**; Confluence ist die gespiegelte Lese-Ansicht
für Nicht-Entwickler.

Space **„FamilyRoots"** (Key `FamilyRoot`, ID `589828`) auf `milanvidovic89.atlassian.net/wiki`.

## Wer pflegt

Ausschließlich der **Deploy-Agent** im Zuge des Deployments.

Der Umsetzungs-Agent (`jira-dev`) pflegt weiterhin die `docs/<feature>.md` **im Repo**, fasst
Confluence aber **nicht** an — sonst stünde dort Dokumentation zu Änderungen, die noch gar nicht
live sind.

## Was beim Deployment zu pflegen ist

1. **App-Dokumentation** (Seite `App-Dokumentation`): betroffene Feature-Seite nachziehen, sobald
   sich Verhalten/Datenmodell/Grenzen geändert haben. Neues Feature → neue Unterseite
   (Spiegel der zugehörigen `docs/<feature>.md`).
2. **Testfälle** (Seite `Testing → Testfälle`): Soll-Verhalten je Feature/Bugfix ergänzen —
   ID-Schema `TF-<Bereich>-<Nr>`, prüfbar formuliert, mit Jira-Key.
3. **Testprotokoll** (Seite `Testing → Testprotokolle`): das TATSÄCHLICHE Testergebnis des
   Durchlaufs mit PASS/FAIL eintragen; Fehlschläge ehrlich protokollieren, 🔬-Punkte kennzeichnen.
4. **Release-Info** (Elternseite `Releases`, je Deploy eine eigene Unterseite
   „Release X.YZ – <Datum>"): Ticketliste, Änderungen in Nutzersprache, Abnahmetest-Ergebnis,
   manuelle Schritte (SQL/Edge Functions), Risiken.

## Reihenfolge

erst Code + Tests → dann Deploy → dann Confluence → dann Jira-Kommentar/Status.

## Wenn Confluence nicht erreichbar ist

403/fehlende Freigabe wird im **Jira-Kommentar ausdrücklich vermerkt** statt stillschweigend
übersprungen.
