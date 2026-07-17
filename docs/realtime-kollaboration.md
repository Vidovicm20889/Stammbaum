# Echtzeit-Kollaboration & Benachrichtigungen

> Teil der FamilyRoots-Doku. Dauerregeln stehen in `CLAUDE.md`; hier stehen die Feature-Details.
> Live-Sync, Presence, Soft-Lock, Konflikterkennung (P1–P5), Obavještenja-Polling.

- **Obavještenja Live-Updates**: Badge + Liste aktualisieren sich ohne Reload per **Polling**
  (`startObavPolling`/`stopObavPolling`/`obavLivePoll`, ~12 s; pausiert bei verstecktem Tab,
  sofort-Refresh bei `visibilitychange`). Polling läuft NUR für eingeloggte Admins und darf den
  Inaktivitäts-Timer NICHT zurücksetzen (sonst kein Auto-Logout). Bewusst Polling statt Supabase
  Realtime: `registrierungs_anfragen` wird über SECURITY-DEFINER-RPCs gelesen (kein direktes
  RLS-SELECT) → Realtime würde solche Zeilen nicht ausliefern.
- **Live-Sync der Baumdaten (Supabase Realtime, ab v8.6):** Baumdaten (`personen`,
  `beziehungen`, `stammbaeume`) werden – anders als `registrierungs_anfragen` – über **echte
  RLS-SELECT-Policies** gelesen ([supabase_rls_setup.sql], [supabase_multitree_phase5.sql]), daher
  ist **Supabase Realtime** hier der gewählte Transport (kein eigener WebSocket-Server, kein
  SignalR — beides nicht stack-konform). Ein Channel (`startRealtimeSync`/`stopRealtimeSync`,
  Channel `stammbaum-sync`) abonniert `postgres_changes` (`event:'*'`) dieser drei Tabellen; bei
  einem Event wird **debounced** (~700 ms) `ladeBaumDaten()` aufgerufen → Karten/Beziehungen/
  Dropdown/Statistiken aktualisieren sich ohne Reload (kein F5). **Invarianten — nicht zurückbauen:**
  (a) Live-Sync darf den **Inaktivitäts-/Auto-Logout-Timer NICHT** zurücksetzen (analog Obav-Polling)
  — also NIE `resetInaktivTimer`/`sessAktivitaet` aus dem Realtime-Callback; (b) gilt für **alle
  eingeloggten Nutzer** (auch lesende Mitglieder), nicht nur Admins; (c) bei verstecktem Tab wird der
  Reload aufgeschoben und bei `visibilitychange` nachgeholt; (d) Start nach `ladeBaumDaten()` im
  Login-Flow, Stop in `loescheUser()` (wie `stopObavPolling`). DB-Voraussetzung: die drei Tabellen
  müssen in der Publication `supabase_realtime` liegen (idempotente DB-Datei
  `supabase_realtime_publication.sql`). **Bewusste P1-Grenze:** v1 macht bei jedem Event einen
  debounced **Vollreload des In-Memory-Modells** (kein echtes Client-seitiges Delta-Merge).
- **Live-Indikator / Presence (P2, ab v8.6):** Zeigt im Header (`#presence-indikator`), wer
  gerade DENSELBEN Stammbaum geöffnet hat („{n} aktiv" + aufklappbare Namensliste). Technik:
  **Supabase Realtime Presence** über einen **eigenen Channel je Baum** (`presence:tree:<id>`,
  `startPresence`/`stopPresence`, Key = `user.id`) — **kein** DB-/Publication-Bedarf (rein
  channel-basiert). Beim Baumwechsel (`waehleStammbaum`) wird umgeklinkt, Stop in `loescheUser`.
  Anzeige nur, wenn AUSSER einem selbst noch jemand da ist (n≥2). Anzeigename best-effort aus der
  E-Mail (`nutzerAnzeigeName`), via `nm()` SR-transliteriert; Panel touch-sicher per `pointerdown`
  außerhalb geschlossen; `wechselSprache` ruft `renderPresenceIndikator` (i18n-Keys
  `presence_aktiv`/`presence_titel`/`presence_sie` in allen 5 Blöcken). Invarianten wie Live-Sync:
  **kein** Zurücksetzen des Inaktivitäts-Timers, gilt für ALLE eingeloggten Nutzer.
- **Live-Aktualisierung offener Personen-Overlays (P3, ab v8.6):** Hat ein Nutzer das Detail-
  (`#modal`) oder Bearbeiten-Overlay (`#person-edit-modal`) einer Person offen und ein anderer
  Nutzer speichert/löscht diese Person, blendet `pruefeOverlayAktualitaet` (Aufruf nach jedem
  Live-Reload in `realtimeReloadAusfuehren`) ein **goldenes Hinweis-Banner** `.sync-hinweis` ein
  („Diese Person wurde soeben aktualisiert/entfernt") mit Button **„Neueste Änderungen übernehmen"**
  (`detailUebernehmen`/`editUebernehmen` rendern das Overlay frisch). **Wichtig:** Im **Editor**
  werden laufende Eingaben NIE automatisch überschrieben — nur auf Klick. Änderungserkennung über
  `personSignatur` (eigene Felder + Beziehungen via **stabile externe IDs**; FAM-IDs/Positionen
  bewusst ausgeklammert, da je Reload neu bzw. inhaltlich irrelevant). Watch-State
  (`detailWatchId`/`editWatchId` + Signatur) wird beim Öffnen gesetzt, beim Schließen geleert; i18n
  `sync_*` in allen 5 Blöcken; `wechselSprache` beschriftet offene Banner neu
  (`aktualisiereSyncBannerSprache`).
- **Soft-Lock / exklusive Bearbeitung (P4, ab v8.6):** Öffnet ein Admin den Personen-Editor, setzt
  er über den **Presence-Channel** (`presenceTrack(personId)`, Feld `editing` in der Presence-
  Nutzlast) eine **Bearbeitungssperre** — **kein SQL/keine Tabelle**. Andere sehen die fremde Sperre
  in `presenceLocks` (aus `presenceState`); in der Detailkarte erscheint live „🔒 Wird gerade von X
  bearbeitet" (`pruefeLockBanner`, `.sync-hinweis.lock-hinweis`). Beim Öffnen-Versuch gilt **Modus 2
  (exklusiv):** normale `familien_admin` werden geblockt (Toast `lock_blockiert`); **nur
  `super_admin`/`familien_owner` der Familie** dürfen die Sperre mit Warnung übernehmen
  (`darfSperreUebernehmen` + `zeigeBestaetigung`). Freigabe in `schliessePersonEdit` (deckt
  Speichern, da der Save-Flow den Editor schließt). **Auto-Freigabe** ohne Heartbeat: Tab zu /
  Logout / Crash → Presence-`leave` entfernt die Nutzlast → Sperre fällt automatisch weg (löst das
  „hängende Lock"-Risiko von Modus 2). i18n `lock_*` in allen 5 Blöcken. **Bewusste Grenze:** rein
  Presence-broadcastbasiert (keine harte DB-Arbitrierung bei exakt gleichzeitigem Öffnen) — echte
  Konfliktauflösung folgt in P5.
- **Konflikterkennung / Optimistic Locking (P5, ab v8.6):** `personen` hat eine **`updated_at`**-
  Spalte (BEFORE-UPDATE-Trigger `personen_touch_updated`, DB-Datei `supabase_personen_updated_at.sql`
  — **muss VOR dem Frontend-Deploy ausgeführt werden**, da `ladeBaumAusSupabase` die Spalte selektiert;
  fehlt sie, schlägt der Select fehl → Fallback auf eingebettete Daten). Beim Öffnen des Editors
  merkt sich das Frontend den Stand (`editBaselineUpdated = p._updated`); `speicherePerson` liest vor
  dem Schreiben das aktuelle `updated_at` und zeigt bei Abweichung den **Konflikt-Dialog**
  (`zeigeKonfliktDialog`): **Meine überschreiben** (`speicherePerson(true)` = Force), **Aktuelle
  übernehmen** (verwerfen + Editor mit frischen Werten neu öffnen) oder **Unterschiede vergleichen**
  (`konfliktVergleich` = Feld-für-Feld-Tabelle Meine/Aktuell über `KONFLIKT_FELDER`). i18n `konflikt_*`
  in allen 5 Blöcken. Nach erfolgreichem Speichern wird `editBaselineUpdated` neutralisiert.
  **Bewusste Grenze:** Vergleich über JS-Re-Select (kein DB-conditional-update); kleines TOCTOU-
  Fenster bei extrem zeitgleichem Speichern — für die Nutzerzahl unkritisch.
- **Noch offen (geplant, NICHT umgesetzt):** echtes Client-seitiges Delta-Merge (statt Vollreload bei
  jedem Live-Sync-Event). Damit ist die Echtzeit-Kollaboration (P1–P5) funktional vollständig.
