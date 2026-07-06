// =====================================================================
// pdf_export.js — PDF-/Druck-Export des Stammbaums (ab v14.3 ausgelagert)
// Aus stammbaum.html herausgelöst (Auslagerung). MUSS VOR dem Haupt-Inline-<script>
// geladen werden (definiert globale pdf*-Funktionen + PDF_*-Konstanten; der Kosten-/
// Troskovi-PDF im Haupt-Script nutzt pdfEl/pdfSvgZuCanvas/pdfDownloadBlob/PDF_SVG_NS).
// Ruft Haupt-Globals (t, d3, escapeHtml, aktuelleWurzel, ladePdfLib, …) erst zur LAUFZEIT auf.
// jsPDF/svg2pdf werden lazy über ladePdfLib() geladen (siehe Haupt-Script).
// =====================================================================
// ============================================================
// PDF-/DRUCK-EXPORT DES STAMMBAUMS (ab v9.2)
// jsPDF + svg2pdf (siehe <head>). Baut ein eigenständiges, INLINE gestyltes SVG aus der
// d3-Layoutlogik (reuse von zeichneBaum/baueBaumDaten) und exportiert es als PDF/PNG/SVG
// oder druckt es. Vektor-PDF nur, wenn alle Zeichen WinAnsi-sicher sind (südslawische
// Diakritika/Kyrillisch in Namen sind es NICHT) — sonst hochauflösendes Raster (i18n-treu).
// ============================================================
const PDF_PAPIER_MM = { A4:[210,297], A3:[297,420], A2:[420,594], A1:[594,841], A0:[841,1189] };
const PDF_SVG_NS = 'http://www.w3.org/2000/svg';
const PDF_TREE_FARBEN = ['#c8a840','#5a9bd4','#7bb274','#d98b5f','#b07cc6','#d46a8a','#54b3b0','#c0b04a'];
let pdfBusy = false;
let pdfEmpfTimer = null;
function pdfEmpfDebounced() { clearTimeout(pdfEmpfTimer); pdfEmpfTimer = setTimeout(pdfBerechneEmpfehlung, 280); }

function pdfEl(tag, attrs, parent) {
  const e = document.createElementNS(PDF_SVG_NS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(e);
  return e;
}
function pdfTick() { return new Promise(r => setTimeout(r, 0)); }
function pdfSetProgress(p, txt) {
  const wrap = document.getElementById('pdf-progress');
  const fill = document.getElementById('pdf-progress-fill');
  const tx   = document.getElementById('pdf-progress-text');
  if (!wrap) return;
  wrap.style.display = p > 0 ? 'block' : 'none';
  fill.style.width = Math.max(0, Math.min(100, p)) + '%';
  tx.textContent = txt || '';
}
function pdfHinweis(msg, warn) {
  const h = document.getElementById('pdf-hinweisbox');
  if (!h) return;
  h.textContent = msg || '';
  h.classList.toggle('warn', !!warn);
}

// ---- Öffnen / Schließen --------------------------------------------------
function oeffnePdfExport() {
  pdfFuelleWurzelSelect();
  pdfUmfangChange();
  pdfBerechneEmpfehlung();
  pdfHinweis('', false);
  const m = document.getElementById('pdf-export-modal');
  m.classList.add('aktiv');
  // Live-Empfehlung bei Optionsänderung (einmalig anhängen)
  ['pdf-wurzel','pdf-verknuepft','pdf-filter-status','pdf-filter-unbestaetigt',
   'pdf-filter-privat','pdf-layout','pdf-gen-zurueck','pdf-gen-vor'].forEach(id => {
    const el = document.getElementById(id);
    if (el && !el._pdfL) { el._pdfL = true; el.addEventListener('change', pdfBerechneEmpfehlung); el.addEventListener('input', pdfEmpfDebounced); }
  });
  if (typeof macheAlleSelectsSuchbar === 'function') macheAlleSelectsSuchbar(m);
}
function schliessePdfExport() {
  document.getElementById('pdf-export-modal').classList.remove('aktiv');
}
function pdfUmfangChange() {
  const u = document.getElementById('pdf-umfang').value;
  document.getElementById('pdf-xgen-zurueck-wrap').style.display = (u === 'xgen') ? '' : 'none';
  pdfBerechneEmpfehlung();
}
// Sprachwechsel: dynamische Inhalte (Personennamen, Empfehlung) neu aufbauen
function pdfModalSprachUpdate() {
  const m = document.getElementById('pdf-export-modal');
  if (!m || !m.classList.contains('aktiv')) return;
  pdfFuelleWurzelSelect();
  pdfBerechneEmpfehlung();
  if (typeof macheAlleSelectsSuchbar === 'function') macheAlleSelectsSuchbar(m);
}

function pdfPersonLabel(p) {
  const name = nm(((p.given || '') + ' ' + (p.surname || '')).trim()) || nm(p.id || '?');
  const j = (p.birth_date && /\d{4}/.test(p.birth_date)) ? ' (* ' + p.birth_date.match(/\d{4}/)[0] + ')' : '';
  const baum = (p._tree && stammbaeumeListe[p._tree]) ? ' — ' + baumLabel(p._tree) : '';
  return name + j + baum;
}
function pdfFuelleWurzelSelect() {
  const sel = document.getElementById('pdf-wurzel');
  if (!sel) return;
  const aktuell = sel.value;
  let liste = Object.values(aktuelleDaten.persons || {});
  if (aktuellerStammbaumId) {
    const imBaum = liste.filter(p => p._tree === aktuellerStammbaumId);
    if (imBaum.length) liste = imBaum;
  }
  liste.sort((a, b) => nm(((a.surname||'')+(a.given||''))).localeCompare(nm(((b.surname||'')+(b.given||'')))));
  // Standard-Vorschlag: die EIGENE Karte des eingeloggten Nutzers (falls in der Liste),
  // sonst Fokusperson, sonst Stammbaum-Wurzel. Der Nutzer kann jederzeit aendern.
  const uid = (typeof aktuellerUser !== 'undefined' && aktuellerUser) ? aktuellerUser.id : null;
  const eigene = uid ? liste.find(p => p._userId === uid) : null;
  const standard = eigene ? eigene.id
                 : (fokusPersonId && aktuelleDaten.persons[fokusPersonId]) ? fokusPersonId
                 : (typeof aktuelleWurzel === 'function' ? aktuelleWurzel() : (liste[0] && liste[0].id));
  sel.innerHTML = liste.map(p => `<option value="${escapeHtml(p.id)}">${escapeHtml(pdfPersonLabel(p))}</option>`).join('');
  sel.value = (aktuell && aktuelleDaten.persons[aktuell]) ? aktuell : standard;
  if (!sel.value && liste[0]) sel.value = liste[0].id;
}

// ---- Optionen einsammeln -------------------------------------------------
function pdfSammleOptionen() {
  const g = id => document.getElementById(id);
  const layout = g('pdf-layout').value;
  return {
    wurzel: g('pdf-wurzel').value,
    umfang: g('pdf-umfang').value,
    genZurueck: g('pdf-gen-zurueck').value,
    genVor: g('pdf-gen-vor').value,
    verknuepft: g('pdf-verknuepft').checked,
    farbe: g('pdf-verknuepft-farbe').checked,
    status: g('pdf-filter-status').value,
    unbestaetigt: g('pdf-filter-unbestaetigt').checked,
    privat: g('pdf-filter-privat').checked,
    layout, kompakt: layout === 'kompakt',
    geburtsort: g('pdf-inhalt-geburtsort').checked,
    foto: g('pdf-inhalt-foto').checked,
    papier: g('pdf-papier').value,
    orientierung: g('pdf-orientierung').value,
    poster: g('pdf-poster').checked,
    titelblatt: g('pdf-titelblatt').checked,
    format: g('pdf-format').value
  };
}
function pdfTiefen(opts) {
  let oben;
  const genVor = Math.max(0, parseInt(opts.genVor, 10) || 0);
  switch (opts.umfang) {
    case 'person': oben = 0; break;
    case 'eltern': oben = 1; break;
    case 'grosseltern': oben = 2; break;
    case 'urgrosseltern': oben = 3; break;
    case 'xgen': oben = Math.max(0, parseInt(opts.genZurueck, 10) || 0); break;
    default: oben = 999;
  }
  let unten = (opts.umfang === 'alles') ? 999 : genVor;
  if (opts.layout === 'ahnen') unten = 0;
  if (opts.layout === 'nachkommen') { oben = 0; unten = (opts.umfang === 'alles') ? 999 : (genVor || 999); }
  return { oben, unten };
}
// Modell bauen (reuse baueBaumDaten). Für „verknüpfte Bäume" wird der Baumfilter
// temporär aufgehoben -> die ganze über Verknüpfungen verbundene Menge.
function pdfBaueModell(opts) {
  if (!opts.wurzel || !aktuelleDaten.persons[opts.wurzel]) return null;
  const { oben, unten } = pdfTiefen(opts);
  const saved = aktuellerStammbaumId;
  try {
    if (opts.verknuepft) aktuellerStammbaumId = null;
    return baueBaumDaten(opts.wurzel, unten, oben);
  } finally { aktuellerStammbaumId = saved; }
}
// Personenfilter (bottom-up; verbindende, nicht passende Knoten werden gedimmt statt entfernt).
function pdfPasst(p, opts) {
  const verstorben = !!(p.deceased || p.death_date);
  if (opts.status === 'lebend' && verstorben) return false;
  if (opts.status === 'verstorben' && !verstorben) return false;
  if (opts.unbestaetigt && !(p.birth_date || p.death_date)) return false;
  if (opts.privat && (p.privat === true || p.privat === 'ja' || p._privat === true)) return false;
  return true;
}
function pdfFiltere(node, opts) {
  if (!node) return null;
  const behalten = [];
  (node.children || []).forEach(c => { const k = pdfFiltere(c, opts); if (k) behalten.push(k); });
  node.children = behalten;
  const selbstOk = pdfPasst(node.person, opts);
  if (selbstOk || behalten.length) { node._dim = !selbstOk; return node; }
  return null;
}
function pdfModellZahlen(node) {
  const pers = new Set(), trees = new Set(); let maxD = 0;
  (function walk(n, d) {
    if (!n) return;
    pers.add(n.person.id); if (n.person._tree) trees.add(n.person._tree);
    (n.partners || []).forEach(p => { pers.add(p.id); if (p._tree) trees.add(p._tree); });
    maxD = Math.max(maxD, d);
    (n.children || []).forEach(c => walk(c, d + 1));
  })(node, 0);
  return { personen: pers.size, baeume: trees.size, gens: maxD + 1 };
}
function pdfAutoPapier(n) { if (n > 500) return 'A0'; if (n > 250) return 'A1'; if (n > 100) return 'A2'; if (n > 25) return 'A3'; return 'A4'; }

function pdfBerechneEmpfehlung() {
  const box = document.getElementById('pdf-empfehlung');
  if (!box) return;
  const opts = pdfSammleOptionen();
  if (!opts.wurzel) { box.innerHTML = ''; return; }
  let model = pdfBaueModell(opts);
  if (model) model = pdfFiltere(model, opts) || model;
  const info = model ? pdfModellZahlen(model) : { personen: 0, baeume: 0, gens: 0 };
  const papier = pdfAutoPapier(info.personen);
  const poster = info.personen > 500;
  box.innerHTML = t('pdf_empf_text', { n: info.personen, gen: info.gens, baeume: info.baeume, papier })
    + (poster ? '<br>' + t('pdf_empf_poster') : '');
}

// ---- Layout (d3.tree, orientierungs-parametrisiert) ----------------------
function pdfLayout(rootNode, opts) {
  const orientV = opts.layout !== 'horizontal';
  const cardW = opts.kompakt ? 120 : 152;
  const cardH = opts.kompakt ? 60 : 76;
  const breadthSpacing = orientV ? (cardW * 2 + 66) : (cardH * 2 + 70);
  const depthSpacing   = orientV ? (cardH + 94) : (cardW + 90);
  const partnerGap     = orientV ? (cardW + 10) : (cardH + 14);
  const halfDepth      = orientV ? cardH / 2 : cardW / 2;

  const hroot = d3.hierarchy(rootNode);
  d3.tree().nodeSize([breadthSpacing, depthSpacing]).separation((a, b) => a.parent === b.parent ? 1.0 : 1.35)(hroot);

  const toXY = (depth, breadth) => orientV ? { x: breadth, y: -depth } : { x: depth, y: breadth };
  const rootTree = (aktuelleDaten.persons[opts.wurzel] || {})._tree || null;
  const treeColorMap = {}; let colorIdx = 0;
  const treeColor = (tid) => {
    if (!opts.verknuepft || !opts.farbe || !tid || tid === rootTree) return null;
    if (!treeColorMap[tid]) treeColorMap[tid] = PDF_TREE_FARBEN[colorIdx++ % PDF_TREE_FARBEN.length];
    return treeColorMap[tid];
  };

  const cards = [], lines = [];
  const personen = new Set(), baeume = new Set();
  let minD = Infinity, maxD = -Infinity;

  hroot.each(n => {
    const d = n.data, p = d.person;
    const partners = d.partners || [];
    const slots = 1 + partners.length;
    const startOff = -partnerGap * (slots - 1) / 2;
    const depth = n.y;
    minD = Math.min(minD, n.depth); maxD = Math.max(maxD, n.depth);
    const slotBreadth = i => n.x + startOff + partnerGap * i;
    const mkCard = (per, i, fokusOk) => {
      const pt = toXY(depth, slotBreadth(i));
      personen.add(per.id); if (per._tree) baeume.add(per._tree);
      cards.push({ cx: pt.x, cy: pt.y, person: per, w: cardW, h: cardH, dim: !!d._dim,
        isFocus: fokusOk && per.id === opts.wurzel, isBlut: BLUTLINIE_IDS.has(per.id),
        treeColor: treeColor(per._tree) });
    };
    mkCard(p, 0, true);
    partners.forEach((pa, i) => mkCard(pa, i + 1, false));
    for (let i = 0; i < slots - 1; i++) {
      const a = toXY(depth, slotBreadth(i)), b = toXY(depth, slotBreadth(i + 1));
      lines.push({ x1: a.x, y1: a.y, x2: b.x, y2: b.y, ehe: true });
    }
    n._depth = depth; n._cb = n.x;
  });

  hroot.descendants().forEach(parent => {
    if (!parent.children || !parent.children.length) return;
    const kids = parent.children;
    const pEdge = parent._depth + halfDepth;
    const cEdge = kids[0]._depth - halfDepth;
    const mid = (pEdge + cEdge) / 2;
    const cb = parent._cb;
    let a = toXY(pEdge, cb), b = toXY(mid, cb);
    lines.push({ x1: a.x, y1: a.y, x2: b.x, y2: b.y });
    const bs = kids.map(k => k._cb).concat([cb]);
    a = toXY(mid, Math.min(...bs)); b = toXY(mid, Math.max(...bs));
    lines.push({ x1: a.x, y1: a.y, x2: b.x, y2: b.y });
    kids.forEach(k => {
      const c1 = toXY(mid, k._cb), c2 = toXY(k._depth - halfDepth, k._cb);
      lines.push({ x1: c1.x, y1: c1.y, x2: c2.x, y2: c2.y });
    });
  });

  let xMin = Infinity, yMin = Infinity, xMax = -Infinity, yMax = -Infinity;
  cards.forEach(c => {
    xMin = Math.min(xMin, c.cx - c.w / 2); xMax = Math.max(xMax, c.cx + c.w / 2);
    yMin = Math.min(yMin, c.cy - c.h / 2); yMax = Math.max(yMax, c.cy + c.h / 2);
  });
  const pad = 40;
  const bounds = { x: xMin - pad, y: yMin - pad, w: (xMax - xMin) + 2 * pad, h: (yMax - yMin) + 2 * pad };
  const gens = (maxD >= minD) ? (maxD - minD + 1) : 1;
  const legend = Object.keys(treeColorMap).map(tid => ({ name: baumLabelNZ(stammbaeumeListe[tid] || tid, stammbaeumeZusatz[tid] || ''), color: treeColorMap[tid] }));
  return { cards, lines, bounds, gens, personen, baeume, legend, cardW, cardH };
}

function pdfZeichneKarte(g, card, opts) {
  const { cx, cy, person: p, w, h } = card;
  const grp = pdfEl('g', card.dim ? { opacity: '0.45' } : {}, g);
  const sex = p.sex;
  const fill = sex === 'M' ? '#dbe9f3' : (sex === 'F' ? '#f4dde6' : '#fffaf0');
  let stroke = sex === 'M' ? '#4a7fa8' : (sex === 'F' ? '#9e4060' : '#9c7c3c');
  let sw = 1.8;
  if (card.isBlut) { stroke = '#c8a840'; sw = 3; }
  if (opts.verknuepft && opts.farbe && card.treeColor) { stroke = card.treeColor; sw = 3; }
  if (card.isFocus) { stroke = '#722f37'; sw = 3.4; }
  pdfEl('rect', { x: cx - w / 2, y: cy - h / 2, width: w, height: h, rx: 6, fill, stroke, 'stroke-width': sw }, grp);

  if (opts.foto) {
    const src = p.foto || p.avatar || p.bild || '';
    if (/^data:/.test(src)) pdfEl('image', { x: cx - w / 2 + 4, y: cy - h / 2 + 4, width: 18, height: 18, href: src, preserveAspectRatio: 'xMidYMid slice' }, grp);
  }

  const kompakt = opts.kompakt;
  const fz = kompakt ? { name: 11, maiden: 8.5, daten: 9 } : { name: 13, maiden: 10, daten: 11 };
  const zeilen = [];
  umbrucheNamen(nm(p.given || '?'), kompakt ? 14 : 17).forEach(l => zeilen.push({ t: l, c: 'name' }));
  const sn = nm(p.surname || ''); if (sn) umbrucheNamen(sn, kompakt ? 15 : 18).forEach(l => zeilen.push({ t: l, c: 'name' }));
  const mn = nm((p.ehename || '').trim()); if (mn) zeilen.push({ t: '(' + (mn.length > 16 ? mn.slice(0, 15) + '…' : mn) + ')', c: 'maiden' });
  if (p.birth_date || p.death_date) {
    let dat = p.birth_date ? '* ' + formatDatumLang(p.birth_date) : '';
    if (p.deceased || p.death_date) dat += (dat ? '  ' : '') + '† ' + (formatDatumLang(p.death_date) || '?');
    if (dat) zeilen.push({ t: dat, c: 'daten' });
  }
  if (opts.geburtsort) {
    const ort = nm((p.geburtsort || p.birth_place || '').trim());
    if (ort) zeilen.push({ t: ort.length > 22 ? ort.slice(0, 21) + '…' : ort, c: 'daten' });
  }
  const LH = kompakt ? 12 : 15;
  const startY = cy - ((zeilen.length - 1) * LH) / 2;
  zeilen.forEach((z, i) => {
    const fillc = z.c === 'maiden' ? '#6a5630' : (z.c === 'daten' ? '#3a2a10' : '#1a1008');
    const fs = z.c === 'name' ? fz.name : (z.c === 'maiden' ? fz.maiden : fz.daten);
    const te = pdfEl('text', { x: cx, y: startY + i * LH + 4, 'text-anchor': 'middle', 'font-family': 'Georgia, serif', 'font-size': fs, fill: fillc }, grp);
    if (z.c === 'name') te.setAttribute('font-weight', 'bold');
    if (z.c === 'maiden') te.setAttribute('font-style', 'italic');
    te.textContent = z.t;
  });
}

function pdfBaueSvg(layout, opts, extra) {
  const b = layout.bounds;
  const header = !!(extra && extra.header);
  const meta = extra && extra.meta;
  const headerH = header ? 130 : 0;
  const legendH = layout.legend.length ? (34 + layout.legend.length * 24) : 0;
  const W = b.w, H = b.h + headerH + legendH;
  const svg = document.createElementNS(PDF_SVG_NS, 'svg');
  svg.setAttribute('xmlns', PDF_SVG_NS);
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  svg.setAttribute('width', W); svg.setAttribute('height', H);
  pdfEl('rect', { x: 0, y: 0, width: W, height: H, fill: '#ffffff' }, svg);

  if (header && meta) {
    let hy = 46;
    const tt = pdfEl('text', { x: 30, y: hy, 'font-family': 'Georgia, serif', 'font-size': 30, 'font-weight': 'bold', fill: '#722f37' }, svg);
    tt.textContent = meta.titel; hy += 30;
    [t('pdf_meta_datum', { d: meta.datum }),
     t('pdf_meta_personen', { n: meta.personen }) + '    ' + t('pdf_meta_gen', { n: meta.gens }) + '    ' + t('pdf_meta_baeume', { n: meta.baeume })
    ].forEach(l => { const e = pdfEl('text', { x: 30, y: hy, 'font-family': 'Georgia, serif', 'font-size': 15, fill: '#2c2418' }, svg); e.textContent = l; hy += 22; });
  }

  const g = pdfEl('g', { transform: `translate(${-b.x},${-b.y + headerH})` }, svg);
  layout.lines.forEach(l => {
    const at = { x1: l.x1, y1: l.y1, x2: l.x2, y2: l.y2, stroke: l.ehe ? '#c08a1e' : '#9c7c3c', 'stroke-width': 2.4, 'stroke-linecap': 'round' };
    if (l.ehe) at['stroke-dasharray'] = '6 3';
    pdfEl('line', at, g);
  });
  layout.cards.forEach(c => pdfZeichneKarte(g, c, opts));

  if (layout.legend.length) {
    let yy = b.h + headerH + 22;
    const lt = pdfEl('text', { x: 30, y: yy, 'font-family': 'Georgia, serif', 'font-size': 16, fill: '#722f37' }, svg);
    lt.textContent = t('pdf_legend_titel'); yy += 24;
    layout.legend.forEach(le => {
      pdfEl('rect', { x: 30, y: yy - 12, width: 22, height: 14, fill: le.color, stroke: '#000', 'stroke-width': 0.5 }, svg);
      const e = pdfEl('text', { x: 60, y: yy, 'font-family': 'Georgia, serif', 'font-size': 14, fill: '#2c2418' }, svg);
      e.textContent = nm(le.name); yy += 24;
    });
  }
  return svg;
}

// ---- Metadaten / Titelblatt ----------------------------------------------
function pdfMetadaten(layout, opts) {
  const rp = aktuelleDaten.persons[opts.wurzel] || {};
  const treeName = (rp._tree && stammbaeumeListe[rp._tree]) ? stammbaeumeListe[rp._tree] : (rp.surname || '');
  // Zusatz zur Unterscheidung gleichnamiger Bäume nur im sichtbaren Titel (nicht im Dateinamen)
  const treeZusatz = (rp._tree && stammbaeumeZusatz[rp._tree]) ? stammbaeumeZusatz[rp._tree] : '';
  const titelName = baumLabelNZ(treeName || '—', treeZusatz);
  const heute = new Date().toISOString().slice(0, 10);
  const datum = formatDatumLang(heute) || new Date().toLocaleDateString();
  let ersteller = '';
  if (typeof meinProfil !== 'undefined' && meinProfil && (meinProfil.vorname || meinProfil.nachname)) {
    ersteller = nm(((meinProfil.vorname || '') + ' ' + (meinProfil.nachname || '')).trim());
  } else if (typeof aktuellerUser !== 'undefined' && aktuellerUser && aktuellerUser.email) {
    ersteller = aktuellerUser.email;
  }
  return {
    titel: t('pdf_meta_titel', { name: titelName || '—' }),
    treeName: nm(treeName) || 'stablo', datum, ersteller,
    personen: layout.personen.size, gens: layout.gens, baeume: layout.baeume.size
  };
}
function pdfCanvasWrap(ctx, text, cx, cy, maxW, lh) {
  const words = (text || '').split(' '); let line = ''; const zeilen = [];
  words.forEach(w => { const test = line ? line + ' ' + w : w; if (ctx.measureText(test).width > maxW && line) { zeilen.push(line); line = w; } else line = test; });
  if (line) zeilen.push(line);
  const startY = cy - (zeilen.length - 1) * lh / 2;
  zeilen.forEach((l, i) => ctx.fillText(l, cx, startY + i * lh));
}
function pdfTitelCanvas(meta, pageW_mm, pageH_mm, pxPerMm) {
  const W = Math.round(pageW_mm * pxPerMm), Hp = Math.round(pageH_mm * pxPerMm);
  const c = document.createElement('canvas'); c.width = W; c.height = Hp;
  const x = c.getContext('2d');
  x.fillStyle = '#ffffff'; x.fillRect(0, 0, W, Hp);
  x.textAlign = 'center';
  x.fillStyle = '#722f37'; x.font = 'bold ' + (pxPerMm * 9) + 'px Georgia, serif';
  pdfCanvasWrap(x, meta.titel, W / 2, Hp * 0.30, W * 0.82, pxPerMm * 11);
  x.strokeStyle = '#722f37'; x.lineWidth = Math.max(1, pxPerMm * 0.4);
  x.beginPath(); x.moveTo(W * 0.32, Hp * 0.37); x.lineTo(W * 0.68, Hp * 0.37); x.stroke();
  x.fillStyle = '#2c2418'; x.font = (pxPerMm * 4.6) + 'px Georgia, serif';
  const lines = [
    t('pdf_meta_datum', { d: meta.datum }),
    meta.ersteller ? t('pdf_meta_ersteller', { e: meta.ersteller }) : null,
    t('pdf_meta_personen', { n: meta.personen }),
    t('pdf_meta_gen', { n: meta.gens }),
    t('pdf_meta_baeume', { n: meta.baeume })
  ].filter(Boolean);
  let yy = Hp * 0.47; lines.forEach(l => { x.fillText(l, W / 2, yy); yy += pxPerMm * 7; });
  x.fillStyle = '#9c7c3c'; x.font = 'italic ' + (pxPerMm * 4) + 'px Georgia, serif';
  x.fillText('FamilyRoots', W / 2, Hp * 0.93);
  return c;
}

// ---- SVG -> Canvas / Downloads ------------------------------------------
async function pdfSvgZuCanvas(svg, scale) {
  const s = new XMLSerializer().serializeToString(svg);
  const blob = new Blob([s], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  try {
    const img = await new Promise((res, rej) => { const im = new Image(); im.onload = () => res(im); im.onerror = () => rej(new Error('SVG-Bild')); im.src = url; });
    const vbW = parseFloat(svg.getAttribute('width')), vbH = parseFloat(svg.getAttribute('height'));
    const cw = Math.max(1, Math.round(vbW * scale)), ch = Math.max(1, Math.round(vbH * scale));
    const canvas = document.createElement('canvas'); canvas.width = cw; canvas.height = ch;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, cw, ch);
    ctx.drawImage(img, 0, 0, cw, ch);
    return canvas;
  } finally { URL.revokeObjectURL(url); }
}
function pdfDownloadBlob(blob, name) {
  const u = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = u; a.download = name;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(u), 4000);
}
function pdfDateiname(meta) {
  const base = (meta.treeName || 'stablo').normalize('NFKD').replace(/[^\w\-]+/g, '_').replace(/^_+|_+$/g, '') || 'stablo';
  return 'Stammbaum_' + base;
}

// ---- Ausgabe-Pfade -------------------------------------------------------
async function pdfExportPng(svg, fname) {
  const vbW = parseFloat(svg.getAttribute('width')), vbH = parseFloat(svg.getAttribute('height'));
  const cap = 16000; let scale = Math.min(3, cap / Math.max(vbW, vbH)); if (!(scale > 0)) scale = 1;
  const canvas = await pdfSvgZuCanvas(svg, scale);
  await new Promise(res => canvas.toBlob(b => { if (b) pdfDownloadBlob(b, fname); res(); }, 'image/png'));
}
function pdfDownloadSvg(svg, fname) {
  const s = new XMLSerializer().serializeToString(svg);
  pdfDownloadBlob(new Blob([s], { type: 'image/svg+xml;charset=utf-8' }), fname);
}
async function pdfDrucke(svg) {
  const stage = document.getElementById('pdf-print-stage');
  stage.innerHTML = '';
  const clone = svg.cloneNode(true);
  clone.removeAttribute('width'); clone.removeAttribute('height');
  stage.appendChild(clone);
  schliessePdfExport();
  await pdfTick();
  document.body.classList.add('print-pdf');   // @media print (body.print-pdf) zeigt nur die Druck-Bühne
  const aufraeumen = () => { document.body.classList.remove('print-pdf'); window.removeEventListener('afterprint', aufraeumen); };
  window.addEventListener('afterprint', aufraeumen);
  setTimeout(aufraeumen, 2000);
  window.print();
  setTimeout(() => { stage.innerHTML = ''; }, 1500);
}
async function pdfExportPdf(svg, layout, opts, meta, fname) {
  const Ctor = (window.jspdf && window.jspdf.jsPDF) ? window.jspdf.jsPDF : (window.jsPDF || null);
  if (!Ctor) { pdfHinweis(t('pdf_kein_jspdf'), true); return; }
  const n = layout.personen.size;
  const paper = (opts.papier === 'auto') ? pdfAutoPapier(n) : opts.papier;
  const vbW = parseFloat(svg.getAttribute('width')), vbH = parseFloat(svg.getAttribute('height'));
  let orientation = opts.orientierung;
  if (orientation === 'auto') orientation = (vbW >= vbH) ? 'landscape' : 'portrait';
  const dims = PDF_PAPIER_MM[paper] || PDF_PAPIER_MM.A4;
  const pageW = orientation === 'landscape' ? dims[1] : dims[0];
  const pageH = orientation === 'landscape' ? dims[0] : dims[1];
  const fmt = paper.toLowerCase();
  const doc = new Ctor({ orientation, unit: 'mm', format: fmt });
  let pages = 0;

  if (opts.titelblatt) {
    const tc = pdfTitelCanvas(meta, pageW, pageH, 5);
    doc.setFillColor(255, 255, 255); doc.rect(0, 0, pageW, pageH, 'F');
    doc.addImage(tc, 'PNG', 0, 0, pageW, pageH); pages = 1;
  }

  const margin = 8;
  if (!opts.poster) {
    if (pages > 0) doc.addPage(fmt, orientation);
    doc.setFillColor(255, 255, 255); doc.rect(0, 0, pageW, pageH, 'F');
    const availW = pageW - 2 * margin, availH = pageH - 2 * margin;
    const sc = Math.min(availW / vbW, availH / vbH);
    const drawW = vbW * sc, drawH = vbH * sc, x = (pageW - drawW) / 2, y = (pageH - drawH) / 2;
    const svgText = new XMLSerializer().serializeToString(svg);
    const winAnsiSafe = !/[^\u0000-\u00FF]/.test(svgText);
    let vektorOk = false;
    if (winAnsiSafe && typeof doc.svg === 'function') {
      try { await doc.svg(svg, { x, y, width: drawW, height: drawH }); vektorOk = true; } catch (e) { console.warn('svg2pdf fehlgeschlagen, Raster-Fallback:', e); }
    }
    if (!vektorOk) {
      let cScale = (drawW * 11.8) / vbW;                    // ~300 dpi (scharfe Schrift)
      cScale = Math.min(cScale, 16000 / Math.max(vbW, vbH));
      const canvas = await pdfSvgZuCanvas(svg, Math.max(0.3, cScale));
      doc.addImage(canvas, 'PNG', x, y, drawW, drawH);
    }
  } else {
    // Poster: ein großes Raster, in Seiten-Kacheln mit Überlappung zerlegt.
    const mmPerPx = 26 / layout.cardW;                      // Karte ~26 mm breit -> lesbar
    const contentW = vbW * mmPerPx, contentH = vbH * mmPerPx;
    const overlap = 10;
    const usableW = pageW - 2 * margin, usableH = pageH - 2 * margin;
    const stepW = Math.max(20, usableW - overlap), stepH = Math.max(20, usableH - overlap);
    const cols = Math.max(1, Math.ceil((contentW - overlap) / stepW));
    const rows = Math.max(1, Math.ceil((contentH - overlap) / stepH));
    let pxPerMm = 8;                                        // ~200 dpi je Kachel
    let canvasScale = pxPerMm * mmPerPx;
    canvasScale = Math.min(canvasScale, 16000 / Math.max(vbW, vbH));
    const big = await pdfSvgZuCanvas(svg, canvasScale);
    const pxmm = canvasScale / mmPerPx;                     // big-px pro mm
    const tilePxW = usableW * pxmm, tilePxH = usableH * pxmm;
    for (let ry = 0; ry < rows; ry++) {
      for (let cx = 0; cx < cols; cx++) {
        const sx = cx * stepW * pxmm, sy = ry * stepH * pxmm;
        const sw = Math.min(tilePxW, big.width - sx), sh = Math.min(tilePxH, big.height - sy);
        if (sw <= 1 || sh <= 1) continue;
        const tmp = document.createElement('canvas'); tmp.width = Math.ceil(sw); tmp.height = Math.ceil(sh);
        const tctx = tmp.getContext('2d');
        tctx.fillStyle = '#ffffff'; tctx.fillRect(0, 0, tmp.width, tmp.height);
        tctx.drawImage(big, sx, sy, sw, sh, 0, 0, sw, sh);
        const seiteNr = ry * cols + cx + 1;
        const fpx = Math.max(11, Math.round(3.5 * pxmm));
        tctx.fillStyle = '#6b5836'; tctx.font = fpx + 'px Georgia, serif'; tctx.textAlign = 'right';
        tctx.fillText(t('pdf_seite', { n: seiteNr, r: ry + 1, c: cx + 1 }), tmp.width - fpx, tmp.height - fpx);
        if (pages > 0) doc.addPage(fmt, orientation);
        pages++;
        doc.setFillColor(255, 255, 255); doc.rect(0, 0, pageW, pageH, 'F');
        doc.addImage(tmp, 'PNG', margin, margin, sw / pxmm, sh / pxmm);
        await pdfTick();
      }
    }
  }
  doc.save(fname);
}

// ---- Haupt-Ablauf --------------------------------------------------------
async function pdfExportStart() {
  if (pdfBusy) return;
  const opts = pdfSammleOptionen();
  if (!opts.wurzel) { pdfHinweis(t('pdf_keine_wurzel'), true); return; }
  if (typeof track === 'function') track('pdf_export', { format: opts.format });   // Analytik
  // jsPDF/svg2pdf erst bei Bedarf laden (PDF + Browser-Druck nutzen jsPDF; PNG/SVG nicht).
  if (opts.format === 'pdf' || opts.format === 'druck') {
    pdfHinweis(t('gam_laden'), false);   // kurzer „Wird geladen…"-Hinweis während des Lib-Downloads
    await ladePdfLib();
    pdfHinweis('', false);
  }
  if (opts.format === 'pdf') {
    const Ctor = (window.jspdf && window.jspdf.jsPDF) ? window.jspdf.jsPDF : (window.jsPDF || null);
    if (!Ctor) { pdfHinweis(t('pdf_kein_jspdf'), true); return; }
  }
  pdfBusy = true;
  const startBtn = document.getElementById('pdf-start-btn');
  if (startBtn) startBtn.disabled = true;
  pdfHinweis('', false);
  pdfSetProgress(5, t('pdf_prog_modell'));
  try {
    await pdfTick();
    let model = pdfBaueModell(opts);
    if (!model) { pdfHinweis(t('pdf_keine_wurzel'), true); return; }
    model = pdfFiltere(model, opts) || model;
    pdfSetProgress(25, t('pdf_prog_layout')); await pdfTick();
    const layout = pdfLayout(model, opts);
    if (!layout.cards.length) { pdfHinweis(t('pdf_leer'), true); return; }
    pdfSetProgress(45, t('pdf_prog_render')); await pdfTick();
    const meta = pdfMetadaten(layout, opts);
    const wantHeader = (opts.format !== 'pdf') && opts.titelblatt;
    const svg = pdfBaueSvg(layout, opts, { header: wantHeader, meta });
    pdfSetProgress(62, t('pdf_prog_ausgabe')); await pdfTick();
    const base = pdfDateiname(meta);
    if (opts.format === 'svg') pdfDownloadSvg(svg, base + '.svg');
    else if (opts.format === 'png') await pdfExportPng(svg, base + '.png');
    else if (opts.format === 'druck') { await pdfDrucke(svg); }
    else await pdfExportPdf(svg, layout, opts, meta, base + '.pdf');
    pdfSetProgress(100, t('pdf_prog_fertig'));
    if (opts.format !== 'druck') pdfHinweis(t('pdf_fertig'), false);
  } catch (e) {
    console.error('PDF-Export-Fehler:', e);
    pdfHinweis(t('pdf_fehler') + (e && e.message ? ' (' + e.message + ')' : ''), true);
  } finally {
    pdfBusy = false;
    if (startBtn) startBtn.disabled = false;
    setTimeout(() => pdfSetProgress(0, ''), 1400);
  }
}
