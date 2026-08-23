-- 23.08.2026 — canlı vaka: uygulama içi YENİ kayıt 31.07'den beri kırıktı.
-- profile_setup upsert'i 'phone' gönderiyordu; 20260731_users_column_privacy
-- authenticated'dan phone SELECT'ini kaldırdığı için Postgres ON CONFLICT DO
-- UPDATE yolu (excluded.phone okuması) "permission denied for table users"
-- veriyordu (PostgREST 403, Kong logu 23.08 13:49). İstemci artık phone
-- göndermiyor; telefon INSERT sırasında burada auth.users'tan doldurulur.

create or replace function public.users_fill_phone_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.phone is null then
    select u.phone into new.phone from auth.users u where u.id = new.id;
  end if;
  return new;
end $$;

revoke all on function public.users_fill_phone_from_auth() from public, anon, authenticated;

drop trigger if exists trg_users_fill_phone_from_auth on public.users;
create trigger trg_users_fill_phone_from_auth
  before insert on public.users
  for each row execute function public.users_fill_phone_from_auth();
