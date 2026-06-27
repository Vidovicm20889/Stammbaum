/* =====================================================
 * sim_render.js — Lokale Renderer-Scope-Simulation (Zwillings-Welt UND simuliert-migrierte Welt).
 *
 * ZWECK: Den Familien-Bleed des Graph-Renderers REPRODUZIERBAR machen, BEVOR die echte Migration
 *   läuft. Repliziert die App-Logik aus stammbaum.html:
 *     - ladeBaumAusSupabase (persons/families inkl. Identitäts-Dedup der Eltern)
 *     - baueGraphModell (canonOf via identitaet_id, parents/children/partners)
 *     - graphKomponente  = ALTER „voll"-Scope (ganze zusammenhängende Komponente)  -> BLEED-Verdacht
 *     - graphBlutScope   = NEUER Scope (Blutlinie + Partner-Blätter + 1. ausgeheiratete Generation,
 *                          gekappt bei der 2.) — Portierung der istBlutName/Kappung aus zeichneBaum
 *   und simuliert die Migration (Zwillinge je identitaet_id zu EINER Person kollabieren, Kanten
 *   umhängen), um beide Scopes auf der migrierten Datenform zu vergleichen.
 *
 * NUTZUNG:
 *   1) sql_archiv/export_render_snapshot.sql im Supabase-SQL-Editor ausführen,
 *      Ergebnis als render_snapshot.json in die Projektwurzel legen.
 *   2) node tools/sim_render.js
 *
 * Erwartung (Diagnose): pro Baum sollte NUR der eigene Nachname (+ eingeheiratete Partner als
 *   Blätter) erscheinen. Tauchen FREMDE Bäume tief auf -> Bleed. Wir wollen sehen:
 *     ALT (Komponente): bleedet auf migrierten Daten.   NEU (Blutlinie): bleedet NICHT, nichts fällt raus.
 * ===================================================== */
'use strict';
const fs = require('fs');
const path = require('path');

const SNAP = path.join(__dirname, '..', 'render_snapshot.json');
if (!fs.existsSync(SNAP)) {
  console.error('FEHLT: render_snapshot.json in der Projektwurzel.');
  console.error('-> sql_archiv/export_render_snapshot.sql ausführen und Ergebnis dorthin speichern.');
  process.exit(1);
}
let raw = JSON.parse(fs.readFileSync(SNAP, 'utf8'));
// Supabase-Editor liefert evtl. [{snapshot:{...}}] oder {snapshot:{...}} oder direkt {...}
if (Array.isArray(raw)) raw = raw[0];
const snapshot0 = raw.snapshot || raw;

// ---- Helfer: Nachname-Normierung (Portierung zweigNachnameNorm, ohne Kyrillisch-Map) ----
function norm(s) {
  const v = (s || '').toString()
    .replace(/\([^)]*\)/g, ' ').replace(/\(.*$/, ' ')
    .toLowerCase()
    .replace(/[čć]/g, 'c').replace(/š/g, 's').replace(/ž/g, 'z').replace(/đ/g, 'd');
  const toks = v.split(/\s+/).filter(w => /[a-z0-9]/.test(w));
  return toks.length ? toks[toks.length - 1] : '';
}

// ---- Modell aus einem Snapshot bauen (Spiegel von ladeBaumAusSupabase) ----
function baueModell(snap) {
  const stammbaeume = {};
  (snap.stammbaeume || []).forEach(s => { stammbaeume[s.id] = s; });

  const uuid2ext = {}, persons = {};
  (snap.personen || []).forEach(row => {
    const sd = row.sd || {};
    const ext = row.externe_id || sd.id;
    if (!ext) return;
    uuid2ext[row.id] = ext;
    persons[ext] = {
      id: ext, _uuid: row.id, _tree: row.stammbaum_id || null,
      _ident: row.identitaet_id || null, _userId: row.user_id || null,
      surname: sd.surname || '', given: sd.given || '', ehename: sd.ehename || '',
      sex: sd.sex || '', platzhalter: sd.platzhalter === 'true' || sd.platzhalter === true,
      families_spouse: [], families_child: []
    };
  });

  const ehe = [], elternVon = {};
  (snap.beziehungen || []).forEach(b => {
    const a = uuid2ext[b.a], c = uuid2ext[b.b];
    if (!a || !c) return;
    if (b.typ === 'ehepartner') ehe.push([a, c]);
    else if (b.typ === 'elternteil') (elternVon[c] = elternVon[c] || new Set()).add(a);
  });

  const families = {}, keyToFam = {}; let famN = 1;
  function holeFamilie(parents) {
    const seen = new Set();
    parents = parents.filter(pid => {
      const ident = persons[pid] && persons[pid]._ident;
      const k = ident ? ('i:' + ident) : ('p:' + pid);
      if (seen.has(k)) return false; seen.add(k); return true;
    });
    const key = parents.slice().sort().join('__');
    if (keyToFam[key]) return keyToFam[key];
    const fid = 'FAM' + (famN++);
    const fam = { id: fid, husband: null, wife: null, children: [] };
    parents.forEach(pid => {
      const sex = (persons[pid] && persons[pid].sex) || '';
      if (sex === 'M' && !fam.husband) fam.husband = pid;
      else if (sex === 'F' && !fam.wife) fam.wife = pid;
      else if (!fam.husband) fam.husband = pid;
      else fam.wife = pid;
    });
    families[fid] = fam; keyToFam[key] = fid; return fid;
  }
  ehe.forEach(([a, b]) => holeFamilie([a, b]));
  Object.entries(elternVon).forEach(([child, set]) => {
    const fid = holeFamilie([...set]);
    if (!families[fid].children.includes(child)) families[fid].children.push(child);
  });
  Object.values(families).forEach(fam => {
    if (fam.husband && persons[fam.husband]) persons[fam.husband].families_spouse.push(fam.id);
    if (fam.wife && persons[fam.wife]) persons[fam.wife].families_spouse.push(fam.id);
    fam.children.forEach(cid => { if (persons[cid]) persons[cid].families_child.push(fam.id); });
  });
  return { persons, families, stammbaeume, uuid2ext };
}

// ---- Graphmodell (Spiegel von baueGraphModell) ----
function baueGraph(M) {
  const { persons, families } = M;
  const canonOf = (id) => { const p = persons[id]; return (p && p._ident) ? ('grp:' + p._ident) : id; };
  const nodes = new Map();
  function ensure(id) {
    const c = canonOf(id), p = persons[id]; if (!p) return null;
    let n = nodes.get(c);
    if (!n) { n = { canon: c, rep: id, person: p, exts: [], trees: new Set() }; nodes.set(c, n); }
    n.exts.push(id); if (p._tree) n.trees.add(p._tree);
    return n;
  }
  Object.keys(persons).forEach(ensure);
  const unionMap = new Map();
  Object.values(families).forEach(fam => {
    const par = []; if (fam.husband) par.push(fam.husband); if (fam.wife) par.push(fam.wife);
    const pc = [...new Set(par.map(canonOf).filter(c => nodes.has(c)))];
    const key = pc.length ? pc.slice().sort().join('&') : ('solo:' + fam.id);
    let u = unionMap.get(key);
    if (!u) { u = { key, parents: new Set(pc), children: new Set() }; unionMap.set(key, u); }
    (fam.children || []).forEach(cid => { const cc = canonOf(cid); if (nodes.has(cc) && !u.parents.has(cc)) u.children.add(cc); });
  });
  const unions = [...unionMap.values()];
  const parents = new Map(), children = new Map(), partners = new Map();
  nodes.forEach((_, c) => { parents.set(c, new Set()); children.set(c, new Set()); partners.set(c, new Set()); });
  unions.forEach(u => {
    const ps = [...u.parents], cs = [...u.children];
    for (let i = 0; i < ps.length; i++) for (let j = i + 1; j < ps.length; j++) { partners.get(ps[i]).add(ps[j]); partners.get(ps[j]).add(ps[i]); }
    ps.forEach(p => cs.forEach(c => { children.get(p).add(c); parents.get(c).add(p); }));
  });
  return { nodes, unions, parents, children, partners, canonOf };
}

// ---- Wurzel wie die App (findeStammbaumWurzel): kein Elternteil-im-Baum, meiste Nachkommen-im-Baum ----
function appWurzel(M, treeId) {
  const { persons, families } = M;
  const imBaum = id => { const p = persons[id]; return p && p._tree === treeId; };
  const leute = Object.values(persons).filter(p => p._tree === treeId);
  if (!leute.length) return null;
  const hatElternImBaum = p => (p.families_child || []).some(fid => {
    const fam = families[fid]; if (!fam) return false;
    return (fam.husband && imBaum(fam.husband)) || (fam.wife && imBaum(fam.wife));
  });
  const kand = leute.filter(p => !hatElternImBaum(p));
  const liste = kand.length ? kand : leute;
  const nachk = (id, seen) => {
    seen = seen || new Set(); if (seen.has(id)) return 0; seen.add(id);
    const p = persons[id]; if (!p) return 0; let n = 0;
    (p.families_spouse || []).forEach(fid => {
      const fam = families[fid]; if (!fam) return;
      (fam.children || []).forEach(cid => { if (imBaum(cid)) n += 1 + nachk(cid, seen); });
    });
    return n;
  };
  let best = liste[0], max = -1;
  liste.forEach(p => { const n = nachk(p.id); if (n > max) { max = n; best = p; } });
  return best ? best.id : null;
}

// ---- istBlutName (Portierung; Vater-Fallback über parent-canon mit passendem Nachnamen) ----
function machIstBlut(M, G, treeNameN) {
  const { persons } = M;
  return (canon) => {
    const n = G.nodes.get(canon); if (!n) return false;
    const p = n.person;
    if (norm(p.surname) === treeNameN) return true;
    if (norm(p.ehename) === treeNameN) return true;
    // Vater-Fallback (wie istBlutName: husband der Geburtsfamilie): der Elternteil mit sex='M'.
    for (const par of (G.parents.get(canon) || [])) {
      const pn = G.nodes.get(par);
      if (pn && pn.person.sex === 'M' && norm(pn.person.surname) === treeNameN) return true;
    }
    return false;
  };
}

// ---- ALTER Scope: FAITHFUL graphRadius (das, was zeichneGraph2/vollGraphRender HEUTE zeichnet:
//      Fokus + Nachkommen[downN] + Partner aller Sichtbaren + Geschwister aller Sichtbaren).
//      Genau diese „Geschwister aller Sichtbaren"-Zeile bleedet: für einen eingeheirateten Partner
//      werden dessen Geschwister (Kinder seiner Eltern) mit hereingezogen. ----
function scopeRadius(G, start, runter, hoch) {
  const vis = new Set([start]);
  let frontier = [start];
  for (let d = 0; d < hoch; d++) {
    const nf = [];
    frontier.forEach(c => (G.parents.get(c) || []).forEach(p => { if (!vis.has(p)) { vis.add(p); nf.push(p); } }));
    frontier = nf;
  }
  frontier = [start];
  for (let d = 0; d < runter; d++) {
    const nf = [];
    frontier.forEach(c => (G.children.get(c) || []).forEach(k => { if (!vis.has(k)) { vis.add(k); nf.push(k); } }));
    if (!nf.length) break;
    frontier = nf;
  }
  [...vis].forEach(c => (G.partners.get(c) || []).forEach(p => vis.add(p)));
  [...vis].forEach(c => (G.parents.get(c) || []).forEach(par => (G.children.get(par) || []).forEach(s => vis.add(s))));
  return vis;
}

// ---- NEUER Scope: Blutlinie ab Wurzel, Partner als Blätter, 2. Auswärts-Generation gekappt ----
function scopeBlut(G, istBlut, zielBaumDa, surnameNormVon, ankerCanon) {
  // 1) hoch zur Blut-Wurzel (solange ein Blut-Elternteil existiert)
  let wurzel = ankerCanon, guard = 0;
  while (guard++ < 200) {
    const blutEltern = [...(G.parents.get(wurzel) || [])].filter(istBlut);
    if (!blutEltern.length) break;
    wurzel = blutEltern[0];
  }
  // 2) runter mit Kappung
  const vis = new Set(), seen = new Set();
  const uncut = new Set();   // 2.+ auswärtige Generation, die NICHT gekappt wurde (kein Ziel-Baum) -> expandiert weiter = potenzieller Tief-Bleed
  const stack = [[wurzel, false]];   // [canon, elternAuswaerts]
  while (stack.length) {
    const [c, elternAus] = stack.pop();
    if (seen.has(c)) continue; seen.add(c);
    const selbstAus = !istBlut(c);
    if (selbstAus && elternAus) {
      if (zielBaumDa(surnameNormVon(c))) { vis.add(c); continue; }   // Übergangs-Blatt (gekappt)
      uncut.add(c);   // kein Ziel-Baum -> wird weiter expandiert (kann tief bleeden)
    }
    vis.add(c);
    (G.partners.get(c) || []).forEach(pc => vis.add(pc));   // Partner als Blatt
    (G.children.get(c) || []).forEach(k => stack.push([k, selbstAus]));
  }
  vis._uncut = uncut;
  return vis;
}

// ---- Migration simulieren: je identitaet_id EINE kanonische Person, Kanten umhängen ----
function simuliereMigration(snap) {
  const aktive = (snap.personen || []);
  // kanonische Wahl: user_id gesetzt > meiste nicht-leere sd-Felder > kleinste externe_id
  const score = (p) => {
    const sd = p.sd || {};
    const fuell = Object.values(sd).filter(v => v != null && v !== '').length;
    return [p.user_id ? 1 : 0, fuell, -(parseInt((p.externe_id || '').replace(/\D/g, ''), 10) || 1e9)];
  };
  const grupp = new Map();
  aktive.forEach(p => { if (p.identitaet_id) (grupp.get(p.identitaet_id) || grupp.set(p.identitaet_id, []).get(p.identitaet_id)).push(p); });
  const kanonVon = {};           // alt-uuid -> kanon-uuid
  grupp.forEach(list => {
    list.sort((a, b) => {
      const sa = score(a), sb = score(b);
      for (let i = 0; i < sa.length; i++) if (sb[i] !== sa[i]) return sb[i] - sa[i];
      return 0;
    });
    const kanon = list[0].id;
    list.forEach(p => { kanonVon[p.id] = kanon; });
  });
  const mapId = (uuid) => kanonVon[uuid] || uuid;

  const behalten = new Set(aktive.filter(p => mapId(p.id) === p.id).map(p => p.id));
  const personenNeu = aktive.filter(p => behalten.has(p.id)).map(p => ({ ...p, identitaet_id: null }));

  // Kanten umhängen, Selbstbezüge + Duplikate entfernen
  const seen = new Set(), bezNeu = [];
  (snap.beziehungen || []).forEach(b => {
    let a = mapId(b.a), c = mapId(b.b);
    if (a === c) return;
    let typ = b.typ;
    if (typ === 'ehepartner' && a > c) { const t = a; a = c; c = t; }
    const k = a + '|' + c + '|' + typ;
    if (seen.has(k)) return; seen.add(k);
    bezNeu.push({ a, b: c, typ });
  });
  return { personen: personenNeu, beziehungen: bezNeu, stammbaeume: snap.stammbaeume };
}

// ---- Report: pro Baum beide Scopes, Nachnamen-Histogramm, Fremd-Bäume markieren ----
function report(titel, snap) {
  console.log('\n========================================================');
  console.log('  ' + titel);
  console.log('  personen=' + (snap.personen || []).length + '  beziehungen=' + (snap.beziehungen || []).length);
  console.log('========================================================');
  const M = baueModell(snap);
  const G = baueGraph(M);
  const surnameNormCanon = (canon) => { const n = G.nodes.get(canon); return n ? norm(n.person.surname) : ''; };

  // alle Baum-Nachnamen (für „Fremd"-Erkennung)
  const baumNamen = new Set(Object.values(M.stammbaeume).map(s => norm((s.name || '').replace(/\s*\([^)]*\)\s*/g, ' '))));

  // Personen je Baum-Nachname zählen (für „fällt jemand raus?"-Plausibilität)
  Object.values(M.stammbaeume).forEach(s => {
    const treeNameN = norm((s.name || '').replace(/\s*\([^)]*\)\s*/g, ' '));
    // Wurzel EXAKT wie die App (findeStammbaumWurzel): Person im Baum OHNE Eltern-im-Baum mit
    // den MEISTEN Nachkommen-im-Baum (NICHT das stammbaeume.wurzel-Feld, das oft ein Blatt ist).
    const wurzelExt = appWurzel(M, s.id);
    if (!wurzelExt) { console.log(`\n[${s.name}] keine Person im Snapshot – übersprungen`); return; }
    const anker = G.canonOf(wurzelExt);
    if (!G.nodes.has(anker)) { console.log(`\n[${s.name}] Wurzel-Knoten fehlt – übersprungen`); return; }

    const istBlut = machIstBlut(M, G, treeNameN);
    const zielBaumDa = (sn) => sn && sn !== treeNameN && baumNamen.has(sn);

    const alt = scopeRadius(G, anker, 99, 0);                                  // = was vollGraphRender HEUTE zeichnet
    const neu = scopeBlut(G, istBlut, zielBaumDa, surnameNormCanon, anker);    // = neuer Blutlinien-Scope

    const histo = (set) => {
      const h = {};
      set.forEach(c => { const sn = surnameNormCanon(c) || '(leer)'; h[sn] = (h[sn] || 0) + 1; });
      return Object.entries(h).sort((a, b) => b[1] - a[1]);
    };
    const fremd = (set) => histo(set).filter(([sn]) => sn !== treeNameN && sn !== '(leer)' && baumNamen.has(sn));
    const entfernt = [...alt].filter(c => !neu.has(c));   // ALT \ NEU = was der Fix WEGNIMMT (soll Fremd-Bleed sein)
    const zusatz   = [...neu].filter(c => !alt.has(c));   // NEU \ ALT = was der Fix HINZUNIMMT (soll ~0 sein)

    console.log(`\n[${s.name}]  (Norm „${treeNameN}", Wurzel ${wurzelExt})`);
    console.log(`  ALT graphRadius: ${alt.size} Knoten | Fremd tief: ` +
      (fremd(alt).map(([sn, n]) => `${sn}×${n}`).join(', ') || '— keine'));
    console.log(`  NEU Blutlinie  : ${neu.size} Knoten | Fremd: ` +
      (fremd(neu).map(([sn, n]) => `${sn}×${n}`).join(', ') || '— keine'));
    console.log(`  → entfernt ${entfernt.length} (` +
      (histo(entfernt).map(([sn, n]) => `${sn}×${n}`).join(', ') || '–') + `)  | neu hinzu ${zusatz.length} (` +
      (histo(zusatz).map(([sn, n]) => `${sn}×${n}`).join(', ') || '–') + ')');
    const uncut = neu._uncut || new Set();
    if (uncut.size) console.log(`  ⚠ UNGEKAPPT (kein Ziel-Baum, expandiert tief): ${uncut.size} (` +
      histo(uncut).map(([sn, n]) => `${sn}×${n}`).join(', ') + ')');
  });
}

console.log('### RENDER-SCOPE-SIMULATION ###');
report('ZWILLINGS-WELT (aktueller Snapshot)', snapshot0);
report('SIMULIERT-MIGRIERTE WELT (Zwillinge kollabiert)', simuliereMigration(snapshot0));
console.log('\nLegende: „Fremd-Bäume tief" = Personen eines ANDEREN Baum-Nachnamens im Scope.');
console.log('  Partner als Blatt zählen mit; entscheidend ist, ob NEU << ALT bleedet (Ziel: NEU ~ keine fremden).');
