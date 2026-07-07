-- ─────────────────────────────────────────────────────────────────────────────
-- 152-ФЗ: kayıt akışına 3 aktif onay checkbox'ı eklendi (yaş/veri işleme/
-- profil görünürlüğü) — profile_setup_screen.dart yeni "Onaylar" adımı.
-- Hangi anda, hangi metin sürümüne onay verildiği audit amaçlı saklanıyor.
-- Nullable: mevcut kullanıcılar geriye dönük NULL kalır (onay akışından
-- geçmediler), yeni kayıtlar her ikisini de dolduracak.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS consent_given_at timestamptz,
  ADD COLUMN IF NOT EXISTS consent_version text;
