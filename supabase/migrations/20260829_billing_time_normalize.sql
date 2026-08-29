-- Billing saat normalizasyonu (Mustafa onayı 28.08.2026, uygulama 29.08 ilk doğal çekim sonrası).
-- Sorun: next_billing_at ödeme anının saatini taşıyor (örn. 07:25:08 UTC); günlük billing-cron
-- 07:25:00 UTC'de koştuğu için çekim ekranda yazan günden BİR GÜN SONRAYA kayıyordu
-- (28.08 vakası: ekran «списание 28.08», fiili çekim 29.08 sabahı).
-- Çözüm: next_billing_at daima MSK 09:00'a (06:00 UTC) sabitlenir — 10:25 MSK cron koşusu
-- aynı gün yakalar; tarih müşteri ekranındaki (MSK) tarihle birebir aynı kalır.
-- Uygulama noktası TRIGGER: edge kodu değişmez (deploy/restart kesintisi yok),
-- bütün yazıcılar (billing-charge, tochka-webhook grantPeriod, manage-subscription resume,
-- elle düzeltmeler) tek noktadan kapsanır. expires_at / premium_until DEĞİŞMEZ;
-- erken çekimde dönem kısalmaz (grant formülü: greatest(premium_until, now()) + 30 gün).

create or replace function public.fn_next_billing_anchor(ts timestamptz)
returns timestamptz
language sql
immutable
as $$
  select ((ts at time zone 'Europe/Moscow')::date + time '09:00') at time zone 'Europe/Moscow'
$$;

create or replace function public.fn_subscriptions_anchor_billing()
returns trigger
language plpgsql
as $$
begin
  if new.next_billing_at is not null then
    new.next_billing_at := public.fn_next_billing_anchor(new.next_billing_at);
  end if;
  return new;
end
$$;

drop trigger if exists zz_anchor_next_billing on public.subscriptions;
create trigger zz_anchor_next_billing
  before insert or update of next_billing_at on public.subscriptions
  for each row execute function public.fn_subscriptions_anchor_billing();

-- Bir defalık düzeltme: mevcut aboneliklerin next_billing_at'i normalize edilir
-- (29.08 yenilemesiyle oluşan 28.09 07:25:08 kaydı dahil; trigger aynı işi yapar,
-- UPDATE yalnız tetikleyicidir).
update public.subscriptions
   set next_billing_at = next_billing_at
 where next_billing_at is not null
   and next_billing_at <> public.fn_next_billing_anchor(next_billing_at);
