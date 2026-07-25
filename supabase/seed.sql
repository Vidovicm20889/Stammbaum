-- ============================================================================
-- FamilyRoots — synthetisches Seed für den LOKALEN Stack (FAMROOTS-36, AK4)
-- ----------------------------------------------------------------------------
-- REIN SYNTHETISCH: erfundene Namen (Mustermann), keine echten Personen — Datenschutz/Kinderschutz
-- (CLAUDE.md, hart). Deterministisch: feste UUIDs + ON CONFLICT DO NOTHING → mehrfaches Einspielen
-- ist idempotent.
--
-- VORAUSSETZUNG: Läuft NACH den Migrationen (SCHEMA.md-Reihenfolge, inkl. Nr. 0
-- supabase_base_tabellen.sql aus dem Prod-Dump). Eingespielt wird es AUSSCHLIESSLICH über
-- scripts/lokal_db_aufbau.mjs (letzter Schritt) — NICHT automatisch bei `supabase start`
-- (`[db.seed] enabled = false` in config.toml; sonst liefe es gegen die leere DB und bräche ab).
--
-- ⚠️ Spaltenannahmen aus dem App-Code belegt (INSERTs in *.sql): familien(name[,verbund_id]),
-- stammbaeume(familie_id,name), personen(familie_id,stammbaum_id,externe_id,vorname,nachname,
-- geburtsdatum,stammbaum_daten), beziehungen(familie_id,person_a,person_b,typ),
-- mitgliedschaften(user_id,familie_id,rolle,aktiv,auto). Zeigt der Prod-Dump zusätzliche NOT-NULL-
-- Spalten, hier ergänzen (erst nach dem Dump final verifizierbar — 🔬).
-- ============================================================================

-- ---- 1) Synthetischer Login-Nutzer (für den Kernfluss-Test, AK5) -----------
-- Standard-Muster für lokale Supabase-Seeds (auth.users + auth.identities). E-Mail/Passwort:
--   test@familyroots.local  /  test1234
-- GoTrue-Schemata variieren leicht je CLI-Version — schlägt dieser Block fehl, den Nutzer
-- stattdessen in Supabase Studio (Authentication → Add user) anlegen und die feste UUID unten
-- übernehmen. Der Rest des Seeds (Baumdaten) hängt für die FK nur an dieser UUID.
-- ⚠️ Die Token-Spalten MÜSSEN '' sein, NICHT NULL — GoTrue scannt sie als Go-`string` und stürzt
-- sonst beim Login ab: „Scan error on column confirmation_token: converting NULL to string is
-- unsupported" (belegt FAMROOTS-36, docs/lessons.md).
INSERT INTO auth.users
  (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
   created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
   confirmation_token, recovery_token, email_change_token_new, email_change,
   email_change_token_current, phone_change, phone_change_token, reauthentication_token)
VALUES
  ('00000000-0000-0000-0000-000000000000',
   'a0000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'test@familyroots.local',
   crypt('test1234', gen_salt('bf')), now(),
   now(), now(), '{"provider":"email","providers":["email"]}', '{}', false,
   '', '', '', '', '', '', '', '')
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities
  (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
VALUES
  ('a0000000-0000-4000-8000-0000000000e1',
   'a0000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000001',
   '{"sub":"a0000000-0000-4000-8000-000000000001","email":"test@familyroots.local"}',
   'email', now(), now(), now())
ON CONFLICT (id) DO NOTHING;

-- ---- 2) Familie (eigener Verbund) ------------------------------------------
INSERT INTO public.familien (id, name, verbund_id)
VALUES ('f0000000-0000-4000-8000-000000000001', 'Testfamilie Mustermann',
        'f0000000-0000-4000-8000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- ---- 3) Mitgliedschaft: Testnutzer = Owner (manuell gesetzt, auto=false) ----
INSERT INTO public.mitgliedschaften (user_id, familie_id, rolle, aktiv, auto)
VALUES ('a0000000-0000-4000-8000-000000000001',
        'f0000000-0000-4000-8000-000000000001', 'familien_owner', true, false)
ON CONFLICT DO NOTHING;

-- ---- 4) Stammbaum ----------------------------------------------------------
INSERT INTO public.stammbaeume (id, familie_id, name)
VALUES ('50000000-0000-4000-8000-000000000001',
        'f0000000-0000-4000-8000-000000000001', 'Mustermann')
ON CONFLICT (id) DO NOTHING;

-- ---- 5) Personen (3 Generationen, synthetisch) -----------------------------
-- stammbaum_daten (jsonb) trägt die Frontend-Felder (given/surname/sex/birth_date); die
-- date-Spalte geburtsdatum bleibt NULL (CLAUDE.md: sonst Fehler 22008).
INSERT INTO public.personen (id, familie_id, stammbaum_id, externe_id, vorname, nachname, stammbaum_daten)
VALUES
  ('60000000-0000-4000-8000-000000000001','f0000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','T0001','Opa','Mustermann',   '{"given":"Opa","surname":"Mustermann","sex":"M","birth_date":"1940-03-12"}'),
  ('60000000-0000-4000-8000-000000000002','f0000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','T0002','Oma','Mustermann',   '{"given":"Oma","surname":"Mustermann","sex":"F","birth_date":"1943-07-04","ehename":"Beispiel"}'),
  ('60000000-0000-4000-8000-000000000003','f0000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','T0003','Vater','Mustermann', '{"given":"Vater","surname":"Mustermann","sex":"M","birth_date":"1968-11-20"}'),
  ('60000000-0000-4000-8000-000000000004','f0000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','T0004','Mutter','Mustermann','{"given":"Mutter","surname":"Mustermann","sex":"F","birth_date":"1971-05-09","ehename":"Vorlage"}'),
  ('60000000-0000-4000-8000-000000000005','f0000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','T0005','Kind','Mustermann',  '{"given":"Kind","surname":"Mustermann","sex":"M","birth_date":"1999-01-01"}')
ON CONFLICT (id) DO NOTHING;

-- Wurzelperson am Baum setzen (ältester Vorfahre = Opa)
UPDATE public.stammbaeume
   SET wurzel_person_id = '60000000-0000-4000-8000-000000000001'
 WHERE id = '50000000-0000-4000-8000-000000000001' AND wurzel_person_id IS NULL;

-- ---- 6) Beziehungen --------------------------------------------------------
-- typ 'elternteil': person_a ist Elternteil von person_b. 'ehepartner': Paar.
INSERT INTO public.beziehungen (familie_id, person_a, person_b, typ)
VALUES
  ('f0000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000002','ehepartner'),
  ('f0000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000003','60000000-0000-4000-8000-000000000004','ehepartner'),
  ('f0000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000003','elternteil'),
  ('f0000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000002','60000000-0000-4000-8000-000000000003','elternteil'),
  ('f0000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000003','60000000-0000-4000-8000-000000000005','elternteil'),
  ('f0000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000004','60000000-0000-4000-8000-000000000005','elternteil')
ON CONFLICT DO NOTHING;

SELECT 'Seed: Testfamilie Mustermann (5 Personen, 6 Beziehungen) — synthetisch' AS status;
