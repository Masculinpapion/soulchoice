-- Ops paneli "Hizmetteki Şehirler" TR/EN dilde de Rusça kalıyordu (01.08):
-- v_live_cities yalnız name_ru döndürüyordu. name_tr/name_en SONA eklendi
-- (create or replace view mevcut kolon sırasını korumak zorunda);
-- `city` (name_ru) online eşleşmesinin anahtarı olarak aynen kalır.
create or replace view public.v_live_cities as
select c.name_ru as city,
       c.country,
       c.lat,
       c.lng,
       count(*) filter (where u.last_seen_at > (now() - interval '5 minutes')) as online,
       count(*) filter (where u.last_seen_at > (now() - interval '1 hour')) as active1h,
       count(*) filter (where not u.is_test_user) as users_real,
       count(*) as users_total,
       c.name_tr,
       c.name_en
  from cities c
  left join users u on u.city_id = c.id and not u.is_deleted
 where c.is_active
 group by c.name_ru, c.name_tr, c.name_en, c.country, c.lat, c.lng;
