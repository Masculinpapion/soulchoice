-- 16.07 selfie E2E testinde yakalandı: selfie yüklemek users.selfie_status'u
-- 'pending'e ÇEVİRMİYORDU (hiçbir kod set etmiyordu) → kullanıcı beklemedeyken
-- ilan/başvuru kapısı hâlâ "selfie yükle" diyordu, "inceleniyor" metinleri ölü
-- koddu. Artık selfie fotoğrafı kuyruğa düşünce durum pending olur.
-- approved kullanıcı yeniden yüklerse statüsü DÜŞMEZ (yalnız none/rejected→pending).

begin;

create or replace function public.mark_selfie_pending()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.is_selfie and coalesce(new.moderation_status, 'pending') = 'pending' then
    update public.users
       set selfie_status = 'pending'
     where id = new.user_id
       and selfie_status in ('none', 'rejected');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_selfie_pending on public.user_photos;
create trigger trg_selfie_pending
  after insert on public.user_photos
  for each row execute function public.mark_selfie_pending();

commit;

notify pgrst, 'reload schema';
