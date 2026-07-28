-- =====================================================
-- BENUTZER-PROFIL (Phase 1) — Tabelle "profile" + Storage-Bucket "avatars"
-- Ausführen in: Supabase -> SQL Editor (Editor leeren, NUR das hier einfügen, Run)
-- Idempotent: kann mehrfach ausgeführt werden.
--
-- Hintergrund:
--  - Der eingeloggte Nutzer existiert bisher nur als auth.users-Zeile (nur E-Mail).
--    Diese Tabelle hält die persönlichen Konto-/Profildaten (NICHT die Stammbaum-Person!).
--  - 1 Zeile je auth.users-Nutzer (user_id = PK = FK auf auth.users).
--  - RLS: jeder Nutzer sieht/bearbeitet AUSSCHLIESSLICH seine EIGENE Zeile
--    (auth.uid() = user_id). Keine Cross-Tabellen-Subquery -> rekursionsfrei,
--    Familien-Isolation bleibt gewahrt. Avatare anderer Nutzer werden NICHT über
--    DB-SELECT, sondern über den Presence-Channel (Broadcast) verteilt.
-- =====================================================


-- 1) Tabelle ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profile (
  user_id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  vorname            text,
  nachname           text,
  telefon            text,
  sprache            text,                                  -- 'de' | 'sr' | 'hr' | 'ba' | 'en'
  land               text,                                  -- ISO-Code (z. B. 'DE') ODER Legacy-Klartext
  zeitzone           text,                                  -- optional, IANA (z. B. 'Europe/Berlin')
  avatar_url         text,                                  -- öffentliche URL (Hauptbild)
  avatar_thumb_url   text,                                  -- öffentliche URL (Thumbnail)
  avatar_sichtbarkeit text NOT NULL DEFAULT 'verbund'
    CHECK (avatar_sichtbarkeit IN ('verbund', 'familie', 'privat')),
  erstellt_am        timestamptz NOT NULL DEFAULT now(),
  aktualisiert_am    timestamptz NOT NULL DEFAULT now()
);

-- Falls die Tabelle schon existierte: fehlende Spalten nachziehen (idempotent).
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS vorname            text;
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS nachname           text;
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS telefon            text;
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS sprache            text;
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS land               text;
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS zeitzone           text;
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS avatar_url         text;
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS avatar_thumb_url   text;
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS avatar_sichtbarkeit text NOT NULL DEFAULT 'verbund';
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS erstellt_am        timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.profile ADD COLUMN IF NOT EXISTS aktualisiert_am    timestamptz NOT NULL DEFAULT now();


-- 2) Trigger: aktualisiert_am bei jedem UPDATE auf now() setzen ----------------
CREATE OR REPLACE FUNCTION public.profile_touch_aktualisiert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.aktualisiert_am := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profile_touch ON public.profile;
CREATE TRIGGER profile_touch
  BEFORE UPDATE ON public.profile
  FOR EACH ROW EXECUTE FUNCTION public.profile_touch_aktualisiert();


-- 3) RLS: nur die EIGENE Zeile ------------------------------------------------
ALTER TABLE public.profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profile_select_own" ON public.profile;
DROP POLICY IF EXISTS "profile_insert_own" ON public.profile;
DROP POLICY IF EXISTS "profile_update_own" ON public.profile;
DROP POLICY IF EXISTS "profile_delete_own" ON public.profile;

CREATE POLICY "profile_select_own" ON public.profile
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "profile_insert_own" ON public.profile
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "profile_update_own" ON public.profile
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "profile_delete_own" ON public.profile
  FOR DELETE TO authenticated USING (auth.uid() = user_id);


-- 4) Storage-Bucket "avatars" (öffentlich lesbar) -----------------------------
--    Public-Bucket -> getPublicUrl() funktioniert; das Profilbild ist über die
--    URL teilbar (für den Presence-Broadcast an andere Verbund-Nutzer).
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;


-- 5) Storage-Policies: jeder darf SEINEN eigenen Ordner verwalten -------------
--    Pfadkonvention im Frontend: "<user_id>/avatar.webp" und "<user_id>/thumb.webp".
--    -> erster Pfad-Teil == auth.uid().
DROP POLICY IF EXISTS "avatars_select" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete" ON storage.objects;

-- Lesen/Auflisten: alle eingeloggten Nutzer (Bucket ist ohnehin public).
CREATE POLICY "avatars_select" ON storage.objects
  FOR SELECT TO authenticated
  USING ( bucket_id = 'avatars' );

-- Hochladen/Überschreiben/Löschen: nur im eigenen Ordner (<user_id>/...).
CREATE POLICY "avatars_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK ( bucket_id = 'avatars'
               AND (storage.foldername(name))[1] = auth.uid()::text );

CREATE POLICY "avatars_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING ( bucket_id = 'avatars'
          AND (storage.foldername(name))[1] = auth.uid()::text )
  WITH CHECK ( bucket_id = 'avatars'
               AND (storage.foldername(name))[1] = auth.uid()::text );

CREATE POLICY "avatars_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING ( bucket_id = 'avatars'
          AND (storage.foldername(name))[1] = auth.uid()::text );


-- 6) Kontrolle ----------------------------------------------------------------
SELECT 'profile-Policies' AS info, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'profile'
ORDER BY cmd;

SELECT 'avatars-Storage-Policies' AS info, policyname, cmd
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname LIKE 'avatars_%'
ORDER BY cmd;
