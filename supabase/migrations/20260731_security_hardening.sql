-- 31.07.2026 — Güvenlik sertleştirme + yaptırım hataları (denetim paketi).
-- Hepsi prod'da canlı kanıtlanmış bulgular; idempotent, tekrar uygulanabilir.

-- ═══════════════════════════════════════════════════════════════════
-- 1) ops_* moderasyon RPC'leri PUBLIC'e açıktı — KRİTİK
--    Kanıt (31.07): anon anahtarla, giriş yapmadan
--    POST /rest/v1/rpc/ops_search_users çağrıldı ve gerçek kullanıcı
--    listesi döndü. Aynı yetkiyle ops_ban_user / ops_approve_selfie /
--    ops_remove_photo da çağrılabiliyordu (herkes istediğini banlar,
--    kendi selfie'sini onaylar). Sebep: CREATE FUNCTION sonrası
--    EXECUTE varsayılan olarak PUBLIC'e verilir; 14-15.07 partisinde
--    REVOKE unutulmuş (ops_unban_user/ops_user_detail'de var).
--    Ops paneli ops_moderator rolüyle bağlandığı için etkilenmez.
-- ═══════════════════════════════════════════════════════════════════
do $$
declare f text;
begin
  for f in
    select p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and (p.proname like 'ops\_%' or p.proname = 'cleanup_closed_invitations')
  loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to ops_moderator', f);
  end loop;
end $$;

-- cleanup_closed_invitations yalnız cron (postgres) çalıştırır
revoke all on function public.cleanup_closed_invitations() from ops_moderator;

-- ═══════════════════════════════════════════════════════════════════
-- 2) can_user_apply: başkasının hak durumu sorgulanabiliyordu
--    Artık yalnız kendi durumunu sorabilirsin (sunucu-içi çağrılar
--    auth.uid() null olduğu için etkilenmez).
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.can_user_apply(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_free_used boolean;
  v_premium boolean;
begin
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'not_authorized';
  end if;
  select free_application_used,
         (subscription_status = 'active' or premium_until > now())
    into v_free_used, v_premium
    from public.users where id = p_user_id;
  if not found then return false; end if;
  return coalesce(v_premium, false) or not coalesce(v_free_used, false);
end $function$;

-- ═══════════════════════════════════════════════════════════════════
-- 3) matches INSERT: "zorla eşleşme" açığı — YÜKSEK
--    Eski kural: (user1_id = auth.uid() OR user2_id = auth.uid())
--    → kullanıcı kendini user2 yapıp İSTEDİĞİ kişiyle match açar ve
--    doğrudan mesaj atar; davet/başvuru/seçim/engelleme/selfie
--    kapılarının tamamı atlanır (taciz vektörü).
--    Yeni kural: yalnız davet SAHİBİ, yalnız o davete başvurmuş kişiyle.
-- ═══════════════════════════════════════════════════════════════════
drop policy if exists matches_insert on public.matches;
create policy matches_insert on public.matches
  for insert to authenticated
  with check (
    user1_id = auth.uid()
    and exists (
      select 1 from public.invitations i
       where i.id = invitation_id and i.owner_id = auth.uid()
    )
    and exists (
      select 1 from public.applications a
       where a.invitation_id = matches.invitation_id
         and a.applicant_id = matches.user2_id
         and a.status in ('pending', 'selected', 'accepted')
    )
  );

-- ═══════════════════════════════════════════════════════════════════
-- 4) match_and_select: başvuru-ilan bağı ve durumu doğrulanmıyordu
--    → başka ilanın başvurusu seçilebiliyor; GERİ ÇEKİLMİŞ başvuru
--    zorla kabul edilip kişi rızası dışında eşleştirilebiliyordu.
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.match_and_select(p_application_id uuid, p_invitation_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_applicant_id uuid;
  v_status       text;
  v_match_id     uuid;
begin
  if not exists (
    select 1 from invitations
    where id = p_invitation_id and owner_id = auth.uid()
  ) then
    raise exception 'not_authorized';
  end if;

  perform id from invitations
    where id = p_invitation_id and status in ('active', 'selecting')
    for update;

  if not found then
    raise exception 'invitation_not_available';
  end if;

  -- 31.07: başvuru GERÇEKTEN bu ilana ait mi ve hâlâ geçerli mi?
  select applicant_id, status into v_applicant_id, v_status
    from applications
   where id = p_application_id and invitation_id = p_invitation_id;

  if v_applicant_id is null then
    raise exception 'application_not_found';
  end if;
  if v_status not in ('pending', 'selected') then
    raise exception 'application_not_selectable';
  end if;

  insert into matches (invitation_id, user1_id, user2_id)
    values (p_invitation_id, auth.uid(), v_applicant_id)
    on conflict (invitation_id, user2_id) do update set invitation_id = excluded.invitation_id
    returning id into v_match_id;

  update applications
    set status = 'accepted', selected_at = NOW(), responded_at = NOW()
    where id = p_application_id;

  return v_match_id;
end;
$function$;

-- ═══════════════════════════════════════════════════════════════════
-- 5) confirm_meeting: "gelmedi" sayacı idempotent DEĞİLDİ — YÜKSEK
--    Dizi guard'ı yalnız işaret UPDATE'indeydi, sayaç koşulsuz artıyordu:
--    aynı kişi iki kez basınca (çift dokunuş/kötü niyet) karşı taraf
--    2'ye ulaşıp OTOMATİK ASKIYA giriyordu. Artık sayaç yalnız ilk
--    bildirimde artar; ayrıca buluşma tarihi geçmeden bildirim yapılamaz.
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.confirm_meeting(p_match_id uuid, p_attended boolean)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_uid uuid := auth.uid();
  v_is_user1 boolean;
  v_other uuid;
  v_meeting timestamptz;
  v_gift boolean;
  v_weight int;
  v_newcount int;
  v_first_report boolean;
begin
  select (m.user1_id = v_uid),
         case when m.user1_id = v_uid then m.user2_id else m.user1_id end,
         m.meeting_date
    into v_is_user1, v_other, v_meeting
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

  if not p_attended and v_other is not null then
    -- 31.07: buluşma vakti gelmeden no-show ihbarı kabul edilmez
    if v_meeting is not null and v_meeting > now() then
      raise exception 'meeting_not_yet';
    end if;

    select exists (
      select 1 from public.invitations i
      join public.matches m on m.invitation_id = i.id
      where m.id = p_match_id and i.category = 'gift'
    ) into v_gift;
    v_weight := case when v_gift then 2 else 1 end;

    -- İşaret + sayaç AYNI guard'a bağlı: satır güncellendiyse bu ilk bildirim
    update public.matches
       set no_show_reported_by =
             array_append(coalesce(no_show_reported_by, '{}'::uuid[]), v_uid)
     where id = p_match_id
       and not (v_uid = any(coalesce(no_show_reported_by, '{}'::uuid[])));
    get diagnostics v_first_report = row_count;

    if v_first_report then
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
  end if;
end;
$function$;

-- ═══════════════════════════════════════════════════════════════════
-- 6) ops_unban_user: no-show askısını KALDIRAMIYORDU — YÜKSEK
--    Askıda banned=false olduğu için "kullanıcı banlı değil" hatası
--    veriyordu → haksız askı kalıcı hesap kaybı demekti. Artık ban VE
--    askı için çalışır, sayacı da sıfırlar (yoksa tek ihbar yeniden askı).
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.ops_unban_user(p_user uuid, p_actor text, p_note text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if coalesce(trim(p_note), '') = '' then raise exception 'not zorunlu'; end if;
  update public.users
     set banned = false,
         suspended_at = null,
         suspension_reason = null,
         no_show_count = 0
   where id = p_user and (banned = true or suspended_at is not null);
  if not found then raise exception 'kullanıcı banlı/askıda değil ya da yok: %', p_user; end if;
  update auth.users set banned_until = null where id = p_user;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'unban_user', 'user', p_user, p_note);
end $function$;

revoke all on function public.ops_unban_user(uuid, text, text) from public, anon, authenticated;
grant execute on function public.ops_unban_user(uuid, text, text) to ops_moderator;

-- ═══════════════════════════════════════════════════════════════════
-- 7) reports.status check'i paneldeki 'dismissed' yazımını reddediyordu
--    → şikayet kapatma sessizce başarısız oluyordu.
-- ═══════════════════════════════════════════════════════════════════
alter table public.reports drop constraint if exists reports_status_check;
alter table public.reports add constraint reports_status_check
  check (status in ('pending', 'reviewed', 'resolved', 'dismissed'));

-- ═══════════════════════════════════════════════════════════════════
-- 8) push_log: FK yoktu → hesap silinince kayıtlar yetim kalıyordu
--    (GDPR). Retention cron'u zaten 14 gün siliyor; FK ile anında.
-- ═══════════════════════════════════════════════════════════════════
delete from public.push_log where user_id not in (select id from public.users);
do $$ begin
  alter table public.push_log
    add constraint push_log_user_fk foreign key (user_id)
    references public.users(id) on delete cascade;
exception when duplicate_object then null; end $$;
