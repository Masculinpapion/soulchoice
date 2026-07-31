-- 31.07.2026 — users tablosunda kişisel veri sızıntısı (denetim K2).
-- Sorun: users_select policy'si `using (true)` → GİRİŞ YAPMIŞ HERHANGİ BİR
-- kullanıcı `select=phone,billing_email,fcm_token` ile tüm kullanıcı tabanının
-- telefon numarasını, fatura e-postasını ve push token'ını çekebiliyordu
-- (152-ФЗ / GDPR). Satır bazlı RLS kolon ayrımı yapamadığı için kolon-seviyesi
-- yetki kullanılıyor.
--
-- DİKKAT: yalnız `revoke select (kolon)` YETMEZ — tablo geneli GRANT üstün
-- gelir (31.07'de canlıda kanıtlandı: revoke sonrası telefon hâlâ çekiliyordu).
-- Doğru sıra: tablo geneli SELECT'i kaldır, sonra yalnız güvenli kolonları ver.
--
-- Kullanım analizi (31.07):
--   • phone      → istemcide OKUNMUYOR (UserModel.fromJson ölü kod)
--   • fcm_token  → istemci yalnız YAZIYOR (update; select gerekmez)
--   • billing_email → kendi satırından okunuyor → my_billing_email() RPC'si
--   • diğer tüm kolonlar profil/feed/paywall ekranlarında kullanılıyor, açık.

revoke select on public.users from authenticated, anon;

grant select (
  id, country_code, language, name, age, gender, city_id, bio, job, education,
  interests, verified, verified_at, subscription_status, subscription_provider,
  warning_count, banned, created_at, last_active_at, suspended_at,
  suspension_reason, selfie_status, selfie_rejected_reason, no_show_count,
  is_admin, is_deleted, show_gender, min_age, max_age, is_test_user,
  free_application_used, consent_given_at, consent_version, premium_until,
  last_platform, premium_sms_sent_at, locale, last_seen_at
) on public.users to authenticated, anon;

-- Kendi fatura e-postanı okumanın güvenli yolu (yalnız kendi satırı)
create or replace function public.my_billing_email()
returns text
language sql
security definer
stable
set search_path = public, pg_temp
as $$ select billing_email from public.users where id = auth.uid() $$;

revoke all on function public.my_billing_email() from public, anon;
grant execute on function public.my_billing_email() to authenticated;
