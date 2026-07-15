-- "Silinen kullanıcı" modeli (karar 15.07.2026):
-- Hesap silinince karşı tarafın sohbeti + mesajları korunur, silinen taraf
-- app'te "Удалённый пользователь" görünür, yeni mesaj yazılamaz.
-- Öncesi: matches.user*_id / reports.* NO ACTION → match'i olan kullanıcı
-- hesabını hiç silemiyordu; messages.sender_id CASCADE → silinseydi karşı
-- tarafın sohbeti de gidecekti.

begin;

-- 1) matches: kullanıcı FK'ları silmeyi bloklamasın, SET NULL olsun
alter table public.matches alter column user1_id drop not null;
alter table public.matches alter column user2_id drop not null;
alter table public.matches drop constraint matches_user1_id_fkey;
alter table public.matches add constraint matches_user1_id_fkey
  foreign key (user1_id) references public.users(id) on delete set null;
alter table public.matches drop constraint matches_user2_id_fkey;
alter table public.matches add constraint matches_user2_id_fkey
  foreign key (user2_id) references public.users(id) on delete set null;

-- 2) messages.sender_id: CASCADE → SET NULL (karşı tarafın sohbeti yaşar)
alter table public.messages alter column sender_id drop not null;
alter table public.messages drop constraint messages_sender_id_fkey;
alter table public.messages add constraint messages_sender_id_fkey
  foreign key (sender_id) references public.users(id) on delete set null;

-- 3) reports: moderasyon kaydı kullanıcı silinse de kalsın
alter table public.reports alter column reporter_id drop not null;
alter table public.reports alter column reported_user_id drop not null;
alter table public.reports drop constraint reports_reporter_id_fkey;
alter table public.reports add constraint reports_reporter_id_fkey
  foreign key (reporter_id) references public.users(id) on delete set null;
alter table public.reports drop constraint reports_reported_user_id_fkey;
alter table public.reports add constraint reports_reported_user_id_fkey
  foreign key (reported_user_id) references public.users(id) on delete set null;

-- 4) Tarafı silinmiş match'e yeni mesaj DB seviyesinde de yazılamaz
drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert
  with check (
    sender_id = auth.uid()
    and match_id in (
      select id from public.matches
      where (user1_id = auth.uid() or user2_id = auth.uid())
        and user1_id is not null
        and user2_id is not null
    )
  );

-- 5) mark-read bugüne kadar HİÇ çalışmadı: messages'ta UPDATE policy yoktu
--    (15.07 denetim bulgusu: 53 mesajın 0'ı read_at almış).
--    Alıcı kendi match'indeki karşı-taraf mesajlarını güncelleyebilir;
--    içerik kurcalaması trigger ile engellenir (sadece read_at değişebilir).
create policy messages_update_read on public.messages for update
  using (
    sender_id is distinct from auth.uid()
    and match_id in (
      select id from public.matches
      where user1_id = auth.uid() or user2_id = auth.uid()
    )
  )
  with check (
    sender_id is distinct from auth.uid()
    and match_id in (
      select id from public.matches
      where user1_id = auth.uid() or user2_id = auth.uid()
    )
  );

create or replace function public.prevent_messages_tamper()
returns trigger
language plpgsql
as $$
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.id := old.id;
    new.match_id := old.match_id;
    new.sender_id := old.sender_id;
    new.content := old.content;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_messages_tamper on public.messages;
create trigger trg_prevent_messages_tamper
  before update on public.messages
  for each row execute function public.prevent_messages_tamper();

-- 6) Her iki tarafı da silinmiş match'ler sahipsizdir — saatlik cleanup'a ekle
--    (mesajları matches.id CASCADE ile birlikte gider)
create or replace function public.cleanup_closed_invitations()
returns integer
language plpgsql
security definer
as $$
declare n integer;
begin
  delete from public.matches
  where user1_id is null and user2_id is null;

  with del as (
    delete from public.invitations i
    where i.status = 'closed'
      and not exists (select 1 from public.matches m where m.invitation_id = i.id)
    returning 1
  )
  select count(*) into n from del;
  return n;
end;
$$;

commit;

notify pgrst, 'reload schema';
