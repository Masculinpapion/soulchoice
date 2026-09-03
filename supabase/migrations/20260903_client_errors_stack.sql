-- 03.09.2026 — Kalite teşhisi (A2): istemci hata raporları stack trace ve cihaz bilgisi taşımıyordu
-- (3 haftada 11 kayıt, hepsinde screen='flutter_error'/'platform_error', stack yok).
begin;
alter table public.client_errors add column if not exists stack  text;
alter table public.client_errors add column if not exists device text;
commit;
