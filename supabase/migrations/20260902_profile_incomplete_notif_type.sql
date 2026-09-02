-- profile_incomplete bildirim tipi: ops/profile-nudge.sh (saatlik cron) kayıttan
-- ≥24 s fotoğrafsız kullanıcıya tek in-app + push yazar. 02.09 sabahı kısıt
-- bu tipi içermediği için insert reddedildi (Гоша'ya 3 koşu boyunca sıfır teslim).
alter table notifications drop constraint notifications_type_check;
alter table notifications add constraint notifications_type_check
  check (type = any (array[
    'new_application', 'selected', 'not_selected', 'new_message',
    'selfie_approved', 'selfie_rejected', 'meeting_reminder',
    'feedback_request', 'selection_reminder', 'premium_activated',
    'invitation_updated', 'profile_incomplete'
  ]::text[]));
