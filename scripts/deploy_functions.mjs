#!/usr/bin/env node
// ============================================================================
// FamilyRoots — Wrapper um `supabase functions deploy` gegen Prod. Analog zu
// StockFlows `npm run deploy:functions -- --confirm --name <function>`: der
// rohe Befehl ist in .claude/settings.json für alle Agenten gesperrt, dieser
// Wrapper ist der einzige erlaubte Weg.
//
// Ohne --confirm: zeigt nur, welche Function deployt würde — führt nichts aus.
// Mit --confirm: echtes Deploy gegen Prod. `--use-api` bündelt serverseitig
// ohne lokales Docker (siehe geteilte Docker-Kapazität, ../CLAUDE.md).
//
//   node scripts/deploy_functions.mjs --name anfrage-senden               # Vorschau
//   node scripts/deploy_functions.mjs --name anfrage-senden --confirm     # echtes Deploy
//   node scripts/deploy_functions.mjs --all --confirm                    # alle Functions
// ============================================================================

import { spawnSync } from 'node:child_process';

const PROJECT_REF = 'tybvzhifvufgvlgjpmyl';
const args = process.argv.slice(2);
const confirmed = args.includes('--confirm');
const all = args.includes('--all');
const nameIdx = args.indexOf('--name');
const name = nameIdx !== -1 ? args[nameIdx + 1] : null;

if (!all && !name) {
  console.error('Fehlt: --name <function-slug> (oder --all für alle Functions).');
  process.exit(1);
}

function run(cliArgs) {
  console.log(`\n$ supabase ${cliArgs.join(' ')}`);
  const result = spawnSync('supabase', cliArgs, { stdio: 'inherit', shell: true });
  if (result.status !== 0) {
    console.error(`\nAbbruch: \`supabase ${cliArgs.join(' ')}\` endete mit Exit-Code ${result.status}.`);
    process.exit(result.status ?? 1);
  }
}

run(['link', '--project-ref', PROJECT_REF]);

const ziel = all ? 'ALLE Functions' : name;

if (!confirmed) {
  console.log(`\nWürde deployen: ${ziel} (kein --confirm, nichts ausgeführt).`);
  process.exit(0);
}

const deployArgs = ['functions', 'deploy', '--project-ref', PROJECT_REF, '--use-api'];
if (!all) deployArgs.push(name);

console.log('\n--- ECHTES DEPLOY GEGEN PROD ---');
run(deployArgs);
console.log(`\n${ziel} gegen Prod deployt.`);
