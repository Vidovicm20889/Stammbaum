#!/usr/bin/env node
// ============================================================================
// FamilyRoots — Wrapper um `supabase db push` gegen Prod. Analog zu
// StockFlows `npm run deploy:db -- --confirm`: der rohe Befehl ist in
// .claude/settings.json für alle Agenten gesperrt (Deny lässt sich nicht
// nach Agent unterscheiden), dieser Wrapper ist der einzige erlaubte Weg.
//
// Ohne --confirm: nur `db push --dry-run` (rein lesend) — zeigt, was
// passieren würde, wendet nichts an. Mit --confirm: echter Push gegen Prod.
//
//   node scripts/deploy_db.mjs              # Dry-Run, nichts wird angewendet
//   node scripts/deploy_db.mjs --confirm    # echter Push gegen Prod
//
// Der deploy-manager legt die Dry-Run-Ausgabe Milan als Teil der
// Freigabe-Vorlage vor (docs/workflow-branching-versionierung.md). Enthält
// sie DROP/TRUNCATE/ALTER … DROP COLUMN, holt er dafür eine zweite,
// getrennte Bestätigung ein, bevor er hier mit --confirm erneut aufruft.
//
// Passwort-Quelle: BEWUSST repo-lokal aus supabase/.env (gitignored), nicht
// aus einer globalen Windows-Umgebungsvariable — SUPABASE_DB_PASSWORD ist auf
// dieser Maschine app-übergreifend als User-Variable belegt (aktuell mit dem
// StockFlow-Passwort). Ein zweites Projekt unter demselben globalen Namen
// würde sich mit StockFlow überschreiben/kollidieren, siehe ../CLAUDE.md
// („Geteilte Docker-/Host-Ressourcen"). Fallback auf die Prozess-Umgebung nur,
// wenn supabase/.env keinen Wert liefert — mit Warnung, weil dann eben jener
// globale, potenziell fremde Wert verwendet wird.
// ============================================================================

import { spawnSync } from 'node:child_process';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const REPO_ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const ENV_FILE = path.join(REPO_ROOT, 'supabase', '.env');
const PROJECT_REF = 'tybvzhifvufgvlgjpmyl';
const confirmed = process.argv.slice(2).includes('--confirm');

function leseDbPasswortAusEnvDatei() {
  if (!existsSync(ENV_FILE)) return null;
  const inhalt = readFileSync(ENV_FILE, 'utf8');
  for (const zeile of inhalt.split('\n')) {
    const m = /^\s*SUPABASE_DB_PASSWORD\s*=\s*(.+?)\s*$/.exec(zeile);
    if (m) return m[1].replace(/^["']|["']$/g, '');
  }
  return null;
}

function ermittleDbPasswort() {
  const ausDatei = leseDbPasswortAusEnvDatei();
  if (ausDatei) return { wert: ausDatei, quelle: `${path.relative(REPO_ROOT, ENV_FILE)}` };
  if (process.env.SUPABASE_DB_PASSWORD) {
    console.warn(
      '\nWarnung: SUPABASE_DB_PASSWORD kommt aus der globalen Prozess-Umgebung, nicht aus\n' +
        `${path.relative(REPO_ROOT, ENV_FILE)}. Diese Variable ist auf dieser Maschine\n` +
        'app-übergreifend gesetzt (z. B. für StockFlow) — falls der Push mit einem\n' +
        'Authentifizierungsfehler scheitert, liegt vermutlich das falsche Passwort vor.\n',
    );
    return { wert: process.env.SUPABASE_DB_PASSWORD, quelle: 'Prozess-Umgebung (global)' };
  }
  return null;
}

function run(args, { maskAt } = {}) {
  const anzeige = args.map((a, i) => (i === maskAt ? '***' : a));
  console.log(`\n$ supabase ${anzeige.join(' ')}`);
  const result = spawnSync('supabase', args, { stdio: 'inherit', shell: true });
  if (result.status !== 0) {
    console.error(`\nAbbruch: \`supabase ${anzeige.join(' ')}\` endete mit Exit-Code ${result.status}.`);
    process.exit(result.status ?? 1);
  }
}

const passwort = ermittleDbPasswort();
if (!passwort) {
  console.error(
    '\nAbbruch: kein Datenbank-Passwort gefunden.\n' +
      `Bitte in ${path.relative(REPO_ROOT, ENV_FILE)} eintragen:\n` +
      '  SUPABASE_DB_PASSWORD=<Passwort aus Supabase-Dashboard → Project Settings → Database>\n' +
      `(Datei ist über .gitignore geschützt, landet nie im Repo.)\n`,
  );
  process.exit(1);
}
console.log(`\nDatenbank-Passwort-Quelle: ${passwort.quelle}`);

run(['link', '--project-ref', PROJECT_REF, '--password', passwort.wert], { maskAt: 4 });

if (!confirmed) {
  console.log('\n--- DRY-RUN (kein --confirm) — es wird NICHTS gegen Prod angewendet ---');
  run(['db', 'push', '--dry-run', '--linked', '--password', passwort.wert], { maskAt: 5 });
  console.log(
    '\nDas war nur die Vorschau. Erst nach ausdrücklicher Freigabe erneut mit\n' +
      '  node scripts/deploy_db.mjs --confirm\n' +
      'aufrufen, um wirklich gegen die produktive FamilyRoots-Datenbank zu pushen.',
  );
  process.exit(0);
}

console.log('\n--- ECHTER PUSH GEGEN PROD ---');
run(['db', 'push', '--linked', '--yes', '--password', passwort.wert], { maskAt: 5 });
console.log('\nMigration(en) gegen Prod angewendet.');
