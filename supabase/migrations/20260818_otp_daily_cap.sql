-- 18.08.2026 — OTP kaba-kuvvet kapısı (DB tarafı, edge deploy'suz — Apple incelemesi sürerken OTP kesintisi riski alınmadı)
-- Sorun: 4 haneli kod × kod başına 5 deneme × sınırsız yeniden gönderim (1/dk) → hedefli numarada
-- günde ~%50 ele geçirme olasılığı. call_otps satırları her gönderimde silinip yeniden yazıldığı için
-- sayım ayrı bir logdan yapılır. Tavan: telefon başına 24 saatte 15 kod (demo bypass numarası muaf).
-- Tavan aşılınca kod SAKLANMAZ → doğrulanamaz → saldırı sonuçsuz (SMS gönderimi kesilmez; o kısım
-- edge fonksiyonunda, Apple sonrası: send-call-otp'de gönderim ÖNCESİ aynı log kontrolü).
begin;

create table if not exists public.otp_send_log (
  id bigserial primary key,
  phone text not null,
  created_at timestamptz not null default now()
);
create index if not exists otp_send_log_phone_idx on public.otp_send_log (phone, created_at);
alter table public.otp_send_log enable row level security;
revoke all on public.otp_send_log from anon, authenticated;

create or replace function public.enforce_otp_daily_cap()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_norm text := regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g');
begin
  if v_norm in ('70000000001') then
    return new;                                   -- mağaza/demo bypass numarası
  end if;
  if (select count(*) from public.otp_send_log
       where phone = v_norm and created_at > now() - interval '24 hours') >= 15 then
    raise exception 'OTP_DAILY_CAP';
  end if;
  insert into public.otp_send_log (phone) values (v_norm);
  return new;
end $$;
drop trigger if exists trg_enforce_otp_daily_cap on public.call_otps;
create trigger trg_enforce_otp_daily_cap
  before insert on public.call_otps for each row execute function public.enforce_otp_daily_cap();

select cron.unschedule(jobid) from cron.job where jobname = 'cleanup-otp-send-log';
select cron.schedule('cleanup-otp-send-log', '45 3 * * *',
  $$delete from public.otp_send_log where created_at < now() - interval '2 days'$$);

commit;
