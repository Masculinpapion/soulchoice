-- 13.07.2026 — Bildirim tercihleri UI'ı canlıya alındı.
-- notification_preferences tablosu + kolonları zaten mevcuttu (kayıt/dok amaçlı).
-- PK = user_id (upsert onConflict), RLS: kullanıcı kendi satırını okur/yazar.
-- send-notification edge fn artık bu tabloyu okuyor: tür kapalı → push atla,
-- sessiz saatler içinde → push atla (uygulama-içi notifications kaydı ayrı).
-- Bu dosya no-op doğrulama; şema değişikliği yok.
do $$
begin
  if not exists (select 1 from information_schema.columns
    where table_name='notification_preferences' and column_name='push_new_application') then
    raise exception 'notification_preferences beklenen kolonları içermiyor';
  end if;
end $$;
