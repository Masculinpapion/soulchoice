-- 🟡5: seçim penceresi kapanırken ilan sahibine tek seferlik hatırlatma.
-- Bulgu (15.07 yolculuk taraması): owner unutursa bekleyen başvurular sessizce
-- expire oluyor, potansiyel eşleşmeler ölüyor. Saatlik selection-reminder edge
-- fonksiyonu ≤12h kalan + bekleyen başvurulu ilanlarda push + in-app gönderir.
alter table public.invitations add column if not exists owner_reminded_at timestamptz;

-- notifications.type check'ine yeni tür eklenir
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type = any (array['new_application','selected','not_selected','new_message',
                           'selfie_approved','selfie_rejected','meeting_reminder',
                           'feedback_request','selection_reminder']));

notify pgrst, 'reload schema';
