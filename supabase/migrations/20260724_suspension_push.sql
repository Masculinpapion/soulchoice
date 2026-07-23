-- 24.07 C1 (Mustafa delegasyonu): askıya alma/ban anında NÖTR push.
-- Tek nokta: users.suspended_at NULL→NOT NULL geçişi — no-show askısı (confirm_meeting),
-- ops ban (ops_ban_user) ve gelecekteki tüm askı yolları otomatik kapsanır.
-- Metin ALICININ dilinde send-notification 'account_suspended' şablonundan üretilir;
-- buradaki RU yalnız fallback. Gerekçe metni ve itiraz akışı = post-launch karar (C1 notu).
-- Zil kaydı bilinçli YOK: eski build'ler bilinmeyen tipi ham slug gösterir.
create or replace function public.notify_suspension()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.suspended_at is not null and old.suspended_at is null then
    begin
      perform net.http_post(
        url := 'http://supabase-edge-functions:9000/send-notification',
        body := jsonb_build_object(
          'user_id', new.id,
          'title', 'SoulChoice',
          'body', 'Аккаунт приостановлен — подробности: support@soulchoice.app',
          'data', jsonb_build_object('type', 'account_suspended')),
        headers := '{"Content-Type": "application/json"}'::jsonb);
    exception when others then null;
    end;
  end if;
  return new;
end $$;

drop trigger if exists trg_notify_suspension on public.users;
create trigger trg_notify_suspension
  after update of suspended_at on public.users
  for each row execute function public.notify_suspension();
