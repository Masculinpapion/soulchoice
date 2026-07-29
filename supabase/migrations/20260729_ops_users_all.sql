-- Ops: tüm kullanıcı listesi (29.07, Mustafa) — v_users_recent'in LIMIT'siz hâli;
-- sayfalama agent tarafında limit/offset ile yapılır.
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
       (users.subscription_status = 'active' OR users.premium_until > now()) AS premium
FROM users
WHERE NOT users.is_deleted
ORDER BY users.created_at DESC;

GRANT SELECT ON public.v_users_all TO ops_moderator;
