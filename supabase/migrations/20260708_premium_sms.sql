-- ─────────────────────────────────────────────────────────────────────────────
-- iOS Premium SMS akışı (08.07.2026)
-- Ücretsiz hakkını kullanan iOS kullanıcısına uygulama DIŞINDAN (SMS) kişisel
-- Точка ödeme linki gönderilir; uygulamada sıfır piksel (App Store 3.1.3).
-- Cron: pg_cron + pg_net ile send-premium-sms edge function (migration dışında
-- elle kurulur, downgrade-expired-premium ile aynı konvansiyon).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) Platform tespiti: app her açılışta fcm_token ile birlikte yazar
--    (main.dart _saveFcmToken). user_devices boş — güvenilir kaynak bu kolon.
alter table users add column if not exists last_platform text
  check (last_platform in ('ios', 'android'));

-- 2) Dedupe damgası: kullanıcı başına tek Premium SMS
alter table users add column if not exists premium_sms_sent_at timestamptz;

-- 3) SMS kanalı satışı Apple aylık raporuna GİRMEZ (uygulama dışı kanal, %0
--    komisyon) — ios_app'ten ayrı source değeri şart
alter table payments drop constraint if exists payments_source_check;
alter table payments add constraint payments_source_check
  check (source in ('web', 'android', 'ios_app', 'ios_sms', 'test'));
