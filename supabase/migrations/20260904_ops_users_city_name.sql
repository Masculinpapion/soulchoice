-- Ops paneli: kullanıcı listesi/aramasında şehir ADI (04.09.2026, Mustafa — panelde UUID görünüyordu).
-- v_users_all'a sona `city` kolonu eklenir (CREATE OR REPLACE: mevcut kolon sırası korunur, izinler kalır).
-- ops_search_users dönüş tipi değiştiği için DROP+CREATE; ACL aynen: PUBLIC yok, postgres/service_role/ops_moderator.
CREATE OR REPLACE VIEW public.v_users_all AS
SELECT users.id,
       users.name,
       users.age,
       users.city_id::text AS city_id,
       users.created_at,
       users.verified,
       users.banned,
       users.warning_count,
       users.is_test_user,
       (users.subscription_status = 'active' OR users.premium_until > now()) AS premium,
       users.last_seen_at,
       (SELECT c.name_ru FROM public.cities c WHERE c.id = users.city_id) AS city
FROM users
WHERE NOT users.is_deleted
ORDER BY users.created_at DESC;

GRANT SELECT ON public.v_users_all TO ops_moderator;

DROP FUNCTION IF EXISTS public.ops_search_users(text);
CREATE FUNCTION public.ops_search_users(q text)
RETURNS TABLE(id uuid, name text, age integer, city_id text, phone_tail text, created_at timestamptz,
              verified boolean, banned boolean, warning_count integer, is_test_user boolean, premium boolean,
              city text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  select u.id, u.name, u.age::int, u.city_id::text, right(u.phone, 4), u.created_at,
         u.verified, u.banned, u.warning_count::int, u.is_test_user,
         (u.subscription_status = 'active' or u.premium_until > now()),
         (select c.name_ru from public.cities c where c.id = u.city_id)
  from public.users u
  where not u.is_deleted
    and (u.name ilike '%' || q || '%' or u.phone like '%' || q)
  order by u.created_at desc
  limit 20
$function$;

REVOKE ALL ON FUNCTION public.ops_search_users(text) FROM PUBLIC;
-- Supabase default privileges yeni fonksiyona anon/authenticated EXECUTE verir (PostgREST /rpc'den çağrılabilir olurdu —
-- telefon son 4 hanesi + isim sızardı). Açıkça geri alınır; 04.09 canlıda proacl ile doğrulandı.
REVOKE EXECUTE ON FUNCTION public.ops_search_users(text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ops_search_users(text) TO postgres, service_role, ops_moderator;
