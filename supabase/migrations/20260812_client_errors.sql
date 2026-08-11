-- 12.08.2026 — Nöbetçi Kovan faz 1: istemci hata telemetrisi (Mustafa kararı).
-- Kullanıcının yaşadığı SESSİZ hatalar (çökme değil) artık görünür olur.
-- Yazma yalnız log-client-error edge fonksiyonundan (service key) — tabloya
-- doğrudan SELECT/INSERT policy'si bilinçli YOK (anon spam + veri sızıntısı
-- kapalı; okuma yalnız servis/ops).
create table if not exists public.client_errors (
  id bigint generated always as identity primary key,
  user_id uuid,
  platform text not null default 'unknown',
  app_build text not null default '',
  screen text not null default '',
  error text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_client_errors_created on public.client_errors (created_at desc);
create index if not exists idx_client_errors_error on public.client_errors (left(error, 80), created_at desc);
alter table public.client_errors enable row level security;

-- 30 günden eski kayıtlar günlük temizlenir (kişisel veri minimizasyonu)
create or replace function public.cleanup_client_errors()
returns integer language plpgsql security definer set search_path = public, pg_temp as $fn$
declare n integer;
begin
  with del as (
    delete from public.client_errors where created_at < now() - interval '30 days' returning 1
  ) select count(*) into n from del;
  return n;
end $fn$;
