-- Kullanıcı kendi bildirimini silebilmeli. SELECT/UPDATE politikası vardı,
-- DELETE hiç eklenmemişti → app'teki kaydır-sil sessizce 0 satır etkiliyor,
-- liste tazelenince bildirim "geri geliyordu" (13.07.2026 Mustafa bulgusu).
DROP POLICY IF EXISTS "Users delete own notifications" ON notifications;
CREATE POLICY "Users delete own notifications"
  ON notifications FOR DELETE
  USING (user_id = auth.uid());
