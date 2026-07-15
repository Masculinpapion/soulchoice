-- 16.07 selfie E2E (Mustafa cihazı): bildirim ekranı realtime'a abone ama
-- notifications tablosu publication'da değildi → insert invalidate'i hiç
-- tetiklenmiyordu, açık ekran bayat kalıyordu (matches'taki dersin aynısı).
alter publication supabase_realtime add table public.notifications;
