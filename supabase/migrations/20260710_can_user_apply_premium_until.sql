-- 10.07.2026 — can_user_apply KARAR 4 uyumu (prod'a uygulandı 10.07)
-- Eski hali yalnız subscription_status='active' bakıyordu: iptal etmiş ama
-- premium dönemi süren kullanıcı (cancelled + premium_until > now) başvuramıyordu.
-- Not: supabase_admin ile koşulmalı (fonksiyon sahibi).

create or replace function public.can_user_apply(p_user_id uuid)
returns boolean language sql stable as $fn$
  select coalesce(
    (select subscription_status = 'active'
         or (premium_until is not null and premium_until > now())
         or free_application_used = false
     from users where id = p_user_id),
    false
  );
$fn$;
