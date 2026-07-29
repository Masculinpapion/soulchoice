-- Ops panel: premium sayacı yalnız GERÇEK aboneleri sayar (29.07, Mustafa)
-- Демо/test hesaplarının kalıcı premium'u metrikleri şişiriyordu ("Premium 1").

CREATE OR REPLACE VIEW public.v_user_stats AS
SELECT
  (SELECT count(*)::int FROM users WHERE NOT is_deleted) AS total,
  (SELECT count(*)::int FROM users
    WHERE created_at > now() - interval '24 hours') AS new24,
  (SELECT count(*)::int FROM users WHERE banned) AS banned,
  (SELECT count(*)::int FROM users
    WHERE is_test_user AND NOT is_deleted) AS test_users,
  (SELECT count(*)::int FROM users
    WHERE (subscription_status = 'active' OR premium_until > now())
      AND NOT is_deleted
      AND NOT is_test_user) AS premium,
  (SELECT count(*)::int FROM users
    WHERE verified AND NOT is_deleted) AS verified;
