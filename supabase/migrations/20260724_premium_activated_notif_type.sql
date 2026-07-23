-- premium_activated bildirim tipi: web ödeme aktivasyonunda zil ekranı kaydı
-- (tochka-webhook, PREMIUM_BELL_NOTIF flag'i açılınca insert etmeye başlar).
alter table notifications drop constraint notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type = any (array[
    'new_application', 'selected', 'not_selected', 'new_message',
    'selfie_approved', 'selfie_rejected', 'meeting_reminder',
    'feedback_request', 'selection_reminder', 'premium_activated'
  ]::text[]));
