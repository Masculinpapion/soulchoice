-- F2 Faz 3: billing-cron zemin — dry_run + S3 banka limiti + digest adresi + grace-uyumlu downgrade
-- Uygulama: supabase_admin ile, öncesinde DB yedeği.

begin;

-- 1) billing_config: cron parametreleri
alter table public.billing_config
  add column if not exists dry_run boolean not null default true,           -- ilk canlı koşu DRY-RUN (Mustafa şartı)
  add column if not exists max_daily_attempts integer not null default 1,   -- S3: banka limiti günde 2; biz 1'de sabitliyoruz
  add column if not exists digest_email text not null default 'mustafaaladag.ma@gmail.com';

-- 2) downgrade_expired_premium: KARAR 2 grace koruması — past_due + grace içindeki kullanıcı
--    premium_until geçmiş olsa bile free'ye DÜŞÜRÜLMEZ (grace bitince billing-cron expired yapar,
--    sonraki saatlik koşuda burası düşürür).
create or replace function public.downgrade_expired_premium()
returns void
language sql
as $function$
  update users u
     set subscription_status = 'free'
   where u.subscription_status = 'active'
     and u.premium_until is not null
     and u.premium_until < now()
     and not exists (
       select 1 from subscriptions s
        where s.user_id = u.id
          and s.status = 'past_due'
          and s.grace_until is not null
          and s.grace_until > now()
     );
$function$;

-- 3) billing_events: cron'un günlük-deneme ve son-sonuç sorguları için indeks
create index if not exists idx_billing_events_sub_event
  on public.billing_events (subscription_id, event, created_at desc);

commit;
