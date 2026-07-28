// scripts/i18n_add.mjs — neue i18n-Schluessel in ALLE 5 Sprachbloecke von i18n.js einfuegen.
//
// Zweck: i18n.js hat ~8.000 Zeilen. Wer einen neuen Text braucht, musste bisher fuenf
// Stellen von Hand suchen und editieren. Dieses Skript macht das in einem Aufruf —
// ohne dass die Datei gelesen/durchsucht werden muss (spart Zeit und Kontext).
//
// Verwendung
//   Einzelner Schluessel:
//     node scripts/i18n_add.mjs mein_key --de "Text" --sr "Текст" --hr "Tekst" --ba "Tekst" --en "Text"
//
//   Mehrere Schluessel aus einer JSON-Datei:
//     node scripts/i18n_add.mjs --json neue_texte.json
//   Format der JSON-Datei:
//     { "mein_key":   { "de": "...", "sr": "...", "hr": "...", "ba": "...", "en": "..." },
//       "andrer_key": { "de": "...", "sr": "...", "hr": "...", "ba": "...", "en": "..." } }
//
//   Vorschau ohne Schreiben:  zusaetzlich --dry
//
// Danach IMMER pruefen:  node i18n_lint.js

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const SPRACHEN = ['de', 'sr', 'hr', 'ba', 'en'];
const WURZEL = join(dirname(fileURLToPath(import.meta.url)), '..');
const I18N_DATEI = join(WURZEL, 'i18n.js');

function abbruch(text) {
  console.error('FEHLER: ' + text);
  process.exit(1);
}

// ---------- Argumente einlesen ----------
const argv = process.argv.slice(2);
const trocken = argv.includes('--dry');
let eintraege = {};

if (argv.includes('--json')) {
  const pfad = argv[argv.indexOf('--json') + 1];
  if (!pfad) abbruch('--json braucht einen Dateipfad.');
  try {
    eintraege = JSON.parse(readFileSync(pfad, 'utf8'));
  } catch (e) {
    abbruch('JSON-Datei nicht lesbar/ungueltig: ' + e.message);
  }
} else {
  const key = argv[0];
  if (!key || key.startsWith('--')) {
    abbruch('Erster Parameter muss der Schluessel sein. Siehe Kopf der Datei fuer Beispiele.');
  }
  const werte = {};
  for (const sp of SPRACHEN) {
    const i = argv.indexOf('--' + sp);
    if (i === -1 || !argv[i + 1]) abbruch(`Uebersetzung fuer --${sp} fehlt (alle 5 Sprachen sind Pflicht).`);
    werte[sp] = argv[i + 1];
  }
  eintraege[key] = werte;
}

// ---------- Eingaben pruefen ----------
const keys = Object.keys(eintraege);
if (!keys.length) abbruch('Keine Schluessel angegeben.');

for (const key of keys) {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) {
    abbruch(`Schluessel "${key}" ist kein gueltiger JS-Bezeichner (nur Buchstaben, Ziffern, _).`);
  }
  const fehlend = SPRACHEN.filter((sp) => typeof eintraege[key][sp] !== 'string' || !eintraege[key][sp].length);
  if (fehlend.length) {
    abbruch(`Schluessel "${key}": Uebersetzung fehlt fuer ${fehlend.join(', ')} — alle 5 Sprachen sind Pflicht.`);
  }
}

// ---------- Datei einlesen ----------
const roh = readFileSync(I18N_DATEI, 'utf8');
const zeilenende = roh.includes('\r\n') ? '\r\n' : '\n';
const zeilen = roh.split(/\r?\n/);

const startTexte = zeilen.findIndex((z) => /^const TEXTE\s*=\s*\{/.test(z));
if (startTexte === -1) abbruch('Block "const TEXTE = {" nicht gefunden — Aufbau von i18n.js geaendert?');

let endeTexte = zeilen.findIndex((z, i) => i > startTexte && /^const RECHTSTEXTE\s*=\s*\{/.test(z));
if (endeTexte === -1) endeTexte = zeilen.length;

// Schluessel darf noch nicht existieren (sonst still ueberschriebene Doppeleintraege)
const bereich = zeilen.slice(startTexte, endeTexte).join('\n');
for (const key of keys) {
  const vorhanden = new RegExp(`(^|[{,\\s])${key}\\s*:`, 'm').test(bereich);
  if (vorhanden) abbruch(`Schluessel "${key}" existiert bereits in TEXTE — bitte dort direkt aendern.`);
}

// ---------- Einfuegepunkte finden (Zeile "  de: {" usw. innerhalb von TEXTE) ----------
const punkte = {};
for (const sp of SPRACHEN) {
  const idx = zeilen.findIndex((z, i) => i > startTexte && i < endeTexte && new RegExp(`^\\s{2}${sp}:\\s*\\{`).test(z));
  if (idx === -1) abbruch(`Sprachblock "${sp}:" innerhalb von TEXTE nicht gefunden.`);
  punkte[sp] = idx;
}

function alsJsString(text) {
  return "'" + text.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\r?\n/g, '\\n') + "'";
}

// Von hinten nach vorne einfuegen, damit die vorher ermittelten Indizes gueltig bleiben
const reihenfolge = [...SPRACHEN].sort((a, b) => punkte[b] - punkte[a]);
for (const sp of reihenfolge) {
  const neu = keys.map((key) => `    ${key}: ${alsJsString(eintraege[key][sp])},`);
  zeilen.splice(punkte[sp] + 1, 0, ...neu);
}

const ergebnis = zeilen.join(zeilenende);

// ---------- Syntaxpruefung vor dem Schreiben ----------
try {
  // i18n.js ist ein klassisches Script mit const-Deklarationen — als Funktionskoerper pruefbar.
  new Function(ergebnis + '\n;return typeof TEXTE;');
} catch (e) {
  abbruch('Ergebnis waere syntaktisch kaputt (' + e.message + ') — es wurde NICHTS geschrieben.');
}

if (trocken) {
  console.log('--dry: nichts geschrieben. Eingefuegt wuerden:');
  for (const key of keys) {
    console.log(`  ${key}: ` + SPRACHEN.map((sp) => `${sp}=${JSON.stringify(eintraege[key][sp])}`).join('  '));
  }
  process.exit(0);
}

writeFileSync(I18N_DATEI, ergebnis, 'utf8');
console.log(`OK: ${keys.length} Schluessel x 5 Sprachen in i18n.js eingefuegt (${keys.join(', ')}).`);
console.log('Naechster Schritt:  node i18n_lint.js');
