-- Launch-öncesi ürün-mantığı düzeltmeleri (docs/product-logic.md §4, §9):
-- (1) Kapanan ilanlarda seçilmeyen 'pending' başvurular sonsuza dek pending
--     kalıyordu → 'expired'e çekilir (başvurana bildirim GÖNDERİLMEZ — §4 bilinçli
--     sessizlik). (2) Selfie onay bildirimindeki "mavi tik" metni (özellik 19.06'da
--     kaldırıldı) nötr metinle değiştirilir.

begin;

-- (1) cleanup_closed_invitations: matchsiz closed ilanları silmeden ÖNCE,
--     tüm closed ilanların bekleyen başvurularını 'expired' yap. (Matchsiz
--     olanların başvuruları zaten ilan silinince CASCADE ile gider; matchli
--     closed ilanların pending başvuruları burada expired olur.)
create or replace function public.cleanup_closed_invitations()
returns integer
language plpgsql
security definer
as $$
declare n integer;
begin
  update public.applications a
     set status = 'expired'
   where a.status = 'pending'
     and a.invitation_id in (select id from public.invitations where status = 'closed');

  delete from public.matches
  where user1_id is null and user2_id is null;

  with del as (
    delete from public.invitations i
    where i.status = 'closed'
      and not exists (select 1 from public.matches m where m.invitation_id = i.id)
    returning 1
  )
  select count(*) into n from del;
  return n;
end;
$$;

-- (2) notify_selfie_status: "mavi tik" metnini nötrleştir (in-app ekranı zaten
--     l10n render ediyor; bu DB metni kayıt + fallback tutarlılığı içindir).
create or replace function public.notify_selfie_status()
returns trigger
language plpgsql
security definer
as $$
BEGIN
  IF OLD.selfie_status = NEW.selfie_status THEN RETURN NEW; END IF;

  IF NEW.selfie_status = 'approved' THEN
    INSERT INTO notifications(user_id, type, title, body, payload)
    VALUES (NEW.id, 'selfie_approved', 'Doğrulandın! 🎉', 'Artık davetlere katılabilirsin.', '{}');
  ELSIF NEW.selfie_status = 'rejected' THEN
    INSERT INTO notifications(user_id, type, title, body, payload)
    VALUES (
      NEW.id, 'selfie_rejected', 'Selfie reddedildi',
      COALESCE('Sebep: ' || NEW.selfie_rejected_reason, 'Lütfen selfieni yeniden yükle.'),
      '{}'
    );
  END IF;
  RETURN NEW;
END;
$$;

commit;
