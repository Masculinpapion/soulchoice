-- Ops billing: gerçek-hayat sayıları (29.07, Mustafa "panel test modundan çıksın")
-- Test kullanıcılarının (Демо) premium'u ve 'Тест ...' amaçlı entegrasyon
-- ödemeleri (08-09.07 banka testleri, 1-2₽ + iadeleri) metriklerden çıkarılır.
CREATE OR REPLACE VIEW public.v_billing_stats AS
SELECT
  (SELECT count(*)::int FROM payments
    WHERE status='paid' AND purpose NOT LIKE 'Тест%') AS paid_total,
  (SELECT COALESCE(sum(amount),0)::int FROM payments
    WHERE status='paid' AND purpose NOT LIKE 'Тест%') AS paid_sum,
  (SELECT count(*)::int FROM payments
    WHERE status='paid' AND purpose NOT LIKE 'Тест%'
      AND paid_at > now() - interval '7 days') AS paid7,
  (SELECT COALESCE(sum(amount),0)::int FROM payments
    WHERE status='paid' AND purpose NOT LIKE 'Тест%'
      AND paid_at > now() - interval '7 days') AS paid7_sum,
  (SELECT count(*)::int FROM payments
    WHERE status='pending' AND purpose NOT LIKE 'Тест%') AS pending,
  (SELECT count(*)::int FROM payments
    WHERE status='refunded' AND purpose NOT LIKE 'Тест%') AS refunded,
  (SELECT count(*)::int FROM subscriptions WHERE status='active') AS subs_active,
  (SELECT count(*)::int FROM subscriptions WHERE status='past_due') AS subs_past_due,
  (SELECT count(*)::int FROM subscriptions WHERE status='cancelled') AS subs_cancelled,
  (SELECT count(*)::int FROM users
    WHERE (subscription_status='active' OR premium_until > now())
      AND NOT is_deleted AND NOT is_test_user) AS premium_users;
