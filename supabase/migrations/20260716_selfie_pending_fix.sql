-- 16.07 E2E devam bulgusu: mark_selfie_pending, app isteği bağlamında
-- (auth.role()='authenticated') çalıştığı için prevent_users_privilege_escalation
-- selfie_status değişikliğini sessizce geri alıyordu. Trigger artık
-- transaction-yerel bayrak koyar; escalation guard YALNIZ bu dar geçişe
-- (none/rejected → pending, bayrak varken) izin verir.

begin;

create or replace function public.mark_selfie_pending()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.is_selfie and coalesce(new.moderation_status, 'pending') = 'pending' then
    -- escalation guard'a dar kapsamlı izin (yalnız bu transaction)
    perform set_config('soulchoice.selfie_pending_ok', '1', true);
    update public.users
       set selfie_status = 'pending',
           selfie_rejected_reason = null
     where id = new.user_id
       and selfie_status in ('none', 'rejected');
  end if;
  return new;
end;
$$;

create or replace function public.prevent_users_privilege_escalation()
returns trigger
language plpgsql
security definer
as $$
declare
  selfie_pending_ok boolean :=
    coalesce(current_setting('soulchoice.selfie_pending_ok', true), '') = '1'
    and old.selfie_status in ('none', 'rejected')
    and new.selfie_status = 'pending';
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.is_admin := old.is_admin;
    new.banned := old.banned;
    new.subscription_status := old.subscription_status;
    if not selfie_pending_ok then
      new.selfie_status := old.selfie_status;
      new.selfie_rejected_reason := old.selfie_rejected_reason;
    end if;
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

commit;

notify pgrst, 'reload schema';
