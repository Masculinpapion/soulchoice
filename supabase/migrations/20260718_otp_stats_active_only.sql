-- v_otp_stats: yalnızca süresi geçmemiş OTP'leri say.
-- Sebep: call_otps satırları sadece başarılı doğrulamada veya aynı numaraya
-- yeni istekte siliniyor; terk edilen satırlar süresiz "bekleyen" görünüyordu
-- (ops panel 18.07.2026: pending 1 / en eski 885 dk — dünkü testin artığı).
create or replace view v_otp_stats as
select
  (select count(*)::int from call_otps where expires_at > now()) as pending_otps,
  (select coalesce(round(extract(epoch from now() - min(created_at)) / 60)::int, 0)
     from call_otps where expires_at > now()) as oldest_pending_min,
  (select count(*)::int from users
    where created_at > now() - interval '24 hours') as users_new24,
  (select count(*)::int from users
    where created_at::date = current_date) as users_today,
  (select coalesce(json_agg(t.* order by t.d), '[]'::json)
     from (select created_at::date as d, count(*)::int as n
             from users
            where created_at > now() - interval '7 days'
            group by 1) t) as reg_trend;
