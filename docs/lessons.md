# Lessons Learned — Fehler-/Lern-Log

Dauerhafte Sammlung **nicht-trivialer** Stolperfallen aus der Arbeit an FamilyRoots. Ziel:
**denselben Fehler nicht zweimal machen.** Gepflegt vom Umsetzungs-Agent im Rahmen des
Fehler-/Lern-Loops (siehe CLAUDE.md → „Dein Arbeitsablauf (Loop)" → „FEHLER-/LERN-LOOP bei Problemen").

## Nutzung
- **VOR** dem Angehen eines Problems in einem hier abgedeckten Bereich **zuerst diese Datei lesen**
  (Ctrl+F auf den Bereich/das Symptom), ob es schon eine Lehre gibt.
- **NACH** dem Lösen eines nicht-trivialen Problems einen neuen Eintrag ergänzen (neueste oben).
- **Nicht** protokollieren: triviale Fehler (Tippfehler, sofort offensichtlich). Nur echte Lehren,
  damit die Datei nützlich und kurz bleibt.

## Eintrags-Vorlage (kopieren)

```
### YYYY-MM-DD — <Kurztitel> [Bereich]
- **Symptom:** Was ist beobachtbar schiefgegangen (Fehlermeldung/Verhalten)?
- **Ursache:** Die tatsächliche Root Cause (nicht das Symptom).
- **Lösung:** Was konkret behoben hat (mit Datei/Funktion, wenn hilfreich).
- **Merksatz:** Eine Zeile, die den Fehler künftig vermeidet.
- **Sackgassen (optional):** Ansätze, die NICHT funktioniert haben — spart nächstes Mal Zeit.
```

Bereiche (Tags) zum Wiederfinden: `[PDF]` `[RLS]` `[Realtime]` `[Datum]` `[i18n]` `[Mobile/iOS]`
`[Storage]` `[Supabase/DB]` `[Build/Deploy]` `[UX]` — bei Bedarf erweitern.

---

## Einträge (neueste oben)

### 2026-07-25 — Ex-ohne-Kinder ins Auto-Diagramm: falscher Renderer + Layout-Bruch [UX]
- **Symptom/Ziel:** Ex-Partner (ohne gemeinsame Kinder) sollte auch im Auto-Diagramm („Automatsko
  ређанje") verbunden erscheinen (im Board via FAMROOTS-46 ok). Zwei Fehlversuche.
- **Fehlversuch 1 (wirkungslos):** Ausblendung `istExOhneKinder` in **`baueBaumDaten`** entfernt — keine
  Wirkung. **Ursache:** Es gibt ZWEI Auto-Renderer: Legacy `baueBaumDaten` und Graph `zeichneGraph2`.
  **`RENDERER_GRAPH_DEFAULT = true`** → live ist `zeichneGraph2` (baueBaumDaten nur bei Flag
  `vidovic_renderer_graph=0`). Änderung saß im inaktiven Renderer.
- **Fehlversuch 2 (bricht das Layout!):** `exOhneKinder`-Ausnahme im **`partners`-Index von
  `baueGraphModell`** entfernt (das speist `zeichneGraph2`). Ergebnis: Die Ehe-Linie erschien zwar, ABER
  ein bereits verpartnerter Bloodline-Knoten (Kind, das mit seinem echten Partner ein Kind hat)
  bekam den Ex als ZWEITEN Partner → in der Vorfahren-Paar-Logik verdrängte der Ex den echten
  Ko-Elternteil → **das Kind verschwand** aus dem Diagramm. Beide Versuche verworfen/zurückgesetzt.
- **Erkenntnis + Lösung (FAMROOTS-47):** Der Ausschluss von Ex-ohne-Kinder aus `model.partners` ist NICHT
  nur kosmetisch — er schützt die `zeichneGraph2`-Anordnung (Ko-Elternschaft/Rang/Vorfahren-Paar). Die
  tragfähige Lösung: ein **separater `nebenPartner`-Index** in `baueGraphModell` (getrennt von `partners`,
  berührt Struktur/Rang NICHT) + ein **Post-Layout-Pass** in `zeichneGraph2`, der den Ex neben die bereits
  platzierte Person setzt (freier Slot in derselben Reihe, `posByCanon`) und eine graue Ex-Linie zieht —
  VOR dem Lose-Karten-Pass, damit er nicht doppelt/schwebend erscheint. **Rein additiv** → kann keine
  Karte verdrängen. Merksatz: „Zeichnen" und „Anordnen" trennen — was nur sichtbar sein soll, gehört in
  einen reinen Zeichen-Index, nicht in die Struktur-Indizes (`partners`/`parents`/`unions`).
- **Merksatz:** (1) Bei Render-Fixes ZUERST prüfen, welcher Renderer aktiv ist (`RENDERER_GRAPH_DEFAULT`).
  (2) `model.partners` steuert in `zeichneGraph2` die PAAR-ANORDNUNG — nichts hineinschreiben, das die
  Ein-/Zwei-Eltern-Logik nicht verträgt (childless-Zweitpartner verdrängt den echten Ko-Elternteil).
  Verbindungen dort lieber als post-layout-Overlay zeichnen.

### 2026-07-24 — `position:fixed`-Panel mit ANGENOMMENER Höhe wird unten abgeschnitten [UX] [Mobile/iOS]
- **Symptom:** Das Board-Verknüpfen-Popover (`#board-verkn-popover`) hing beim Scrollen im Viewport
  und war am unteren Rand abgeschnitten (Fehlertext/Buttons nicht erreichbar) — verschärft, als ein
  5. Typ-Button (Ex-Partner) dazukam.
- **Ursache:** Die Positionierung klemmte mit einer **fest angenommenen Höhe** (`top = min(y,
  innerHeight - 240)`). Sobald der echte Inhalt höher ist (mehr Buttons, eingeblendeter Fehlertext),
  stimmt die Annahme nicht → unterer Teil rutscht aus dem Bild. Zusätzlich fehlte der scroll/resize-
  Reposition-Handler (CLAUDE.md-Panel-Regel).
- **Lösung:** Nach `display:block` die **echte** `offsetHeight` messen und daran klemmen
  (`boardPopoverPositionieren`), bei Nichtpassen oberhalb der Drop-Stelle öffnen; CSS
  `max-height: calc(100vh - 16px)` + `overflow-y:auto` + `box-sizing:border-box` für sehr kleine
  Viewports; global `scroll`(capture)/`resize` neu positionieren (Muster wie `dpPositioniere`).
- **Merksatz:** Ein `position:fixed`-Panel NIE mit geratener Höhe klemmen — erst sichtbar schalten,
  `offsetHeight` messen, dann klemmen (oben/unten) + `max-height/overflow` als Sicherheitsnetz +
  scroll/resize-Reposition. Gilt für alle Popovers/Panels, nicht nur dieses.

### 2026-07-24 — Board-Redo („ponovi") immer als Fremdänderung blockiert [UX]
- **Symptom:** Im Tabla-Modus funktioniert **Rückgängig**, aber **Wiederholen/Redo** wirft scheinbar
  einen Fehler bzw. tut nichts — der Nutzer sieht den `board_undo_konflikt`-Hinweis, obwohl niemand
  sonst etwas geändert hat.
- **Ursache:** Der Fremdänderungs-Schutz (`boardUndoKonfliktfrei`) nutzte **einen** festen
  `pruef`-Zustand für Undo UND Redo. Der Move-Eintrag prüfte auf die **neuen** Positionen (`neuP`).
  Nach dem Undo stehen die Karten aber auf den **alten** (`altP`) → beim Redo passt der erwartete
  Zustand nicht → Prüfung meldet „Fremdänderung" und blockiert das Redo. Redo einer Verschiebung ging
  damit **nie**.
- **Lösung:** Prüfung **richtungsabhängig** machen: `boardUndoKonfliktfrei(e, richtung)` wählt
  `pruefUndo` (erwartet `neuP`) bzw. `pruefRedo` (erwartet `altP`). `boardUndo` ruft mit `'undo'`,
  `boardRedo` mit `'redo'`. `e.pruef` bleibt Undo-Rückfall. (stammbaum.html, Move-Closure + die drei
  Undo-Funktionen.)
- **Merksatz:** Ein Undo/Redo-Konfliktcheck, der einen Zustand mit dem „erwarteten" vergleicht, MUSS
  je Richtung einen anderen Erwartungswert haben — vor Undo den Nach-Zustand, vor Redo den Vor-Zustand.
- **Sackgassen:** Stack-Logik (push/pop/Tiefe) war korrekt und grün getestet — der Bug lag NICHT im
  Stack, sondern im Konfliktcheck der einzelnen Closure. Reine Stack-Tests hätten ihn nie gefunden;
  erst der End-to-End-Zyklus Verschieben→Undo→Redo deckt ihn auf.

### 2026-07-24 — Lokaler Login: „Database error querying schema" (NULL-Token in auth.users) [Supabase/DB]
- **Symptom:** Login gegen den lokalen Stack scheitert mit `500: Database error querying schema`;
  im Auth-Container-Log: `error finding user: sql: Scan error on column index 3, name
  "confirmation_token": converting NULL to string is unsupported`.
- **Ursache:** Ein per SQL-Seed angelegter `auth.users`-Datensatz ließ die Token-Spalten
  (`confirmation_token`, `recovery_token`, `email_change_token_new`, `email_change`,
  `email_change_token_current`, `phone_change`, `phone_change_token`, `reauthentication_token`) auf
  `NULL`. GoTrue (Go) scannt diese Spalten in `string` (nicht `*string`) → NULL knallt.
- **Lösung:** Diese Spalten im Seed explizit auf `''` (leerer String) setzen, nicht weglassen.
  Bestehende DB reparierbar per `UPDATE auth.users SET confirmation_token=COALESCE(confirmation_token,'') …`.
- **Merksatz:** Test-Auth-User per SQL-Seed IMMER mit **leeren Strings** für alle Token-Spalten
  anlegen — GoTrue verträgt dort kein NULL. (Alternative: User über Studio/CLI anlegen, dann stimmt's.)

### 2026-07-24 — Die 117 Migrations-`.sql` sind NICHT als Neuaufbau replaybar [Supabase/DB]
- **Symptom:** Frischer lokaler Aufbau (Nr.1→Nr.117 aus SCHEMA.md) scheitert reihenweise:
  `relation "public.stammbaeume" does not exist` (verbund vor multitree), `policy "…" already exists`
  (fehlendes `DROP … IF EXISTS`), zuletzt `column "person_id" does not exist` bei
  `event_eingeladene.sql`.
- **Ursache:** Drei verschiedene, systemische Gründe — die Kette wurde nie am Stück gegen eine leere
  DB gedacht: (1) **Reihenfolge** — Tabellen werden benutzt, bevor ein späteres Skript sie anlegt;
  (2) **Nicht-Idempotenz** — `CREATE POLICY`/`CREATE TRIGGER` ohne `DROP … IF EXISTS` (Postgres kennt
  kein `CREATE POLICY IF NOT EXISTS`); (3) **überholte Migrationen** (der harte, unlösbare Fall) —
  `event_eingeladene.sql` legt `person_id` an, die spätere `event_eingeladene_user.sql` stellte das
  auf `user_id` um. Der Prod-**Endstand** hat `user_id`; der überholte Schritt mit `person_id` läuft
  dagegen prinzipiell auf Grund. Kein Umsortieren kann das lösen.
- **Lösung:** **Der komplette Prod-Dump IST das Schema.** Frischer Aufbau (lokal/neues Projekt) über
  `supabase db dump -f supabase_prod_schema.sql` → `node scripts/lokal_db_aufbau.mjs` (Dump + Seed,
  via docker exec). Die 117 `.sql` bleiben als Änderungs-Historie in SCHEMA.md, werden aber NICHT
  mehr am Stück ausgeführt. „Erst lokal, dann prod" gilt für NEUE `.sql` gegen den Prod-Spiegel.
- **Merksatz:** Eine gewachsene, teils von Hand gepflegte Migrations-Sammlung ist kein reproduzierbarer
  Neuaufbau — für einen frischen Klon den **Schema-Dump** nehmen, nicht die Historie replayen.
- **Sackgassen:** (a) Nur die 6 Kern-Tabellen als Basis + Replay → löst Reihenfolge, nicht die
  überholten Migrationen. (b) Alle 60 Tabellen als Basis + Replay → löst „relation does not exist",
  scheitert aber weiter an überholten Spalten (`person_id`). Erst der volle Dump ist tragfähig.

### 2026-07-23 — `supabase start` bricht mit „relation public.personen does not exist" ab [Supabase/DB]
- **Symptom:** `supabase start` läuft bis „Seeding data from supabase/seed.sql…", dann
  `failed to send batch: ERROR: relation "public.personen" does not exist (SQLSTATE 42P01)`,
  danach „Stopping containers…" — der Stack startet NICHT.
- **Ursache:** `[db.seed] enabled = true` in `config.toml` lässt `supabase start` das Seed
  **automatisch beim Start** gegen die **noch leere** DB einspielen. In diesem Projekt baut aber
  NICHT die Supabase-Migrationsmechanik das Schema (es gibt keine `supabase/migrations/`), sondern
  `scripts/lokal_db_aufbau.mjs` (Basis-Dump → 117 `.sql` → Seed). Beim Start existieren die Tabellen
  also noch gar nicht → Seed scheitert → Start-Rollback.
- **Lösung:** `[db.seed] enabled = false` in `supabase/config.toml`. Das Seed läuft ausschließlich
  über `lokal_db_aufbau.mjs` als letzter Schritt, NACH dem Schema.
- **Merksatz:** Wenn das Schema per eigenem Skript (nicht `supabase/migrations/`) aufgebaut wird,
  MUSS `[db.seed]` in der `config.toml` AUS sein — sonst seedet `supabase start` gegen eine leere DB.
- **Sackgassen:** Reihenfolge im Seed umsortieren hilft nicht — das ganze Schema fehlt, nicht nur
  eine Tabelle.
