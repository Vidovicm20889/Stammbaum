# Supabase-Schema — Migrations-Index & Ausführungsreihenfolge

Diese Datei beschreibt, **welche `.sql`-Dateien eine frische Supabase-DB aufbauen** und in
welcher **Reihenfolge** sie im SQL-Editor auszuführen sind. Sie ersetzt das frühere
„85 Dateien im Root, niemand weiß was Pflicht ist".

- **Alle Migrationen sind idempotent** (mehrfaches Ausführen schadet nicht) — so der Anspruch
  laut CLAUDE.md. Bei Abweichung bitte hier vermerken.
- **Reihenfolge = Best-Effort** nach Abhängigkeiten/Phasen. Läuft ein Skript wegen einer noch
  fehlenden Funktion/Tabelle auf einen Fehler, das benötigte Skript der früheren Gruppe
  zuerst ausführen.
- **Einmal-/Vorfall-Skripte** (Diagnose, person-/konto-spezifische Reparaturen, Restore/Rollback)
  liegen unter [`sql_archiv/`](sql_archiv/) und gehören **NICHT** zum Neuaufbau.
- **Edge Functions** (kein SQL) liegen unter [`supabase/functions/`](supabase/functions/) und
  werden über das Supabase-Dashboard deployt (CLI durch Citrix-Firewall blockiert).

---

## Reihenfolge für eine frische DB

### 1 — Grundgerüst (Basis-Tabellen, RLS, Verbund)
1. `supabase_rls_setup.sql` — Basis-Tabellen (familien/stammbaeume/personen/beziehungen) + RLS
2. `supabase_rls_fix_recursion.sql` — rekursionsfreie `mitgliedschaften`-SELECT-Policy
3. `supabase_verbund.sql` — `verbund_id`, `ist_super_admin`, `kann_familie_bearbeiten`
4. `supabase_multitree_phase5.sql` — Mehrbaum-Fähigkeit (RLS-SELECT-Policies für Baumdaten)
5. `supabase_stammbaum_phase4.sql` — Stammbaum-Phase 4

### 2 — Rollen & Mitglieder
6. `supabase_mitglieder_komplett.sql` — **konsolidiert** (ersetzt die Einzel-Iterationen, s. u.)
7. `supabase_rolle_owner.sql` — Owner-Rolle
8. `supabase_owner_baeume.sql`
9. `supabase_owner_wechsel.sql` — `stammbaum_owner_wechseln` (Owner-Übertragung, Super-Admin)
10. `supabase_admins_alle_familien.sql`
11. `supabase_verwaltbare_familien.sql` — RPC `verwaltbare_familien` (inkl. `baum_namen`)

### 3 — Registrierung / Zugangsanfragen
12. `supabase_registrierung_setup.sql`
13. `supabase_registrierung_phase2.sql`
14. `supabase_registrierung_phase3.sql`
15. `supabase_fix_anfragen_rls.sql` — INSERT-Policy für `registrierungs_anfragen` (anon)
16. `supabase_familie_finden_exakt.sql` — `familie_finden_exakt` (strikter 4-Felder-Match)
17. `supabase_email_validierung.sql`

### 4 — Stammbaum-Lebenszyklus
18. `supabase_stammbaum_anlegen_fix.sql`
19. `supabase_stammbaum_loeschen.sql`
20. `supabase_fix_stammbaum_loeschen.sql` — räumt Familie + Mitgliedschaften mit ab
21. `supabase_stammbaum_auto_leer.sql` — Auto-Löschung leerer Bäume (kontoschonend)
22. `supabase_stammbaum_bereinigung.sql`
23. `supabase_leere_familien_loeschen.sql`
24. `supabase_stammbaum_zweig_heirat.sql` — `stammbaum_zweig_aus_heirat` (Auto-Zweigbaum)
25. `supabase_split_alle_baeume.sql` — Werkzeug „eine Familie pro Baum" (Generalisierung)

### 5 — Personen / Identität / Merge
26. `supabase_personen_updated_at.sql` — **VOR jedem Frontend-Deploy** (Spalte wird selektiert)
27. `supabase_personen_eines_baums.sql`
28. `supabase_personen_suche_verbinden.sql` — `personen_suche` (verbundweit)
29. `supabase_gleiche_person_sync.sql` — **aktuell** (ersetzt `supabase_gleiche_person.sql`)
30. `supabase_person_merge.sql` — Merge-Primitiv `person_zusammenfuehren`
31. `supabase_merge_gui.sql` — aktuelles Merge-Werkzeug `person_merge_aufgeloest`
32. `supabase_merge_zwilling_schutz.sql`
33. `supabase_kind_baeume_sync.sql` — `kind_baeume_sync` (Kind über beide Eltern spiegeln)
33a. `supabase_person_anlegen_atomar.sql` — `person_anlegen_atomar(p_op jsonb)`: legt Person +
    ALLE Beziehungen (inkl. optionalem Geschwister-Platzhalter) in EINER Transaktion an
    (Audit Vorschlag 2 gegen „lose Inseln"). **VOR Frontend-Deploy ausführen** — `speichereNeuePerson`
    ruft die RPC ab v12.4 auf. (Voraussetzung: 3 `supabase_verbund.sql`.)
33b. `supabase_beziehung_verschieben.sql` — `beziehung_verschieben(p_person,p_other,p_neu_typ,
    p_ersetzt_elternteil)`: hängt eine Beziehung von einer Rolle in eine andere um (eltern/kind/
    partner/geschwister), ATOMAR, identitätsbewusst, mit Validierung (Selbst/Zyklus/Geschwister↔
    Eltern/Partner-Inzest/2‑Eltern-Grenze) + optionalem Eltern-Ersetzen. Liefert `sync_kind` →
    Frontend ruft `kind_baeume_sync`. **VOR Frontend-Deploy ausführen** (Detailkarten-⇄-Button ab
    v12.9). (Voraussetzung: 3 `supabase_verbund.sql`, 33 `supabase_kind_baeume_sync.sql`.)
34. `supabase_meine_person.sql` — Self-Service Konto↔Karte

### 6 — Blutlinien-Rechte (auto, additiv)
35. `supabase_blutlinie_rechte.sql`
36. `supabase_blutlinie_phase2.sql`

### 6a — Diagnose (read-only, dauerhaft)
36a. `supabase_baum_integritaet.sql` — `baum_integritaet_pruefen(p_stammbaum_id)`: read-only
    „TÜV-Bericht" eines Baums. Findet **Inseln** (Personen ohne Kanten-Pfad zur Render-Wurzel
    = im Diagramm unsichtbar, Zeile existiert), **lose Personen** (Grad 0), **verwaiste Kanten**
    (Beziehung mit fehlendem Endpunkt) und **Personen ohne stammbaum_id**. SCHREIBT NICHTS.
    Trennt „Anzeigeproblem" vs. „Datenproblem". Rechte: Admin/Owner/Super der Familie.
    (Voraussetzung: 3 `supabase_verbund.sql`.)

### 7 — Profil
37. `supabase_profile.sql` — Tabelle `profile` + Bucket `avatars`
38. `supabase_profil_sicherheit.sql` — `meine_sicherheit_info` / `andere_sitzungen_abmelden`
39. `supabase_profil_person_sync.sql` — bidirektionale Profil↔Karte-Sync-Trigger

### 8 — Verknüpfung Konto ↔ Karte
40. `supabase_verknuepfung_anfragen.sql`
41. `supabase_verknuepfung_verwaltung.sql`
41a. `supabase_user_karte_zuweisung.sql` — Admin/Super-Admin: `karten_suche_admin`,
    `karte_user_zuweisen` (Belegt-Warnung), `meine_person_status`(+familie),
    `mitglieder_verwaltbar`(+verknüpfte Karte). **VOR Frontend-Deploy ausführen** (neue RPCs;
    `mitglieder_verwaltbar` ändert Signatur → DROP+CREATE).

### 9 — Events
42. `supabase_events.sql`
43. `supabase_events_medien_organisator.sql`
44. `supabase_event_kosten.sql`
45. `supabase_event_eingeladene.sql`
46. `supabase_event_eingeladene_user.sql`
47. `supabase_storage_events_policies.sql` — Storage-Policies Bucket `events`

### 10 — Benachrichtigungen / Obavještenja
48. `supabase_obavjestenja.sql`
49. `supabase_benachrichtigungen.sql`
50. `supabase_benachrichtigungen_realtime.sql`
50a. `supabase_benachrichtigungen_anlaesse.sql` — Geburtstags-/Gedenktag-Erinnerungen (Stufe B): `benachrichtigungs_einstellungen` + `anlaesse_taeglich_erzeugen()` + Idempotenz-Spalten an `benachrichtigungen`. pg_cron-Snippet separat aktivieren. (Voraussetzung: 49 + Verbund)
50b. `supabase_benachrichtigungen_anlaesse_email.sql` — E-Mail-Layer: `benachrichtigungen.email_gesendet` + `anlaesse_email_offen()`/`anlaesse_email_erledigt()`. Edge Function `anlaesse-erinnerung` + pg_net-Cron separat aktivieren. (Voraussetzung: 50a)

### 11 — Realtime
51. `supabase_realtime_publication.sql` — `personen`/`beziehungen`/`stammbaeume` in Publication

### 12 — Länder / Familieneinstellungen
52. `supabase_land_iso_migration.sql` — Länder auf ISO-Codes
53. `supabase_familie_einstellungen.sql` — `stammbaeume.einstellungen` (jsonb) + Bucket `familien`

### 13 — Personen-Medien (Fotos & Dokumente) & Lebensgeschichten
54. `supabase_personen_fotos.sql` — Foto-Galerie pro Person: Tabelle `personen_fotos` + **public** Bucket `personen-fotos` + Storage-Policies (verbund-RLS, Schreiben über erstes Pfad-Segment = `stammbaum_id`). (Voraussetzung: `personen` + Verbund-Helfer)
55. `supabase_personen_dokumente.sql` — Dokumente & Quellen pro Person: Tabelle `personen_dokumente` + **privater** Bucket `personen-dokumente` (signierte URLs) + Storage-Policies (`darf_dokordner_sehen`/`darf_dokordner_bearbeiten`). (Voraussetzung: `personen` + Verbund-Helfer)
56. `supabase_personen_geschichten.sql` — Mehrsprachige Lebensgeschichten pro Person: Tabelle `personen_geschichten` (UNIQUE person_id+sprache [`de|sr|hr|ba|en`], Markdown), verbund-RLS (Entwürfe nur für Bearbeiter), Identitäts-Sync-Trigger `geschichte_ident_sync` (Zwillinge, analog `ident_sync`) + Backfill `beschreibung`→`de`. KEIN Bucket. (Voraussetzung: `personen` + `identitaet_id` aus `supabase_gleiche_person_sync.sql` + Verbund-Helfer)

### 14 — Chat (verbundweit)
56. `supabase_chat.sql` — Chat (1:1 + Gruppen): Tabellen `chats`/`chat_teilnehmer`/`chat_nachrichten`,
    rekursionsfreie RLS über `ist_chat_teilnehmer`, RPCs `verbund_nutzer`/`direkt_chat_finden_oder_anlegen`/
    `gruppen_chat_anlegen`/`chat_nachricht_senden`/`chat_gelesen`/`chat_teilnehmer_entfernen`/
    `chat_gruppen_admin_setzen` + Aufnahme von `chat_nachrichten`/`chat_teilnehmer` in die Publication
    `supabase_realtime`. **VOR Frontend-Deploy ausführen** (neue Tabellen/RPCs). (Voraussetzung: 3
    `supabase_verbund.sql`, 6 `supabase_mitglieder_komplett.sql`, 37 `supabase_profile.sql`)

### 15 — Verbundübergreifende Personensuche + Kontaktanfragen (Discovery, 3 Stufen)
57. `supabase_auffindbarkeit.sql` — Stufe 1 (ENTDECKEN): `profile.auffindbar_extern` (Opt-in
    Lebende) + Avatar-Stufe `oeffentlich` + Helfer `_alter_jahre`/`_person_entdeckbar` +
    `personen_entdecken(p_query)` (verbundübergreifend, NUR 4 Minimalfelder). (Voraussetzung: 3
    `supabase_verbund.sql`, 37 `supabase_profile.sql`, `merge_norm`, `stammbaeume.einstellungen`)
58. `supabase_kontakt_anfragen.sql` — Stufe 2+3 (KONTAKT/BAUMZUGRIFF): Tabellen `kontakt_anfragen`/
    `kontakt_verbindungen`/`baum_freigaben` + Helfer `darf_baum_sehen`/`darf_beziehung_sehen`/
    `darf_chatten` + RPCs (`kontakt_anfrage_stellen`/`offene_kontakt_anfragen`/
    `kontakt_anfrage_entscheiden`/`…_zurueckziehen`/`baum_freigabe_widerrufen`/
    `kontakt_verbindung_entfernen`/`meine_kontakte`). **NACH 57.** (Voraussetzung: 57 + Verbund + benachrichtigungen)
59. `supabase_baum_freigaben_rls.sql` — Stufe 3 RLS: erweitert die SELECT-Policies auf
    `personen`/`stammbaeume`/`beziehungen` ADDITIV um `darf_baum_sehen`/`darf_beziehung_sehen`
    (nur LESEN). **NACH 3 `supabase_verbund.sql` UND 58.**
60. `supabase_chat_kontakt.sql` — Chat-Ergänzung: `chats.verbund_id` nullable +
    `direkt_chat_finden_oder_anlegen` verbundübergreifend über `darf_chatten`. **NACH 56
    `supabase_chat.sql` UND 58.**

### 16 — Soziale Schicht (Engagement)
61. `supabase_reaktionen_kommentare.sql` — Reaktionen & Kommentare (POLYMORPH, verbund-gebunden):
    Tabellen `reaktionen`/`kommentare` (denormalisierter `verbund_id`, `ziel_typ`/`ziel_id`) +
    Helfer `ist_in_verbund`/`darf_verbund_moderieren`/`_ziel_verbund` + RPCs (`reaktion_umschalten`/
    `kommentar_schreiben`/`kommentar_bearbeiten`/`kommentar_loeschen`/`engagement_holen`) +
    Realtime-Publication. SELECT nur verbund-intern (KEIN baum_freigaben-Pfad). **VOR Frontend-Deploy
    ausführen** (neue Tabellen/RPCs). (Voraussetzung: 3 `supabase_verbund.sql`, 37 `supabase_profile.sql`,
    `personen_fotos`/`personen_geschichten`/`events` mit `familie_id`)
62. `supabase_beitraege.sql` — Familien-Feed/Beiträge: Tabelle `beitraege` (verbund-RLS) + RPCs
    (`beitrag_erstellen`/`beitrag_bearbeiten`/`beitrag_loeschen`/`mein_verbund`) +
    Erweiterung `_ziel_verbund` um `beitrag` + public-Bucket `beitraege` + Realtime. **NACH 61**
    (nutzt `ist_in_verbund`/`darf_verbund_moderieren`/`_ziel_verbund`). **VOR Frontend-Deploy ausführen.**
    **Hinweis:** das frühere einfache `feed_holen` ist ENTFERNT (DROP) — der Feed liest über den
    allgemeinen Aktivitäten-Stream `aktivitaeten_holen` (Nr. 63).
63. `supabase_aktivitaeten.sql` — Familien-Feed/Aktivitäten-Stream: Tabelle `aktivitaeten`
    (verbund-RLS, `UNIQUE(typ,ref_id)`) + **Trigger** an `personen`/`personen_fotos`/
    `personen_geschichten`/`events`/`beitraege` (nur bei `auth.uid()` = echte Nutzer-Aktion →
    KEIN Import-Spam; Platzhalter + `identitaet_id`-Spiegelkarten übersprungen) + RPC
    `aktivitaeten_holen` (alle Typen, `beitrag_neu` trägt volle Beitragsfelder) + Realtime.
    **NACH 61 + 62.** (Voraussetzung: 61, 62, `personen_fotos`/`personen_geschichten`/`events`)
64. `supabase_foto_personen.sql` — Foto-Tagging: Tabelle `foto_personen` (verbund-RLS,
    `UNIQUE(foto_id,person_id)`) + RPCs `foto_person_markieren`/`foto_person_entfernen`/
    `foto_tags_holen`/`person_markierte_fotos` + Helfer `_foto_familie`. Markieren nur
    Foto-Bearbeiter; markierte Person muss im selben Verbund liegen (rein verbund-intern →
    keine verbundübergreifende Exposition). **NACH 54 `supabase_personen_fotos.sql` + 61.**
65. `supabase_familien_fragen.sql` — Familien-Fragen „Wer ist das?" (Crowdsourcing): schaltet
    `'frage'` im `ziel_typ`-CHECK von `reaktionen`/`kommentare` frei + erweitert `_ziel_verbund`;
    Tabelle `familien_fragen` (verbund-RLS) + RPCs (`frage_stellen`/`frage_loesen`/
    `frage_wieder_oeffnen`/`frage_loeschen`/`fragen_holen`) + Realtime. Antworten = Kommentare
    (`ziel_typ='frage'`). **NACH 61 + 62.** **VOR Frontend-Deploy ausführen.**
66. `supabase_person_aufnahmen.sql` — Sprach-/Video-Zeitzeugen pro Person: Tabelle
    `person_aufnahmen` (typ `audio`/`video`, titel/transkript/dauer_sek, verbund-RLS EXAKT wie
    `personen`/Dokumente) + **privater** Bucket `person-aufnahmen` (signierte URLs — Aufnahmen
    lebender Personen bleiben verbund-intern) + Storage-Policies (`darf_aufnordner_sehen`/
    `darf_aufnordner_bearbeiten`, erstes Pfad-Segment = `stammbaum_id`). Aufnahme im Browser
    (MediaRecorder) oder Datei-Upload. PREMIUM-/LIMIT-KANDIDAT (Egress). (Voraussetzung: `personen`
    + Verbund-Helfer) **VOR Frontend-Deploy ausführen.**
67. `supabase_gedenkseiten.sql` — Gedenkseiten + Kondolenz-/Erinnerungsbuch für Verstorbene:
    Tabelle `gedenk_eintraege` (typ `kondolenz`/`kerze`, text + optionales Foto, verbund-RLS via
    `ist_in_verbund`) + RPCs (`gedenk_eintrag_schreiben`/`_bearbeiten`/`_loeschen`,
    `gedenk_kerze_umschalten`, `gedenkseite_holen`) + public-Bucket `gedenkseiten` (Pfad
    `<user_id>/<uuid>`, wie `beitraege`). Schreiben nur über SECURITY-DEFINER-RPCs; Moderation via
    `darf_verbund_moderieren`. KEIN Realtime (lädt frisch beim Öffnen). **NACH 61** (nutzt
    `ist_in_verbund`/`darf_verbund_moderieren`/`_ziel_verbund`). (Voraussetzung: `personen`,
    `profile`, Verbund-Helfer, Engagement-Datei 61.)
68. `supabase_beitrags_statistik.sql` — Sanfte Gamification: Tabelle `beitrags_statistik`
    (`(verbund_id,user_id)`-PK, Zähler personen/fotos/geschichten, verbund-RLS via `ist_in_verbund`)
    + AFTER-INSERT-Trigger an `personen`/`personen_fotos`/`personen_geschichten` (nur bei
    `auth.uid()`, Platzhalter/Spiegelkarten/Backfill ausgeklammert; Geschichte-Spiegel via
    `pg_trigger_depth()`) + RPC `beitrags_statistik_holen` (eigene Summen + alphabetische, NICHT
    gerankte Beitragenden-Liste). KEIN Realtime. **NACH 61/62** (nutzt `ist_in_verbund`/
    `mein_verbund`). Abzeichen werden NICHT gespeichert (Frontend leitet sie aus den Zählern ab).
    (Voraussetzung: `personen`/`personen_fotos`/`personen_geschichten`, `familien`, `profile`,
    Verbund-Helfer aus 61/62.)
69. `supabase_woechentlicher_digest.sql` — Wöchentlicher Familien-Digest (E-Mail): Opt-out-Spalte
    `email_woechentlicher_digest` an `benachrichtigungs_einstellungen` + Protokoll-Tabelle
    `digest_versand` (`(user_id,verbund_id,woche_start)`-UNIQUE gegen Doppelversand, RLS nur
    service_role) + RPCs `digest_woche_sammeln` (je Empfänger+Verbund Zähler der letzten 7 Tage
    aus `aktivitaeten` + anstehende Geburtstage/Gedenktage + offene Fragen; nur „etwas Neues",
    opted-in, noch nicht versorgt) und `digest_markiere_gesendet`. Versand über Edge Function
    `woechentlicher-digest` (Resend) + pg_cron/pg_net-Snippet (separat aktivieren). Datensparsam
    (nur Zähler + Anlass-Namen, keine Inhalte). **NACH 50a/63/65**. (Voraussetzung:
    `benachrichtigungs_einstellungen`, `aktivitaeten`, `familien_fragen`, `profile`, Verbund-Helfer.)
    **VOR Frontend-Deploy ausführen** (Profil-Toggle liest/schreibt die neue Spalte; Frontend ist
    aber tolerant, falls die Spalte fehlt).
70. `supabase_event_album.sql` — Gemeinsame Event-Alben: Tabelle `event_album_fotos` (verbund-RLS via
    `ist_in_verbund`; an EVENT gehängt, `ON DELETE CASCADE`) + **privater** Bucket `event-album`
    (signierte URLs, Pfad `{stammbaum_id}/{event_id}/{uuid}`) + Storage-Policies (`darf_albumordner_
    sehen`/`darf_albumordner_bearbeiten` über erstes Pfad-Segment; DELETE auch für `owner`=Uploader)
    + RPCs `event_album_holen`/`event_album_foto_anlegen`/`event_album_foto_loeschen`/
    `event_album_uebersicht`. Schaltet zusätzlich `ziel_typ='album_foto'` frei (Engagement-CHECKs +
    `_ziel_verbund`). Ansehen/Hochladen = wer das Event sehen darf (`darf_event_sehen`), Löschen =
    Uploader oder `kann_familie_bearbeiten`. KEIN Realtime (lädt frisch beim Öffnen). Storage-Cleanup
    beim Event-/Baum-Löschen im Frontend (`loescheAlbumMedien` + `verwaiste_event_medien`-Queue).
    **NACH 42 (events), event_eingeladene (darf_event_sehen), 61 (Engagement), 65 (familien_fragen =
    letzte `_ziel_verbund`-Fassung).** (Voraussetzung: `events`, `darf_event_sehen`, Verbund-Helfer,
    Engagement-Datei 61, `familien_fragen` 65.)
    **v14.x-Erweiterung (im selben File, idempotent):** Der alte Event-„Medien"-Abschnitt entfällt;
    bestehende Medien aus dem `events`-Bucket werden PER REFERENZ ins Album übernommen — Spalten
    `bucket`/`mime`/`quelle` (+ partieller UNIQUE `(event_id,quelle)`) + RPC
    `event_album_legacy_uebernehmen` (legt Album-Zeilen an, die auf die vorhandenen `events`-Dateien
    zeigen; kein Byte-Kopieren/Löschen → kein Datenverlust). Album hält jetzt Bild/Video/PDF.

---

## ⚠️ Möglicherweise überholt — bitte bestätigen

Diese Dateien liegen noch im Root, sind aber vermutlich durch neuere ersetzt. **Nicht ohne
Bestätigung löschen/archivieren** (könnte eine noch benötigte Funktion enthalten):

| Datei | Vermutlich ersetzt durch |
|---|---|
| `supabase_gleiche_person.sql` | `supabase_gleiche_person_sync.sql` |
| `supabase_mitglieder.sql` | `supabase_mitglieder_komplett.sql` |
| `supabase_mitglieder_erweitert.sql` | `supabase_mitglieder_komplett.sql` |
| `supabase_mitglieder_crud.sql` | `supabase_mitglieder_komplett.sql` |

---

## Archiv (`sql_archiv/`) — NICHT für den Neuaufbau

Einmalige Diagnose-, Reparatur-, Restore- und konto-/person-spezifische Skripte:
Diagnose (`diagnose_*`, `supabase_diagnose_*`, `*_backup_diagnose`, `aufraeumen_check`),
Reparaturen (`repair_zorana_knezevic`, `supabase_fix_begovic_eltern`, `supabase_fix_testeric`),
Restore/Rollback (`supabase_restore_*`, `supabase_split_backup_rollback`),
person-/konto-gebundene Migrationen (`supabase_split_stojanovic`, `supabase_split_familien`,
`supabase_zweig_begovic`, `supabase_merge_andrea`, `supabase_trivo_petrovic_admin`,
`supabase_user_entfernen`, `supabase_user_mmax_entfernen`).

Sie dokumentieren vergangene Eingriffe und bleiben als Referenz/Vorlage erhalten.
