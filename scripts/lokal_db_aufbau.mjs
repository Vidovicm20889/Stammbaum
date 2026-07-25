#!/usr/bin/env node
// ============================================================================
// FamilyRoots — lokaler DB-Aufbau (FAMROOTS-36)
// ----------------------------------------------------------------------------
// Baut die lokale DB als EXAKTEN Prod-Spiegel auf: spielt `supabase_prod_schema.sql` (kompletter
// Prod-Schema-Dump — Tabellen, Spalten, Functions, Policies, RPCs, Trigger, FKs) ein, danach das
// synthetische `supabase/seed.sql`.
//
// ⚠️ WARUM NICHT die 117 nummerierten `.sql` replayen? Belegt in FAMROOTS-36: die gewachsene
// Migrationskette ist NICHT als Start-zu-Ende-Replay lauffähig — etliche Skripte wurden von
// späteren ERSETZT (z. B. `event_eingeladene.sql` legt `person_id` an, das die nächste Migration
// `event_eingeladene_user.sql` auf `user_id` umstellte). Ein überholter Schritt lässt sich nicht auf
// den fertigen Prod-Endstand replayen. Deshalb: der Dump IST das Schema. Die nummerierten Skripte
// bleiben als Änderungs-Historie im Repo (SCHEMA.md), werden aber nicht mehr am Stück ausgeführt.
// „Erst lokal, dann prod" gilt ab jetzt für NEUE `.sql` — die testest du gegen diesen Prod-Spiegel.
//
// VORAUSSETZUNGEN (Nutzer richtet die CLI selbst ein — docs/staging-umgebung.md):
//   1) Docker läuft, 2) supabase-CLI installiert, 3) `supabase start` (Stack oben),
//   4) KEIN separates psql nötig: läuft der DB-Container (supabase_db_familyroots), spricht das
//      Skript die DB per `docker exec` an (psql ist im Container). Sonst Host-psql (--host).
//
// BENUTZUNG (immer VORHER `supabase db reset`, damit frisch aufgebaut wird):
//   supabase db reset
//   node scripts/lokal_db_aufbau.mjs                 # Schema + Seed
//   node scripts/lokal_db_aufbau.mjs --schema-only   # nur Schema, kein Seed
//   node scripts/lokal_db_aufbau.mjs --dry-run       # nur anzeigen, kein DB-Zugriff
//   Optionen: --host | --docker | --container <name> | --db-url <url>
//
// Das Prod-Schema wird per `supabase db dump -f supabase_prod_schema.sql` erzeugt (einmalig bzw.
// nach Prod-Änderungen). Anleitung: docs/staging-umgebung.md.
// ============================================================================

import { readFileSync, existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HIER = dirname(fileURLToPath(import.meta.url));
const REPO = join(HIER, '..');
const SCHEMA_FILE = join(REPO, 'supabase_prod_schema.sql');
const SEED = join(REPO, 'supabase', 'seed.sql');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const schemaOnly = args.includes('--schema-only');
const dbUrlArg = args.indexOf('--db-url');
const DB_URL = dbUrlArg >= 0 ? args[dbUrlArg + 1]
  : 'postgresql://postgres:postgres@127.0.0.1:54332/postgres';
const contArg = args.indexOf('--container');
const CONTAINER = contArg >= 0 ? args[contArg + 1] : 'supabase_db_familyroots';
const forceDocker = args.includes('--docker');
const forceHost = args.includes('--host');

function hostHatPsql() {
  const r = spawnSync('psql', ['--version'], { stdio: 'ignore' });
  return !r.error && r.status === 0;
}
function containerLaeuft(name) {
  const r = spawnSync('docker', ['ps', '--format', '{{.Names}}'], { encoding: 'utf8' });
  return !r.error && String(r.stdout || '').split(/\r?\n/).includes(name);
}
function ermittleModus() {
  if (forceHost) return 'host';
  if (forceDocker) return 'docker';
  if (hostHatPsql()) return 'host';
  if (containerLaeuft(CONTAINER)) return 'docker';
  return null;
}

let MODUS = null;

function spieleEin(pfad) {
  let r;
  if (MODUS === 'docker') {
    const sql = readFileSync(pfad, 'utf8');   // Repo ist im Container nicht gemountet -> via stdin
    r = spawnSync('docker',
      ['exec', '-i', CONTAINER, 'psql', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-q'],
      { input: sql, stdio: ['pipe', 'inherit', 'inherit'] });
    if (r.error) {
      console.error(`\n❌ docker exec fehlgeschlagen (${r.error.message}). Läuft Docker / Container ${CONTAINER}?`);
      process.exit(2);
    }
  } else {
    r = spawnSync('psql', [DB_URL, '-v', 'ON_ERROR_STOP=1', '-q', '-f', pfad], { stdio: 'inherit' });
    if (r.error) {
      console.error(`\n❌ psql nicht ausführbar (${r.error.message}). Ist es installiert/im PATH?`);
      process.exit(2);
    }
  }
  return r.status === 0;
}

// --- Ablauf -----------------------------------------------------------------
if (!existsSync(SCHEMA_FILE)) {
  console.error(`\n⛔ ${SCHEMA_FILE} fehlt. Einmalig aus Prod erzeugen (siehe docs/staging-umgebung.md):`);
  console.error('     supabase login && supabase link --project-ref tybvzhifvufgvlgjpmyl');
  console.error('     supabase db dump -f supabase_prod_schema.sql');
  process.exit(3);
}

const plan = [{ label: 'Prod-Schema', pfad: SCHEMA_FILE }];
if (!schemaOnly && existsSync(SEED)) plan.push({ label: 'Seed (synthetisch)', pfad: SEED });

if (dryRun) {
  console.log('--- Dry-Run (kein DB-Zugriff) ---');
  plan.forEach((s, i) => console.log(`${i + 1}. ${s.label}  (${s.pfad.replace(REPO + '\\', '').replace(REPO + '/', '')})`));
  console.log('\nHinweis: VOR dem echten Lauf `supabase db reset` ausführen (frischer Aufbau).');
  process.exit(0);
}

MODUS = ermittleModus();
if (!MODUS) {
  console.error('\n⛔ Kein Weg zur DB gefunden. Entweder:');
  console.error(`   • lokalen Stack starten:  supabase start   (Container ${CONTAINER} muss laufen), oder`);
  console.error('   • Postgres-Client installieren, sodass `psql` im PATH ist.');
  console.error('   Erzwingen: --docker bzw. --host.');
  process.exit(2);
}
console.log(MODUS === 'docker'
  ? `Spiele über docker exec in ${CONTAINER} ein …\n`
  : `Spiele über host-psql gegen ${DB_URL} ein …\n`);

for (const s of plan) {
  process.stdout.write(`→ ${s.label}\n`);
  if (!spieleEin(s.pfad)) {
    console.error(`\n❌ Fehler bei ${s.label} — Abbruch (ON_ERROR_STOP).`);
    process.exit(1);
  }
}
console.log(`\n✅ Fertig: Prod-Schema${plan.length > 1 ? ' + Seed' : ''} eingespielt. Lokale DB spiegelt Prod.`);
