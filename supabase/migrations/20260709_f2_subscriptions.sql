-- F2 otomatik yenilemeli abonelik — Faz 1 zemin migration'ı (docs/f2-billing-plan.md)
-- Uygulama: prod'da `supabase_admin` ile koşulur (postgres "must be owner" verir), ÖNCESİNDE DB yedeği.
--
-- BİLİNÇLİ ERTELEME: payments UNIQUE(operation_id) → UNIQUE(operation_id, order_id) geçişi bu
-- dosyada YOK. Canlıdaki tochka-webhook `on conflict (operation_id)` kullanıyor; kısıt şimdi
-- değişirse webhook'un insert yolu anında kırılır. Geçiş Faz 2'de webhook deploy'uyla atomik
-- yapılacak (ilk renewal Faz 3'te — pencere güvenli).

begin;

-- 1) users: abonelik bildirim e-postası (KARAR 3 — yalnız abonelerden istenir)
alter table public.users add column if not exists billing_email text;

-- 2) subscriptions: kayıt günlüğünden gerçek abonelik varlığına
alter table public.subscriptions
  add column if not exists tochka_subscription_id text,
  add column if not exists next_billing_at timestamptz,
  add column if not exists renewal_notified_at timestamptz,
  add column if not exists notified_channels text[],
  add column if not exists retry_count integer not null default 0,
  add column if not exists grace_until timestamptz,
  add column if not exists card_masked_pan text,   -- Точка CofToken.maskedPan (maske; PAN saklanmaz)
  add column if not exists card_type text;

-- F1 satırlarında null kalacağı için partial unique
create unique index if not exists subscriptions_tochka_sub_id_key
  on public.subscriptions (tochka_subscription_id)
  where tochka_subscription_id is not null;

alter table public.subscriptions drop constraint if exists subscriptions_status_check;
alter table public.subscriptions add constraint subscriptions_status_check
  check (status = any (array['pending_binding'::text, 'active'::text, 'cancelled'::text,
                             'past_due'::text, 'expired'::text]));

-- billing-cron taraması (FAZ A/B): aktif+auto_renew dolanlar
create index if not exists idx_subscriptions_billing
  on public.subscriptions (next_billing_at)
  where status in ('active', 'past_due') and auto_renew;

-- 3) payments: abonelik bağı + çekim türü + Точка Order[].orderId (Faz 0: renewal kimliği)
alter table public.payments
  add column if not exists subscription_id uuid references public.subscriptions(id) on delete set null,
  add column if not exists charge_type text not null default 'one_time',
  add column if not exists order_id text not null default '';

alter table public.payments drop constraint if exists payments_charge_type_check;
alter table public.payments add constraint payments_charge_type_check
  check (charge_type = any (array['one_time'::text, 'subscription_initial'::text,
                                  'subscription_renewal'::text]));

create index if not exists idx_payments_subscription on public.payments (subscription_id);

-- 4) billing_events (P1): append-only denetim günlüğü.
--    ZORUNLU consent sözleşmesi (Mustafa, 09.07.2026): event='consent_autopay' kaydının detail'i
--    MUTLAKA içerir: oferta_version (örn "2026-07-07"), accepted_at (ISO ts), source ("web"|"app").
--    Diğer event'ler: created / binding_paid / notified / charge_attempt / charge_ok / charge_fail /
--    grace_start / downgraded / cancelled / reactivated / mismatch / digest.
create table if not exists public.billing_events (
  id uuid primary key default uuid_generate_v4(),
  subscription_id uuid references public.subscriptions(id) on delete set null,
  user_id uuid references public.users(id) on delete set null,
  event text not null,
  detail jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_billing_events_sub on public.billing_events (subscription_id, created_at);
create index if not exists idx_billing_events_user on public.billing_events (user_id, created_at);

-- 5) billing_config (P6): tek satırlık parametre tablosu — fiyat/retry deploy'suz değişir
create table if not exists public.billing_config (
  id integer primary key default 1 check (id = 1),
  price_rub integer not null default 1000,
  period_days integer not null default 30,
  retry_offsets_hours integer[] not null default '{0,24,48}',  -- KARAR 2
  grace_hours integer not null default 24,                     -- son denemeden sonra
  notify_before_hours integer not null default 36,             -- FAZ A penceresi
  min_notify_gap_hours integer not null default 24,            -- F2-1: bildirim→çekim asgari arası
  updated_at timestamptz not null default now()
);
insert into public.billing_config (id) values (1) on conflict (id) do nothing;

-- 6) cron_heartbeat (P3): dead-man switch damgası (status endpoint'i yaşı raporlar)
create table if not exists public.cron_heartbeat (
  job text primary key,
  last_run_at timestamptz not null default now(),
  last_status text,
  detail jsonb
);

-- 7) RLS + grants (F1 dersi: yeni tabloya grant ELLE verilir; mevcut policy kalıbı role()='service_role')
alter table public.billing_events enable row level security;
alter table public.billing_config enable row level security;
alter table public.cron_heartbeat enable row level security;

drop policy if exists service_manage_billing_events on public.billing_events;
create policy service_manage_billing_events on public.billing_events
  using (auth.role() = 'service_role');
drop policy if exists service_manage_billing_config on public.billing_config;
create policy service_manage_billing_config on public.billing_config
  using (auth.role() = 'service_role');
drop policy if exists service_manage_cron_heartbeat on public.cron_heartbeat;
create policy service_manage_cron_heartbeat on public.cron_heartbeat
  using (auth.role() = 'service_role');

grant all on public.billing_events, public.billing_config, public.cron_heartbeat to service_role;
-- webhook/cron DB_URL bağlantısı postgres rolüyle geliyor:
grant all on public.billing_events, public.billing_config, public.cron_heartbeat to postgres;

commit;
