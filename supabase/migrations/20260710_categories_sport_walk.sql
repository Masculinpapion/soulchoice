-- 10.07.2026 — Davet kategorileri 9→11: sport + walk
-- (Prod'a 10.07.2026 uygulandı; bu dosya kayıt/yeniden-kurulum içindir.)
-- Not: ALTER, tablo sahibi (supabase_admin) ile koşulmalı.

alter table public.invitations drop constraint invitations_category_check;
alter table public.invitations add constraint invitations_category_check
  check (category = any (array[
    'food','concert','travel','culture','cinema','theater','coffee','bar','gift',
    'sport','walk'
  ]::text[]));
