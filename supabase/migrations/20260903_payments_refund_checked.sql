-- 03.09.2026 — Kalite teşhisi (B3, billing-cron Faz E): iade taraması damgası.
-- Eskiden son 120 günün her ödemesi her koşuda Точка API'sine soruluyordu; artık operasyon başına
-- 24 saatte bir, koşu başına ≤50 (en eski kontrol önce). billing-cron artık saatlik koşar
-- ({"quiet":true}: aktivite/kırmızı yoksa digest maili yok; 07:25 UTC tam digest).
begin;
alter table public.payments add column if not exists refund_checked_at timestamptz;
create index if not exists idx_payments_refund_check
  on public.payments (refund_checked_at nulls first)
  where status = 'paid' and operation_id <> '';
commit;
