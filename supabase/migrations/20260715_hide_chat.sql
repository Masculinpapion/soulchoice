-- Tek-taraflı sohbet gizleme (WhatsApp standardı, docs/product-logic.md §7).
-- Gizleyen kullanıcının listesinden sohbet kalkar; karşı tarafta durur; mesaj
-- geçmişi korunur; gizlenen sohbete yeni mesaj gelince liste'ye geri döner
-- (liste sorgusu son-mesaj > hidden_at kontrolüyle otomatik). Match SİLİNMEZ.
-- Engelleme bundan ayrıdır (match silme, değişmedi).

begin;

alter table public.matches add column if not exists user1_hidden_at timestamptz;
alter table public.matches add column if not exists user2_hidden_at timestamptz;

-- Gizleyen taraf yalnız KENDİ hidden_at kolonunu set eder (karşı tarafınkine
-- dokunamaz) + bu match'teki okunmamışlarını okundu yapar (rozet temizliği;
-- sohbet geri geldiğinde yalnız yeni mesaj "okunmamış" sayılır).
create or replace function public.hide_chat(p_match_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.matches
     set user1_hidden_at = case when user1_id = auth.uid() then now() else user1_hidden_at end,
         user2_hidden_at = case when user2_id = auth.uid() then now() else user2_hidden_at end
   where id = p_match_id
     and (user1_id = auth.uid() or user2_id = auth.uid());

  update public.messages
     set read_at = now()
   where match_id = p_match_id
     and read_at is null
     and sender_id is distinct from auth.uid();
end;
$$;

revoke all on function public.hide_chat(uuid) from public;
grant execute on function public.hide_chat(uuid) to authenticated;

commit;

notify pgrst, 'reload schema';
