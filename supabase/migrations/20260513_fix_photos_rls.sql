-- Fix: photos moderation default ve RLS
-- Sorun: yeni yüklenen fotoğraflar 'pending' kalıyor, başka kullanıcılar göremiyordu

-- 1. Mevcut pending fotoğrafları approve et
update user_photos
set moderation_status = 'approved'
where moderation_status = 'pending';

-- 2. Default'u 'approved' olarak değiştir (AI moderation pipeline aktif olana kadar)
alter table user_photos
  alter column moderation_status set default 'approved';

-- 3. RLS: rejected hariç tüm fotoğrafları göster
drop policy if exists "photos_select" on user_photos;
create policy "photos_select" on user_photos for select using (
  moderation_status != 'rejected' or user_id = auth.uid()
);
