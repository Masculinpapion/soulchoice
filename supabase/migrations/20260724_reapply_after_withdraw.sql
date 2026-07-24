-- 24.07.2026 E2E bulgusu + ürün kararı (Mustafa): geri çekilen başvuru YENİDEN yapılabilmeli.
-- Mevcut durum: istemci upsert(onConflict) doğru; engel RLS'te — applicant WITH CHECK yalnız
-- 'withdrawn' yazabiliyordu, withdrawn→pending dönüşü 42501 ile düşüyordu (kırmızı "hata oluştu").
-- Çözüm (tamamen sunucu tarafı):
--   1) RLS: applicant kendi başvurusunu 'withdrawn' VEYA 'pending' yapabilir
--   2) enforce_application_rules artık UPDATE'te de çalışır: yalnız withdrawn→pending geçişine
--      izin verir ve INSERT ile aynı iş kurallarını (ilan açık, selfie onaylı, hak/premium,
--      askı kontrolü) uygular; responded_at sıfırlanır
--   3) notify_new_application withdrawn→pending geçişinde de sahibi bilgilendirir

alter policy applications_update on public.applications
  with check (
    ((applicant_id = auth.uid()) and (status in ('withdrawn', 'pending')))
    or ((invitation_id in (select invitations.id from invitations
                            where invitations.owner_id = auth.uid()))
        and (status in ('accepted', 'rejected')))
  );

create or replace function public.enforce_application_rules()
returns trigger
language plpgsql
security definer
as $function$
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then
    return new;
  end if;

  if TG_OP = 'UPDATE' then
    -- yalnız yeniden-başvuru (withdrawn→pending) geçişini denetle;
    -- diğer geçişler (accept/reject/withdraw) RLS WITH CHECK kapsamında
    if new.status = 'pending' then
      if old.status <> 'withdrawn' then
        raise exception 'INVALID_STATUS_TRANSITION';
      end if;
      if not exists (
        select 1 from invitations i
        where i.id = new.invitation_id
          and i.status = 'active'
          and i.expires_at > now()
          and i.owner_id <> new.applicant_id
      ) then
        raise exception 'INVITATION_NOT_OPEN';
      end if;
      if not exists (
        select 1 from users u
        where u.id = new.applicant_id
          and u.selfie_status = 'approved'
          and u.suspended_at is null
          and not u.banned
      ) then
        raise exception 'SELFIE_NOT_APPROVED';
      end if;
      if not public.can_user_apply(new.applicant_id) then
        raise exception 'APPLY_LIMIT_REACHED';
      end if;
      new.responded_at := null;
    end if;
    return new;
  end if;

  -- INSERT yolu (mevcut kurallar)
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
$function$;

drop trigger if exists trg_enforce_application_rules on public.applications;
create trigger trg_enforce_application_rules
  before insert or update on public.applications
  for each row execute function enforce_application_rules();

create or replace function public.notify_new_application()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  inv RECORD;
  applicant_name TEXT;
begin
  -- UPDATE'te yalnız yeniden-başvuru (withdrawn→pending) bildirim üretir
  if TG_OP = 'UPDATE' and not (old.status = 'withdrawn' and new.status = 'pending') then
    return new;
  end if;

  select * into inv from invitations where id = new.invitation_id;
  select name into applicant_name from users where id = new.applicant_id;
  insert into notifications (user_id, type, title, body, payload)
  values (
    inv.owner_id,
    'new_application',
    'Yeni Basvuru',
    applicant_name || ' davetinize basvurdu.',
    jsonb_build_object('invitation_id', new.invitation_id, 'application_id', new.id, 'actor_id', new.applicant_id)
  );
  return new;
end;
$function$;

drop trigger if exists trg_notify_new_application on public.applications;
create trigger trg_notify_new_application
  after insert or update on public.applications
  for each row execute function notify_new_application();
