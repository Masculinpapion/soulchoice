-- Sürüm telemetrisi + zorunlu-güncelleme kapısı (29.08.2026 gecesi).
-- Sebep: RuStore'da güncelleme dağıtımı belirsiz (São 768 çıktıktan sonra da
-- 708'de kaldı) ve moderasyon ≤3 gün — hangi kullanıcı hangi build'de
-- görünmüyordu ve kritik fix'te eski sürümü durdurma imkânı yoktu.
--
-- users.app_build: istemci savePushToken'da yazar (authenticated'ın UPDATE'i
-- tablo seviyesinde — ek grant gerekmez; SELECT bilinçli verilmiyor).
alter table public.users add column if not exists app_build integer;

-- min_supported_build: {"v":0} = kapı KAPALI (varsayılan). Kritik durumda
-- {"v":N} yapılırsa build<N istemciler /update-required'a kilitlenir
-- (update_gate.dart; bayrak okunamazsa kapı açılmaz — yanlış pozitif yok).
insert into public.feature_flags (key, value)
values ('min_supported_build', '{"v": 0}'::jsonb)
on conflict (key) do nothing;
