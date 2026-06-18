// =====================================================================
// chat.js — 1:1- und Gruppen-Chat (ab v14.4 ausgelagert)
// Aus stammbaum.html herausgelöst. MUSS VOR dem Haupt-Inline-<script> geladen werden
// (definiert globale chat*-Funktionen + -State). Ruft Haupt-Globals (sbClient, aktuellerUser,
// t, nm, escapeHtml, zeigeBestaetigung, …) erst zur LAUFZEIT auf. Lifecycle: startChat()/
// stopChat() aus dem Login-/Logout-Flow, chatSpracheUpdate() aus wechselSprache (typeof-Guard).
// =====================================================================
// ============================================================
// CHAT (1:1 + Gruppen, verbundweit) — Supabase Realtime (wie Live-Sync der Baumdaten)
// Geltungsbereich = verbund_id (CLAUDE.md). Transport: echte RLS-SELECT-Policies +
// Publication supabase_realtime. Der Realtime-Callback setzt den Inaktivitäts-/
// Auto-Logout-Timer NICHT zurück (eingehende Nachrichten zählen nicht als Aktivität).
// ============================================================
let chatNutzer       = [];     // verbund_nutzer(): [{user_id, anzeigename, avatar_url, familie_name, baum_namen}]
let chatNutzerMap    = {};     // user_id -> Nutzer
let chatListe        = [];     // [{id, typ, name, erstellt_am, teilnehmer:[{user_id,ist_gruppen_admin}], letzteText, letzteZeit, letzteGeloescht, ungelesen}]
let chatById         = {};     // id -> Eintrag aus chatListe
let chatAktivId      = null;   // aktuell geöffneter Chat
let chatNachrichten  = [];     // Nachrichten des offenen Chats
let chatNeuAuswahl   = new Set();
let chatGeladen      = false;  // Nutzerliste schon geladen?
let chatChannel      = null;   // Realtime-Channel
let chatLiveTimer    = null;
let chatLivePending  = false;
let chatTippInit     = false;  // tippAuswahl nur einmal binden

// ---- Lifecycle (analog startRealtimeSync/startPresence) ----------------------
async function startChat() {
  stopChat();
  if (!aktuellerUser || !sbClient) return;
  try {
    await chatLadeNutzer();
    await chatLadeListe();
  } catch (e) { console.warn('Chat-Initialladung:', e); }
  try {
    chatChannel = sbClient.channel('chat-sync')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'chat_nachrichten' }, () => chatLiveAnstossen())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'chat_teilnehmer'  }, () => chatLiveAnstossen())
      .subscribe();
  } catch (e) { console.warn('Chat-Realtime nicht verfügbar:', e); chatChannel = null; }
}
function stopChat() {
  if (chatLiveTimer) { clearTimeout(chatLiveTimer); chatLiveTimer = null; }
  chatLivePending = false;
  if (chatChannel) { try { sbClient.removeChannel(chatChannel); } catch (e) {} chatChannel = null; }
  chatNutzer = []; chatNutzerMap = {}; chatListe = []; chatById = {};
  chatAktivId = null; chatNachrichten = []; chatNeuAuswahl.clear(); chatGeladen = false;
  chatBadgeAktualisieren();
}
// Debounced Live-Reload; bei verstecktem Tab aufschieben (visibilitychange holt nach).
// WICHTIG: KEIN resetInaktivTimer/sessAktivitaet hier (wie Live-Sync/Presence).
function chatLiveAnstossen() {
  if (!aktuellerUser) return;
  if (document.visibilityState !== 'visible') { chatLivePending = true; return; }
  if (chatLiveTimer) clearTimeout(chatLiveTimer);
  chatLiveTimer = setTimeout(chatLiveAusfuehren, 500);
}
async function chatLiveAusfuehren() {
  chatLiveTimer = null;
  if (!aktuellerUser) return;
  try {
    await chatLadeListe();
    if (chatAktivId && document.getElementById('chat-modal').classList.contains('aktiv')) {
      await chatLadeNachrichten(chatAktivId, true);
      // Unterhaltung ist offen & sichtbar (Tab visible, sonst liefe diese Funktion gar nicht):
      // eingehende Nachrichten SOFORT als gelesen markieren, damit das Ungelesen-Badge nicht
      // stehen bleibt (Bug: "1" blieb bis zum erneuten Klick auf die Person). Nur markieren,
      // wenn wirklich Ungelesene da sind — sonst löst das eigene chat_gelesen-UPDATE wieder ein
      // Realtime-Event aus → Endlosschleife. Nach dem Markieren ist ungelesen=0 → Schleife endet.
      const aktiv = chatById[chatAktivId];
      if (aktiv && aktiv.ungelesen > 0) {
        try { await sbClient.rpc('chat_gelesen', { p_chat: chatAktivId }); } catch (e) {}
        await chatLadeListe();   // Liste + Badge nach dem Gelesen-Markieren aktualisieren
      }
    }
  } catch (e) { console.warn('Chat-Live-Reload:', e); }
  finally { if (chatLivePending) { chatLivePending = false; chatLiveAnstossen(); } }
}
// Nachhol-Refresh, wenn der Tab wieder sichtbar wird (kein Timer-Reset).
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && chatLivePending && aktuellerUser) {
    chatLivePending = false; chatLiveAnstossen();
  }
});

// ---- Datenladen -------------------------------------------------------------
async function chatLadeNutzer() {
  // Verbund-Nutzer (wie bisher) + genehmigte verbundübergreifende Kontakte (Instagram-Feature).
  const [rv, rk] = await Promise.all([
    sbClient.rpc('verbund_nutzer'),
    sbClient.rpc('meine_kontakte')
  ]);
  if (rv.error) { console.warn('verbund_nutzer:', rv.error.message); }
  if (rk.error) { console.warn('meine_kontakte:', rk.error.message); }
  chatNutzer = rv.error ? [] : (rv.data || []);
  chatNutzerMap = {};
  chatNutzer.forEach(u => { chatNutzerMap[u.user_id] = u; });
  // Kontakte mergen (nur falls noch nicht als Verbund-Nutzer enthalten); Marker _kontakt.
  (rk.error ? [] : (rk.data || [])).forEach(u => {
    if (chatNutzerMap[u.user_id]) return;
    const eintrag = { user_id: u.user_id, anzeigename: u.anzeigename, avatar_url: u.avatar_url,
                      familie_name: u.familie_name, baum_namen: '', _kontakt: true };
    chatNutzer.push(eintrag);
    chatNutzerMap[u.user_id] = eintrag;
  });
  chatGeladen = true;
}
async function chatLadeListe() {
  if (!aktuellerUser) return;
  const me = aktuellerUser.id;
  const { data: meine, error: e1 } = await sbClient
    .from('chat_teilnehmer').select('chat_id, zuletzt_gelesen_am').eq('user_id', me);
  if (e1) { console.warn('chat_teilnehmer (eigene):', e1.message); return; }
  const ids = (meine || []).map(r => r.chat_id);
  if (!ids.length) { chatListe = []; chatById = {}; chatRenderListe(); chatBadgeAktualisieren(); return; }
  const gelesenMap = {};
  (meine || []).forEach(r => { gelesenMap[r.chat_id] = r.zuletzt_gelesen_am; });

  const [{ data: chats }, { data: alleT }, { data: msgs }] = await Promise.all([
    sbClient.from('chats').select('id, typ, name, erstellt_am').in('id', ids),
    sbClient.from('chat_teilnehmer').select('chat_id, user_id, ist_gruppen_admin').in('chat_id', ids),
    sbClient.from('chat_nachrichten').select('chat_id, text, erstellt_am, absender_id, geloescht')
      .in('chat_id', ids).order('erstellt_am', { ascending: false }).limit(500)
  ]);

  const teilnByChat = {};
  (alleT || []).forEach(t => { (teilnByChat[t.chat_id] = teilnByChat[t.chat_id] || []).push(t); });

  chatListe = (chats || []).map(c => {
    const gelesen = gelesenMap[c.id];
    const chatMsgs = (msgs || []).filter(m => m.chat_id === c.id);   // bereits desc sortiert
    const letzte = chatMsgs[0] || null;
    const ungelesen = chatMsgs.filter(m =>
      m.absender_id !== me && (!gelesen || new Date(m.erstellt_am) > new Date(gelesen))).length;
    return {
      id: c.id, typ: c.typ, name: c.name, erstellt_am: c.erstellt_am,
      teilnehmer: teilnByChat[c.id] || [],
      letzteText: letzte ? (letzte.geloescht ? '' : letzte.text) : '',
      letzteGeloescht: letzte ? letzte.geloescht : false,
      letzteZeit: letzte ? letzte.erstellt_am : c.erstellt_am,
      ungelesen
    };
  }).sort((a, b) => new Date(b.letzteZeit) - new Date(a.letzteZeit));

  chatById = {}; chatListe.forEach(c => { chatById[c.id] = c; });
  chatRenderListe();
  chatBadgeAktualisieren();
}
async function chatLadeNachrichten(chatId, nurRender) {
  if (!chatId) return;
  const { data, error } = await sbClient.from('chat_nachrichten')
    .select('*').eq('chat_id', chatId).order('erstellt_am', { ascending: true }).limit(500);
  if (error) { console.warn('chat_nachrichten:', error.message); return; }
  chatNachrichten = data || [];
  chatRenderKonversation();
  if (!nurRender) {
    try { await sbClient.rpc('chat_gelesen', { p_chat: chatId }); } catch (e) {}
    chatLadeListe();   // Ungelesen-Badge aktualisieren
  }
}

// ---- Öffnen/Schließen -------------------------------------------------------
async function oeffneChat() {
  if (!aktuellerUser) return;
  document.getElementById('avatar-menu')?.classList.remove('offen');
  document.getElementById('chat-modal').classList.add('aktiv');
  if (!chatTippInit) {
    chatTippInit = true;
    tippAuswahl(document.getElementById('chat-liste'),    '.chat-listitem', el => chatOeffneKonversation(el.dataset.id));
    tippAuswahl(document.getElementById('chat-neu-liste'), '.chat-pers-row', el => chatNeuToggle(el.dataset.uid));
  }
  if (!chatGeladen) { try { await chatLadeNutzer(); } catch (e) {} }
  await chatLadeListe();
  // War beim Wieder-Öffnen noch eine Unterhaltung aktiv: frisch laden UND als gelesen markieren
  // (nurRender=false → chat_gelesen), sonst die leere Spalte zeigen.
  if (chatAktivId) { await chatLadeNachrichten(chatAktivId, false); }
  else { chatZeigeLeer(); }
}
function schliesseChat() {
  document.getElementById('chat-modal').classList.remove('aktiv');
}
function chatZeigeLeer() {
  chatAktivId = null;
  document.getElementById('chat-body').classList.remove('konv-offen');
  const konv = document.getElementById('chat-konv');
  konv.innerHTML = `<div class="chat-konv-leer">${escapeHtml(t('chat_leer'))}</div>`;
  chatRenderListe();
}
function chatZurueck() { chatZeigeLeer(); }

// ---- Anzeige-Helfer ---------------------------------------------------------
function chatNameVon(uid) {
  if (uid === (aktuellerUser && aktuellerUser.id)) return t('chat_du');
  const u = chatNutzerMap[uid];
  return u ? nm(u.anzeigename) : '—';
}
function chatTitelVon(c) {
  if (c.typ === 'gruppe') return c.name || t('chat_gruppe');
  const me = aktuellerUser.id;
  const other = (c.teilnehmer || []).find(p => p.user_id !== me);
  return other ? chatNameVon(other.user_id) : t('chat_titel');
}
function chatAvatarVon(c) {
  if (c.typ === 'direkt') {
    const me = aktuellerUser.id;
    const other = (c.teilnehmer || []).find(p => p.user_id !== me);
    const u = other && chatNutzerMap[other.user_id];
    if (u && u.avatar_url) return u.avatar_url;
  }
  return AVATAR_PLATZHALTER;
}
function chatZeit(iso) {
  if (!iso) return '';
  const d = new Date(iso), jetzt = new Date();
  const loc = { de: 'de-DE', sr: 'sr-RS', hr: 'hr-HR', ba: 'bs-BA', en: 'en-US' }[aktuelleSprache] || 'de-DE';
  const zeit = d.toLocaleTimeString(loc, { hour: '2-digit', minute: '2-digit' });
  if (d.toDateString() === jetzt.toDateString()) return zeit;
  const gestern = new Date(jetzt); gestern.setDate(jetzt.getDate() - 1);
  if (d.toDateString() === gestern.toDateString()) return t('chat_gestern') + ' ' + zeit;
  const datum = d.toLocaleDateString(loc, { day: '2-digit', month: '2-digit',
    year: d.getFullYear() === jetzt.getFullYear() ? undefined : '2-digit' });
  return datum + ' ' + zeit;
}

// ---- Liste rendern ----------------------------------------------------------
function chatRenderListe() {
  const box = document.getElementById('chat-liste');
  if (!box) return;
  if (!chatListe.length) {
    box.innerHTML = `<div class="chat-leer-hinweis">${escapeHtml(t('chat_keine_chats'))}<br>` +
      `<span style="opacity:.8">${escapeHtml(t('chat_keine_chats_hint'))}</span></div>`;
    return;
  }
  box.innerHTML = chatListe.map(c => {
    const aktiv = c.id === chatAktivId ? ' aktiv' : '';
    const preview = c.letzteGeloescht ? t('chat_geloescht') : (c.letzteText || '');
    const badge = c.ungelesen > 0 ? `<span class="chat-unread">${c.ungelesen}</span>` : '';
    return `<div class="chat-listitem${aktiv}" data-id="${escapeHtml(c.id)}">
      <img class="chat-li-avatar" src="${escapeHtml(chatAvatarVon(c))}" alt="" onerror="this.src='${AVATAR_PLATZHALTER}'">
      <div class="chat-li-haupt">
        <div class="chat-li-name">${escapeHtml(chatTitelVon(c))}</div>
        <div class="chat-li-preview">${escapeHtml(preview)}</div>
      </div>
      <div class="chat-li-meta">
        <span class="chat-li-zeit">${escapeHtml(chatZeit(c.letzteZeit))}</span>
        ${badge}
      </div>
    </div>`;
  }).join('');
}

// ---- Konversation -----------------------------------------------------------
async function chatOeffneKonversation(chatId) {
  chatAktivId = chatId;
  document.getElementById('chat-body').classList.add('konv-offen');
  await chatLadeNachrichten(chatId);
  chatRenderListe();
}
function chatRenderKonversation() {
  const c = chatById[chatAktivId];
  if (!c) return;
  const konv = document.getElementById('chat-konv');
  const me = aktuellerUser.id;
  let sub;
  if (c.typ === 'gruppe') {
    sub = t('chat_mitglieder', { n: (c.teilnehmer || []).length });
  } else {
    const other = (c.teilnehmer || []).find(p => p.user_id !== me);
    const u = other && chatNutzerMap[other.user_id];
    sub = u ? [u.familie_name, u.baum_namen].filter(Boolean).join(' · ') : '';
  }
  const infoBtn = c.typ === 'gruppe'
    ? `<button class="chat-konv-menu-btn" onclick="chatInfoOeffnen()" title="${escapeHtml(t('chat_info'))}">ⓘ</button>` : '';

  // Nachrichten-Bubbles mit Tagestrennern
  let html = '', letzterTag = '';
  (chatNachrichten || []).forEach(m => {
    const tag = new Date(m.erstellt_am).toDateString();
    if (tag !== letzterTag) {
      letzterTag = tag;
      html += `<div class="chat-tagtrenner">${escapeHtml(chatTagLabel(m.erstellt_am))}</div>`;
    }
    const eigen = m.absender_id === me;
    const klass = 'chat-msg ' + (eigen ? 'eigen' : 'fremd') + (m.geloescht ? ' geloescht' : '');
    const absName = (!eigen && c.typ === 'gruppe')
      ? `<div class="chat-msg-absender">${escapeHtml(chatNameVon(m.absender_id))}</div>` : '';
    const text = m.geloescht ? t('chat_geloescht') : (m.text || '');
    const fuss = escapeHtml(chatZeit(m.erstellt_am)) + (m.bearbeitet_am && !m.geloescht ? ' · ' + escapeHtml(t('chat_bearbeitet')) : '');
    const aktionen = (eigen && !m.geloescht)
      ? `<div class="chat-msg-aktionen">
           <button onclick="chatMsgBearbeiten('${escapeHtml(m.id)}')">${escapeHtml(t('chat_bearbeiten'))}</button>
           <button onclick="chatMsgLoeschen('${escapeHtml(m.id)}')">${escapeHtml(t('chat_loeschen'))}</button>
         </div>` : '';
    html += `<div class="${klass}" data-id="${escapeHtml(m.id)}">
      ${absName}<div class="chat-msg-text">${escapeHtml(text)}</div>
      <div class="chat-msg-fuss">${fuss}</div>${aktionen}</div>`;
  });

  konv.innerHTML = `
    <div class="chat-konv-head">
      <button class="chat-zurueck-btn" onclick="chatZurueck()" aria-label="${escapeHtml(t('chat_zurueck'))}">←</button>
      <div class="chat-konv-info">
        <div class="chat-konv-titel">${escapeHtml(chatTitelVon(c))}</div>
        <div class="chat-konv-sub">${escapeHtml(sub)}</div>
      </div>
      ${infoBtn}
    </div>
    <div class="chat-nachrichten" id="chat-nachrichten">${html}</div>
    <div class="chat-eingabe-zeile">
      <textarea class="chat-eingabe" id="chat-eingabe" rows="1"
        placeholder="${escapeHtml(t('chat_nachricht_ph'))}" oninput="chatEingabeWachsen(this)"
        onkeydown="chatEingabeTaste(event)"></textarea>
      <button class="chat-send-btn" onclick="chatSenden()" aria-label="${escapeHtml(t('chat_senden'))}">➤</button>
    </div>`;
  const liste = document.getElementById('chat-nachrichten');
  if (liste) liste.scrollTop = liste.scrollHeight;
}
function chatTagLabel(iso) {
  const d = new Date(iso), jetzt = new Date();
  if (d.toDateString() === jetzt.toDateString()) return t('chat_heute');
  const gestern = new Date(jetzt); gestern.setDate(jetzt.getDate() - 1);
  if (d.toDateString() === gestern.toDateString()) return t('chat_gestern');
  const loc = { de: 'de-DE', sr: 'sr-RS', hr: 'hr-HR', ba: 'bs-BA', en: 'en-US' }[aktuelleSprache] || 'de-DE';
  return d.toLocaleDateString(loc, { day: '2-digit', month: 'long', year: 'numeric' });
}
function chatEingabeWachsen(el) { el.style.height = 'auto'; el.style.height = Math.min(el.scrollHeight, 120) + 'px'; }
function chatEingabeTaste(e) {
  // Desktop: Enter sendet, Shift+Enter = neue Zeile. Mobil: Enter = neue Zeile.
  if (e.key === 'Enter' && !e.shiftKey && !window.matchMedia('(max-width:480px)').matches) {
    e.preventDefault(); chatSenden();
  }
}
async function chatSenden() {
  const feld = document.getElementById('chat-eingabe');
  if (!feld || !chatAktivId) return;
  const text = feld.value.trim();
  if (!text) return;
  feld.value = ''; chatEingabeWachsen(feld);
  try {
    const { error } = await sbClient.rpc('chat_nachricht_senden', { p_chat: chatAktivId, p_text: text });
    if (error) throw error;
    await chatLadeNachrichten(chatAktivId);
    await chatLadeListe();
  } catch (e) {
    console.warn('chat_nachricht_senden:', e.message || e);
    feld.value = text;   // bei Fehler Eingabe nicht verlieren
    zeigeHinweis(t('chat_fehler'));
  }
}

// ---- Nachricht bearbeiten / löschen (RLS: nur eigener Absender) --------------
function chatMsgBearbeiten(id) {
  const m = (chatNachrichten || []).find(x => x.id === id);
  if (!m) return;
  const bubble = document.querySelector(`.chat-msg[data-id="${id}"]`);
  if (!bubble) return;
  bubble.innerHTML = `
    <textarea class="chat-msg-editfeld" id="chat-edit-${id}" rows="2">${escapeHtml(m.text || '')}</textarea>
    <div class="chat-msg-aktionen">
      <button onclick="chatMsgSpeichern('${escapeHtml(id)}')">${escapeHtml(t('chat_speichern'))}</button>
      <button onclick="chatRenderKonversation()">${escapeHtml(t('chat_abbrechen'))}</button>
    </div>`;
  const ta = document.getElementById('chat-edit-' + id);
  if (ta) { ta.focus(); ta.setSelectionRange(ta.value.length, ta.value.length); }
}
async function chatMsgSpeichern(id) {
  const ta = document.getElementById('chat-edit-' + id);
  if (!ta) return;
  const neu = ta.value.trim();
  if (!neu) return;
  try {
    const { error } = await sbClient.from('chat_nachrichten')
      .update({ text: neu, bearbeitet_am: new Date().toISOString() }).eq('id', id);
    if (error) throw error;
    await chatLadeNachrichten(chatAktivId);
    await chatLadeListe();
  } catch (e) {
    console.warn('Nachricht bearbeiten:', e.message || e);
    zeigeHinweis(t('chat_fehler'));
  }
}
async function chatMsgLoeschen(id) {
  const ok = await zeigeBestaetigung(t('chat_loeschen_frage'), { gefahr: true, jaText: t('chat_loeschen') });
  if (!ok) return;
  try {
    const { error } = await sbClient.from('chat_nachrichten')
      .update({ geloescht: true, text: null }).eq('id', id);
    if (error) throw error;
    await chatLadeNachrichten(chatAktivId);
    await chatLadeListe();
  } catch (e) {
    console.warn('Nachricht löschen:', e.message || e);
    zeigeHinweis(t('chat_fehler'));
  }
}

// ---- Neuer Chat (Personenwahl: 1 = direkt, mehrere = Gruppe) -----------------
async function chatNeuOeffnen() {
  chatNeuAuswahl.clear();
  document.getElementById('chat-neu-suche').value = '';
  if (!chatGeladen) { try { await chatLadeNutzer(); } catch (e) {} }
  feldFehlerReset('chat-neu-modal');
  chatNeuRender();
  document.getElementById('chat-neu-modal').classList.add('aktiv');
}
function chatNeuSchliessen() { document.getElementById('chat-neu-modal').classList.remove('aktiv'); }
function chatNeuFilter() { chatNeuRender(); }
function chatNeuToggle(uid) {
  if (chatNeuAuswahl.has(uid)) chatNeuAuswahl.delete(uid); else chatNeuAuswahl.add(uid);
  chatNeuRender();
}
function chatNeuRender() {
  const such = (document.getElementById('chat-neu-suche').value || '').trim().toLowerCase();
  const liste = document.getElementById('chat-neu-liste');
  const treffer = chatNutzer.filter(u => !such || (u.anzeigename || '').toLowerCase().includes(such)
    || (u.familie_name || '').toLowerCase().includes(such) || (u.baum_namen || '').toLowerCase().includes(such));
  if (!treffer.length) {
    liste.innerHTML = `<div class="chat-leer-hinweis">${escapeHtml(t('chat_keine_nutzer'))}</div>`;
  } else {
    liste.innerHTML = treffer.map(u => {
      const gewaehlt = chatNeuAuswahl.has(u.user_id) ? ' gewaehlt' : '';
      const ctx = [u.familie_name, u.baum_namen].filter(Boolean).join(' · ');
      return `<div class="chat-pers-row${gewaehlt}" data-uid="${escapeHtml(u.user_id)}">
        <img class="chat-pers-avatar" src="${escapeHtml(u.avatar_url || AVATAR_PLATZHALTER)}" alt="" onerror="this.src='${AVATAR_PLATZHALTER}'">
        <div class="chat-pers-haupt">
          <div class="chat-pers-name">${escapeHtml(nm(u.anzeigename))}</div>
          ${ctx ? `<div class="chat-pers-ctx">${escapeHtml(ctx)}</div>` : ''}
        </div>
        <div class="chat-pers-check">${gewaehlt ? '✓' : ''}</div>
      </div>`;
    }).join('');
  }
  // Gruppenname-Feld nur bei Mehrfachauswahl
  document.getElementById('chat-neu-gruppe-wrap').style.display = chatNeuAuswahl.size > 1 ? '' : 'none';
}
async function chatNeuErstellen() {
  feldFehlerReset('chat-neu-modal');
  const auswahl = Array.from(chatNeuAuswahl);
  if (!auswahl.length) return feldFehler('chat-neu-suche', t('chat_mind_eine'));
  try {
    let chatId;
    if (auswahl.length === 1) {
      const { data, error } = await sbClient.rpc('direkt_chat_finden_oder_anlegen', { p_user2: auswahl[0] });
      if (error) throw error;
      chatId = data;
    } else {
      const name = document.getElementById('chat-neu-gruppenname').value.trim();
      if (!name) return feldFehler('chat-neu-gruppenname', t('chat_gruppe_name_pflicht'));
      const { data, error } = await sbClient.rpc('gruppen_chat_anlegen', { p_name: name, p_user_ids: auswahl });
      if (error) throw error;
      chatId = data;
    }
    chatNeuSchliessen();
    await chatLadeListe();
    await chatOeffneKonversation(chatId);
  } catch (e) {
    console.warn('Chat anlegen:', e.message || e);
    zeigeHinweis(t('chat_fehler'));
  }
}

// ---- Gruppen-Info: Mitglieder, entfernen, Admin, verlassen ------------------
function chatInfoOeffnen() {
  const c = chatById[chatAktivId];
  if (!c || c.typ !== 'gruppe') return;
  chatInfoRender();
  document.getElementById('chat-info-modal').classList.add('aktiv');
}
function chatInfoSchliessen() { document.getElementById('chat-info-modal').classList.remove('aktiv'); }
function chatInfoRender() {
  const c = chatById[chatAktivId];
  if (!c) return;
  const me = aktuellerUser.id;
  document.getElementById('chat-info-name').textContent = c.name || t('chat_gruppe');
  const meinT = (c.teilnehmer || []).find(p => p.user_id === me);
  const darfVerwalten = (meinT && meinT.ist_gruppen_admin) || istAdmin();
  const box = document.getElementById('chat-info-liste');
  box.innerHTML = (c.teilnehmer || []).map(tn => {
    const istIch = tn.user_id === me;
    const adminBadge = tn.ist_gruppen_admin ? `<span class="chat-info-badge">${escapeHtml(t('chat_admin_badge'))}</span>` : '';
    let aktion = '';
    if (darfVerwalten && !istIch) {
      const adminBtn = tn.ist_gruppen_admin
        ? `<button class="account-btn" style="padding:4px 8px;font-size:12px" onclick="chatAdminToggle('${escapeHtml(tn.user_id)}',false)">${escapeHtml(t('chat_admin_entziehen'))}</button>`
        : `<button class="account-btn" style="padding:4px 8px;font-size:12px" onclick="chatAdminToggle('${escapeHtml(tn.user_id)}',true)">${escapeHtml(t('chat_admin_machen'))}</button>`;
      aktion = `<div class="chat-info-aktion">${adminBtn}
        <button class="account-btn admin-danger" style="padding:4px 8px;font-size:12px" onclick="chatTeilnehmerEntfernen('${escapeHtml(tn.user_id)}')">${escapeHtml(t('chat_entfernen'))}</button></div>`;
    }
    return `<div class="chat-info-row">
      <span>${escapeHtml(chatNameVon(tn.user_id))}</span>${adminBadge}${aktion}</div>`;
  }).join('');
}
async function chatAdminToggle(uid, wert) {
  try {
    const { error } = await sbClient.rpc('chat_gruppen_admin_setzen', { p_chat: chatAktivId, p_user: uid, p_wert: wert });
    if (error) throw error;
    await chatLadeListe(); chatInfoRender(); chatRenderKonversation();
  } catch (e) { console.warn('Admin setzen:', e.message || e); zeigeHinweis(t('chat_fehler')); }
}
async function chatTeilnehmerEntfernen(uid) {
  const ok = await zeigeBestaetigung(t('chat_entfernen_frage', { name: chatNameVon(uid) }), { gefahr: true, jaText: t('chat_entfernen') });
  if (!ok) return;
  try {
    const { error } = await sbClient.rpc('chat_teilnehmer_entfernen', { p_chat: chatAktivId, p_user: uid });
    if (error) throw error;
    await chatLadeListe(); chatInfoRender(); chatRenderKonversation();
  } catch (e) { console.warn('Teilnehmer entfernen:', e.message || e); zeigeHinweis(t('chat_fehler')); }
}
async function chatGruppeVerlassen() {
  const ok = await zeigeBestaetigung(t('chat_verlassen_frage'), { gefahr: true, jaText: t('chat_verlassen') });
  if (!ok) return;
  try {
    const { error } = await sbClient.rpc('chat_teilnehmer_entfernen', { p_chat: chatAktivId, p_user: aktuellerUser.id });
    if (error) throw error;
    chatInfoSchliessen();
    chatZeigeLeer();
    await chatLadeListe();
  } catch (e) { console.warn('Gruppe verlassen:', e.message || e); zeigeHinweis(t('chat_fehler')); }
}

// ---- Ungelesen-Badge (Menüeintrag) ------------------------------------------
function chatBadgeAktualisieren() {
  const gesamt = (chatListe || []).reduce((s, c) => s + (c.ungelesen || 0), 0);
  // Ungelesen-Badge sitzt jetzt am Chat-Icon der Navigationsleiste (#chat-nav-badge).
  const badge = document.getElementById('chat-nav-badge');
  if (badge) { badge.textContent = gesamt > 99 ? '99+' : String(gesamt); badge.style.display = gesamt > 0 ? 'inline-flex' : 'none'; }
}

// ---- Sprachwechsel: offene Chat-Oberflächen neu rendern ---------------------
function chatSpracheUpdate() {
  const offen = id => document.getElementById(id)?.classList.contains('aktiv');
  if (offen('chat-modal')) {
    chatRenderListe();
    if (chatAktivId) chatRenderKonversation(); else chatZeigeLeer();
  }
  if (offen('chat-neu-modal')) chatNeuRender();
  if (offen('chat-info-modal')) chatInfoRender();
}
