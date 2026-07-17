# FamilyRoots — Roadmap & Ausblick

> Statuskontext; keine verbindlichen Regeln (die stehen in CLAUDE.md).

## Roadmap-Kontext
- Phase 1 (kostenlos/statisch) und Phase 2 (Auth/Supabase, Familien-Isolation, Rollen,
  Self-Service-Stammbäume, Owner-Konzept) sind umgesetzt.
- Umgesetzt (Frontend live bzw. lokal fertig): einheitliche Datumsfelder mit Kalender;
  Event-System (Medien Bild/Video/PDF im Storage, „Organizovano od", Kostenübersicht mit
  automatischer Aufteilung/Ausgleich/PDF); **Obavještenja** (offene Anfragen + Akzeptieren/Ablehnen
  + Mail, Badge); Sofort-Sprachwechsel; touch-sichere Dropdowns; Session-Auto-Logout +
  Update-/Versions-Erkennung.
- **Anfrage-Bearbeitung NUR in der App (kein E-Mail-Accept/Reject mehr):** Die Entscheidung über
  Zugangsanfragen trifft ein Admin ausschließlich unter „Obavještenja" (Edge Function
  `anfrage-bearbeiten`, mit Login + Rollenprüfung super_admin/familien_owner/familien_admin).
  Die Benachrichtigungs-Mail (`anfrage-senden`) enthält KEINE Annehmen/Ablehnen-Links mehr,
  sondern nur einen „App öffnen"-Deep-Link (`?obav=1` → öffnet nach Login automatisch die
  Obavještenja-Liste). Die früher öffentliche `anfrage-entscheiden` ist deaktiviert (leitet nur
  noch in die App) und sollte im Dashboard gelöscht werden.
- **„Kreiraj nalog"-Overlay (kein da/ne-Self-Service-Schalter mehr):** Ein einziger Flow.
  Pflichtfelder: Naziv stabla + Država + Opština (+ E-Mail); **Grad/selo (= Dorf) ist optional**.
  Eine Hintergrundprüfung (`familie_finden_exakt`, **strikter 3-Felder-Match Name/Land/Gemeinde**,
  diakritik-/groß-klein-unempfindlich über
  `merge_norm`; **Grad/selo/Dorf ist seit v13.9 NICHT mehr Teil des Abgleichs**) erkennt einen
  vorhandenen Baum: Treffer → Info + Rollen-Dropdown → Zugriffsanfrage
  (Entscheidung in der App). Kein Treffer → bisheriger Self-Service: `neue-familie-anlegen` legt
  Konto + Baum sofort an (User = `familien_owner`, sofortige Passwort-Mail, KEINE Freigabe).
  Beim Self-Service-Anlegen werden `land`/`stadt`/`gemeinde` in `familien` gespeichert, damit das
  strikte Matching künftiger Anfragen greift.
- Offen/Ausblick: Abo-Modell (Stripe); weitere Admin-Funktionen (Familieneinstellungen).

# Stammbaum → Familien-Netzwerk: Social-Feature-Prompts

Idee: eine **soziale Schicht** über dem bestehenden Stammbaum – die App wird vom Daten-Archiv zum
lebendigen Familien-Netzwerk (MyHeritage trifft Instagram/Facebook). Jeder Block ist ein
eigenständiger Prompt zum Kopieren in Claude Code. Reihenfolge = empfohlene Bearbeitung
(Engagement-Primitive zuerst, dann das, was darauf aufbaut).

---
