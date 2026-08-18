-- 18.08.2026 — Veri sızıntısı kapatma (kapanış taraması, canlıda anon key ile doğrulandı)
-- B1 ops görünümleri (v_*) anon/authenticated'a açıktı (default privileges) → yalnız ops_moderator/service
-- B2 invitations_select / photos_select 'to public' → giriş yapmadan tüm aktif davetler + foto satırları okunuyordu
-- B3 yardımcı/prod-only RPC'ler anon çağırabiliyordu (simulate_test_liveliness, cleanup_client_errors, …)
-- B4 users UPDATE'te warning_count korunmuyordu (kullanıcı kendi uyarı sayacını sıfırlar)
-- B5 users guard yalnız BEFORE UPDATE'ti → ilk kayıt INSERT'inde is_admin/premium/selfie_status yazılabiliyordu
-- İstemci hiçbir v_* görünümünü ve bu RPC'leri kullanmıyor (grep lib/) → geriye uyumlu.
begin;

-- B1: tüm ops görünümleri
do $$
declare v record;
begin
  for v in select table_name from information_schema.views where table_schema = 'public' and table_name like 'v\_%' escape '\'
  loop
    execute format('revoke all on public.%I from anon, authenticated, public', v.table_name);
  end loop;
end $$;

-- B2: yalnız oturum açmış kullanıcı
alter policy invitations_select on public.invitations to authenticated;
alter policy photos_select on public.user_photos to authenticated;

-- B3: yardımcı / prod-only fonksiyonlar (trigger'lar security definer olduğundan iç çağrılar etkilenmez)
revoke all on function public.simulate_test_liveliness() from public, anon, authenticated;
revoke all on function public.cleanup_client_errors() from public, anon, authenticated;
revoke all on function public.downgrade_expired_premium() from public, anon, authenticated;
revoke all on function public.users_blocked_pair(uuid, uuid) from public, anon, authenticated;
revoke all on function public.is_test_or_service(uuid) from public, anon, authenticated;
revoke all on function public.contains_contact_info(text) from public, anon, authenticated;

-- B4 + B5: users guard — UPDATE'e warning_count; INSERT için ayrı guard (varsayılanlar zorlanır)
create or replace function public.prevent_users_privilege_escalation()
returns trigger language plpgsql security definer as $function$
declare
  selfie_pending_ok boolean :=
    coalesce(current_setting('soulchoice.selfie_pending_ok', true), '') = '1'
    and old.selfie_status in ('none', 'rejected')
    and new.selfie_status = 'pending';
  free_app_ok boolean :=
    coalesce(current_setting('soulchoice.free_app_ok', true), '') = '1'
    and old.free_application_used = false
    and new.free_application_used = true;
  noshow_ok boolean :=
    coalesce(current_setting('soulchoice.noshow_ok', true), '') = '1'
    and coalesce(new.no_show_count, 0) >= coalesce(old.no_show_count, 0);
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
    new.premium_until := old.premium_until;
    if not free_app_ok then
      new.free_application_used := old.free_application_used;
    end if;
    if not noshow_ok then
      new.no_show_count := old.no_show_count;
      new.suspended_at := old.suspended_at;
      new.suspension_reason := old.suspension_reason;
    elsif old.suspended_at is not null then
      new.suspended_at := old.suspended_at;
      new.suspension_reason := old.suspension_reason;
    end if;
    new.is_deleted := old.is_deleted;
    new.is_test_user := old.is_test_user;
    new.warning_count := old.warning_count;          -- 18.08: moderasyon sayacı
  end if;
  return new;
end;
$function$;

create or replace function public.prevent_users_insert_escalation()
returns trigger language plpgsql security definer as $function$
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.is_admin := false;
    new.banned := false;
    new.subscription_status := 'free';
    new.premium_until := null;
    new.selfie_status := 'none';
    new.selfie_rejected_reason := null;
    new.verified := false;
    new.free_application_used := false;
    new.no_show_count := 0;
    new.suspended_at := null;
    new.suspension_reason := null;
    new.is_deleted := false;
    new.is_test_user := false;
    new.warning_count := 0;
    new.subscription_provider := null;
  end if;
  return new;
end;
$function$;
drop trigger if exists trg_prevent_users_insert_escalation on public.users;
create trigger trg_prevent_users_insert_escalation
  before insert on public.users for each row execute function public.prevent_users_insert_escalation();

commit;
