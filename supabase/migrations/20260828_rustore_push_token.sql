-- RuStore Push token (28.08.2026, София vakası): GMS'siz cihazlar (RuStore
-- kitlesinde yaygın) FCM token alamıyor → kullanıcı tamamen push'suz kalıyordu.
-- İstemci RuStore Push SDK token'ını bu kolona yazar; send-notification
-- gönderimde fcm_token'ı önceler, yoksa RuStore transportuna (VK PNS) düşer.
--
-- Grant notu: authenticated'ın UPDATE'i tablo seviyesinde olduğundan yeni kolon
-- otomatik yazılabilir; SELECT kolon-bazlı verildiğinden bu kolon (fcm_token
-- gibi) istemciden OKUNAMAZ — bilinçli.
alter table public.users add column if not exists rustore_token text;
