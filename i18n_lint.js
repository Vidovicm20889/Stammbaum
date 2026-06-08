// i18n_lint.js — Schlüssel-Parität der Übersetzungen prüfen.
// Aufruf:  node i18n_lint.js
// Lädt i18n.js (definiert die globalen const TEXTE + RECHTSTEXTE) und meldet je
// Objekt/Sprache, welche Schlüssel gegenüber der Vereinigungsmenge ALLER Sprachen
// fehlen. Exit-Code 1, wenn etwas fehlt (für „vor jedem Commit prüfen").
'use strict';
const fs = require('fs');
const path = require('path');

const datei = path.join(__dirname, 'i18n.js');
const code = fs.readFileSync(datei, 'utf8');

// i18n.js nutzt globale const-Bindungen (kein module.exports). In eine Funktion
// kapseln und die beiden Objekte zurückgeben.
let TEXTE, RECHTSTEXTE;
try {
  ({ TEXTE, RECHTSTEXTE } = new Function(code + '\n;return { TEXTE, RECHTSTEXTE };')());
} catch (e) {
  console.error('❌ i18n.js konnte nicht ausgewertet werden:', e.message);
  process.exit(1);
}

let fehler = 0;

function pruefe(name, obj) {
  if (!obj || typeof obj !== 'object') { console.error(`❌ ${name} fehlt oder ist kein Objekt.`); fehler++; return; }
  const sprachen = Object.keys(obj);
  // Vereinigungsmenge aller Schlüssel über alle Sprachen
  const alle = new Set();
  sprachen.forEach(sp => Object.keys(obj[sp] || {}).forEach(k => alle.add(k)));

  console.log(`\n=== ${name} === (${sprachen.length} Sprachen: ${sprachen.join(', ')}, ${alle.size} Schlüssel gesamt)`);
  let okAlle = true;
  sprachen.forEach(sp => {
    const vorhanden = new Set(Object.keys(obj[sp] || {}));
    const fehlend = [...alle].filter(k => !vorhanden.has(k));
    if (fehlend.length) {
      okAlle = false; fehler += fehlend.length;
      console.log(`  ⚠️  ${sp}: ${fehlend.length} fehlend -> ${fehlend.join(', ')}`);
    }
  });
  if (okAlle) console.log('  ✅ alle Sprachen vollständig (Schlüssel-Parität ok)');
}

pruefe('TEXTE', TEXTE);
pruefe('RECHTSTEXTE', RECHTSTEXTE);

if (fehler) { console.log(`\n❌ ${fehler} fehlende Schlüssel gefunden.`); process.exit(1); }
console.log('\n✅ Alles paritätisch. Keine fehlenden Schlüssel.');
