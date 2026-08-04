#!/usr/bin/env node
// ============================================================================
// FamilyRoots — App-übergreifende RAM-Bremse (von StockFlow übertragen)
// ----------------------------------------------------------------------------
// Alle drei Apps (StockFlow, LedgerFlow, FamilyRoots) teilen sich dieselbe
// WSL2-VM (siehe `c:/VidovicAi/CLAUDE.md`, „Geteilte Docker-/Host-Ressourcen").
// Ein `supabase start` hier ist unabhängig davon, was StockFlow oder
// LedgerFlow gerade an RAM belegen — diese Bremse misst deshalb den
// tatsächlichen Verbrauch ALLER laufenden Container, nicht nur des eigenen
// `supabase_db_familyroots`-Stacks.
//
// Vorbild: StockFlow/scripts/db-instances.mjs. Dort zählte die bisherige
// Bremse (STOCKFLOW_MAX_STACKS) nur StockFlow-eigene Container und übersah
// genau deshalb am 2026-08-03 gleichzeitig laufende Fremd-Stacks — diese
// Bremse hier misst den echten RAM-Verbrauch statt einer Namens-Zählung.
// ============================================================================

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

function docker(...args) {
  try {
    return execFileSync('docker', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  } catch {
    return null; // Engine nicht erreichbar – der Aufrufer entscheidet
  }
}

/** `.wslconfig`-`memory=`-Wert in MiB, Standard 10 GB, falls nicht lesbar. */
export function wslMemoryLimitMiB() {
  const pfad = join(homedir(), '.wslconfig');
  const standard = 10 * 1024;
  if (!existsSync(pfad)) return standard;
  try {
    const inhalt = readFileSync(pfad, 'utf8');
    const treffer = inhalt.match(/^\s*memory\s*=\s*([\d.]+)\s*(GB|MB)\s*$/im);
    if (!treffer) return standard;
    const [, zahl, einheit] = treffer;
    return einheit.toUpperCase() === 'GB' ? Number(zahl) * 1024 : Number(zahl);
  } catch {
    return standard;
  }
}

/** Tatsächlicher RAM-Verbrauch aller laufenden Container in MiB, app- und
 * namensunabhängig (`docker stats`, erster Wert je Zeile ist der Verbrauch,
 * nicht das Limit). */
export function gesamtDockerSpeicherMiB() {
  const out = docker('stats', '--no-stream', '--format', '{{.MemUsage}}');
  if (out === null || out === '') return null;

  let summe = 0;
  for (const zeile of out.split('\n')) {
    const verbrauch = zeile.split('/')[0]?.trim();
    const treffer = verbrauch?.match(/^([\d.]+)\s*(KiB|MiB|GiB|B)$/);
    if (!treffer) continue;
    const [, zahl, einheit] = treffer;
    const wert = Number(zahl);
    summe += einheit === 'GiB' ? wert * 1024 : einheit === 'KiB' ? wert / 1024 : einheit === 'B' ? wert / 1024 ** 2 : wert;
  }
  return Math.round(summe);
}

/** Kosten eines weiteren FamilyRoots-Supabase-Stacks, konservativ geschätzt.
 * Analytics ist hier bereits abgeschaltet (`supabase/config.toml`,
 * `[analytics] enabled = false`) — etwas leichter als StockFlows vollen
 * Stack, aber immer noch Studio + Kong + Auth + Storage + Realtime + DB. */
export const GESCHAETZTE_STACK_KOSTEN_MIB = 800;

/** Wie viel Prozent des WSL2-Limits maximal ausgeschöpft werden, bevor
 * gebremst wird – Rest bleibt Puffer für Windows selbst und Lastspitzen. */
export const SICHERHEITS_ANTEIL = 0.8;
