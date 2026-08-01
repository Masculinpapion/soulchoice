-- 01.08.2026 — Sohbet silme (tek taraflı, Mustafa kararı; UI etiketi düz "Удалить чат")
-- Semantik: silen tarafın geçmişi kalıcı gizlenir (cleared_at öncesi mesajlar ona
-- gösterilmez), karşı tarafın kopyası aynen durur. Yeni mesaj gelirse sohbet
-- sıfırdan (yalnız yeni mesajlarla) geri gelir. 20.07 "sohbetler kalıcı" kararıyla
-- uyumlu: sunucudan hiçbir mesaj silinmez.
ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS user1_cleared_at timestamptz,
  ADD COLUMN IF NOT EXISTS user2_cleared_at timestamptz;

CREATE OR REPLACE FUNCTION public.clear_chat(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
begin
  update public.matches
     set user1_cleared_at = case when user1_id = auth.uid() then now() else user1_cleared_at end,
         user2_cleared_at = case when user2_id = auth.uid() then now() else user2_cleared_at end,
         user1_hidden_at  = case when user1_id = auth.uid() then now() else user1_hidden_at end,
         user2_hidden_at  = case when user2_id = auth.uid() then now() else user2_hidden_at end
   where id = p_match_id
     and (user1_id = auth.uid() or user2_id = auth.uid());

  -- Silinen sohbetin okunmamışları rozette sayılmasın
  update public.messages
     set read_at = now()
   where match_id = p_match_id
     and read_at is null
     and sender_id is distinct from auth.uid();
end;
$$;
GRANT EXECUTE ON FUNCTION public.clear_chat(uuid) TO authenticated;

-- Sohbet özetleri: cleared_at öncesi mesajlar çağırana yok sayılır
CREATE OR REPLACE FUNCTION public.my_chat_summaries()
RETURNS TABLE(match_id uuid, content text, sender_id uuid, created_at timestamptz, unread integer)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  with my as (
    select id,
           case when user1_id = auth.uid() then user1_cleared_at
                else user2_cleared_at end as cleared_at
      from matches
     where user1_id = auth.uid() or user2_id = auth.uid()
  ),
  last_msg as (
    select distinct on (m.match_id)
           m.match_id, m.content, m.sender_id, m.created_at
      from messages m
      join my on my.id = m.match_id
     where my.cleared_at is null or m.created_at > my.cleared_at
     order by m.match_id, m.created_at desc
  ),
  unread_cnt as (
    select m.match_id, count(*)::int as cnt
      from messages m
      join my on my.id = m.match_id
     where m.read_at is null
       and m.sender_id is distinct from auth.uid()
       and (my.cleared_at is null or m.created_at > my.cleared_at)
     group by m.match_id
  )
  select l.match_id, l.content, l.sender_id, l.created_at,
         coalesce(u.cnt, 0)
    from last_msg l
    left join unread_cnt u on u.match_id = l.match_id;
$$;
