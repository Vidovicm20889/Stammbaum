// scripts/karte_bauen.mjs — erzeugt docs/karte.md: Zeilen-Index der grossen Frontend-Dateien.
//
// Zweck: stammbaum.html hat ~25.000 Zeilen. Wer die Datei am Stueck liest, verbrennt sehr viel
// Kontext. Diese Karte sagt, in welchem Abschnitt und in welcher Zeile etwas steht — danach
// genuegt ein gezieltes Lesen mit offset/limit.
//
// Verwendung:  node scripts/karte_bauen.mjs
// Nach groesseren Umbauten neu laufen lassen (die Datei wird komplett neu geschrieben).

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const WURZEL = join(dirname(fileURLToPath(import.meta.url)), '..');
const DATEIEN = ['stammbaum.html', 'pdf_export.js', 'chat.js'];

const TRENNER = /^\s*\/\/\s*={5,}\s*$/;              // // ==========
const BANNER_TEXT = /^\s*\/\/\s*(.+?)\s*$/;          // // Titel
const BLOCK_BANNER = /^\s*\/\*+\s*={3,}\s*(.+?)\s*={3,}\s*\*+\/\s*$/; // /* ==== Titel ==== */

// Funktions-/Konstantendefinitionen, die als Sprungziel taugen
const MUSTER = [
  /^\s*(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(/,
  /^\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:function\b|\([^)]*\)\s*=>|[A-Za-z_$][\w$]*\s*=>)/,
  /^\s*window\.([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:function\b|\()/,
];

function abschnitteLesen(zeilen) {
  // Ergebnis: [{ zeile, titel }]
  const treffer = [];
  for (let i = 0; i < zeilen.length; i++) {
    const block = BLOCK_BANNER.exec(zeilen[i]);
    if (block) { treffer.push({ zeile: i + 1, titel: block[1] }); continue; }
    // Muster:  // =====  /  // Titel  /  // =====
    if (TRENNER.test(zeilen[i]) && i + 2 < zeilen.length && TRENNER.test(zeilen[i + 2])) {
      const m = BANNER_TEXT.exec(zeilen[i + 1]);
      if (m && !TRENNER.test(zeilen[i + 1])) treffer.push({ zeile: i + 1, titel: m[1] });
      i += 2;
    }
  }
  return treffer;
}

function namenLesen(zeilen) {
  const treffer = [];
  for (let i = 0; i < zeilen.length; i++) {
    for (const re of MUSTER) {
      const m = re.exec(zeilen[i]);
      if (m) { treffer.push({ zeile: i + 1, name: m[1] }); break; }
    }
  }
  return treffer;
}

function dateiKarte(datei) {
  const pfad = join(WURZEL, datei);
  if (!existsSync(pfad)) return null;
  const zeilen = readFileSync(pfad, 'utf8').split(/\r?\n/);
  const abschnitte = abschnitteLesen(zeilen);
  const namen = namenLesen(zeilen);

  // Namen den Abschnitten zuordnen
  const gruppen = [];
  if (!abschnitte.length || abschnitte[0].zeile > 1) {
    gruppen.push({ zeile: 1, titel: '(ohne Abschnittsueberschrift)', namen: [] });
  }
  for (const a of abschnitte) gruppen.push({ ...a, namen: [] });

  for (const n of namen) {
    let ziel = gruppen[0];
    for (const g of gruppen) { if (g.zeile <= n.zeile) ziel = g; else break; }
    if (ziel) ziel.namen.push(n);
  }

  const zeilenGesamt = zeilen.length;
  for (let i = 0; i < gruppen.length; i++) {
    gruppen[i].bis = i + 1 < gruppen.length ? gruppen[i + 1].zeile - 1 : zeilenGesamt;
  }

  return { datei, zeilenGesamt, gruppen: gruppen.filter((g) => g.namen.length || g.titel !== '(ohne Abschnittsueberschrift)') };
}

const heute = process.env.KARTE_DATUM || '';
let md = `# Karte: Zeilen-Index der grossen Frontend-Dateien

> **Generiert** von \`node scripts/karte_bauen.mjs\` — **nicht von Hand pflegen.**
> Nach groesseren Umbauten neu erzeugen.

**Wozu:** \`stammbaum.html\` ist zu gross, um sie am Stueck zu lesen.

**So benutzen (nicht die ganze Datei lesen):**
1. Funktionsname bekannt → \`Grep\` auf den Namen **in dieser Datei** (Teil 2) → eine kurze Zeile
   mit Datei + Zeilennummer → dann gezielt \`Read\` mit \`offset\`/\`limit\`.
2. Nur das Thema bekannt → Abschnittstabelle (Teil 1) → Zeilenbereich → dort gezielt lesen.
${heute ? `\n**Stand:** ${heute}\n` : ''}
---

## Teil 1 — Abschnitte
`;

const alleNamen = [];

for (const datei of DATEIEN) {
  const k = dateiKarte(datei);
  if (!k) continue;
  md += `\n### ${k.datei} — ${k.zeilenGesamt.toLocaleString('de-DE')} Zeilen\n\n`;
  md += '| Zeilen | Abschnitt | Funktionen |\n|---|---|---|\n';
  for (const g of k.gruppen) {
    md += `| ${g.zeile}–${g.bis} | ${g.titel.replace(/\|/g, '\\|')} | ${g.namen.length} |\n`;
    for (const n of g.namen) alleNamen.push({ ...n, datei: k.datei, abschnitt: g.titel });
  }
}

md += `\n---\n\n## Teil 2 — Funktions-Index (alphabetisch, ${alleNamen.length} Eintraege)\n\n`;
md += 'Per `Grep` auf den Namen abfragen — jede Zeile ist eigenstaendig.\n\n';
alleNamen.sort((a, b) => a.name.localeCompare(b.name, 'de'));
for (const n of alleNamen) {
  md += `- \`${n.name}\` — ${n.datei}:${n.zeile} — ${n.abschnitt.replace(/\|/g, '\\|')}\n`;
}

md += `\n---\n\n## Weitere grosse Dateien (nie am Stueck lesen)\n
| Datei | Inhalt | Zugriff |
|---|---|---|
| \`i18n.js\` | TEXTE (5 Sprachbloecke) + RECHTSTEXTE | neue Schluessel via \`node scripts/i18n_add.mjs\`, Pruefung via \`node i18n_lint.js\` |
| \`pdf_font.js\` | Base64-Schrift-Subset (Noto Serif) | gar nicht lesen — siehe \`docs/externe-libraries-csp.md\` |
| \`rezepte_pool.js\` | Rezept-Datenbestand | gezielt per Grep |
| \`render_snapshot.json\` | Test-Snapshot | gezielt per Grep |
| \`supabase_prod_schema.sql\` | kompletter Prod-Dump | gezielt per Grep, siehe \`docs/staging-umgebung.md\` |
`;

writeFileSync(join(WURZEL, 'docs', 'karte.md'), md, 'utf8');
console.log('OK: docs/karte.md geschrieben.');
