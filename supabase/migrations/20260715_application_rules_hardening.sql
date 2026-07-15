-- Başvuru/kabul kurallarının sunucuda zorlanması (15.07.2026 ürün-mantığı denetimi).
-- Öncesi (kırık): (1) applications UPDATE policy sahibine yalnız 'rejected' izni
-- veriyordu → uygulamanın yazdığı 'accepted' sessizce 0 satır etkiliyordu, kabul
-- edilen aday sonsuza dek 'pending' kalıyor + kabul bildirimi hiç tetiklenmiyordu.
-- (2) Başvuru kuralları (premium/ücretsiz hak, ilan aktifliği, self-apply, selfie)
-- yalnız istemcideydi → modifiye istemci bedava/sınırsız başvurabilir, hatta
-- doğrudan 'accepted' insert edebilirdi. Bu paket ikisini de DB'de zorlar.
-- Ref: docs/product-logic.md §5, §6, §9, §10.

begin;

-- 1) Sahibi başvuruyu 'accepted' de yapabilsin (mevcut 'rejected' korunur;
--    başvuran yalnız kendi başvurusunu 'withdrawn' yapabilir).
drop policy if exists applications_update on public.applications;
create policy applications_update on public.applications for update
  using (
    applicant_id = auth.uid()
    or invitation_id in (select id from invitations where owner_id = auth.uid())
  )
  with check (
    (applicant_id = auth.uid() and status = 'withdrawn')
    or (
      invitation_id in (select id from invitations where owner_id = auth.uid())
      and status in ('accepted', 'rejected')
    )
  );

-- 2) Yeni başvuruyu DB seviyesinde zorla. service_role (backend/cron/test) muaf;
--    yalnız gerçek kullanıcı başvurusu (auth.uid()) denetlenir.
create or replace function public.enforce_application_rules()
returns trigger
language plpgsql
security definer
as $$
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then
    return new;
  end if;

  -- yeni başvuru daima 'pending' açılır (doğrudan 'accepted' insert engeli)
  if new.status <> 'pending' then
    raise exception 'APPLICATION_MUST_START_PENDING';
  end if;

  -- ilan açık olmalı + sahibi kendi ilanına başvuramaz
  if not exists (
    select 1 from invitations i
    where i.id = new.invitation_id
      and i.status = 'active'
      and i.expires_at > now()
      and i.owner_id <> new.applicant_id
  ) then
    raise exception 'INVITATION_NOT_OPEN';
  end if;

  -- başvuran selfie'si onaylı olmalı (product-logic §10: doğrulama zorunlu)
  if not exists (
    select 1 from users u where u.id = new.applicant_id and u.selfie_status = 'approved'
  ) then
    raise exception 'SELFIE_NOT_APPROVED';
  end if;

  -- premium ya da kullanılmamış ücretsiz hak (product-logic §5)
  if not public.can_user_apply(new.applicant_id) then
    raise exception 'APPLY_LIMIT_REACHED';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_application_rules on public.applications;
create trigger trg_enforce_application_rules
  before insert on public.applications
  for each row execute function public.enforce_application_rules();

-- 3) Kabul bildirimi: uygulama 'accepted' yazıyor ama bildirim trigger'ı yalnız
--    'selected' bekliyordu → in-app kabul bildirimi hiç oluşmuyordu. 'accepted'
--    dalını ekle + bozuk metni düzelt. (In-app metinlerin RU/EN/TR l10n'a
--    taşınması ayrı iş — product-logic §9 backlog.)
create or replace function public.notify_application_status()
returns trigger
language plpgsql
security definer
as $$
DECLARE
  inv RECORD;
  owner_name TEXT;
  notif_type TEXT;
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status IN ('selected', 'accepted') THEN
    notif_type := 'selected';
  ELSIF NEW.status = 'rejected' THEN
    notif_type := 'not_selected';
  ELSE
    RETURN NEW;
  END IF;
  SELECT * INTO inv FROM invitations WHERE id = NEW.invitation_id;
  SELECT name INTO owner_name FROM users WHERE id = inv.owner_id;
  INSERT INTO notifications (user_id, type, title, body, payload)
  VALUES (
    NEW.applicant_id,
    notif_type,
    CASE notif_type
      WHEN 'selected' THEN 'Seçildin! 🎉'
      WHEN 'not_selected' THEN 'Başvuru sonucu'
    END,
    CASE notif_type
      WHEN 'selected' THEN owner_name || ' seni seçti — sohbet açıldı.'
      WHEN 'not_selected' THEN owner_name || ' davetinden haber var.'
    END,
    jsonb_build_object('invitation_id', NEW.invitation_id, 'application_id', NEW.id, 'actor_id', inv.owner_id)
  );
  RETURN NEW;
END;
$$;

commit;

notify pgrst, 'reload schema';
