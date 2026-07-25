// ============================================================================
// FamilyRoots — Vorlage für die LOKALE Supabase-Umschaltung (FAMROOTS-36)
// ----------------------------------------------------------------------------
// SO BENUTZEN:
//   1) Diese Datei kopieren:  supabase_local.example.js  ->  supabase_local.js
//   2) url + key mit den Werten aus `supabase start` füllen (API URL + anon key).
//   3) stammbaum.html lokal öffnen (localhost/127.0.0.1) — die App zeigt dann auf den lokalen Stack.
//
// supabase_local.js ist per .gitignore vom Repo ausgeschlossen und wird auf GitHub Pages NIE
// geladen (der Loader in stammbaum.html fragt sie nur auf localhost an). Prod bleibt unberührt.
//
// Der API-URL entspricht dem config.toml-Port 54331 (FamilyRoots-Offset +10). Den anon-Key zeigt
// `supabase start` bzw. `supabase status` an ("anon key"). Er ist der bekannte lokale Demo-Key —
// kein Geheimnis, gehört aber trotzdem nicht ins Repo (Trennung Prod/Local).
// ============================================================================
window.__SB_LOCAL = {
  url: 'http://127.0.0.1:54331',
  key: 'HIER_DEN_LOKALEN_ANON_KEY_AUS_supabase_status_EINSETZEN',
};
