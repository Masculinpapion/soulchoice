-- photoFocus sınırsız sorgu (31.07 denetim backlog'u): istemci her açılışta TÜM
-- kullanıcıların TÜM fotoğraflarını çekiyordu. Artık yalnız görünür kullanıcıların
-- (silinmemiş/banlanmamış) odak verisi iner, en yeni 5000 fotoğrafla sınırlı.
-- security definer: istemciye users join'i açmadan filtre sunucuda uygulanır.
create or replace function public.photo_focus_entries()
returns table (url text, face_focus_x real, face_focus_y real)
language sql
stable
security definer
set search_path = public
as $$
  select p.url, p.face_focus_x, p.face_focus_y
    from user_photos p
    join users u on u.id = p.user_id
   where p.face_focus_x >= 0
     and coalesce(u.is_deleted, false) = false
     and coalesce(u.banned, false) = false
   order by p.created_at desc
   limit 5000
$$;

-- DİKKAT: default privileges anon'a DOĞRUDAN execute verir — 'from public'
-- revoke'u onu kaldırmaz (31.07 kolon-GRANT dersiyle aynı aile), anon ayrıca yazılır.
revoke all on function public.photo_focus_entries() from public;
revoke execute on function public.photo_focus_entries() from anon;
grant execute on function public.photo_focus_entries() to authenticated, service_role;
