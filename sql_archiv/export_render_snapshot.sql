-- =====================================================
-- EXPORT eines Render-Snapshots als EINE JSON-Zelle (read-only, kein Risiko).
-- Zweck: lokale node-Simulation des Renderers (Zwillings-Welt UND simuliert-migrierte Welt),
--   um den Familien-Bleed REPRODUZIERBAR zu prüfen, BEVOR die echte Migration läuft.
--
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier, Run).
-- Danach: in der Ergebniszelle das JSON kopieren ODER per "Download" sichern und im Repo als
--   render_snapshot.json ablegen (Projektwurzel). Enthält KEINE Passwörter/Secrets — nur
--   Stammbaum-Strukturdaten (Namen/Beziehungen), die der eingeloggte Nutzer ohnehin sieht.
-- =====================================================
SELECT jsonb_build_object(
  'personen', (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id,
      'externe_id', p.externe_id,
      'stammbaum_id', p.stammbaum_id,
      'identitaet_id', p.identitaet_id,
      'familie_id', p.familie_id,
      'user_id', p.user_id,
      -- nur die für den Renderer-Scope nötigen Felder aus stammbaum_daten (klein halten)
      'sd', jsonb_build_object(
        'id',       p.stammbaum_daten->>'id',
        'given',    p.stammbaum_daten->>'given',
        'surname',  p.stammbaum_daten->>'surname',
        'ehename',  p.stammbaum_daten->>'ehename',
        'sex',      p.stammbaum_daten->>'sex',
        'platzhalter', p.stammbaum_daten->>'platzhalter'
      )
    )), '[]'::jsonb)
    FROM public.personen p
    WHERE p.geloescht_am IS NULL
  ),
  'beziehungen', (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'a', b.person_a, 'b', b.person_b, 'typ', b.typ)), '[]'::jsonb)
    FROM public.beziehungen b
    WHERE b.geloescht_am IS NULL
  ),
  'stammbaeume', (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'name', s.name, 'zusatz', s.zusatz, 'familie_id', s.familie_id,
      'wurzel', s.wurzel_person_id)), '[]'::jsonb)
    FROM public.stammbaeume s
  )
) AS snapshot;
