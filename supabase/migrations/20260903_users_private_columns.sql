-- 03.09.2026 — Kalite teşhisi (B4): users_select = true + geniş kolon grant'i → her doğrulanmış
-- kullanıcı diğer herkesin banned / suspended_at / suspension_reason / warning_count /
-- no_show_count / is_admin / selfie_rejected_reason / ücretsiz hak sayaçlarını okuyabiliyordu.
-- Çözüm: kolon grant'i yalnız herkese açık profil alanlarına indirilir; kişinin KENDİ özel
-- alanları my_private_profile() RPC'siyle (SECURITY DEFINER, auth.uid()) döner.
-- İstemci: splash / router / selfie / invitation_detail / profile_provider bu RPC'ye geçti (aynı commit).
begin;

create or replace function public.my_private_profile()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select (select jsonb_build_object(
      'id', id,
      'banned', banned,
      'suspended_at', suspended_at,
      'suspension_reason', suspension_reason,
      'is_admin', is_admin,
      'selfie_status', selfie_status,
      'selfie_rejected_reason', selfie_rejected_reason,
      'free_application_used', free_application_used,
      'free_applications_used', free_applications_used,
      'no_show_count', no_show_count,
      'warning_count', warning_count,
      'subscription_status', subscription_status,
      'premium_until', premium_until,
      'locale', locale)
    from public.users where id = auth.uid())
$$;
revoke all on function public.my_private_profile() from public, anon;
grant execute on function public.my_private_profile() to authenticated, service_role;

-- Kolon grant'leri: önce sıfırla, sonra açık profil alanları.
-- FAZ 1 (03.09, CANLI): sahadaki ESKİ build'ler (RuStore 782, Apple'daki 233, Play testçileri)
-- splash/profil/router/selfie sorgularında banned, suspended_at, suspension_reason, is_admin,
-- selfie_rejected_reason, free_application(s)_used, no_show_count kolonlarını DOĞRUDAN okuyor —
-- bunlar geri alınırsa eski istemcide sorgu 42501 ile tümden düşer. Bu 8 kolon geriye uyumluluk
-- için ŞİMDİLİK açık kalır; hiçbir build'in okumadığı warning_count, consent_*, premium_sms_sent_at,
-- last_platform, subscription_provider kapatıldı.
-- FAZ 2 (yeni build'ler yayılıp min_supported_build ≥ RPC'li build olunca): aşağıdaki
-- «-- FAZ2» satırı çalıştırılır → 8 kolon da yalnız my_private_profile() üzerinden.
revoke select on public.users from anon, authenticated;
grant select (
  id, name, age, gender, city_id, country_code, bio, job, education, interests,
  min_age, max_age, show_gender, verified, verified_at, selfie_status,
  subscription_status, premium_until, locale, language, is_deleted, is_test_user,
  created_at, last_seen_at, last_active_at,
  banned, suspended_at, suspension_reason, is_admin, selfie_rejected_reason,
  free_application_used, free_applications_used, no_show_count
) on public.users to authenticated, anon;
-- FAZ2: revoke select (banned, suspended_at, suspension_reason, is_admin, selfie_rejected_reason,
--   free_application_used, free_applications_used, no_show_count) on public.users from anon, authenticated;

commit;
