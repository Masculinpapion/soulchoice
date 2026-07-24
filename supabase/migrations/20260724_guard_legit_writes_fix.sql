-- 24.07.2026 E2E bulgusu (launch-kritik):
-- prevent_users_privilege_escalation (15.07 sertleştirmesi), authenticated bağlamında çalışan
-- MEŞRU sunucu yazımlarını da geri alıyordu:
--   1) mark_free_application_used (applications INSERT trigger'ı, başvuranın oturumunda çalışır)
--      → free_application_used hiç true olmuyordu → paywall HİÇ tetiklenmiyordu (sonsuz ücretsiz başvuru)
--   2) confirm_meeting (authenticated'a grant'li RPC)
--      → no_show_count artışı + 2x no-show otomatik askısı sessizce iptal oluyordu
-- Çözüm: selfie_pending_ok deseninin genelleştirilmesi — transaction-local GUC + yön kısıtlı istisnalar.
-- Güvenlik notu: GUC'lar PostgREST üzerinden set edilemez; istisnalar yalnız kullanıcı aleyhine
-- yönde değişime izin verir (free hak tüketimi, sayaç artışı); askı (suspended_at) geri alınamaz.

create or replace function public.prevent_users_privilege_escalation()
returns trigger
language plpgsql
security definer
as $function$
declare
  selfie_pending_ok boolean :=
    coalesce(current_setting('soulchoice.selfie_pending_ok', true), '') = '1'
    and old.selfie_status in ('none', 'rejected')
    and new.selfie_status = 'pending';
  -- 24.07: ücretsiz başvuru hakkının tüketimi — yalnız false→true yönü
  free_app_ok boolean :=
    coalesce(current_setting('soulchoice.free_app_ok', true), '') = '1'
    and old.free_application_used = false
    and new.free_application_used = true;
  -- 24.07: no-show yaptırımı — sayaç yalnız artabilir
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
    -- 15.07 sertleştirme: para + moderasyon kolonları
    new.premium_until := old.premium_until;
    if not free_app_ok then
      new.free_application_used := old.free_application_used;
    end if;
    if not noshow_ok then
      new.no_show_count := old.no_show_count;
      new.suspended_at := old.suspended_at;
      new.suspension_reason := old.suspension_reason;
    elsif old.suspended_at is not null then
      -- askı geri alınamaz / gerekçesi değiştirilemez
      new.suspended_at := old.suspended_at;
      new.suspension_reason := old.suspension_reason;
    end if;
    new.is_deleted := old.is_deleted;
    new.is_test_user := old.is_test_user;
  end if;
  return new;
end;
$function$;

create or replace function public.mark_free_application_used()
returns trigger
language plpgsql
as $function$
begin
  perform set_config('soulchoice.free_app_ok', '1', true);
  update users
     set free_application_used = true
   where id = new.applicant_id
     and subscription_status = 'free'
     and free_application_used = false;
  perform set_config('soulchoice.free_app_ok', '', true);
  return new;
end;
$function$;

create or replace function public.confirm_meeting(p_match_id uuid, p_attended boolean)
returns void
language plpgsql
security definer
as $function$
declare
  v_uid uuid := auth.uid();
  v_is_user1 boolean;
  v_other uuid;
  v_gift boolean;
  v_weight int;
  v_newcount int;
begin
  select (m.user1_id = v_uid),
         case when m.user1_id = v_uid then m.user2_id else m.user1_id end
    into v_is_user1, v_other
    from public.matches m
   where m.id = p_match_id and (m.user1_id = v_uid or m.user2_id = v_uid);
  if not found then
    raise exception 'match bulunamadı veya katılımcı değil';
  end if;

  if v_is_user1 then
    update public.matches set meeting_confirmed_user1 = p_attended where id = p_match_id;
  else
    update public.matches set meeting_confirmed_user2 = p_attended where id = p_match_id;
  end if;

  -- "gelmedi" → karşı tarafın no-show sayacı (gift ağırlıklı) + işaret + suspend
  if not p_attended and v_other is not null then
    select exists (
      select 1 from public.invitations i
      join public.matches m on m.invitation_id = i.id
      where m.id = p_match_id and i.category = 'gift'
    ) into v_gift;
    v_weight := case when v_gift then 2 else 1 end;

    update public.matches
       set no_show_reported_by =
             array_append(coalesce(no_show_reported_by, '{}'::uuid[]), v_uid)
     where id = p_match_id
       and not (v_uid = any(coalesce(no_show_reported_by, '{}'::uuid[])));

    perform set_config('soulchoice.noshow_ok', '1', true);

    update public.users
       set no_show_count = coalesce(no_show_count, 0) + v_weight
     where id = v_other
    returning no_show_count into v_newcount;

    if v_newcount >= 2 then
      update public.users
         set suspended_at = coalesce(suspended_at, now()),
             suspension_reason = coalesce(
               suspension_reason,
               case when v_gift then 'gift no-show (maddi kayıp)' else '2x no-show' end)
       where id = v_other;
    end if;

    perform set_config('soulchoice.noshow_ok', '', true);
  end if;
end;
$function$;

revoke all on function public.confirm_meeting(uuid, boolean) from public;
grant execute on function public.confirm_meeting(uuid, boolean) to authenticated;
