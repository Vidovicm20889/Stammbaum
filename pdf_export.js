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
// SCRUM-32: Export-Linienfarben an EINER Stelle. Beide Exportwege — Auto (pdfBaueSvg) und Board
// (druckfester Style-Block in pdfBoardSvg) — lesen dieselben Werte; vorher standen sie doppelt und
// wichen voneinander ab. Alle >= 3:1 gegen den Export-Hintergrund #fbfaf7 (WCAG 1.4.11, grafische
// Elemente). #c08a1e schaffte nur 2,92:1 und ist deshalb durch #b07d15 ersetzt (optisch fast gleich).
const PDF_FARBE_VERB   = '#9c7c3c';   // Eltern-Kind    3,75:1
const PDF_FARBE_EHE    = '#b07d15';   // Partner/Ehe    3,47:1  (war #c08a1e = 2,92:1)
const PDF_FARBE_EHE_EX = '#7a7f85';   // Ex-Partner     3,87:1
let pdfBusy = false;
let pdfEmpfTimer = null;
// SCRUM-27: merkt sich, ob der letzte PDF-Lauf auf ein RASTERBILD zurückfiel (Text dann nicht
// selektierbar/durchsuchbar). Wird in pdfExportPdf gesetzt und in pdfExportStart als Hinweis
// ausgegeben — Ende der stillen Degradierung.
let pdfWarRaster = false;
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
// Quelle vorbelegen: wer im Tabla-Modus auf „Export" drückt, will fast immer SEINE Anordnung.
// vorgabe überschreibt die Automatik (z. B. Aufruf aus dem Board-Kontextmenü).
function oeffnePdfExport(vorgabe) {
  const qs = document.getElementById('pdf-quelle');
  if (qs) {
    const imBoard = (typeof ansichtModus !== 'undefined' && ansichtModus === 'board');
    qs.value = vorgabe || (imBoard ? 'tabla' : 'auto');
  }
  pdfFuelleWurzelSelect();
  pdfUmfangChange();
  pdfQuelleChange();
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
// Quelle „Tabla": Positionen und Linien kommen fertig vom Bildschirm — Wurzel, Umfang, Filter und
// Layout steuern dort nichts mehr. Sie werden deshalb SICHTBAR deaktiviert (nicht still ignoriert):
// `disabled` fürs Formular + `.aus` fürs Ausgrauen inkl. pointer-events (fängt auch die
// suchbaren Selects ab, deren sichtbares Steuerelement das `disabled` des <select> nicht erbt).
function pdfQuelleChange() {
  const tabla = pdfQuelleIstTabla();
  document.querySelectorAll('#pdf-export-modal .pdf-nur-auto').forEach(el => {
    el.classList.toggle('aus', tabla);
    el.querySelectorAll('input, select, textarea, button').forEach(f => { f.disabled = tabla; });
  });
  const h = document.getElementById('pdf-quelle-hinweis');
  if (h) {
    const imBoard = (typeof ansichtModus !== 'undefined' && ansichtModus === 'board');
    // Tabla gewählt, aber der Board ist gar nicht offen -> das kann nichts exportieren.
    h.textContent = tabla ? (imBoard ? t('pdf_quelle_hinweis') : t('pdf_quelle_kein_board')) : '';
    h.classList.toggle('warn', tabla && !imBoard);
    h.style.display = tabla ? '' : 'none';
  }
  // SCRUM-25: Personenfilter gelten im Board-Export nicht (er gibt exakt den Bildschirm aus).
  // Statt wortlos auszugrauen den Grund NENNEN — der Nutzer soll sehen, warum, und den Ausweg
  // kennen (Karten im Board ausblenden). Text ist per data-i18n vorbefüllt, hier nur ein-/ausblenden.
  const fh = document.getElementById('pdf-filter-board-hinweis');
  if (fh) fh.style.display = tabla ? '' : 'none';
  pdfTitelblattSync();
  pdfBerechneEmpfehlung();
}
// SCRUM-21: Das Titelblatt entsteht bei PNG/SVG/Druck ausschliesslich in `pdfBaueSvg` — die läuft
// im Tabla-Zweig gar nicht (dort IST der Board-SVG das Ergebnis). Fuer `format === 'pdf'` baut
// `pdfExportPdf` das Titelblatt selbst aus `meta`, dort funktioniert es also auch bei Tabla.
// Ergebnis: genau die Kombination `tabla && format !== 'pdf'` war STILL wirkungslos — verboten
// laut AK5 von SCRUM-7. Deshalb hier sichtbar deaktivieren + Grund nennen.
// BEWUSST NICHT ueber die Klasse `.pdf-nur-auto`: die deaktiviert generell bei Tabla und wuerde
// die bei `Tabla + PDF` GUELTIGE Option grundlos mitsperren (neuer Fehler statt Korrektur).
function pdfTitelblattSync() {
  const cb = document.getElementById('pdf-titelblatt');
  const wrap = document.getElementById('pdf-titelblatt-wrap');
  const hint = document.getElementById('pdf-titelblatt-hinweis');
  if (!cb) return;
  const fmtEl = document.getElementById('pdf-format');
  const fmt = fmtEl ? fmtEl.value : 'pdf';
  const aus = pdfQuelleIstTabla() && fmt !== 'pdf';
  cb.disabled = aus;
  if (wrap) wrap.classList.toggle('aus', aus);
  if (hint) {
    hint.textContent = aus ? t('pdf_titelblatt_nur_pdf') : '';
    hint.style.display = aus ? '' : 'none';
  }
}
// Formatwechsel: bisher gab es dafuer gar keinen Handler — der Titelblatt-Zustand haette sonst
// erst beim naechsten Quellenwechsel nachgezogen (AK6: kein Nachhinken um einen Schritt).
function pdfFormatChange() {
  pdfTitelblattSync();
  if (typeof pdfBerechneEmpfehlung === 'function') pdfBerechneEmpfehlung();
}
function pdfQuelleIstTabla() {
  const q = document.getElementById('pdf-quelle');
  return !!(q && q.value === 'tabla');
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
    quelle: g('pdf-quelle') ? g('pdf-quelle').value : 'auto',
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
  // Quelle „Tabla": die Empfehlung stammt aus dem berechneten Modell und sagt über den frei
  // angeordneten Board nichts aus -> Kartenzahl direkt aus dem Renderzustand.
  if (typeof pdfQuelleIstTabla === 'function' && pdfQuelleIstTabla()) {
    const n = (typeof boardState !== 'undefined' && boardState && boardState.visible) ? boardState.visible.size : 0;
    box.innerHTML = t('pdf_empf_tabla', { n, papier: pdfAutoPapier(n) });
    return;
  }
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
    const at = { x1: l.x1, y1: l.y1, x2: l.x2, y2: l.y2, stroke: l.ehe ? PDF_FARBE_EHE : PDF_FARBE_VERB, 'stroke-width': 2.4, 'stroke-linecap': 'round' };
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
// Metadaten für die Quelle „Tabla": der Baum steht fest (der offene Board), es gibt keine
// gewählte Wurzel und keine Generationsrechnung. Gleiche Feldnamen wie pdfMetadaten, damit
// Titelblatt und Dateiname unverändert funktionieren.
function pdfMetaTabla(layout) {
  const sid = (typeof aktuellerStammbaumId !== 'undefined') ? aktuellerStammbaumId : null;
  const treeName = (sid && stammbaeumeListe[sid]) ? stammbaeumeListe[sid] : '';
  const treeZusatz = (sid && typeof stammbaeumeZusatz !== 'undefined' && stammbaeumeZusatz[sid]) ? stammbaeumeZusatz[sid] : '';
  const heute = new Date().toISOString().slice(0, 10);
  let ersteller = '';
  if (typeof meinProfil !== 'undefined' && meinProfil && (meinProfil.vorname || meinProfil.nachname)) {
    ersteller = nm(((meinProfil.vorname || '') + ' ' + (meinProfil.nachname || '')).trim());
  } else if (typeof aktuellerUser !== 'undefined' && aktuellerUser && aktuellerUser.email) {
    ersteller = aktuellerUser.email;
  }
  return {
    titel: t('pdf_meta_titel', { name: baumLabelNZ(treeName || '—', treeZusatz) || '—' }),
    treeName: nm(treeName) || 'stablo',
    datum: formatDatumLang(heute) || new Date().toLocaleDateString(),
    ersteller, personen: layout.personen.size, gens: 0, baeume: 1
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
  pdfWarRaster = false;   // SCRUM-27: pro Lauf neu bewerten
  if (opts.poster) pdfWarRaster = true;   // Poster/mehrseitig ist IMMER Raster (Kachelung, AK5)

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
    // SCRUM-27 Stufe 2 / FAMROOTS-35: Ist die Unicode-Schrift eingebettet (Noto Serif,
    // pdf_font.js), registriert pdfFontRegistrieren sie im jsPDF-VFS und liefert den Font-Namen.
    // Der Vektorweg oeffnet aber NUR, wenn die Schrift auch jedes vorkommende Zeichen setzen kann
    // (pdfVektorMoeglich -> pdfFontDeckt) — sonst stuenden im PDF leere Kaestchen, die schlimmere
    // Regression. Ohne Schrift (Base64 leer, Datei nicht geladen) bleibt es beim WinAnsi-Guard von
    // SCRUM-23 und beim Raster-Fallback mit Hinweis (AK7: sauberer Rueckfall, kein Mojibake).
    const textInhalt = pdfSvgTextInhalt(svg);
    const fontName = (typeof pdfFontRegistrieren === 'function') ? pdfFontRegistrieren(doc) : null;
    const winAnsiSafe = pdfWinAnsiSafe(textInhalt);
    const fontDeckt = !!fontName && (typeof pdfFontDeckt === 'function') && pdfFontDeckt(textInhalt);
    let vektorOk = false;
    if ((fontDeckt || winAnsiSafe) && typeof doc.svg === 'function') {
      try {
        if (fontDeckt) {
          doc.setFont(fontName);   // Doc-Default, wo das SVG nichts vorgibt
          // svg2pdf liest die font-family AM ELEMENT. Der Auto-Pfad schreibt „Georgia, serif", der
          // Board-Klon bekommt sie ueber die eingebettete Klassen-CSS — beides kennt jsPDF nicht.
          // Deshalb hier INLINE-STYLE (nicht Praesentationsattribut): inline schlaegt die
          // Klassenregel, ein Attribut waere schwaecher (gleiche Begruendung wie bei den
          // Linienfarben in SCRUM-24).
          svg.querySelectorAll('text, tspan').forEach(n => { n.style.fontFamily = fontName; });
        }
        await doc.svg(svg, { x, y, width: drawW, height: drawH }); vektorOk = true;
      } catch (e) { console.warn('svg2pdf fehlgeschlagen, Raster-Fallback:', e); }
    }
    if (!vektorOk) {
      // Blieb der Vektorweg zu (oder ist svg2pdf gescheitert), laeuft jetzt DOCH eine Canvas.
      // Cross-Origin-Avatare muessen dann raus, sonst wirft toDataURL einen SecurityError und der
      // Export bricht ab. pdfExportStart hat sie in diesem Fall stehen lassen (Vektor erwartet).
      if (opts.quelle === 'tabla') svg.querySelectorAll(PDF_BOARD_WEG_CANVAS).forEach(n => n.remove());
      let cScale = (drawW * 11.8) / vbW;                    // ~300 dpi (scharfe Schrift)
      cScale = Math.min(cScale, 16000 / Math.max(vbW, vbH));
      const canvas = await pdfSvgZuCanvas(svg, Math.max(0.3, cScale));
      doc.addImage(canvas, 'PNG', x, y, drawW, drawH);
      pdfWarRaster = true;   // SCRUM-27 Stufe 1: Text ist jetzt nicht selektierbar -> Hinweis
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

// ---- Quelle „Tabla": den angeordneten Board-Zustand als SVG -------------
// Statt ein Layout zu RECHNEN wird der live gezeichnete Board-SVG geklont und auf die belegte
// Fläche zugeschnitten. Dadurch stimmen Kartenpositionen (board_layout) UND manuelle Linien-
// Wegpunkte/Anker (board_linie) exakt mit dem Bildschirm überein. Das Ergebnis geht durch
// DIESELBE Ausgabekette wie das berechnete Layout -> PDF (Vektor via svg2pdf), PNG, SVG, Druck.
// Edit-Artefakte, die es nie ins PDF schaffen dürfen (Griffe, Trefferlinien, Connection-Points,
// Presence-Cursor, Marquee):
// SCRUM-23: ZWEI Listen statt einer. Edit-Artefakte duerfen NIE ins Ergebnis; Avatare dagegen nur
// dort entfernen, wo der Export ueber eine Canvas laeuft (Cross-Origin-Taint). Frueher flog `image`
// pauschal mit raus — auch bei SVG/Druck/Vektor-PDF, wo gar keine Canvas im Spiel ist.
const PDF_BOARD_WEG = [
  '.board-connect', '.board-connect-temp',      // ⊕-Schnellzugriff
  '.board-anker-griff-grp', '.board-linie-griff-grp',   // Endpunkt-/Wegpunkt-Griffe (inkl. Fasskreise)
  '.board-anker-griff', '.board-linie-griff', '.board-anker-hit',
  '.board-linie-hit',                           // unsichtbare Lösch-Trefferlinien
  '.board-cursors', '.board-marquee'            // Presence-Cursor, Auswahlrahmen
].join(', ');
// Nur bei Canvas-Wegen zu entfernen (Storage-Avatare sind cross-origin -> `toDataURL`/`toBlob`
// wuerfen sonst einen SecurityError und der Export BRICHT AB).
const PDF_BOARD_WEG_CANVAS = 'image';

// SCRUM-23 (AK7): Die Canvas-Frage EINMAL beantworten und weiterreichen — nicht an zwei Stellen
// nachbauen (Drift-Falle aus SCRUM-20). `textInhalt` ist optional: ohne ihn wird fuer den einseitigen
// PDF-Weg konservativ `true` angenommen (lieber ein Avatar zu wenig als ein abgebrochener Export).
// Belegte Matrix (siehe docs/ansichten-pdf.md):
//   svg / druck            -> nein  (serialisieren bzw. ins DOM haengen)
//   png                    -> JA
//   pdf + poster           -> JA    (Kacheln entstehen immer per Canvas)
//   pdf einseitig          -> nur wenn der Vektorweg ZU ist (dann Raster-Fallback statt doc.svg)
function pdfWinAnsiSafe(svgText) { return !/[^ -ÿ]/.test(String(svgText || '')); }
// FAMROOTS-35: Zeichen, für die Noto Serif GAR KEINEN Glyph besitzt (nicht etwa nur das Subset —
// die Schrift kennt weder Emoji noch ✉/♂/♀ noch den kompletten Pfeilblock U+2190–21FF). Ohne
// Ersatz bliebe jede Karte mit Zusatzfeldern ein Raster-Auslöser; mit der Schrift und OHNE Guard
// gäbe es leere Kästchen. Ersetzt wird NUR im Export — die Bildschirmkarten behalten ihre Emoji.
// Gewählt ist die klassische genealogische Notation (* Geburt, † Tod, oo Heirat): sprachneutral
// und vollständig von PDF_FONT_ABDECKUNG gedeckt.
const PDF_ZEICHEN_ERSATZ = {
  '\u{1F4CD}': '*',    // Geburtsort   -> wie beim Geburtsdatum
  '\u{1FAA6}': '†',    // Sterbeort    -> wie beim Sterbedatum
  '\u{1F48D}': 'oo',   // Hochzeit     -> genealogisches Heiratszeichen
  '\u{1F492}': 'oo',   // Hochzeitsort
  '\u{1F4BC}': '·',    // Beruf
  '\u{1F4DE}': '·',    // Telefon
  '✉': '@',       // E-Mail
  '♂': 'M',       // maennlich (entspricht personen.sex)
  '♀': 'F',       // weiblich
  '→': '»',       // Uebergangs-Badge (bl_uebergang)
  '\u{1F517}': '»',    // Cross-Tree-Chip / Verbund-Badge
};
// Regex ueber die Schluessel, mit u-Flag — sonst zerfallen die Emoji in Surrogat-Haelften und
// werden nicht getroffen (genau die Falle, an der die zweite Kette-Stelle unsichtbar blieb).
const PDF_ZEICHEN_ERSATZ_RE = new RegExp('[' + Object.keys(PDF_ZEICHEN_ERSATZ).join('') + ']', 'gu');

// Schreibt die Textinhalte des Export-SVG so um, dass die eingebettete Schrift sie setzen kann.
// Fasst ausschliesslich <text>/<tspan> an — Attribute, IDs und die eingebettete CSS bleiben
// unberuehrt (die landen nie als Glyph im PDF).
function pdfTextFuerSchrift(svg) {
  if (!svg || typeof svg.querySelectorAll !== 'function') return svg;
  svg.querySelectorAll('text, tspan').forEach(n => {
    n.childNodes.forEach(k => {
      if (k.nodeType !== 3 || !k.nodeValue) return;
      PDF_ZEICHEN_ERSATZ_RE.lastIndex = 0;              // /g -> Suchzustand vor jedem Lauf zuruecksetzen
      k.nodeValue = k.nodeValue.replace(PDF_ZEICHEN_ERSATZ_RE, z => PDF_ZEICHEN_ERSATZ[z] || '');
    });
  });
  return svg;
}

// Nur das, was im PDF wirklich als Glyph gesetzt wird. Der fruehere Test lief ueber den KOMPLETTEN
// serialisierten SVG-String — bei Quelle „Tabla" inklusive der eingebetteten App-CSS. Ein
// Sonderzeichen in irgendeiner CSS-Regel erzwang damit einen Raster-Fallback, obwohl es nie
// gezeichnet wird (FAMROOTS-35 AK10).
function pdfSvgTextInhalt(svg) {
  if (!svg || typeof svg.querySelectorAll !== 'function') return null;
  let s = '';
  svg.querySelectorAll('text, tspan').forEach(n => {
    n.childNodes.forEach(k => { if (k.nodeType === 3 && k.nodeValue) s += k.nodeValue; });
  });
  return s;
}

// Die Vektor-Entscheidung an EINER Stelle (SCRUM-23-Prinzip): sowohl die Avatar-Frage in
// pdfExportStart als auch der Guard in pdfExportPdf fragen hier. Vektor ist moeglich, wenn
// entweder die Unicode-Schrift JEDES vorkommende Zeichen darstellen kann ODER der Text ohnehin
// WinAnsi ist (dann reicht die jsPDF-Standardschrift, wie vor SCRUM-27).
function pdfVektorMoeglich(opts, textInhalt) {
  if (opts && opts.poster) return false;                // Poster wird immer gekachelt = Raster
  if (opts && opts.format !== 'pdf') return false;      // nur der PDF-Weg kennt doc.svg
  if (textInhalt == null) return false;                 // unbekannt -> konservativ
  const fontDa = (typeof pdfFontVerfuegbar === 'function') && pdfFontVerfuegbar();
  const deckt = fontDa && (typeof pdfFontDeckt === 'function') && pdfFontDeckt(textInhalt);
  return !!deckt || pdfWinAnsiSafe(textInhalt);
}

function pdfNutztCanvas(opts, textInhalt, vektorMoeglich) {
  const f = opts && opts.format;
  if (f === 'svg' || f === 'druck') return false;
  if (f === 'png') return true;
  if (opts && opts.poster) return true;
  if (textInhalt == null) return true;                  // unbekannt -> auf Nummer sicher
  // FAMROOTS-35: haengt nicht mehr an winAnsiSafe. Sobald die Schrift den Vektorweg oeffnet,
  // laeuft KEINE Canvas — die Avatare muessen dann drinbleiben, sonst faehrt das Vektor-PDF ohne
  // Kartenbilder aus. Faellt der Vektorweg doch noch, raeumt pdfExportPdf sie selbst ab.
  const vektor = (arguments.length > 2) ? !!vektorMoeglich : pdfVektorMoeglich(opts, textInhalt);
  return !vektor;
}

function pdfBoardSvg() {
  if (typeof ansichtModus === 'undefined' || ansichtModus !== 'board') return null;
  if (typeof boardState === 'undefined' || !boardState || !boardState.visible || !boardState.visible.size) return null;
  const xs = [], ys = [];
  boardState.visible.forEach(c => { if (boardState.PX.has(c)) { xs.push(boardState.PX.get(c)); ys.push(boardState.PY.get(c)); } });
  if (!xs.length) return null;
  const pad = 120;
  const minX = Math.min(...xs) - pad, minY = Math.min(...ys) - pad;
  const w = (Math.max(...xs) + pad) - minX, hgt = (Math.max(...ys) + pad) - minY;
  const src = document.getElementById('baum-svg'); if (!src) return null;
  const clone = src.cloneNode(true);
  clone.querySelectorAll(PDF_BOARD_WEG).forEach(n => n.remove());
  // Auswahl-Highlight ist Bildschirm-Zustand, kein Inhalt.
  clone.querySelectorAll('.selektiert').forEach(n => n.classList.remove('selektiert'));
  const g = clone.querySelector('g'); if (g) g.removeAttribute('transform');   // Zoom raus -> viewBox rahmt
  clone.setAttribute('viewBox', minX + ' ' + minY + ' ' + w + ' ' + hgt);
  clone.setAttribute('width', String(Math.round(w)));
  clone.setAttribute('height', String(Math.round(hgt)));
  clone.removeAttribute('style');
  clone.removeAttribute('class');
  // Same-origin CSS einbetten: sonst verliert der Klon außerhalb des Dokuments die Karten-/
  // Linien-Optik (Farben, Schrift, Strichstärken).
  let css = '';
  try { for (const sh of document.styleSheets) { try { for (const r of sh.cssRules) css += r.cssText + '\n'; } catch (e) {} } } catch (e) {}
  const styleEl = document.createElementNS(PDF_SVG_NS, 'style'); styleEl.textContent = css;
  clone.insertBefore(styleEl, clone.firstChild);
  // SCRUM-24: Druckfarben DIREKT aufs Element, nicht per <style>-Klassenregel.
  // Die Bildschirmfarben sind fuer den DUNKLEN Hintergrund (Bild4.jpg) gebaut — `.verbindung` ist
  // cremeweiss (rgba(255,248,220,.88)); der Export legt `#fbfaf7` darunter -> Linien unsichtbar,
  // auf Papier komplett weg. Der fruehere Fix haengte einen `<style>`-Block mit `!important` an —
  // das griff NICHT: eingebettete <style>-KLASSENSELEKTOREN werden von svg2pdf und beim Rastern
  // (SVG->Image->Canvas) nicht zuverlaessig aufgeloest, die cremeweisse Regel blieb (Nutzer: TEST NOK).
  // Der funktionierende Auto-Export (pdfBaueSvg, s. `stroke: l.ehe ? …`) setzt die Farbe ebenfalls
  // direkt am Element. Hier per INLINE-STYLE (nicht Praesentationsattribut): Inline-style schlaegt
  // die eingebettete `.verbindung`-Klassenregel; ein Attribut waere schwaecher als die Klasse. Die
  // Edit-`!important`-Regel matcht im Klon ohnehin nicht (Vorfahre `#baum-container` fehlt).
  // Farbwerte = dieselben Konstanten wie der Auto-Export (SCRUM-32), alle >= 3:1 gegen #fbfaf7.
  const faerbe = (sel, prop, farbe) => clone.querySelectorAll(sel).forEach(n => { n.style[prop] = farbe; });
  faerbe('.verbindung', 'stroke', PDF_FARBE_VERB);
  faerbe('.ehe-linie', 'stroke', PDF_FARBE_EHE);
  faerbe('.ehe-linie-ex', 'stroke', PDF_FARBE_EHE_EX);
  faerbe('.ehe-ex-label', 'fill', '#5c5346');                 // war #d9cfb6 = auf Weiss unlesbar
  clone.querySelectorAll('.verbindung-badge .verbindung-text').forEach(n => { n.style.fill = '#7a5f18'; n.style.stroke = 'none'; });
  faerbe('.paar-knoten', 'fill', PDF_FARBE_VERB);
  faerbe('.paar-knoten', 'stroke', PDF_FARBE_VERB);
  const bg = document.createElementNS(PDF_SVG_NS, 'rect');
  bg.setAttribute('x', minX); bg.setAttribute('y', minY);
  bg.setAttribute('width', w); bg.setAttribute('height', hgt); bg.setAttribute('fill', '#fbfaf7');
  clone.insertBefore(bg, styleEl.nextSibling);
  // Ersatz-„layout" für die gemeinsame Ausgabekette: pdfExportPdf braucht daraus nur
  // personen.size (Papierwahl) und cardW (Poster-Kachelung).
  const layout = { cards: new Array(boardState.visible.size), personen: new Set(boardState.visible), gens: 0, baeume: new Set(), cardW: 152 };
  return { svg: clone, layout };
}

// ---- Haupt-Ablauf --------------------------------------------------------
async function pdfExportStart() {
  if (pdfBusy) return;
  const opts = pdfSammleOptionen();
  const tabla = (opts.quelle === 'tabla');
  // Bei „Tabla" gibt es keine Wurzel-/Umfangswahl — der Board bringt seine Kartenmenge mit.
  if (!tabla && !opts.wurzel) { pdfHinweis(t('pdf_keine_wurzel'), true); return; }
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
    let layout, meta, svg;
    if (tabla) {
      // Kein Modell/Layout rechnen: der Board-SVG IST das Ergebnis.
      pdfSetProgress(35, t('pdf_prog_render')); await pdfTick();
      const b = pdfBoardSvg();
      if (!b) { pdfHinweis(t('pdf_quelle_kein_board'), true); return; }
      layout = b.layout; svg = b.svg; meta = pdfMetaTabla(layout);
    } else {
      let model = pdfBaueModell(opts);
      if (!model) { pdfHinweis(t('pdf_keine_wurzel'), true); return; }
      model = pdfFiltere(model, opts) || model;
      pdfSetProgress(25, t('pdf_prog_layout')); await pdfTick();
      layout = pdfLayout(model, opts);
      if (!layout.cards.length) { pdfHinweis(t('pdf_leer'), true); return; }
      pdfSetProgress(45, t('pdf_prog_render')); await pdfTick();
      meta = pdfMetadaten(layout, opts);
      const wantHeader = (opts.format !== 'pdf') && opts.titelblatt;
      svg = pdfBaueSvg(layout, opts, { header: wantHeader, meta });
    }
    pdfSetProgress(62, t('pdf_prog_ausgabe')); await pdfTick();
    // FAMROOTS-35: Zeichen ohne Glyph (Emoji, ✉ ♂ ♀, →) vor JEDER weiteren Entscheidung durch
    // darstellbare ersetzen — sonst blockierten sie den Vektorweg fuer die ganze Seite. Zentral
    // fuer BEIDE Quellen: der Board-Klon bringt sie ueber die Bildschirmkarten mit, der Auto-Pfad
    // koennte sie kuenftig ueber Personendaten bekommen.
    pdfTextFuerSchrift(svg);
    // SCRUM-23: Avatare erst JETZT entfernen — und nur, wenn der gewaehlte Weg ueber eine Canvas
    // laeuft. Vorher ging das nicht: die Zeichen-Entscheidung haengt am fertigen SVG-Text, steht in
    // `pdfBoardSvg` also noch gar nicht fest. Betrifft nur die Tabla-Quelle (der Auto-Pfad baut
    // sein SVG selbst, seine Fotos sind data:-URLs und damit canvas-sicher).
    const textInhalt = pdfSvgTextInhalt(svg);
    if (tabla && pdfNutztCanvas(opts, textInhalt, pdfVektorMoeglich(opts, textInhalt))) {
      svg.querySelectorAll(PDF_BOARD_WEG_CANVAS).forEach(n => n.remove());
    }
    const base = pdfDateiname(meta);
    if (opts.format === 'svg') pdfDownloadSvg(svg, base + '.svg');
    else if (opts.format === 'png') await pdfExportPng(svg, base + '.png');
    else if (opts.format === 'druck') { await pdfDrucke(svg); }
    else await pdfExportPdf(svg, layout, opts, meta, base + '.pdf');
    pdfSetProgress(100, t('pdf_prog_fertig'));
    // SCRUM-27 Stufe 1: Fiel das PDF auf ein Rasterbild zurück, sagen wir das jetzt — statt still
    // ein nicht-selektierbares Bild-PDF zu liefern. Nur bei format 'pdf' relevant (PNG ist gewollt
    // Raster, SVG ist Vektor, Druck hat keinen Fertig-Hinweis).
    if (opts.format === 'pdf' && pdfWarRaster) pdfHinweis(t('pdf_raster_hinweis'), true);
    else if (opts.format !== 'druck') pdfHinweis(t('pdf_fertig'), false);
  } catch (e) {
    console.error('PDF-Export-Fehler:', e);
    pdfHinweis(t('pdf_fehler') + (e && e.message ? ' (' + e.message + ')' : ''), true);
  } finally {
    pdfBusy = false;
    if (startBtn) startBtn.disabled = false;
    setTimeout(() => pdfSetProgress(0, ''), 1400);
  }
}
