-- 16.07 panel bulgusu (Mustafa): selfie kartında city_id ham UUID görünüyordu.
-- View artık şehir ADI döndürür; panel meta satırı okunur hale gelir.
-- (kolon adı değiştiği için drop+create; ops_moderator grant'i yeniden verilir)
drop view if exists public.v_pending_selfies;
create view public.v_pending_selfies as
 SELECT u.id AS user_id,
    u.name,
    u.age,
    (SELECT c.name FROM cities c WHERE c.id = u.city_id) AS city,
    u.created_at AS registered_at,
    u.is_test_user,
    ( SELECT o.name
           FROM storage.objects o
          WHERE o.bucket_id = 'selfies'::text AND o.name ~~ (u.id::text || '/%'::text)
          ORDER BY o.created_at DESC
         LIMIT 1) AS selfie_object,
    ( SELECT p.url
           FROM user_photos p
          WHERE p.user_id = u.id AND p.is_primary
          ORDER BY p.created_at DESC
         LIMIT 1) AS primary_photo_url
   FROM users u
  WHERE u.selfie_status = 'pending'::text AND u.is_deleted = false
  ORDER BY u.created_at;
grant select on public.v_pending_selfies to ops_moderator;
notify pgrst, 'reload schema';
