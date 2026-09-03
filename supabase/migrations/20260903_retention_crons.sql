-- 03.09.2026 — Kalite teşhisi (B4 hijyen): retention'sız tablolar.
--  notifications: 189 kullanıcıda 10 320 satır, silinmiyordu → okunmuş ve 90 günden eski olanlar gece silinir.
--  call_otps: süresi dolmuş kodlar (5 dk TTL) temizlenmiyordu → 1 günden eski satırlar silinir.
--  otp_send_log: 2 günlük cron zaten var (20260818), verify satırları da aynı kurala tabi.
select cron.unschedule(jobid) from cron.job where jobname in ('cleanup-notifications', 'cleanup-call-otps');
select cron.schedule('cleanup-notifications', '50 3 * * *',
  $$delete from public.notifications where read_at is not null and created_at < now() - interval '90 days'$$);
select cron.schedule('cleanup-call-otps', '55 3 * * *',
  $$delete from public.call_otps where expires_at < now() - interval '1 day'$$);
