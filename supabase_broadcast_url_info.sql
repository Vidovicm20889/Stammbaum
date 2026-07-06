-- =====================================================
-- BROADCAST: Einmalige Info-Mail an ALLE registrierten Konten (z. B. neue URL familyroots.club).
-- Ausführen in: Supabase -> SQL Editor. IDEMPOTENT.
--
-- Liefert der Edge Function "broadcast-info" die Empfänger (E-Mail + Sprache + Name) aus
-- auth.users (+ profile) und merkt sich PRO KAMPAGNE, wer schon gemailt wurde -> erneutes
-- Auslösen verschickt NICHT doppelt (wichtig bei manueller Wiederholung / Unsicherheit).
--
-- SICHERHEIT: Die Empfängerliste enthält ALLE E-Mail-Adressen. Die RPC ist daher SECURITY
-- DEFINER und NUR für service_role ausführbar (kein authenticated/anon-Zugriff -> keine
-- Adress-Enumeration durch normale Nutzer). Die Edge Function ruft sie mit dem Service-Role-Key.
--
-- Voraussetzung: Tabelle public.profile (Sprache/Name) existiert.
-- =====================================================

-- 1) Merk-Tabelle: wer wurde je Kampagne schon gemailt -------------------------
CREATE TABLE IF NOT EXISTS public.broadcast_gesendet (
  user_id     uuid NOT NULL,
  kampagne    text NOT NULL,
  gesendet_am timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, kampagne)
);
-- RLS an, KEINE Policies -> nur SECURITY-DEFINER-RPCs / service_role greifen zu.
ALTER TABLE public.broadcast_gesendet ENABLE ROW LEVEL SECURITY;

-- 2) Empfänger einer Kampagne: alle Konten mit E-Mail, die noch NICHT gemailt wurden.
CREATE OR REPLACE FUNCTION public.broadcast_empfaenger(p_kampagne text)
RETURNS TABLE(user_id uuid, email text, name text, sprache text)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT u.id,
         u.email::text,
         nullif(trim(coalesce(pr.vorname,'') || ' ' || coalesce(pr.nachname,'')), '') AS name,
         coalesce(nullif(pr.sprache,''), 'de')                                        AS sprache
    FROM auth.users u
    LEFT JOIN public.profile pr ON pr.user_id = u.id
   WHERE u.email IS NOT NULL AND u.email <> ''
     AND u.deleted_at IS NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.broadcast_gesendet b
        WHERE b.user_id = u.id AND b.kampagne = p_kampagne);
$$;
REVOKE ALL ON FUNCTION public.broadcast_empfaenger(text) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.broadcast_empfaenger(text) TO service_role;

-- 3) Als gesendet markieren (bulk, idempotent) --------------------------------
CREATE OR REPLACE FUNCTION public.broadcast_markiere_gesendet(p_users uuid[], p_kampagne text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_n integer;
BEGIN
  INSERT INTO public.broadcast_gesendet (user_id, kampagne)
  SELECT DISTINCT uid, p_kampagne FROM unnest(coalesce(p_users, '{}'::uuid[])) AS t(uid)
  ON CONFLICT (user_id, kampagne) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;
REVOKE ALL ON FUNCTION public.broadcast_markiere_gesendet(uuid[], text) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.broadcast_markiere_gesendet(uuid[], text) TO service_role;

NOTIFY pgrst, 'reload schema';

-- KONTROLLE: wie viele Konten würde die Kampagne 'url_familyroots_2026' erreichen?
SELECT count(*) AS offene_empfaenger FROM public.broadcast_empfaenger('url_familyroots_2026');

SELECT 'OK: broadcast_gesendet + broadcast_empfaenger()/broadcast_markiere_gesendet() angelegt' AS status;
