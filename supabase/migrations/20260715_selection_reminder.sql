-- 🟡5: seçim penceresi kapanırken ilan sahibine tek seferlik hatırlatma.
-- Bulgu (15.07 yolculuk taraması): owner unutursa bekleyen başvurular sessizce
-- expire oluyor, potansiyel eşleşmeler ölüyor. Saatlik selection-reminder edge
-- fonksiyonu ≤12h kalan + bekleyen başvurulu ilanlarda push + in-app gönderir.
alter table public.invitations add column if not exists owner_reminded_at timestamptz;
notify pgrst, 'reload schema';
