-- F2 Faz 2: payments idempotency anahtarı (operation_id) → (operation_id, order_id)
-- Faz 0 bulgusu: abonelik çekimleri yeni operasyon yaratmaz; aynı operationId'nin Order[]
-- dizisine orderId eklenir → renewal kimliği (operation_id, order_id) çiftidir.
--
-- ⚠️ DEPLOY KURALI: Bu migration, tochka-webhook v2 ile AYNI pencerede uygulanır
-- (eski webhook `on conflict (operation_id)` kullanır ve bu kısıt kalkınca kırılır;
-- yeni webhook `on conflict (operation_id, order_id)` kullanır ve composite kısıt ister).
-- Sıra: migration → /root/volumes/functions/tochka-webhook güncelle → functions restart.
-- Uygulama: supabase_admin ile, öncesinde DB yedeği.

begin;

alter table public.payments drop constraint if exists payments_operation_id_key;
alter table public.payments add constraint payments_operation_order_key
  unique (operation_id, order_id);

commit;
