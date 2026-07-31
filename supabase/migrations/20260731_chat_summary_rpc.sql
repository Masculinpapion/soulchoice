-- 31.07.2026 — Mesajlar listesi ölçek düzeltmesi (performans denetimi).
-- Eski davranış: istemci "son mesaj + okunmamış sayısı" için TÜM eşleşmelerin
-- TÜM mesajlarını limitsiz indiriyordu (30 sohbet × 400 mesaj = 12.000 satır)
-- ve her yeni mesajda bunu baştan yapıyordu. Artık tek sorguda özet döner.

create or replace function public.my_chat_summaries()
returns table (
  match_id   uuid,
  content    text,
  sender_id  uuid,
  created_at timestamptz,
  unread     int
)
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  with my as (
    select id from matches
     where user1_id = auth.uid() or user2_id = auth.uid()
  ),
  last_msg as (
    select distinct on (m.match_id)
           m.match_id, m.content, m.sender_id, m.created_at
      from messages m
      join my on my.id = m.match_id
     order by m.match_id, m.created_at desc
  ),
  unread_cnt as (
    select m.match_id, count(*)::int as cnt
      from messages m
      join my on my.id = m.match_id
     where m.read_at is null
       and m.sender_id is distinct from auth.uid()
     group by m.match_id
  )
  select l.match_id, l.content, l.sender_id, l.created_at,
         coalesce(u.cnt, 0)
    from last_msg l
    left join unread_cnt u on u.match_id = l.match_id;
$$;

revoke all on function public.my_chat_summaries() from public, anon;
grant execute on function public.my_chat_summaries() to authenticated;

-- Sohbet listesi ve sayfalama için gereken indeks (yoksa her özet full scan)
create index if not exists idx_messages_match_created
  on public.messages (match_id, created_at desc);
