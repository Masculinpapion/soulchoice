-- ─────────────────────────────────────────────────────────────────────────────
-- Точка Банк ödeme entegrasyonu — V1 (платёжные ссылки)
-- Mimari: web/RuStore/Play → Точка linki; iOS entitlement onayına kadar hidden.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) payments — her Точка operasyonunun kaydı (Apple aylık raporu source üzerinden)
create table if not exists payments (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references users(id) on delete set null,
  operation_id text unique not null,
  amount numeric(10,2) not null,
  currency text not null default 'RUB',
  source text not null check (source in ('web', 'android', 'ios_app', 'test')),
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'refunded', 'failed', 'expired')),
  purpose text,
  payment_link text,
  raw jsonb,
  created_at timestamptz default now(),
  paid_at timestamptz
);

create index if not exists idx_payments_user on payments(user_id);
create index if not exists idx_payments_status on payments(status);

alter table payments enable row level security;

-- Kullanıcı sadece kendi ödemelerini okur; yazma yalnız service_role (policy yok)
drop policy if exists payments_own_read on payments;
create policy payments_own_read on payments
  for select using (auth.uid() = user_id);

-- 2) subscriptions.provider: 'tochka' eklendi (yookassa artık kullanılmıyor ama
--    eski kayıtlar bozulmasın diye listede kalıyor)
alter table subscriptions drop constraint if exists subscriptions_provider_check;
alter table subscriptions add constraint subscriptions_provider_check
  check (provider in ('yookassa', 'apple', 'google', 'stripe', 'tochka'));

-- 3) users.premium_until — ucuz süre kontrolü + billing cron hedefi
alter table users add column if not exists premium_until timestamptz;

-- 4) Paywall davranışı sunucudan yönetilir (store incelemesinde kill switch).
--    iOS, External Purchase entitlement onayına kadar 'hidden' başlar.
insert into feature_flags (key, value, description) values
  ('paywall_mode',
   '{"web": "link", "android": "link", "ios": "hidden"}',
   'Paywall CTA per platform: link = Tochka linkini ac, hidden = buton gizli')
on conflict (key) do nothing;

-- 5) Billing V1: süresi dolan premium'u free'ye düşür (pg_cron saatlik çağırır;
--    cron.schedule migration dışında elle kurulur)
create or replace function downgrade_expired_premium()
returns void
language sql
as $$
  update users
     set subscription_status = 'free'
   where subscription_status = 'active'
     and premium_until is not null
     and premium_until < now();
$$;
