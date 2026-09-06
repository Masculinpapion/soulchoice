-- 06.09.2026 (Mustafa, «Ангелина» vakası): Telegram kayıt/selfie alarmı ve panel kuyruğu
-- profil özetini de göstersin — cinsiyet, gösterim tercihi, yaş aralığı, dil, bio.
-- Kadın fotoğraflı «erkek» profil + «Мы пара ищем девушку…» bio'su fotoğraf-only
-- alarmda görünmüyordu; karar insanda kalır, bilgi erken gelir. Kolonlar SONA eklendi
-- (panel/agent mevcut kolonları isimle okur). ops_moderator SELECT hakkı view'de kalır.
begin;

create or replace view public.v_pending_selfies as
select u.id  as user_id,
       u.name, u.age,
       (select c.name from public.cities c where c.id = u.city_id) as city,
       u.created_at as registered_at,
       u.is_test_user,
       (select o.name from storage.objects o
         where o.bucket_id = 'selfies' and o.name like u.id::text || '/%'
         order by o.created_at desc limit 1) as selfie_object,
       (select p.url from public.user_photos p
         where p.user_id = u.id and p.is_primary
         order by p.created_at desc limit 1) as primary_photo_url,
       u.gender,
       u.show_gender,
       u.min_age, u.max_age,
       u.locale,
       left(coalesce(u.bio, ''), 300) as bio
from public.users u
where u.selfie_status = 'pending' and u.is_deleted = false
order by u.created_at;

grant select on public.v_pending_selfies to ops_moderator;

commit;
notify pgrst, 'reload schema';
