-- ============================================================================
-- ops/teardown-test-data.sql — Canlılık simülasyonu SÖKÜM (tek dosya, sıralı)
-- Çalıştırmadan önce: pg_dump yedeği al (feedback_production_change_safety).
-- ============================================================================

begin;

-- 0) Silinecek storage objelerinin envanterini ÖNCE çıkar (users silinince kaybolur)
create temp table _teardown_photo_urls as
select distinct regexp_replace(p.url, '^.*/object/public/profile-photos/', '') as object_name
from public.user_photos p
join public.users u on u.id = p.user_id
where u.is_test_user = true;

-- 1) cron + fonksiyon
select cron.unschedule(jobid) from cron.job where jobname = 'simulate-test-liveliness';
drop function if exists public.simulate_test_liveliness();

-- 2) matches: users FK'ları CASCADE değil (D3 bulgusu 10.07) → önce elle sil
delete from public.matches m
using public.users u
where u.is_test_user = true
  and (m.user1_id = u.id or m.user2_id = u.id);

-- 3) reports: FK'lar NO ACTION → test kullanıcısına dokunan raporları temizle
delete from public.reports r
using public.users u
where u.is_test_user = true
  and (r.reported_user_id = u.id or r.reporter_id = u.id);

-- 4) Kullanıcılar: auth.users → public.users CASCADE → invitations/applications/
--    user_photos/messages/subscriptions/… hepsi CASCADE (D3 teyitli)
delete from auth.users a
using public.users u
where u.id = a.id and u.is_test_user = true;

-- 5) Storage satırları (envanterden)
-- DİKKAT: aynı dosya gerçek bir kullanıcıda da kullanılıyorsa silme — kesişim kontrolü:
delete from storage.objects o
where o.bucket_id = 'profile-photos'
  and o.name in (select object_name from _teardown_photo_urls)
  and not exists (
    select 1 from public.user_photos p2
    where p2.url like '%' || o.name
  );

commit;

-- 6) NOT (SQL dışı): storage file-backend disk dosyaları objects satırı silinince
--    otomatik gitmez — /var/lib/storage altında yetim dosya temizliği için
--    storage API üzerinden silme tercih edilir ya da yetimler ayrı script ile
--    süpürülür (bkz reference_storage_xattr_restore — dosya backend'i xattr'lı).
