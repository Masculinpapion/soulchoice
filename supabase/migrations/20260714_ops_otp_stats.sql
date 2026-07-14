-- 20260714_ops_otp_stats.sql
-- OTP/Auth sekmesi için agregat view (telefon/kod ASLA expose edilmez).
-- Not: call_otps geçici tablo (doğrulanan satır silinir) → tarihsel başarı oranı
-- bu veriyle ölçülemez; kayıt trendi proxy olarak kullanılır.
create or replace view public.v_otp_stats as
select
  (select count(*)::int from public.call_otps)                                          as pending_otps,
  (select coalesce(round(extract(epoch from (now() - min(created_at))) / 60)::int, 0)
     from public.call_otps)                                                             as oldest_pending_min,
  (select count(*)::int from public.users
     where created_at > now() - interval '24 hours')                                    as users_new24,
  (select count(*)::int from public.users
     where created_at::date = current_date)                                             as users_today,
  (select coalesce(json_agg(t order by t.d), '[]'::json) from (
     select created_at::date as d, count(*)::int as n
     from public.users
     where created_at > now() - interval '7 days'
     group by 1) t)                                                                     as reg_trend;

grant select on public.v_otp_stats to ops_moderator;
