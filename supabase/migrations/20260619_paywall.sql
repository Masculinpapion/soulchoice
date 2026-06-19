-- ─────────────────────────────────────────────────────────────────────────────
-- Paywall — V1
-- Tek paket: 1000₽/ay. Ömür boyu 1 ücretsiz başvuru.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) users.subscription_status enum'unu kod ile hizala: 'free' / 'active'
--    (Eski constraint 'free'/'premium' idi, kod ise 'active' arıyordu → kimse premium olamıyordu)
alter table users
  drop constraint if exists users_subscription_status_check;

update users set subscription_status = 'active' where subscription_status = 'premium';

alter table users
  add constraint users_subscription_status_check
  check (subscription_status in ('free', 'active'));

-- 2) Ömür boyu 1 ücretsiz başvuru — bayrak
alter table users
  add column if not exists free_application_used boolean default false not null;

-- 3) subscriptions: YooKassa token saklama + iptal zamanı
alter table subscriptions
  add column if not exists yookassa_payment_method_id text;

alter table subscriptions
  add column if not exists cancelled_at timestamptz;

-- 4) Server-side guard: başvuru insert'inden önce kontrol
--    Premium aktif VEYA ücretsiz hak kullanılmamış olmalı.
create or replace function can_user_apply(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select coalesce(
    (select subscription_status = 'active' or free_application_used = false
     from users where id = p_user_id),
    false
  );
$$;

-- 5) Application insert sonrası free flag işaretle (sadece free kullanıcı için)
create or replace function mark_free_application_used()
returns trigger
language plpgsql
as $$
begin
  update users
     set free_application_used = true
   where id = new.applicant_id
     and subscription_status = 'free'
     and free_application_used = false;
  return new;
end;
$$;

drop trigger if exists trg_mark_free_application on applications;
create trigger trg_mark_free_application
after insert on applications
for each row
execute function mark_free_application_used();
