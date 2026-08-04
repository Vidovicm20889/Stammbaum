#!/usr/bin/env node
// ============================================================================
// FamilyRoots — Wrapper um `supabase start`, der vorher die app-übergreifende
// RAM-Bremse prüft (siehe db_capacity.mjs). Analog zu StockFlows
// `scripts/supabase.mjs` bzw. LedgerFlows `scripts/db-start.mjs`.
//
//   node scripts/db_start.mjs            # supabase start
//   node scripts/db_start.mjs status     # jeder supabase-Unterbefehl geht durch
//
// Override für einen Einzelfall, falls die Schätzung hier nachweislich zu
// konservativ ist: FAMILYROOTS_SKIP_RAM_CHECK=1 vor den Befehl setzen.
// ============================================================================

import { spawnSync } from 'node:child_process';
import {
  gesamtDockerSpeicherMiB,
  wslMemoryLimitMiB,
  GESCHAETZTE_STACK_KOSTEN_MIB,
  SICHERHEITS_ANTEIL,
} from './db_capacity.mjs';

const args = process.argv.slice(2);
const supabaseArgs = args.length > 0 ? args : ['start'];

// Die Bremse nur vor einem echten Start prüfen – `status`/`stop` u. ä.
// belegen keinen zusätzlichen RAM und sollen nicht blockiert werden.
if (supabaseArgs[0] === 'start') {
  const verbrauch = gesamtDockerSpeicherMiB();
  const limit = wslMemoryLimitMiB();
  const sicherGrenze = limit * SICHERHEITS_ANTEIL;

  if (verbrauch !== null && verbrauch + GESCHAETZTE_STACK_KOSTEN_MIB > sicherGrenze) {
    console.error(
      `\nAbbruch: RAM-Verbrauch app-übergreifend bereits ${(verbrauch / 1024).toFixed(1)} GB ` +
        `von ${(limit / 1024).toFixed(1)} GB WSL2-Limit (Sicherheitsgrenze ` +
        `${(sicherGrenze / 1024).toFixed(1)} GB). Der FamilyRoots-Stack würde das überschreiten.\n\n` +
        'Das zählt StockFlow- und LedgerFlow-Container mit, nicht nur familyroots-eigene:\n' +
        '  docker ps\n\n' +
        'Zuerst dort Kapazität freigeben (Stack stoppen, egal welcher App), dann erneut starten.\n' +
        'Override: FAMILYROOTS_SKIP_RAM_CHECK=1 vor den Befehl setzen.\n',
    );
    if (process.env.FAMILYROOTS_SKIP_RAM_CHECK !== '1') process.exit(1);
  }
}

const result = spawnSync('supabase', supabaseArgs, { stdio: 'inherit', shell: true });
process.exit(result.status ?? 1);
