-- 03.09.2026 — Kalite teşhisi (B1): 15 FK kolonunda index yoktu; my_chat_summaries her açılışta
-- matches tam tarama yapıyordu (user1_id OR user2_id, ikisi de index'siz).
-- NOT: CREATE INDEX CONCURRENTLY transaction içinde çalışmaz → bu dosya BEGIN/COMMIT içermez,
-- psql ile satır satır uygulanır (canlıda kilitsiz).
create index concurrently if not exists idx_user_photos_user        on public.user_photos (user_id);
create index concurrently if not exists idx_matches_user1           on public.matches (user1_id);
create index concurrently if not exists idx_matches_user2           on public.matches (user2_id);
create index concurrently if not exists idx_blocks_blocked          on public.blocks (blocked_id);
create index concurrently if not exists idx_subscriptions_user      on public.subscriptions (user_id);
create index concurrently if not exists idx_messages_sender         on public.messages (sender_id);
create index concurrently if not exists idx_users_city              on public.users (city_id);
create index concurrently if not exists idx_invitations_place       on public.invitations (place_id);
create index concurrently if not exists idx_user_devices_user       on public.user_devices (user_id);
create index concurrently if not exists idx_message_reactions_user  on public.message_reactions (user_id);
create index concurrently if not exists idx_reports_invitation      on public.reports (invitation_id);
create index concurrently if not exists idx_reports_reporter        on public.reports (reporter_id);
create index concurrently if not exists idx_reports_reported_user   on public.reports (reported_user_id);
create index concurrently if not exists idx_reports_match           on public.reports (match_id);
create index concurrently if not exists idx_city_requests_user      on public.city_requests (user_id);

-- my_chat_summaries: OR yerine UNION ALL → iki index taraması (planlayıcı OR'da seq scan'e düşüyordu).
create or replace function public.my_chat_summaries()
 returns table(match_id uuid, content text, sender_id uuid, created_at timestamptz, unread integer)
 language sql stable security definer
 set search_path to 'public', 'pg_temp'
as $$
  with my as (
    select id, user1_cleared_at as cleared_at from matches where user1_id = auth.uid()
    union all
    select id, user2_cleared_at as cleared_at from matches where user2_id = auth.uid()
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
