-- 🔴 Askıya alma / ban ZORLAMASI — 15.07.2026 yolculuk taraması bulgusu.
-- Önceki durum: confirm_meeting (no-show eşiği) ve ops_ban_user yalnız
-- suspended_at/banned KOLONU yazıyordu; hiçbir RLS/feed/auth/app katmanı
-- okumuyordu → askı/ban fiilen yoktu ("ölü mekanik", product-logic §13.1/5).
-- Ayrıca: authenticated rolünün premium_until / free_application_used /
-- no_show_count kolonlarında UPDATE grant'i vardı ve escalation trigger'ı
-- bunları korumuyordu → modifiye istemci kendine bedava premium yazabilirdi.

begin;

-- 1) İstemci kendi para/moderasyon kolonlarını DEĞİŞTİREMEZ
--    (app bu kolonları hiç yazmıyor; hepsi trigger/edge fn ile service_role'den)
create or replace function public.prevent_users_privilege_escalation()
returns trigger
language plpgsql
security definer
as $$
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.is_admin := old.is_admin;
    new.banned := old.banned;
    new.subscription_status := old.subscription_status;
    new.selfie_status := old.selfie_status;
    new.selfie_rejected_reason := old.selfie_rejected_reason;
    new.verified := old.verified;
    -- 15.07 sertleştirme: para + moderasyon kolonları
    new.premium_until := old.premium_until;
    new.free_application_used := old.free_application_used;
    new.no_show_count := old.no_show_count;
    new.suspended_at := old.suspended_at;
    new.suspension_reason := old.suspension_reason;
    new.is_deleted := old.is_deleted;
    new.is_test_user := old.is_test_user;
  end if;
  return new;
end;
$$;

-- 2) Askıdaki/banlı kullanıcı yeni ilan / başvuru / mesaj ÜRETEMEZ
--    (token hata: istemci 🟠3 eşlemesiyle lokalize gösterir)
create or replace function public.enforce_not_suspended()
returns trigger
language plpgsql
security definer
as $$
begin
  if auth.uid() is not null and exists (
    select 1 from public.users
     where id = auth.uid() and (suspended_at is not null or banned)
  ) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_not_suspended_invitations on public.invitations;
create trigger trg_not_suspended_invitations
  before insert on public.invitations
  for each row execute function public.enforce_not_suspended();

drop trigger if exists trg_not_suspended_applications on public.applications;
create trigger trg_not_suspended_applications
  before insert on public.applications
  for each row execute function public.enforce_not_suspended();

drop trigger if exists trg_not_suspended_messages on public.messages;
create trigger trg_not_suspended_messages
  before insert on public.messages
  for each row execute function public.enforce_not_suspended();

-- 3) Feed/keşfet: askıdaki/banlı kullanıcı görünmez (engellemeyle aynı kanal)
create or replace function public.hidden_from_feed()
returns table(user_id uuid)
language sql
stable
security definer
as $$
  select blocked_id from public.blocks where blocker_id = auth.uid()
  union
  select blocker_id from public.blocks where blocked_id = auth.uid()
  union
  select id from public.users where suspended_at is not null or banned
$$;

-- 4) Ops banı artık OTURUMU da keser: GoTrue yeni token vermez + mevcut
--    refresh token'lar silinir (access token en geç 1 saatte ölür)
create or replace function public.ops_ban_user(p_user uuid, p_actor text, p_note text)
returns void
language plpgsql
security definer
as $$
begin
  if coalesce(trim(p_note), '') = '' then raise exception 'ban notu zorunlu'; end if;
  update public.users
     set banned = true, suspended_at = now(), suspension_reason = p_note
   where id = p_user and banned = false and is_deleted = false;
  if not found then raise exception 'kullanıcı zaten banlı ya da yok: %', p_user; end if;
  update public.invitations set status = 'closed' where owner_id = p_user and status = 'active';
  update auth.users set banned_until = 'infinity' where id = p_user;
  delete from auth.refresh_tokens where user_id = p_user::text;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'ban_user', 'user', p_user, p_note);
end
$$;

commit;

notify pgrst, 'reload schema';
