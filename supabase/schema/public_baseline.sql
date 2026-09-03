--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: archive_messages_before_match_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.archive_messages_before_match_delete() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  insert into public.messages_archive
    (id, match_id, sender_id, content, created_at, read_at, deleted_by, user1_id, user2_id, invitation_id, invitation_category)
  select m.id, m.match_id, m.sender_id, m.content, m.created_at, m.read_at, auth.uid(),
         old.user1_id, old.user2_id, old.invitation_id, old.invitation_category
    from public.messages m where m.match_id = old.id;
  return old;
end $$;


--
-- Name: block_withdraw_after_decision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.block_withdraw_after_decision() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then
    return new;
  end if;
  if new.status = 'withdrawn' and old.status in ('rejected', 'expired') then
    raise exception 'INVALID_STATUS_TRANSITION';
  end if;
  return new;
end;
$$;


--
-- Name: can_user_apply(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_user_apply(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_used int;
  v_premium boolean;
  v_susp boolean;
begin
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'not_authorized';
  end if;
  select free_applications_used,
         (subscription_status = 'active' or premium_until > now()),
         (suspended_at is not null or banned)
    into v_used, v_premium, v_susp
    from public.users where id = p_user_id;
  if not found then return false; end if;
  -- 20.08 (kısa tur H3): askıdaki kullanıcı paywall'a YÖNLENDİRİLMEZ (ödeyip yine
  -- başvuramazdı — para mağduriyeti); istemci ACCOUNT_SUSPENDED'i /suspended'a eşler.
  if coalesce(v_susp, false) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  return coalesce(v_premium, false) or coalesce(v_used, 0) < 3;
end $$;


--
-- Name: check_active_invitation_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_active_invitation_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.status = 'active' and exists (
    select 1 from invitations
    where owner_id = new.owner_id
      and flow_type = new.flow_type
      and status = 'active'
      and expires_at > now()
      and id != new.id
  ) then
    raise exception 'ACTIVE_INVITATION_LIMIT'
      using detail = new.flow_type;
  end if;
  return new;
end;
$$;


--
-- Name: clamp_expires_before_event(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clamp_expires_before_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.event_date is not null and new.expires_at is not null
     and new.expires_at > new.event_date then
    new.expires_at := new.event_date;
  end if;
  return new;
end $$;


--
-- Name: cleanup_client_errors(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_client_errors() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare n integer;
begin
  with del as (
    delete from public.client_errors where created_at < now() - interval '30 days' returning 1
  ) select count(*) into n from del;
  return n;
end $$;


--
-- Name: cleanup_closed_invitations(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_closed_invitations() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare n integer;
begin
  -- 15.07 adımı (11.08 yeniden yazımında düşmüştü — kısa tur 20.08 geri ekledi):
  -- kapanan ilanların bekleyen başvuruları 'expired' (bildirim yok, §4 sessizlik)
  update public.applications a
     set status = 'expired'
   where a.status = 'pending'
     and a.invitation_id in (select id from public.invitations where status = 'closed');

  -- 15.07 §8 adımı: iki tarafı da silinmiş eşleşmeler temizlenir (mesajlar arşiv trigger'ı ile)
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
end $$;


--
-- Name: clear_chat(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_chat(p_match_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  update public.matches
     set user1_cleared_at = case when user1_id = auth.uid() then now() else user1_cleared_at end,
         user2_cleared_at = case when user2_id = auth.uid() then now() else user2_cleared_at end,
         user1_hidden_at  = case when user1_id = auth.uid() then now() else user1_hidden_at end,
         user2_hidden_at  = case when user2_id = auth.uid() then now() else user2_hidden_at end
   where id = p_match_id
     and (user1_id = auth.uid() or user2_id = auth.uid());

  -- Silinen sohbetin okunmamışları rozette sayılmasın
  update public.messages
     set read_at = now()
   where match_id = p_match_id
     and read_at is null
     and sender_id is distinct from auth.uid();
end;
$$;


--
-- Name: confirm_meeting(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_meeting(p_match_id uuid, p_attended boolean) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_is_user1 boolean;
  v_other uuid;
  v_meeting timestamptz;
  v_created timestamptz;
  v_gift boolean;
  v_weight int;
  v_newcount int;
  v_first_report boolean;
begin
  select (m.user1_id = v_uid),
         case when m.user1_id = v_uid then m.user2_id else m.user1_id end,
         m.meeting_date, m.created_at,
         coalesce(m.invitation_category, i.category) = 'gift'
    into v_is_user1, v_other, v_meeting, v_created, v_gift
    from public.matches m
    left join public.invitations i on i.id = m.invitation_id
   where m.id = p_match_id and (m.user1_id = v_uid or m.user2_id = v_uid);
  if not found then
    raise exception 'match bulunamadı veya katılımcı değil';
  end if;
  -- 20.08 (kısa tur): engelli eşleşmede buluşma anketi/no-show YOK — engellenen taraf
  -- "gelmedi" diyerek engelleyeni (hediye: +2 → anında) askıya aldıramaz.
  if exists (select 1 from public.matches where id = p_match_id and blocked_at is not null) then
    raise exception 'MATCH_BLOCKED';
  end if;

  perform set_config('soulchoice.match_ok', '1', true);
  if v_is_user1 then
    update public.matches set meeting_confirmed_user1 = p_attended where id = p_match_id;
  else
    update public.matches set meeting_confirmed_user2 = p_attended where id = p_match_id;
  end if;

  if not p_attended and v_other is not null then
    -- buluşma vakti gelmeden VE eşleşmeden 24 saat geçmeden no-show kabul edilmez
    if greatest(coalesce(v_meeting, '-infinity'::timestamptz), v_created + interval '24 hours') > now() then
      perform set_config('soulchoice.match_ok', '', true);
      raise exception 'meeting_not_yet';
    end if;

    v_weight := case when coalesce(v_gift, false) then 2 else 1 end;

    update public.matches
       set no_show_reported_by = array_append(coalesce(no_show_reported_by, '{}'::uuid[]), v_uid)
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
               suspension_reason = coalesce(suspension_reason,
                 case when coalesce(v_gift, false) then 'gift no-show (maddi kayıp)' else '2x no-show' end)
         where id = v_other;
      end if;
      perform set_config('soulchoice.noshow_ok', '', true);
    end if;
  end if;
  perform set_config('soulchoice.match_ok', '', true);
end $$;


--
-- Name: contains_contact_info(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contains_contact_info(p text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select coalesce(p, '') ~* '(https?://|www\.|t\.me|wa\.me|vk\.com|telegram|whatsapp|телеграм|ватсап|вацап|@[a-z0-9_]{4,}|\+?\d[\d\s\-()]{8,}\d)'
$$;


--
-- Name: downgrade_expired_premium(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.downgrade_expired_premium() RETURNS void
    LANGUAGE sql
    AS $$
  update users u
     set subscription_status = 'free'
   where u.subscription_status = 'active'
     and u.premium_until is not null
     and u.premium_until < now()
     -- past_due + grace: KARAR 2 (premium grace boyunca açık)
     and not exists (
       select 1 from subscriptions s
        where s.user_id = u.id
          and s.status = 'past_due'
          and s.grace_until is not null
          and s.grace_until > now()
     )
     -- 19.08: yenileme çekimi sırada — günlük FAZ B gelene kadar düşürme
     and not exists (
       select 1 from subscriptions s
        where s.user_id = u.id
          and s.status = 'active'
          and s.auto_renew
          and s.tochka_subscription_id is not null
          and s.next_billing_at is not null
          and s.next_billing_at > now() - interval '48 hours'
     );
$$;


--
-- Name: enforce_application_rules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_application_rules() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare v_owner uuid;
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then
    return new;
  end if;

  select owner_id into v_owner from public.invitations where id = new.invitation_id;

  if TG_OP = 'UPDATE' then
    if new.status = 'pending' then
      if old.status <> 'withdrawn' then
        raise exception 'INVALID_STATUS_TRANSITION';
      end if;
      if not exists (
        select 1 from public.invitations i
        where i.id = new.invitation_id and i.status = 'active' and i.expires_at > now()
          and i.owner_id <> new.applicant_id
      ) then
        raise exception 'INVITATION_NOT_OPEN';
      end if;
      if not exists (
        select 1 from public.users u
        where u.id = new.applicant_id and u.selfie_status = 'approved'
          and u.suspended_at is null and not u.banned
      ) then
        raise exception 'SELFIE_NOT_APPROVED';
      end if;
      if public.users_blocked_pair(new.applicant_id, v_owner) then
        raise exception 'MATCH_BLOCKED';
      end if;
      if not public.can_user_apply(new.applicant_id) then
        raise exception 'APPLY_LIMIT_REACHED';
      end if;
      new.responded_at := null;
    end if;
    return new;
  end if;

  if new.status <> 'pending' then
    raise exception 'APPLICATION_MUST_START_PENDING';
  end if;
  if not exists (
    select 1 from public.invitations i
    where i.id = new.invitation_id and i.status = 'active' and i.expires_at > now()
      and i.owner_id <> new.applicant_id
  ) then
    raise exception 'INVITATION_NOT_OPEN';
  end if;
  if not exists (
    select 1 from public.users u where u.id = new.applicant_id and u.selfie_status = 'approved'
  ) then
    raise exception 'SELFIE_NOT_APPROVED';
  end if;
  if public.users_blocked_pair(new.applicant_id, v_owner) then
    raise exception 'MATCH_BLOCKED';
  end if;
  if not public.can_user_apply(new.applicant_id) then
    raise exception 'APPLY_LIMIT_REACHED';
  end if;
  return new;
end $$;


--
-- Name: enforce_gift_link(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_gift_link() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
declare
  host text;
  inv_category text;
  d text;
  ok boolean := false;
  whitelist constant text[] := array[
    'ozon.ru','wildberries.ru','wb.ru','market.yandex.ru','megamarket.ru','aliexpress.ru',
    'goldapple.ru','letoile.ru','rive-gauche.ru','podrygka.ru','randewoo.ru',
    'lamoda.ru','tsum.ru','brandshop.ru','sportmaster.ru','12storeez.com','befree.ru','lime-shop.com',
    'dns-shop.ru','mvideo.ru','eldorado.ru','citilink.ru','re-store.ru','technopark.ru','holodilnik.ru','onlinetrade.ru',
    'samsung.com','mi.com','mts.ru','megafon.ru','beeline.ru','t2.ru','tele2.ru','svyaznoy.ru',
    'sokolov.ru','sunlight.net','585zolotoy.ru','adamas.ru','miuz.ru',
    'chitai-gorod.ru','labirint.ru','litres.ru','book24.ru','detmir.ru','hoff.ru','flowwow.com'
  ];
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then
    new.updated_at := now();
    return new;
  end if;

  select category into inv_category from public.invitations where id = new.invitation_id;
  if inv_category is distinct from 'gift' then
    raise exception 'GIFT_URL_ONLY_FOR_GIFT_CATEGORY';
  end if;

  if new.url ~* '^https?://' then
    -- LINK: beyaz liste zorunlu (alt alanlar dahil)
    host := lower(regexp_replace(btrim(new.url), '^https?://([^/?#]+).*$', '\1'));
    host := regexp_replace(host, '^.*@', '');        -- userinfo hilesi
    host := regexp_replace(host, ':[0-9]+$', '');    -- port
    host := regexp_replace(host, '^www\.', '');
    foreach d in array whitelist loop
      if host = d or host like '%.' || d then
        ok := true;
        exit;
      end if;
    end loop;
    if not ok then
      raise exception 'GIFT_URL_NOT_WHITELISTED';
    end if;
    -- 20.08: tanınan mağaza linki insan onayı beklemez
    new.status := 'approved';
  else
    -- SERBEST METİN: ürün adı/tarifi (beyaz liste atlanır), makul uzunluk
    if length(btrim(new.url)) < 2 or length(new.url) > 200 then
      raise exception 'GIFT_TEXT_INVALID';
    end if;
    -- 18.08: metin dalında para/kart/СБП/sertifika/temas isteği yasak (yalnız ürün adı)
    if new.url ~* '(\d\s*(₽|руб|р\.)|\y(карт[аеуы]|сбп|перевод[а-я]*|сертификат[а-я]*|номер|телефон[а-я]*|деньги|денег)\y|t\.me|wa\.me|@|https?:|www\.)' then
      raise exception 'GIFT_TEXT_FORBIDDEN';
    end if;
    -- metin dalı manuel moderasyonda kalır
    new.status := 'pending';
  end if;

  new.updated_at := now();
  return new;
end $_$;


--
-- Name: enforce_invitation_rules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_invitation_rules() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then return new; end if;

  if TG_OP = 'INSERT' then
    if not exists (select 1 from public.users where id = new.owner_id and selfie_status = 'approved') then
      raise exception 'SELFIE_NOT_APPROVED';
    end if;
    -- hediye soğuması: 7 günde en fazla 3 hediye daveti (test kullanıcısı muaf)
    if new.category = 'gift' and not public.is_test_or_service(new.owner_id)
       and (select count(*) from public.invitation_create_log
             where owner_id = new.owner_id and category = 'gift'
               and created_at > now() - interval '7 days') >= 3 then
      raise exception 'GIFT_INVITATION_COOLDOWN';
    end if;
  elsif TG_OP = 'UPDATE' then
    if (new.category, new.flow_type) is distinct from (old.category, old.flow_type)
       and exists (select 1 from public.applications
                    where invitation_id = old.id and status in ('pending', 'selected', 'accepted')) then
      raise exception 'INVITATION_LOCKED_HAS_APPLICATIONS';
    end if;
  end if;

  if not public.is_test_or_service(new.owner_id)
     and (public.contains_contact_info(new.title)
          or public.contains_contact_info(new.description)
          or public.contains_contact_info(new.venue_name)) then
    raise exception 'CONTACT_INFO_NOT_ALLOWED';
  end if;
  return new;
end $$;


--
-- Name: enforce_message_allowed(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_message_allowed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare v_u1 uuid; v_u2 uuid; v_blocked timestamptz;
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then return new; end if;
  select user1_id, user2_id, blocked_at into v_u1, v_u2, v_blocked from public.matches where id = new.match_id;
  if v_blocked is not null
     or public.users_blocked_pair(new.sender_id, case when v_u1 = new.sender_id then v_u2 else v_u1 end) then
    raise exception 'MATCH_BLOCKED';
  end if;
  return new;
end $$;


--
-- Name: enforce_not_suspended(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_not_suspended() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


--
-- Name: enforce_otp_daily_cap(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_otp_daily_cap() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare v_norm text := public.otp_norm(new.phone);
begin
  if public.otp_is_bypass(v_norm) then
    return new;
  end if;
  if (select count(*) from public.otp_send_log
       where phone = v_norm and created_at > now() - interval '24 hours'
         and coalesce(result, 'sent') = 'sent') >= 15 then
    raise exception 'OTP_DAILY_CAP';
  end if;
  insert into public.otp_send_log (phone) values (v_norm);
  return new;
end $$;


--
-- Name: enforce_profile_text_rules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_profile_text_rules() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if public.is_test_or_service(new.id) then return new; end if;
  if TG_OP = 'UPDATE' and old.gender is not null and new.gender is distinct from old.gender then
    new.gender := old.gender;                       -- cinsiyet kilidi (yem-değiştir)
  end if;
  if public.contains_contact_info(new.name) or public.contains_contact_info(new.bio)
     or public.contains_contact_info(new.job) or public.contains_contact_info(new.education) then
    raise exception 'CONTACT_INFO_NOT_ALLOWED';
  end if;
  return new;
end $$;


--
-- Name: enforce_prompt_text_rules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_prompt_text_rules() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if public.is_test_or_service(new.user_id) then return new; end if;
  if public.contains_contact_info(new.answer) then
    raise exception 'CONTACT_INFO_NOT_ALLOWED';
  end if;
  return new;
end $$;


--
-- Name: fn_next_billing_anchor(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_next_billing_anchor(ts timestamp with time zone) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE
    AS $$
  select ((ts at time zone 'Europe/Moscow')::date + time '09:00') at time zone 'Europe/Moscow'
$$;


--
-- Name: fn_subscriptions_anchor_billing(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_subscriptions_anchor_billing() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.next_billing_at is not null then
    new.next_billing_at := public.fn_next_billing_anchor(new.next_billing_at);
  end if;
  return new;
end
$$;


--
-- Name: get_gift_link(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_gift_link(p_match_id uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select l.url
  from public.invitation_gift_links l
  join public.matches m on m.invitation_id = l.invitation_id
  where m.id = p_match_id
    and (m.user1_id = auth.uid() or m.user2_id = auth.uid())
    and l.status = 'approved';
$$;


--
-- Name: get_own_gift_link(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_own_gift_link(p_invitation_id uuid) RETURNS TABLE(url text, status text)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select l.url, l.status
  from public.invitation_gift_links l
  join public.invitations i on i.id = l.invitation_id
  where l.invitation_id = p_invitation_id
    and i.owner_id = auth.uid();
$$;


--
-- Name: has_application_to(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_application_to(inv uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  select exists (
    select 1 from applications
    where invitation_id = inv and applicant_id = auth.uid()
  );
$$;


--
-- Name: hidden_from_feed(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hidden_from_feed() RETURNS TABLE(user_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select blocked_id from public.blocks where blocker_id = auth.uid()
  union
  select blocker_id from public.blocks where blocked_id = auth.uid()
  union
  select id from public.users where suspended_at is not null or banned
$$;


--
-- Name: hide_chat(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hide_chat(p_match_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  update public.matches
     set user1_hidden_at = case when user1_id = auth.uid() then now() else user1_hidden_at end,
         user2_hidden_at = case when user2_id = auth.uid() then now() else user2_hidden_at end
   where id = p_match_id
     and (user1_id = auth.uid() or user2_id = auth.uid());

  update public.messages
     set read_at = now()
   where match_id = p_match_id
     and read_at is null
     and sender_id is distinct from auth.uid();
end;
$$;


--
-- Name: internal_service_key(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.internal_service_key() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$ select value from public.internal_secrets where key = 'service_role_key' $$;


--
-- Name: is_test_or_service(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_test_or_service(p_user uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select coalesce(auth.role(), 'service_role') = 'service_role'
      or exists (select 1 from public.users where id = p_user and is_test_user)
$$;


--
-- Name: log_invitation_create(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_invitation_create() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  insert into public.invitation_create_log (owner_id, category) values (new.owner_id, new.category);
  return new;
end $$;


--
-- Name: mark_free_application_used(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_free_application_used() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform set_config('soulchoice.free_app_ok', '1', true);
  update public.users
     set free_applications_used = free_applications_used + 1,
         free_application_used  = (free_applications_used + 1 >= 3)
   where id = new.applicant_id
     and subscription_status = 'free'
     and free_applications_used < 3;
  perform set_config('soulchoice.free_app_ok', '', true);
  return new;
end;
$$;


--
-- Name: mark_selfie_pending(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_selfie_pending() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


--
-- Name: match_and_select(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.match_and_select(p_application_id uuid, p_invitation_id uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_applicant_id uuid;
  v_status       text;
  v_match_id     uuid;
begin
  if not exists (select 1 from invitations where id = p_invitation_id and owner_id = auth.uid()) then
    raise exception 'not_authorized';
  end if;
  -- 20.08: askıdaki/banlı sahip seçim yapamaz (kısa tur denetimi H2) — aksi hâlde match +
  -- "Seçildin" push çıkıyor, karşı taraf yazıyor, askıdaki cevaplayamıyordu. Askıdaki/banlı
  -- başvuran da seçilemez (zaten yazamaz; ölü eşleşme açılmasın).
  if exists (select 1 from public.users where id = auth.uid() and (suspended_at is not null or banned)) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  perform id from invitations where id = p_invitation_id and status in ('active', 'selecting') for update;
  if not found then
    raise exception 'invitation_not_available';
  end if;
  select applicant_id, status into v_applicant_id, v_status
    from applications where id = p_application_id and invitation_id = p_invitation_id;
  if v_applicant_id is null then
    raise exception 'application_not_found';
  end if;
  if v_status not in ('pending', 'selected') then
    raise exception 'application_not_selectable';
  end if;
  if public.users_blocked_pair(auth.uid(), v_applicant_id) then
    raise exception 'MATCH_BLOCKED';
  end if;
  if exists (select 1 from public.users where id = v_applicant_id and (suspended_at is not null or banned)) then
    raise exception 'application_not_selectable';
  end if;
  -- 20.08 (kısa tur): kabul anında ilanın event_date'i buluşma tarihi olarak kopyalanır
  -- (§7; decision_screen eski yolu kopyalıyordu, RPC kopyalamıyordu → anket/no-show ölüydü)
  -- 20.08 (Mustafa kararı): BİR ÇİFT = BİR SOHBET, KALICI. Çift daha önce eşleşmişse
  -- (engelsiz) yeni sohbet açılmaz: mevcut eşleşme yeni plana bağlanır (invitation_id,
  -- kategori anlık görüntüsü, meeting_date yenilenir; buluşma teyitleri sıfırlanır;
  -- iki tarafta da gizlilik kalkar → sohbet listeye döner), mesaj geçmişi aynen durur.
  select m.id into v_match_id
    from matches m
   where m.blocked_at is null
     and ((m.user1_id = auth.uid() and m.user2_id = v_applicant_id)
       or (m.user1_id = v_applicant_id and m.user2_id = auth.uid()))
   order by m.created_at asc
   limit 1;
  if v_match_id is not null then
    perform set_config('soulchoice.match_relink_ok', '1', true);
    -- 20.08 yön normalizasyonu: kural = user1 SAHİP (auth.uid()), user2 BAŞVURAN.
    -- UPDATE sağ tarafı ESKİ değerleri okur → ters yönde cleared_at çifti takaslanır
    -- (hidden/confirmed zaten sıfırlanıyor; blocked_by kullanıcı id'si, takas gerekmez).
    update matches
       set invitation_id = p_invitation_id,
           invitation_category = (select category from invitations where id = p_invitation_id),
           meeting_date = (select event_date from invitations where id = p_invitation_id),
           meeting_confirmed_user1 = null,
           meeting_confirmed_user2 = null,
           user1_hidden_at = null,
           user2_hidden_at = null,
           user1_id = auth.uid(),
           user2_id = v_applicant_id,
           user1_cleared_at = case when user1_id = auth.uid()
                                   then user1_cleared_at else user2_cleared_at end,
           user2_cleared_at = case when user1_id = auth.uid()
                                   then user2_cleared_at else user1_cleared_at end
     where id = v_match_id;
    perform set_config('soulchoice.match_relink_ok', '', true);
  else
    insert into matches (invitation_id, user1_id, user2_id, meeting_date)
      values (p_invitation_id, auth.uid(), v_applicant_id,
              (select event_date from invitations where id = p_invitation_id))
      on conflict (invitation_id, user2_id) do update set invitation_id = excluded.invitation_id
      returning id into v_match_id;
  end if;
  update applications set status = 'accepted', selected_at = now(), responded_at = now()
    where id = p_application_id;
  return v_match_id;
end $$;


--
-- Name: matches_snapshot_category(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.matches_snapshot_category() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if new.invitation_category is null and new.invitation_id is not null then
    select category into new.invitation_category from public.invitations where id = new.invitation_id;
  end if;
  return new;
end $$;


--
-- Name: my_billing_email(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.my_billing_email() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$ select billing_email from public.users where id = auth.uid() $$;


--
-- Name: my_chat_summaries(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.my_chat_summaries() RETURNS TABLE(match_id uuid, content text, sender_id uuid, created_at timestamp with time zone, unread integer)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  with my as (
    select id, user1_cleared_at as cleared_at from matches where user1_id = auth.uid()
    union all
    select id, user2_cleared_at as cleared_at from matches where user2_id = auth.uid()
  ),
  last_msg as (
    select distinct on (m.match_id)
           m.match_id, m.content, m.sender_id, m.created_at
      from messages m
      join my on my.id = m.match_id
     where my.cleared_at is null or m.created_at > my.cleared_at
     order by m.match_id, m.created_at desc
  ),
  unread_cnt as (
    select m.match_id, count(*)::int as cnt
      from messages m
      join my on my.id = m.match_id
     where m.read_at is null
       and m.sender_id is distinct from auth.uid()
       and (my.cleared_at is null or m.created_at > my.cleared_at)
     group by m.match_id
  )
  select l.match_id, l.content, l.sender_id, l.created_at,
         coalesce(u.cnt, 0)
    from last_msg l
    left join unread_cnt u on u.match_id = l.match_id;
$$;


--
-- Name: notify_application_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_application_status() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  inv RECORD;
  owner_name TEXT;
  owner_gender TEXT;
  notif_type TEXT;
  v_match_id UUID;
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
  SELECT name, gender INTO owner_name, owner_gender FROM users WHERE id = inv.owner_id;
  IF notif_type = 'selected' THEN
    SELECT id INTO v_match_id FROM matches
     WHERE invitation_id = NEW.invitation_id
       AND user2_id = NEW.applicant_id
     ORDER BY created_at DESC LIMIT 1;
  END IF;
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
    jsonb_build_object(
      'invitation_id', NEW.invitation_id,
      'application_id', NEW.id,
      'actor_id', inv.owner_id
    ) || CASE WHEN v_match_id IS NOT NULL
              THEN jsonb_build_object('match_id', v_match_id)
              ELSE '{}'::jsonb END
  );

  -- push yalnız 'selected' için (not_selected bilinçli push'suz — in-app yeter)
  IF notif_type = 'selected' THEN
    BEGIN
      PERFORM net.http_post(
        url := 'http://supabase-edge-functions:9000/send-notification',
        body := jsonb_build_object(
          'user_id', NEW.applicant_id,
          'title', 'Тебя выбрали! 🎉',
          'body', COALESCE(owner_name, '') || ' выбрал(а) тебя — чат открыт',
          'data', jsonb_build_object('type', 'selected', 'invitation_id', NEW.invitation_id)
                  || CASE WHEN v_match_id IS NOT NULL
                          THEN jsonb_build_object('match_id', v_match_id)
                          ELSE '{}'::jsonb END,
          'template', jsonb_build_object('name', COALESCE(owner_name, ''), 'gender', COALESCE(owner_gender, ''))),
        headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: notify_invitation_updated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_invitation_updated() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare r record;
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then return new; end if;
  if (new.title, new.venue_name, new.event_date, new.description)
     is not distinct from (old.title, old.venue_name, old.event_date, old.description) then
    return new;
  end if;
  begin
    for r in select applicant_id from public.applications
              where invitation_id = new.id and status in ('pending', 'selected')
    loop
      if exists (select 1 from public.notifications
                  where user_id = r.applicant_id and type = 'invitation_updated'
                    and payload->>'invitation_id' = new.id::text
                    and created_at > now() - interval '30 minutes') then
        continue;
      end if;
      insert into public.notifications (user_id, type, title, body, payload)
      values (r.applicant_id, 'invitation_updated', 'Приглашение изменилось', new.title,
              jsonb_build_object('invitation_id', new.id, 'actor_id', new.owner_id));
      begin
        perform net.http_post(
          url := 'http://supabase-edge-functions:9000/send-notification',
          body := jsonb_build_object(
            'user_id', r.applicant_id,
            'title', 'Приглашение изменилось ✏️',
            'body', new.title,
            'data', jsonb_build_object('type', 'invitation_updated', 'invitation_id', new.id)),
          headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));  -- 19.08: send-notification 401 düzeltmesi
      exception when others then null;
      end;
    end loop;
  exception when others then
    raise warning 'notify_invitation_updated: %', sqlerrm;   -- düzenlemeyi asla engelleme
  end;
  return new;
end $$;


--
-- Name: notify_new_application(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_application() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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

  begin
    perform net.http_post(
      url := 'http://supabase-edge-functions:9000/send-notification',
      body := jsonb_build_object(
        'user_id', inv.owner_id,
        'title', 'Новая заявка 🔔',
        'body', coalesce(applicant_name, '') || ' хочет присоединиться',
        'data', jsonb_build_object('type', 'new_application', 'invitation_id', new.invitation_id),
        'template', jsonb_build_object('name', coalesce(applicant_name, ''))),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));
  exception when others then null;
  end;

  return new;
end;
$$;


--
-- Name: notify_new_match(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_match() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  other_name TEXT;
BEGIN
  SELECT name INTO other_name FROM users WHERE id = NEW.user2_id;
  BEGIN
    PERFORM net.http_post(
      url := 'http://supabase-edge-functions:9000/send-notification',
      body := jsonb_build_object(
        'user_id', NEW.user1_id,
        'title', 'Совпадение! 🎉',
        'body', 'Чат с ' || COALESCE(other_name, '') || ' открыт',
        'data', jsonb_build_object('type', 'match', 'match_id', NEW.id),
        'template', jsonb_build_object('name', COALESCE(other_name, ''))),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RETURN NEW;
END;
$$;


--
-- Name: notify_new_message(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_new_message() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  match_rec RECORD;
  sender_name TEXT;
  recipient_id UUID;
BEGIN
  SELECT user1_id, user2_id INTO match_rec FROM matches WHERE id = NEW.match_id;
  SELECT name INTO sender_name FROM users WHERE id = NEW.sender_id;
  recipient_id := CASE WHEN match_rec.user1_id = NEW.sender_id THEN match_rec.user2_id ELSE match_rec.user1_id END;

  INSERT INTO notifications(user_id, type, title, body, payload)
  VALUES (
    recipient_id,
    'new_message',
    sender_name || ' mesaj gönderdi 💬',
    CASE WHEN length(NEW.content) > 60 THEN left(NEW.content, 60) || '…' ELSE NEW.content END,
    jsonb_build_object('match_id', NEW.match_id, 'sender_id', NEW.sender_id, 'actor_id', NEW.sender_id)
  );

  BEGIN
    PERFORM net.http_post(
      url := 'http://supabase-edge-functions:9000/send-notification',
      body := jsonb_build_object(
        'user_id', recipient_id,
        'title', '💬 ' || COALESCE(sender_name, ''),
        'body', 'Новое сообщение',
        'data', jsonb_build_object('type', 'new_message', 'match_id', NEW.match_id),
        'template', jsonb_build_object('name', COALESCE(sender_name, ''))),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN NEW;
END;
$$;


--
-- Name: notify_selfie_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_selfie_status() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF OLD.selfie_status = NEW.selfie_status THEN RETURN NEW; END IF;

  IF NEW.selfie_status = 'approved' THEN
    INSERT INTO notifications(user_id, type, title, body, payload)
    VALUES (NEW.id, 'selfie_approved', 'Doğrulandın! 🎉', 'Artık davetlere katılabilirsin.', '{}');
    BEGIN
      PERFORM net.http_post(
        url := 'http://supabase-edge-functions:9000/send-notification',
        body := jsonb_build_object(
          'user_id', NEW.id,
          'title', 'Профиль подтверждён ✓',
          'body', 'Теперь ты можешь участвовать в приглашениях',
          'data', jsonb_build_object('type', 'selfie_approved')),
        headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  ELSIF NEW.selfie_status = 'rejected' THEN
    INSERT INTO notifications(user_id, type, title, body, payload)
    VALUES (
      NEW.id, 'selfie_rejected', 'Selfie reddedildi',
      COALESCE('Sebep: ' || NEW.selfie_rejected_reason, 'Lütfen selfieni yeniden yükle.'),
      CASE WHEN NEW.selfie_rejected_reason IS NOT NULL
           THEN jsonb_build_object('reason', NEW.selfie_rejected_reason)
           ELSE '{}'::jsonb END
    );
    BEGIN
      PERFORM net.http_post(
        url := 'http://supabase-edge-functions:9000/send-notification',
        body := jsonb_build_object(
          'user_id', NEW.id,
          'title', 'Фото отклонено',
          'body', 'Пожалуйста, загрузи новое селфи',
          'data', jsonb_build_object('type', 'selfie_rejected'),
          'template', jsonb_build_object('reason', NEW.selfie_rejected_reason)),
        headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: notify_suspension(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_suspension() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if new.suspended_at is not null and old.suspended_at is null then
    begin
      perform net.http_post(
        url := 'http://supabase-edge-functions:9000/send-notification',
        body := jsonb_build_object(
          'user_id', new.id,
          'title', 'SoulChoice',
          'body', 'Аккаунт приостановлен — подробности: support@soulchoice.app',
          'data', jsonb_build_object('type', 'account_suspended')),
        headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public.internal_service_key()));
    exception when others then null;
    end;
  end if;
  return new;
end $$;


--
-- Name: on_block_inserted(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_block_inserted() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  -- (a) eşleşmeleri kapat (iki yön)
  update public.matches m
     set blocked_by = new.blocker_id,
         blocked_at = now(),
         user1_hidden_at = case when m.user1_id = new.blocker_id then coalesce(m.user1_hidden_at, now()) else m.user1_hidden_at end,
         user2_hidden_at = case when m.user2_id = new.blocker_id then coalesce(m.user2_hidden_at, now()) else m.user2_hidden_at end
   where m.blocked_at is null
     and ((m.user1_id = new.blocker_id and m.user2_id = new.blocked_id)
       or (m.user1_id = new.blocked_id and m.user2_id = new.blocker_id));

  -- (b) bekleyen başvuruları sessizce geri çek (iki yön)
  update public.applications a
     set status = 'withdrawn'
    from public.invitations i
   where i.id = a.invitation_id
     and a.status = 'pending'
     and ((a.applicant_id = new.blocked_id and i.owner_id = new.blocker_id)
       or (a.applicant_id = new.blocker_id and i.owner_id = new.blocked_id));
  return new;
end $$;


--
-- Name: ops_approve_gift_link(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_approve_gift_link(p_invitation_id uuid, p_actor text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  update public.invitation_gift_links
     set status = 'approved', updated_at = now()
   where invitation_id = p_invitation_id and status = 'pending';
  if not found then raise exception 'gift link pending durumda değil: %', p_invitation_id; end if;
  insert into public.audit_log(actor, action, target_type, target_id)
  values (p_actor, 'approve_gift_link', 'gift_link', p_invitation_id);
end;
$$;


--
-- Name: ops_approve_selfie(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_approve_selfie(p_user uuid, p_actor text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  update public.users
     set selfie_status = 'approved', verified = true, verified_at = now(),
         selfie_rejected_reason = null
   where id = p_user and selfie_status = 'pending';
  if not found then raise exception 'selfie pending durumda değil: %', p_user; end if;
  insert into public.audit_log(actor, action, target_type, target_id)
  values (p_actor, 'approve_selfie', 'user', p_user);
end $$;


--
-- Name: ops_ban_user(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_ban_user(p_user uuid, p_actor text, p_note text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


--
-- Name: ops_close_invitation(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_close_invitation(p_invitation uuid, p_actor text, p_note text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  update public.invitations set status = 'closed'
   where id = p_invitation and status = 'active';
  if not found then raise exception 'aktif davet bulunamadı: %', p_invitation; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'close_invitation', 'invitation', p_invitation, p_note);
end $$;


--
-- Name: ops_reject_gift_link(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_reject_gift_link(p_invitation_id uuid, p_reason text, p_actor text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  update public.invitation_gift_links
     set status = 'rejected', updated_at = now()
   where invitation_id = p_invitation_id and status = 'pending';
  if not found then raise exception 'gift link pending durumda değil: %', p_invitation_id; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'reject_gift_link', 'gift_link', p_invitation_id, p_reason);
end;
$$;


--
-- Name: ops_reject_selfie(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_reject_selfie(p_user uuid, p_reason text, p_actor text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if coalesce(trim(p_reason), '') = '' then raise exception 'red sebebi zorunlu'; end if;
  update public.users
     set selfie_status = 'rejected', selfie_rejected_reason = p_reason, verified = false
   where id = p_user and selfie_status = 'pending';
  if not found then raise exception 'selfie pending durumda değil: %', p_user; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'reject_selfie', 'user', p_user, p_reason);
end $$;


--
-- Name: ops_remove_photo(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_remove_photo(p_photo uuid, p_actor text, p_note text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare v_user uuid; v_url text;
begin
  delete from public.user_photos where id = p_photo returning user_id, url into v_user, v_url;
  if not found then raise exception 'fotoğraf bulunamadı: %', p_photo; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason, meta)
  values (p_actor, 'remove_photo', 'user_photo', p_photo, p_note,
          jsonb_build_object('user_id', v_user, 'url', v_url));
end $$;


--
-- Name: ops_report_messages(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_report_messages(p_report_id uuid) RETURNS TABLE(source text, sender_id uuid, content text, created_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  select 'live', m.sender_id, m.content, m.created_at
    from public.reports r join public.messages m on m.match_id = coalesce(r.match_id, r.match_id_snapshot) where r.id = p_report_id
  union all
  select 'archive', a.sender_id, a.content, a.created_at
    from public.reports r join public.messages_archive a on a.match_id = coalesce(r.match_id, r.match_id_snapshot) where r.id = p_report_id
  order by 4
$$;


--
-- Name: ops_resolve_report(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_resolve_report(p_report uuid, p_actor text, p_note text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  update public.reports set status = 'resolved'
   where id = p_report and status not in ('resolved', 'dismissed');
  if not found then raise exception 'açık şikayet bulunamadı: %', p_report; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'resolve_report', 'report', p_report, p_note);
end $$;


--
-- Name: ops_search_users(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_search_users(q text) RETURNS TABLE(id uuid, name text, age integer, city_id text, phone_tail text, created_at timestamp with time zone, verified boolean, banned boolean, warning_count integer, is_test_user boolean, premium boolean)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  select u.id, u.name, u.age::int, u.city_id::text, right(u.phone, 4), u.created_at,
         u.verified, u.banned, u.warning_count::int, u.is_test_user,
         (u.subscription_status = 'active' or u.premium_until > now())
  from public.users u
  where not u.is_deleted
    and (u.name ilike '%' || q || '%' or u.phone like '%' || q)
  order by u.created_at desc
  limit 20
$$;


--
-- Name: ops_unban_user(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_unban_user(p_user uuid, p_actor text, p_note text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
end $$;


--
-- Name: ops_user_detail(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_user_detail(p_user_id uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT jsonb_build_object(
    'user', (SELECT jsonb_build_object(
        'id', u.id, 'name', u.name, 'age', u.age, 'gender', u.gender,
        'bio', u.bio,
        'city', (SELECT c.name FROM cities c WHERE c.id = u.city_id),
        'phone', (SELECT au.phone FROM auth.users au WHERE au.id = p_user_id),
        'billing_email', u.billing_email,
        'selfie_status', u.selfie_status,
        'subscription_status', u.subscription_status,
        'premium_until', u.premium_until,
        'free_application_used', u.free_application_used,
        'free_applications_used', u.free_applications_used,
        'is_test_user', u.is_test_user,
        'banned', COALESCE(u.banned, false),
        'suspended_at', u.suspended_at,
        'verified', u.verified,
        'created_at', u.created_at,
        'locale', u.locale
      ) FROM users u WHERE u.id = p_user_id),
    -- Yalnız profil fotoları: selfie'ler private bucket'ta, ham URL panelde
    -- açılmaz (29.07 bulgusu) — güncel selfie agent'ın selfie-photo ucundan gelir.
    'photos', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'url', p.url, 'is_primary', p.is_primary,
        'moderation_status', p.moderation_status)
        ORDER BY p.is_primary DESC, p.order_index)
      FROM user_photos p WHERE p.user_id = p_user_id AND p.is_selfie = false), '[]'::jsonb),
    'counters', jsonb_build_object(
      'active_invitations', (SELECT count(*)::int FROM invitations i
        WHERE i.owner_id = p_user_id AND i.status = 'active' AND i.expires_at > now()),
      'total_invitations', (SELECT count(*)::int FROM invitations i
        WHERE i.owner_id = p_user_id),
      'applications_sent', (SELECT count(*)::int FROM applications a
        WHERE a.applicant_id = p_user_id),
      'matches', (SELECT count(*)::int FROM matches m
        WHERE m.user1_id = p_user_id OR m.user2_id = p_user_id),
      'reports_against', (SELECT count(*)::int FROM reports r
        WHERE r.reported_user_id = p_user_id),
      'payments_paid', (SELECT count(*)::int FROM payments pay
        WHERE pay.user_id = p_user_id AND pay.status = 'paid')
    )
  );
$$;


--
-- Name: ops_warn_user(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ops_warn_user(p_user uuid, p_actor text, p_note text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if coalesce(trim(p_note), '') = '' then raise exception 'uyarı notu zorunlu'; end if;
  update public.users set warning_count = warning_count + 1 where id = p_user and is_deleted = false;
  if not found then raise exception 'kullanıcı bulunamadı: %', p_user; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'warn_user', 'user', p_user, p_note);
end $$;


--
-- Name: otp_is_bypass(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.otp_is_bypass(p_norm text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select p_norm in ('70000000001','70000000002','70000000003','70000000004',
                    '70000000005','70000000006','70000000007')
$$;


--
-- Name: otp_log_fail(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.otp_log_fail(p_phone text, p_channel text, p_reason text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  insert into public.otp_send_log (phone, channel, result)
    values (public.otp_norm(p_phone), p_channel, 'fail:' || left(coalesce(p_reason, '?'), 60))
$$;


--
-- Name: otp_norm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.otp_norm(p_phone text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  select regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
$$;


--
-- Name: otp_precheck(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.otp_precheck(p_phone text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_norm text := public.otp_norm(p_phone);
  v_last timestamptz;
  v_age  numeric;
begin
  if public.otp_is_bypass(v_norm) then
    return 'ok';
  end if;
  select max(created_at) into v_last from public.call_otps where public.otp_norm(phone) = v_norm;
  if v_last is not null then
    v_age := extract(epoch from (now() - v_last));
    if v_age < 60 then
      return 'too_soon:' || ceil(60 - v_age)::int;
    end if;
  end if;
  if (select count(*) from public.otp_send_log
       where phone = v_norm and created_at > now() - interval '24 hours'
         and coalesce(result, 'sent') = 'sent') >= 15 then
    return 'cap';
  end if;
  return 'ok';
end $$;


--
-- Name: otp_store(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.otp_store(p_phone text, p_code text, p_channel text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_norm  text := public.otp_norm(p_phone);
  v_phone text := '+' || v_norm;
begin
  delete from public.call_otps where public.otp_norm(phone) = v_norm;
  insert into public.call_otps (phone, code, expires_at)
    values (v_phone, p_code, now() + interval '5 minutes');
  if not public.otp_is_bypass(v_norm) then
    update public.otp_send_log set channel = p_channel, result = 'sent'
     where id = (select max(id) from public.otp_send_log where phone = v_norm);
  end if;
  return 'ok';
exception when others then
  if sqlerrm = 'OTP_DAILY_CAP' then return 'cap'; end if;
  raise;
end $$;


--
-- Name: otp_verify(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.otp_verify(p_phone text, p_code text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  v_norm text := public.otp_norm(p_phone);
  v_row  public.call_otps%rowtype;
begin
  select * into v_row from public.call_otps
   where public.otp_norm(phone) = v_norm and expires_at > now()
   order by created_at desc limit 1
   for update;
  if not found then
    return 'invalid';
  end if;
  if v_row.attempts >= 5 then
    delete from public.call_otps where public.otp_norm(phone) = v_norm;
    insert into public.otp_send_log (phone, channel, result) values (v_norm, 'verify', 'too_many');
    return 'too_many';
  end if;
  if v_row.code <> p_code then
    update public.call_otps set attempts = attempts + 1 where id = v_row.id;
    insert into public.otp_send_log (phone, channel, result) values (v_norm, 'verify', 'wrong');
    return 'invalid';
  end if;
  delete from public.call_otps where public.otp_norm(phone) = v_norm;
  if not public.otp_is_bypass(v_norm) then
    insert into public.otp_send_log (phone, channel, result) values (v_norm, 'verify', 'verified');
  end if;
  return 'ok';
end $$;


--
-- Name: photo_focus_entries(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.photo_focus_entries() RETURNS TABLE(url text, face_focus_x real, face_focus_y real)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select p.url, p.face_focus_x, p.face_focus_y
    from user_photos p
    join users u on u.id = p.user_id
   where p.face_focus_x >= 0
     and coalesce(u.is_deleted, false) = false
     and coalesce(u.banned, false) = false
   order by p.created_at desc
   limit 5000
$$;


--
-- Name: prevent_invitations_tamper(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_invitations_tamper() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.status := old.status;
    new.expires_at := old.expires_at;
    new.owner_id := old.owner_id;
  end if;
  return new;
end;
$$;


--
-- Name: prevent_matches_tamper(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_matches_tamper() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
declare
  match_ok boolean := coalesce(current_setting('soulchoice.match_ok', true), '') = '1';
  -- 20.08: match_and_select içinde "bir çift = bir sohbet" yeniden bağlama (invitation_id,
  -- kategori, meeting_date, teyit sıfırlama) yalnız bu GUC ile; istemciden asla.
  relink_ok boolean := coalesce(current_setting('soulchoice.match_relink_ok', true), '') = '1';
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.id := old.id;
    new.user1_id := old.user1_id;
    new.user2_id := old.user2_id;
    new.created_at := old.created_at;
    if not relink_ok then
      new.invitation_id := old.invitation_id;
      new.invitation_category := old.invitation_category;
    end if;
    if not match_ok and not relink_ok then
      new.meeting_confirmed_user1 := old.meeting_confirmed_user1;
      new.meeting_confirmed_user2 := old.meeting_confirmed_user2;
      new.no_show_reported_by := old.no_show_reported_by;
    end if;
    if new.blocked_at is distinct from old.blocked_at or new.blocked_by is distinct from old.blocked_by then
      if old.blocked_at is not null then
        new.blocked_at := old.blocked_at;
        new.blocked_by := old.blocked_by;
      else
        new.blocked_by := auth.uid();
        new.blocked_at := now();
      end if;
    end if;
  end if;
  return new;
end $$;


--
-- Name: prevent_messages_tamper(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_messages_tamper() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.id := old.id;
    new.match_id := old.match_id;
    new.sender_id := old.sender_id;
    new.content := old.content;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;


--
-- Name: prevent_photos_tamper(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_photos_tamper() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.moderation_status := old.moderation_status;
    new.url := old.url;
    new.is_selfie := old.is_selfie;
  end if;
  return new;
end;
$$;


--
-- Name: prevent_users_insert_escalation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_users_insert_escalation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
    new.free_applications_used := 0;
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
$$;


--
-- Name: prevent_users_privilege_escalation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_users_privilege_escalation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  selfie_pending_ok boolean :=
    coalesce(current_setting('soulchoice.selfie_pending_ok', true), '') = '1'
    and old.selfie_status in ('none', 'rejected')
    and new.selfie_status = 'pending';
  -- 19.08: 3 ücretsiz hak — sayaç yalnız +1 artabilir (trigger bağlamında), bayrak = sayaç>=3
  free_app_ok boolean :=
    coalesce(current_setting('soulchoice.free_app_ok', true), '') = '1'
    and new.free_applications_used = old.free_applications_used + 1
    and new.free_application_used = (new.free_applications_used >= 3);
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
      new.free_applications_used := old.free_applications_used;
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
$$;


--
-- Name: reports_snapshot(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reports_snapshot() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  select name into new.reported_name_snapshot from public.users where id = new.reported_user_id;
  return new;
end $$;


--
-- Name: reports_snapshot_match_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reports_snapshot_match_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.match_id is not null then new.match_id_snapshot := new.match_id; end if;
  return new;
end $$;


--
-- Name: reset_created_at_on_reapply(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reset_created_at_on_reapply() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if old.status = 'withdrawn' and new.status = 'pending' then
    new.created_at := now();
    new.selected_at := null;
  end if;
  return new;
end;
$$;


--
-- Name: reset_face_focus_on_url_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reset_face_focus_on_url_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.url is distinct from old.url then
    new.face_focus_x := null;
    new.face_focus_y := null;
  end if;
  return new;
end $$;


--
-- Name: set_invitation_feed_rank(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_invitation_feed_rank() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  select case when u.is_test_user then 1 else 0 end into new.feed_rank
    from public.users u where u.id = new.owner_id;
  new.feed_rank := coalesce(new.feed_rank, 0);
  return new;
end $$;


--
-- Name: simulate_test_liveliness(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.simulate_test_liveliness() RETURNS TABLE(refreshed_invitations integer, seeded_applications integer, touched_users integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_now       timestamptz := now();
  v_msk_hour  int := extract(hour from v_now at time zone 'Europe/Moscow')::int;
  -- Bypass/Mustafa hesabı: motor hiçbir yazmada bu kullanıcıya dokunmaz
  v_bypass    uuid := '279e44e0-f09e-4b31-ad20-94966aa6f6bb';
  -- Демо hesabı (is_test_user=TRUE!): Apple review sahnesi — motor ASLA dokunmaz
  -- (19.08 denetimi: yalnız demo-autoextend cron'u koruyordu; açık guard eklendi)
  v_demo      uuid := '385ea0eb-2089-4fd2-8883-8a47a39da29a';
  r           record;
  v_created   timestamptz;
  v_expires   timestamptz;
  n_apps      int;
  v_refreshed int := 0;
  v_apps      int := 0;
  v_touched   int := 0;
  -- İçerik rotasyonu (19.08.2026): kişi başına birden çok davet varyantı
  v_nvar      int;
  v_cur       int;
  v_next      int;
  v_var       record;
  v_season    text;   -- 02.09: vitrin mevsimi (warm/cold)
  v_evbase    timestamptz;
  v_evdate    timestamptz;
begin
  -- 02.09.2026 (Mustafa): vitrin içeriği mevsime uyar — «Сап по Москве-реке» Eylül
  -- yağmurunda sahte olduğunu ele veriyordu. feature_flags.test_content_season
  -- {"mode":"auto"|"warm"|"cold"}; auto = Moskova takvimi: Mayıs–Ağustos warm, diğer cold.
  select coalesce(value->>'mode', 'auto') into v_season
    from public.feature_flags where key = 'test_content_season';
  if v_season is null or v_season not in ('warm','cold') then
    v_season := case when extract(month from (v_now at time zone 'Europe/Moscow')) between 5 and 8
                     then 'warm' else 'cold' end;
  end if;
  -- ── 1) Davet rebirth: dolan kart ANINDA yenilenir (v2 — ölü bekleme yok) ──
  for r in
    select u.id as user_id, u.gender, u.city_id,
           i.id as inv_id, i.status as inv_status, i.flow_type,
           i.expires_at, i.event_date
    from public.users u
    left join lateral (
      select id, status, flow_type, expires_at, event_date
      from public.invitations
      where owner_id = u.id
      order by expires_at desc
      limit 1
    ) i on true
    where u.is_test_user = true
      and u.id <> v_bypass
      and u.id <> v_demo
      and u.is_deleted = false
      and u.banned = false
      and i.id is not null                -- davetsiz test kullanıcısını fonksiyon YARATMAZ
                                          -- (ilk davet add-test-user.sh'ın işi)
  loop
    -- Aktif ve süresi dolmamış davet varsa dokunma.
    -- Expiry-race fix: 2 dk tolerans — cron koşarken dolmak üzere olanlar da yenilenir.
    if r.inv_status = 'active' and r.expires_at > v_now + interval '2 minutes' then
      continue;
    end if;

    -- Rebirth damgaları: hep "az önce / 1 saat önce" hissi + doğal geri sayım
    v_created := v_now - (random() * interval '90 minutes');
    v_expires := v_created + interval '20 hours' + (random() * interval '6 hours');

    update public.invitations i
    set status     = 'active',
        created_at = v_created,
        expires_at = v_expires,
        -- event_date geçmişte/expiry içinde kalmasın: saat korunur, gün ileri itilir
        event_date = case
          when i.event_date > v_expires then i.event_date
          else i.event_date
             + (ceil(extract(epoch from (v_expires - i.event_date)) / 86400.0)::int
                * interval '1 day')
        end
        -- selection_deadline'a DOKUNULMAZ (D1 teyitli 10.07): job 1 onu yalnız
        -- active→selecting geçişinde expires_at+48h yapar; aktif davette inert.
        -- selecting/closed'a düşmüş test daveti bu update ile zaten active'e döner.
    where i.id = r.inv_id
      and exists (select 1 from public.users ou
                  where ou.id = i.owner_id and ou.is_test_user = true);  -- çifte guard
    v_refreshed := v_refreshed + 1;

    -- Eski başvuruları sil — TEST ve GERÇEK kullanıcılarınki birlikte (19.08.2026,
    -- Mustafa kararı). Gerekçe: gerçek akışta dolan matchsiz ilan closed→SİLİNİR
    -- ve başvurular CASCADE ile gider; yeniden doğan test kartı "yeni ilan"dır,
    -- gerçek kullanıcının eski başvurusu aynı satırda sonsuza dek 'pending'
    -- kalıyordu (Başvurularım'da 21 gün "Bekliyor" = sahte sinyal). selected/
    -- accepted ASLA silinmez (test sahibi seçmez; olası match korunur).
    delete from public.applications a
    where a.invitation_id = r.inv_id
      and a.status in ('pending', 'withdrawn', 'rejected', 'expired');

    -- İÇERİK ROTASYONU (19.08.2026, Mustafa kararı): test kartı yeniden doğarken
    -- kişinin sıradaki davet varyantını alır (kategori/başlık/açıklama/mekân/saat)
    -- → "aynı kişi aynı kafede her gün" sahte sinyali kalkar. Varyant yoksa
    -- (ör. Демо) içerik aynen kalır. Sıra: test_rotation_state (kişi başına seq).
    select count(*) into v_nvar
      from public.test_invitation_variants where owner_id = r.user_id;
    if v_nvar > 1 then
      select seq into v_cur from public.test_rotation_state where owner_id = r.user_id;
      -- 22.08 (Mustafa: «Ресторан'da 2-3 kişi var; kişi ilk gördüğüne tıklar,
      -- 3 kart görürse boş app der gider»): kör sıra yerine AĞIRLIKLI DİLİM
      -- DENGESİ — kişinin varyantları arasından, bu şehir+akış+cinsiyet
      -- diliminde doluluk/hedef oranı EN DÜŞÜK kategori seçilir. Hedefler çip
      -- görünürlüğüne göre (food 6, bar/concert 5, coffee/walk 4, travel/
      -- culture/cinema 3, niş 2): vitrindeki ilk kategoriler her zaman dolu
      -- kalır, walk 11'e şişemez. Eşitlikte çip sırası, sonra doğal rotasyon.
      select v.* into v_var
        from public.test_invitation_variants v
        left join lateral (
          select count(*) as n
            from public.invitations ai
            join public.users au on au.id = ai.owner_id
           where ai.status = 'active'
             and ai.expires_at > v_now
             and ai.category = v.category
             and ai.city_id = r.city_id
             and ai.flow_type = r.flow_type
             and au.is_test_user = true
             and au.gender = r.gender
             and ai.id <> r.inv_id
        ) cnt on true
       where v.owner_id = r.user_id
         and (v.season = 'all' or v.season = v_season)   -- 02.09 mevsim filtresi
       order by (cnt.n::numeric / case v.category
                   when 'food'    then 6
                   when 'bar'     then 5
                   when 'concert' then 5
                   when 'coffee'  then 4
                   when 'walk'    then 4
                   when 'travel'  then 3
                   when 'culture' then 3
                   when 'cinema'  then 3
                   else 2 end) asc,
                case v.category
                   when 'food' then 0 when 'bar' then 1 when 'concert' then 2
                   when 'travel' then 3 else 4 end asc,
                ((v.seq - coalesce(v_cur, 0) - 1 + v_nvar) % v_nvar) asc
       limit 1;
      v_next := v_var.seq;
      if v_var.seq is not null then
        -- event_date: expires+1h'den sonraki ilk "varyant saati" (MSK) — süre kuralı
        -- expires_at ≤ event_date − 1h (17.08) korunur.
        v_evbase := v_expires + interval '1 hour';
        v_evdate := (date_trunc('day', v_evbase at time zone 'Europe/Moscow')
                     + make_interval(hours => v_var.ev_hour)) at time zone 'Europe/Moscow';
        if v_evdate < v_evbase then v_evdate := v_evdate + interval '1 day'; end if;

        update public.invitations i
           set category    = v_var.category,
               title       = v_var.title,
               description = v_var.description,
               venue_name  = v_var.venue_name,
               event_date  = v_evdate
         where i.id = r.inv_id
           and exists (select 1 from public.users ou
                       where ou.id = i.owner_id and ou.is_test_user = true);  -- çifte guard

        insert into public.test_rotation_state (owner_id, seq)
        values (r.user_id, v_next)
        on conflict (owner_id) do update set seq = excluded.seq, updated_at = now();
      end if;
    end if;

    -- 0–4 taze test başvuranı ek (aynı şehir, karşı cinsiyet, davet doğumundan sonra damga)
    n_apps := floor(random()*5)::int;
    with fresh as (
      insert into public.applications (invitation_id, applicant_id, status, created_at)
      select r.inv_id, tu.id, 'pending',
             v_created + (random() * (v_now - v_created))
      from public.users tu
      where tu.is_test_user = true
        and tu.id <> r.user_id
        and tu.id <> v_bypass
        and tu.id <> v_demo
        and tu.city_id = r.city_id
        and tu.gender is distinct from r.gender
        and tu.is_deleted = false
        and tu.banned = false
      order by random()
      limit n_apps
      on conflict (invitation_id, applicant_id) do nothing
      returning applicant_id, created_at
    )
    -- Başvuranların keşfet tazeliği: last_active_at ≈ başvuru anı
    update public.users u
    set last_active_at = greatest(coalesce(u.last_active_at, f.created_at), f.created_at)
    from fresh f
    where u.id = f.applicant_id and u.is_test_user = true;

    get diagnostics n_apps = row_count;  -- update edilen başvuran sayısı
    v_apps := v_apps + n_apps;

    -- Davet sahibinin tazeliği
    update public.users
    set last_active_at = v_created + (random() * (v_now - v_created))
    where id = r.user_id and is_test_user = true;
  end loop;

  -- ── 2) Keşfet tazelik nabzı: uyanık saatlerde koşu başına 2–4 rastgele
  --       test kullanıcısına "az önce aktifti" damgası (davetten bağımsız) ──
  if v_msk_hour between 8 and 23 then
    update public.users u
    set last_active_at = v_now - (random() * interval '30 minutes')
    from (
      select id from public.users
      where is_test_user = true and id <> v_bypass and id <> v_demo
        and is_deleted = false and banned = false
      order by random()
      limit 2 + floor(random()*3)::int
    ) pick
    where u.id = pick.id;
    get diagnostics v_touched = row_count;
  end if;

  return query select v_refreshed, v_apps, v_touched;
end;
$$;


--
-- Name: suggest_places(text, text, uuid, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.suggest_places(p_q text, p_kind text, p_city_id uuid DEFAULT NULL::uuid, p_category text DEFAULT NULL::text, p_limit integer DEFAULT 8) RETURNS TABLE(id uuid, name text, category text, street text, housenumber text, metro text, district text, website text, country_ru text, lat double precision, lng double precision, source text)
    LANGUAGE plpgsql STABLE
    AS $$
declare
  v_key text; v_market text; v_clat float8; v_clng float8;
  v_q text := lower(trim(p_q));
begin
  select ck.key, ck.brand_market, ck.center_lat, ck.center_lng
    into v_key, v_market, v_clat, v_clng
  from public.city_keys ck where ck.city_id = p_city_id;

  return query
  select p.id, p.name, p.category, p.street, p.housenumber,
         p.metro, p.district, p.website, p.country_ru, p.lat, p.lng, p.source
  from public.places p
  where p.is_active
    and p.kind = p_kind
    and (case p.kind
           when 'venue' then p.city_key = v_key
           when 'brand' then p.city_key = coalesce(v_market, p.city_key)
           else true end)
    and (lower(p.name) like v_q || '%'
         or lower(p.name) like '% ' || v_q || '%'
         or similarity(lower(p.name), v_q) > 0.3
         or lower(coalesce(p.name_en,'')) like v_q || '%'
         or lower(coalesce(p.name_ru,'')) like v_q || '%')
  order by
    greatest(similarity(lower(p.name), v_q),
             similarity(lower(coalesce(p.name_en,'')), v_q)) desc,
    (p.source = 'curated') desc,
    p.usage_count desc,
    (p_category is not null and p.category = p_category) desc,
    case when p.lat is not null and v_clat is not null
         then abs(p.lat - v_clat) + abs(p.lng - v_clng)
         else 9 end asc
  limit least(p_limit, 25);
end $$;


--
-- Name: sync_feed_rank_on_user_flag(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_feed_rank_on_user_flag() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if new.is_test_user is distinct from old.is_test_user then
    update public.invitations set feed_rank = case when new.is_test_user then 1 else 0 end
     where owner_id = new.id;
  end if;
  return new;
end $$;


--
-- Name: touch_last_seen(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_last_seen() RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  update public.users set last_seen_at = now() where id = auth.uid();
$$;


--
-- Name: touch_place(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_place(p_place_id uuid) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  update public.places set usage_count = usage_count + 1 where id = p_place_id;
$$;


--
-- Name: users_blocked_pair(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.users_blocked_pair(a uuid, b uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  select exists (select 1 from public.blocks
                  where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;


--
-- Name: users_fill_phone_from_auth(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.users_fill_phone_from_auth() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
begin
  if new.phone is null then
    select u.phone into new.phone from auth.users u where u.id = new.id;
  end if;
  return new;
end $$;


--
-- Name: zz_flag_test_phone(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.zz_flag_test_phone() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  if regexp_replace(coalesce(new.phone,''),'[^0-9]','','g') in ('70000000001','70000000002','70000000003','70000000004','70000000005','70000000006','70000000007') then
    new.is_test_user := true;
  end if;
  return new;
end $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applications (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    invitation_id uuid,
    applicant_id uuid,
    status text DEFAULT 'pending'::text,
    selected_at timestamp with time zone,
    responded_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT applications_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'selected'::text, 'accepted'::text, 'rejected'::text, 'expired'::text, 'withdrawn'::text])))
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    ts timestamp with time zone DEFAULT now() NOT NULL,
    actor text NOT NULL,
    action text NOT NULL,
    target_type text NOT NULL,
    target_id uuid,
    reason text,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: TABLE audit_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.audit_log IS 'Ops panel yazma günlüğü — sadece SECURITY DEFINER RPC''ler yazar';


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: billing_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_config (
    id integer DEFAULT 1 NOT NULL,
    price_rub integer DEFAULT 1000 NOT NULL,
    period_days integer DEFAULT 30 NOT NULL,
    retry_offsets_hours integer[] DEFAULT '{0,24,48}'::integer[] NOT NULL,
    grace_hours integer DEFAULT 24 NOT NULL,
    notify_before_hours integer DEFAULT 36 NOT NULL,
    min_notify_gap_hours integer DEFAULT 24 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    dry_run boolean DEFAULT true NOT NULL,
    max_daily_attempts integer DEFAULT 1 NOT NULL,
    digest_email text DEFAULT 'mustafaaladag.ma@gmail.com'::text NOT NULL,
    tochka_jwt_expires_at date DEFAULT '2027-07-08'::date NOT NULL,
    CONSTRAINT billing_config_id_check CHECK ((id = 1))
);


--
-- Name: billing_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_events (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    subscription_id uuid,
    user_id uuid,
    event text NOT NULL,
    detail jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocks (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    blocker_id uuid,
    blocked_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: call_otps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.call_otps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone text NOT NULL,
    code text NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:05:00'::interval) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    attempts integer DEFAULT 0 NOT NULL
);


--
-- Name: cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cities (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    country text NOT NULL,
    lat double precision,
    lng double precision,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    name_en text,
    name_ru text,
    name_tr text,
    utc_offset smallint
);


--
-- Name: city_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.city_keys (
    city_id uuid NOT NULL,
    key text NOT NULL,
    brand_market text NOT NULL,
    center_lat double precision NOT NULL,
    center_lng double precision NOT NULL
);


--
-- Name: city_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.city_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    city_text text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: client_errors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_errors (
    id bigint NOT NULL,
    user_id uuid,
    platform text DEFAULT 'unknown'::text NOT NULL,
    app_build text DEFAULT ''::text NOT NULL,
    screen text DEFAULT ''::text NOT NULL,
    error text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: client_errors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.client_errors ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.client_errors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cron_heartbeat; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cron_heartbeat (
    job text NOT NULL,
    last_run_at timestamp with time zone DEFAULT now() NOT NULL,
    last_status text,
    detail jsonb
);


--
-- Name: feature_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feature_flags (
    key text NOT NULL,
    value jsonb NOT NULL,
    description text,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: internal_secrets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.internal_secrets (
    key text NOT NULL,
    value text NOT NULL
);


--
-- Name: invitation_create_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitation_create_log (
    id bigint NOT NULL,
    owner_id uuid NOT NULL,
    category text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: invitation_create_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invitation_create_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invitation_create_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invitation_create_log_id_seq OWNED BY public.invitation_create_log.id;


--
-- Name: invitation_gift_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitation_gift_links (
    invitation_id uuid NOT NULL,
    url text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT invitation_gift_links_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitations (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    owner_id uuid,
    flow_type text NOT NULL,
    category text NOT NULL,
    title text NOT NULL,
    description text,
    venue_name text,
    venue_lat double precision,
    venue_lng double precision,
    event_date timestamp with time zone,
    city_id uuid,
    slots_total integer DEFAULT 1,
    status text DEFAULT 'active'::text,
    created_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval),
    selection_deadline timestamp with time zone,
    place_id uuid,
    place_kind text,
    venue_address text,
    owner_reminded_at timestamp with time zone,
    feed_rank smallint DEFAULT 0 NOT NULL,
    CONSTRAINT invitations_category_check CHECK ((category = ANY (ARRAY['food'::text, 'concert'::text, 'travel'::text, 'culture'::text, 'cinema'::text, 'theater'::text, 'coffee'::text, 'bar'::text, 'gift'::text, 'sport'::text, 'walk'::text, 'karaoke'::text]))),
    CONSTRAINT invitations_description_len_check CHECK (((description IS NULL) OR (char_length(description) <= 300))),
    CONSTRAINT invitations_flow_type_check CHECK ((flow_type = ANY (ARRAY['invite'::text, 'request'::text]))),
    CONSTRAINT invitations_place_kind_check CHECK ((place_kind = ANY (ARRAY['venue'::text, 'destination'::text, 'brand'::text]))),
    CONSTRAINT invitations_slots_total_check CHECK ((slots_total = ANY (ARRAY[1, 2]))),
    CONSTRAINT invitations_status_check CHECK ((status = ANY (ARRAY['active'::text, 'selecting'::text, 'closed'::text, 'cancelled'::text, 'matched'::text]))),
    CONSTRAINT invitations_title_len_check CHECK ((char_length(title) <= 60)),
    CONSTRAINT invitations_venue_name_len_check CHECK (((venue_name IS NULL) OR (char_length(venue_name) <= 80)))
);


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    invitation_id uuid,
    user1_id uuid,
    user2_id uuid,
    meeting_date timestamp with time zone,
    meeting_status text DEFAULT 'scheduled'::text,
    chat_archived boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    meeting_confirmed_user1 boolean,
    meeting_confirmed_user2 boolean,
    archived_at timestamp with time zone,
    no_show_reported_by uuid[] DEFAULT '{}'::uuid[],
    user1_hidden_at timestamp with time zone,
    user2_hidden_at timestamp with time zone,
    user1_cleared_at timestamp with time zone,
    user2_cleared_at timestamp with time zone,
    invitation_category text,
    blocked_by uuid,
    blocked_at timestamp with time zone,
    CONSTRAINT matches_meeting_status_check CHECK ((meeting_status = ANY (ARRAY['scheduled'::text, 'happened'::text, 'no_show'::text])))
);


--
-- Name: message_reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_reactions (
    message_id uuid NOT NULL,
    user_id uuid NOT NULL,
    match_id uuid NOT NULL,
    emoji text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT message_reactions_emoji_check CHECK ((emoji = ANY (ARRAY['❤️'::text, '😂'::text, '👍'::text, '😮'::text, '😢'::text, '🔥'::text])))
);

ALTER TABLE ONLY public.message_reactions REPLICA IDENTITY FULL;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    match_id uuid,
    sender_id uuid,
    content text NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT messages_content_len_check CHECK ((char_length(content) <= 2000))
);


--
-- Name: messages_archive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages_archive (
    id uuid,
    match_id uuid,
    sender_id uuid,
    content text,
    created_at timestamp with time zone,
    read_at timestamp with time zone,
    archived_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_by uuid,
    user1_id uuid,
    user2_id uuid,
    invitation_id uuid,
    invitation_category text
);


--
-- Name: notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_preferences (
    user_id uuid NOT NULL,
    push_new_application boolean DEFAULT true,
    push_selected boolean DEFAULT true,
    push_message boolean DEFAULT true,
    push_match boolean DEFAULT true,
    quiet_hours_enabled boolean DEFAULT false,
    quiet_hours_start time without time zone,
    quiet_hours_end time without time zone
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    type text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT notifications_type_check CHECK ((type = ANY (ARRAY['new_application'::text, 'selected'::text, 'not_selected'::text, 'new_message'::text, 'selfie_approved'::text, 'selfie_rejected'::text, 'meeting_reminder'::text, 'feedback_request'::text, 'selection_reminder'::text, 'premium_activated'::text, 'invitation_updated'::text, 'profile_incomplete'::text])))
);


--
-- Name: otp_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone text NOT NULL,
    code text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: otp_send_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_send_log (
    id bigint NOT NULL,
    phone text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    channel text,
    result text
);


--
-- Name: otp_send_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.otp_send_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: otp_send_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.otp_send_log_id_seq OWNED BY public.otp_send_log.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid,
    operation_id text NOT NULL,
    amount numeric(10,2) NOT NULL,
    currency text DEFAULT 'RUB'::text NOT NULL,
    source text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    purpose text,
    payment_link text,
    raw jsonb,
    created_at timestamp with time zone DEFAULT now(),
    paid_at timestamp with time zone,
    subscription_id uuid,
    charge_type text DEFAULT 'one_time'::text NOT NULL,
    order_id text DEFAULT ''::text NOT NULL,
    CONSTRAINT payments_charge_type_check CHECK ((charge_type = ANY (ARRAY['one_time'::text, 'subscription_initial'::text, 'subscription_renewal'::text]))),
    CONSTRAINT payments_source_check CHECK ((source = ANY (ARRAY['web'::text, 'android'::text, 'ios_app'::text, 'ios_sms'::text, 'test'::text]))),
    CONSTRAINT payments_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'refunded'::text, 'failed'::text, 'expired'::text])))
);


--
-- Name: places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.places (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    kind text NOT NULL,
    name text NOT NULL,
    name_ru text,
    name_en text,
    category text,
    lat double precision,
    lng double precision,
    street text,
    housenumber text,
    metro text,
    district text,
    brand text,
    website text,
    country_ru text,
    country_en text,
    city_key text,
    source text DEFAULT 'osm'::text NOT NULL,
    osm_ref text,
    usage_count integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT places_kind_check CHECK ((kind = ANY (ARRAY['venue'::text, 'destination'::text, 'brand'::text]))),
    CONSTRAINT places_source_check CHECK ((source = ANY (ARRAY['osm'::text, 'curated'::text, 'user'::text])))
);


--
-- Name: push_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_log (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    type text NOT NULL,
    ref text DEFAULT ''::text NOT NULL,
    sent_at timestamp with time zone DEFAULT now() NOT NULL,
    status text
);


--
-- Name: push_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.push_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.push_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    reporter_id uuid,
    reported_user_id uuid,
    reason text,
    description text,
    status text DEFAULT 'pending'::text,
    created_at timestamp with time zone DEFAULT now(),
    match_id uuid,
    invitation_id uuid,
    reported_name_snapshot text,
    match_id_snapshot uuid,
    CONSTRAINT reports_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'reviewed'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid,
    status text,
    provider text,
    started_at timestamp with time zone,
    expires_at timestamp with time zone,
    auto_renew boolean DEFAULT true,
    price_paid integer,
    currency text,
    created_at timestamp with time zone DEFAULT now(),
    yookassa_payment_method_id text,
    cancelled_at timestamp with time zone,
    tochka_subscription_id text,
    next_billing_at timestamp with time zone,
    renewal_notified_at timestamp with time zone,
    notified_channels text[],
    retry_count integer DEFAULT 0 NOT NULL,
    grace_until timestamp with time zone,
    card_masked_pan text,
    card_type text,
    CONSTRAINT subscriptions_currency_check CHECK ((currency = ANY (ARRAY['RUB'::text, 'USD'::text]))),
    CONSTRAINT subscriptions_provider_check CHECK ((provider = ANY (ARRAY['yookassa'::text, 'apple'::text, 'google'::text, 'stripe'::text, 'tochka'::text]))),
    CONSTRAINT subscriptions_status_check CHECK ((status = ANY (ARRAY['pending_binding'::text, 'active'::text, 'cancelled'::text, 'past_due'::text, 'expired'::text])))
);


--
-- Name: test_invitation_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_invitation_variants (
    id bigint NOT NULL,
    owner_id uuid NOT NULL,
    seq integer NOT NULL,
    category text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    venue_name text NOT NULL,
    ev_hour integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    season text DEFAULT 'all'::text NOT NULL,
    CONSTRAINT test_invitation_variants_category_check CHECK ((category = ANY (ARRAY['food'::text, 'concert'::text, 'travel'::text, 'culture'::text, 'cinema'::text, 'theater'::text, 'coffee'::text, 'bar'::text, 'gift'::text, 'sport'::text, 'walk'::text, 'karaoke'::text]))),
    CONSTRAINT test_invitation_variants_description_check CHECK (((char_length(description) >= 10) AND (char_length(description) <= 300))),
    CONSTRAINT test_invitation_variants_ev_hour_check CHECK (((ev_hour >= 0) AND (ev_hour <= 23))),
    CONSTRAINT test_invitation_variants_season_check CHECK ((season = ANY (ARRAY['all'::text, 'warm'::text, 'cold'::text]))),
    CONSTRAINT test_invitation_variants_seq_check CHECK ((seq >= 0)),
    CONSTRAINT test_invitation_variants_title_check CHECK (((char_length(title) >= 1) AND (char_length(title) <= 60))),
    CONSTRAINT test_invitation_variants_venue_name_check CHECK (((char_length(venue_name) >= 1) AND (char_length(venue_name) <= 80)))
);


--
-- Name: test_invitation_variants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.test_invitation_variants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: test_invitation_variants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.test_invitation_variants_id_seq OWNED BY public.test_invitation_variants.id;


--
-- Name: test_rotation_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_rotation_state (
    owner_id uuid NOT NULL,
    seq integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_devices (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid,
    device_id text,
    device_name text,
    last_active_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_photos (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid,
    url text NOT NULL,
    is_primary boolean DEFAULT false,
    is_selfie boolean DEFAULT false,
    moderation_status text DEFAULT 'approved'::text,
    ai_scan_result jsonb,
    order_index integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    face_focus_x real,
    face_focus_y real,
    CONSTRAINT user_photos_moderation_status_check CHECK ((moderation_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: COLUMN user_photos.face_focus_x; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_photos.face_focus_x IS 'Yüz merkezi x (0-1 fraksiyon); null=işlenmedi, -1=yüz yok';


--
-- Name: user_prompts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_prompts (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid,
    question_key text NOT NULL,
    answer text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT user_prompts_answer_len_check CHECK (((answer IS NULL) OR (char_length(answer) <= 150)))
);


--
-- Name: user_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_stats (
    user_id uuid NOT NULL,
    total_invitations integer DEFAULT 0,
    total_applications integer DEFAULT 0,
    total_matches integer DEFAULT 0,
    total_meetings integer DEFAULT 0,
    no_show_count integer DEFAULT 0,
    cancel_count integer DEFAULT 0
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    phone text,
    country_code text,
    language text DEFAULT 'tr'::text,
    name text,
    age integer,
    gender text,
    city_id uuid,
    bio text,
    job text,
    education text,
    interests jsonb DEFAULT '[]'::jsonb,
    verified boolean DEFAULT false,
    verified_at timestamp with time zone,
    subscription_status text DEFAULT 'free'::text,
    subscription_provider text,
    warning_count integer DEFAULT 0,
    banned boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    last_active_at timestamp with time zone DEFAULT now(),
    suspended_at timestamp with time zone,
    suspension_reason text,
    selfie_status text DEFAULT 'none'::text,
    selfie_rejected_reason text,
    no_show_count integer DEFAULT 0,
    is_admin boolean DEFAULT false,
    is_deleted boolean DEFAULT false NOT NULL,
    show_gender text DEFAULT 'opposite'::text NOT NULL,
    min_age integer DEFAULT 21,
    max_age integer DEFAULT 45,
    fcm_token text,
    is_test_user boolean DEFAULT false,
    free_application_used boolean DEFAULT false NOT NULL,
    consent_given_at timestamp with time zone,
    consent_version text,
    premium_until timestamp with time zone,
    last_platform text,
    premium_sms_sent_at timestamp with time zone,
    billing_email text,
    locale text,
    last_seen_at timestamp with time zone,
    free_applications_used integer DEFAULT 0 NOT NULL,
    rustore_token text,
    app_build integer,
    CONSTRAINT users_age_check CHECK (((age >= 21) AND (age <= 60))),
    CONSTRAINT users_bio_check CHECK ((char_length(bio) <= 200)),
    CONSTRAINT users_education_len_check CHECK (((education IS NULL) OR (char_length(education) <= 60))),
    CONSTRAINT users_free_applications_used_check CHECK ((free_applications_used >= 0)),
    CONSTRAINT users_gender_check CHECK ((gender = ANY (ARRAY['female'::text, 'male'::text]))),
    CONSTRAINT users_job_len_check CHECK (((job IS NULL) OR (char_length(job) <= 60))),
    CONSTRAINT users_last_platform_check CHECK ((last_platform = ANY (ARRAY['ios'::text, 'android'::text]))),
    CONSTRAINT users_name_len_check CHECK (((name IS NULL) OR (char_length(name) <= 30))),
    CONSTRAINT users_selfie_status_check CHECK ((selfie_status = ANY (ARRAY['none'::text, 'pending'::text, 'approved'::text, 'rejected'::text]))),
    CONSTRAINT users_show_gender_check CHECK ((show_gender = ANY (ARRAY['opposite'::text, 'all'::text, 'male'::text, 'female'::text]))),
    CONSTRAINT users_subscription_status_check CHECK ((subscription_status = ANY (ARRAY['free'::text, 'active'::text])))
);


--
-- Name: v_active_invitations; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_active_invitations AS
 SELECT i.id,
    i.title,
    i.description,
    i.category,
    i.flow_type,
    i.venue_name,
    i.event_date,
    i.created_at,
    i.expires_at,
    u.id AS owner_id,
    u.name AS owner_name,
    u.age AS owner_age,
    u.is_test_user,
    ( SELECT p.url
           FROM public.user_photos p
          WHERE ((p.user_id = u.id) AND (p.is_selfie = false))
          ORDER BY p.is_primary DESC, p.order_index
         LIMIT 1) AS owner_photo_url,
    ( SELECT (count(*))::integer AS count
           FROM public.applications a
          WHERE ((a.invitation_id = i.id) AND (a.status = 'pending'::text))) AS pending_applications
   FROM (public.invitations i
     JOIN public.users u ON ((u.id = i.owner_id)))
  WHERE ((i.status = 'active'::text) AND (i.expires_at > now()))
  ORDER BY i.created_at DESC;


--
-- Name: v_billing_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_billing_stats AS
 SELECT ( SELECT (count(*))::integer AS count
           FROM public.payments
          WHERE ((payments.status = 'paid'::text) AND (payments.purpose !~~ 'Тест%'::text))) AS paid_total,
    ( SELECT (COALESCE(sum(payments.amount), (0)::numeric))::integer AS "coalesce"
           FROM public.payments
          WHERE ((payments.status = 'paid'::text) AND (payments.purpose !~~ 'Тест%'::text))) AS paid_sum,
    ( SELECT (count(*))::integer AS count
           FROM public.payments
          WHERE ((payments.status = 'paid'::text) AND (payments.purpose !~~ 'Тест%'::text) AND (payments.paid_at > (now() - '7 days'::interval)))) AS paid7,
    ( SELECT (COALESCE(sum(payments.amount), (0)::numeric))::integer AS "coalesce"
           FROM public.payments
          WHERE ((payments.status = 'paid'::text) AND (payments.purpose !~~ 'Тест%'::text) AND (payments.paid_at > (now() - '7 days'::interval)))) AS paid7_sum,
    ( SELECT (count(*))::integer AS count
           FROM public.payments
          WHERE ((payments.status = 'pending'::text) AND (payments.purpose !~~ 'Тест%'::text))) AS pending,
    ( SELECT (count(*))::integer AS count
           FROM public.payments
          WHERE ((payments.status = 'refunded'::text) AND (payments.purpose !~~ 'Тест%'::text))) AS refunded,
    ( SELECT (count(*))::integer AS count
           FROM public.subscriptions
          WHERE (subscriptions.status = 'active'::text)) AS subs_active,
    ( SELECT (count(*))::integer AS count
           FROM public.subscriptions
          WHERE (subscriptions.status = 'past_due'::text)) AS subs_past_due,
    ( SELECT (count(*))::integer AS count
           FROM public.subscriptions
          WHERE (subscriptions.status = 'cancelled'::text)) AS subs_cancelled,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE (((users.subscription_status = 'active'::text) OR (users.premium_until > now())) AND (NOT users.is_deleted) AND (NOT users.is_test_user))) AS premium_users;


--
-- Name: v_feature_flags; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_feature_flags AS
 SELECT feature_flags.key,
    (feature_flags.value)::text AS value
   FROM public.feature_flags
  ORDER BY feature_flags.key;


--
-- Name: v_funnel; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_funnel AS
 SELECT ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE ((NOT users.is_test_user) AND (NOT users.is_deleted))) AS registered,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE ((NOT users.is_test_user) AND (NOT users.is_deleted) AND (users.selfie_status = 'approved'::text))) AS selfie_approved,
    ( SELECT (count(DISTINCT a.applicant_id))::integer AS count
           FROM (public.applications a
             JOIN public.users u ON ((u.id = a.applicant_id)))
          WHERE (NOT u.is_test_user)) AS applied,
    ( SELECT (count(DISTINCT x.uid))::integer AS count
           FROM (( SELECT matches.user1_id AS uid
                   FROM public.matches
                UNION
                 SELECT matches.user2_id
                   FROM public.matches) x
             JOIN public.users u ON ((u.id = x.uid)))
          WHERE (NOT u.is_test_user)) AS matched;


--
-- Name: v_live_cities; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_live_cities AS
 SELECT c.name_ru AS city,
    c.country,
    c.lat,
    c.lng,
    count(*) FILTER (WHERE (u.last_seen_at > (now() - '00:05:00'::interval))) AS online,
    count(*) FILTER (WHERE (u.last_seen_at > (now() - '01:00:00'::interval))) AS active1h,
    count(*) FILTER (WHERE (NOT u.is_test_user)) AS users_real,
    count(*) AS users_total,
    c.name_tr,
    c.name_en
   FROM (public.cities c
     LEFT JOIN public.users u ON (((u.city_id = c.id) AND (NOT u.is_deleted))))
  WHERE c.is_active
  GROUP BY c.name_ru, c.name_tr, c.name_en, c.country, c.lat, c.lng;


--
-- Name: v_live_events; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_live_events AS
 WITH ev AS (
         SELECT 'user'::text AS kind,
            u.created_at AS at,
            u.name AS who,
            c.name_ru AS city,
            NULL::text AS what
           FROM (public.users u
             LEFT JOIN public.cities c ON ((c.id = u.city_id)))
          WHERE ((NOT u.is_deleted) AND (u.created_at > (now() - '24:00:00'::interval)))
        UNION ALL
         SELECT 'invitation'::text,
            i.created_at,
            u.name,
            c.name_ru,
            i.title
           FROM ((public.invitations i
             JOIN public.users u ON ((u.id = i.owner_id)))
             LEFT JOIN public.cities c ON ((c.id = u.city_id)))
          WHERE (i.created_at > (now() - '24:00:00'::interval))
        UNION ALL
         SELECT 'application'::text,
            a.created_at,
            u.name,
            c.name_ru,
            i.title
           FROM (((public.applications a
             JOIN public.users u ON ((u.id = a.applicant_id)))
             JOIN public.invitations i ON ((i.id = a.invitation_id)))
             LEFT JOIN public.cities c ON ((c.id = u.city_id)))
          WHERE (a.created_at > (now() - '24:00:00'::interval))
        UNION ALL
         SELECT 'match'::text,
            m.created_at,
            u.name,
            c.name_ru,
            NULL::text
           FROM ((public.matches m
             JOIN public.users u ON ((u.id = m.user1_id)))
             LEFT JOIN public.cities c ON ((c.id = u.city_id)))
          WHERE (m.created_at > (now() - '24:00:00'::interval))
        )
 SELECT ev.kind,
    ev.at,
    ev.who,
    ev.city,
    ev.what
   FROM ev
  ORDER BY ev.at DESC
 LIMIT 40;


--
-- Name: v_live_online_users; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_live_online_users AS
 SELECT u.id,
    u.name,
    u.age,
    c.name_ru AS city,
    c.lat,
    c.lng,
    u.last_seen_at,
    ( SELECT p.url
           FROM public.user_photos p
          WHERE ((p.user_id = u.id) AND p.is_primary AND (NOT p.is_selfie))
          ORDER BY p.order_index
         LIMIT 1) AS photo
   FROM (public.users u
     LEFT JOIN public.cities c ON ((c.id = u.city_id)))
  WHERE ((NOT u.is_deleted) AND (u.last_seen_at > (now() - '00:05:00'::interval)))
  ORDER BY u.last_seen_at DESC
 LIMIT 60;


--
-- Name: v_live_pulse; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_live_pulse AS
 SELECT ( SELECT count(*) AS count
           FROM public.users
          WHERE ((users.last_seen_at > (now() - '00:05:00'::interval)) AND (NOT users.is_deleted))) AS online,
    ( SELECT count(*) AS count
           FROM public.users
          WHERE ((users.last_seen_at > (now() - '01:00:00'::interval)) AND (NOT users.is_deleted))) AS active1h,
    ( SELECT count(*) AS count
           FROM public.users
          WHERE (NOT users.is_deleted)) AS users_total,
    ( SELECT count(*) AS count
           FROM public.users
          WHERE (users.created_at > (now() - '24:00:00'::interval))) AS users_24h,
    ( SELECT count(*) AS count
           FROM public.invitations
          WHERE (invitations.created_at > (now() - '24:00:00'::interval))) AS inv_24h,
    ( SELECT count(*) AS count
           FROM public.applications
          WHERE (applications.created_at > (now() - '24:00:00'::interval))) AS app_24h,
    ( SELECT count(*) AS count
           FROM public.matches
          WHERE (matches.created_at > (now() - '24:00:00'::interval))) AS match_24h,
    ( SELECT count(*) AS count
           FROM public.messages
          WHERE (messages.created_at > (now() - '24:00:00'::interval))) AS msg_24h,
    ( SELECT count(*) AS count
           FROM public.invitations
          WHERE (invitations.status = 'active'::text)) AS inv_active;


--
-- Name: v_open_reports; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_open_reports AS
 SELECT r.id,
    r.created_at,
    r.reason,
    r.description,
    r.status,
    r.reporter_id,
    ru.name AS reporter_name,
    r.reported_user_id,
    COALESCE(tu.name, r.reported_name_snapshot) AS reported_name,
    tu.banned AS reported_banned,
    tu.warning_count AS reported_warning_count,
    tu.is_test_user AS reported_is_test_user,
    ai.id AS reported_active_invitation_id,
    ai.title AS reported_active_invitation_title,
    ( SELECT p.url
           FROM public.user_photos p
          WHERE ((p.user_id = tu.id) AND p.is_primary)
         LIMIT 1) AS reported_photo_url,
    ( SELECT p.id
           FROM public.user_photos p
          WHERE ((p.user_id = tu.id) AND p.is_primary)
         LIMIT 1) AS reported_primary_photo_id,
    r.match_id,
    r.invitation_id,
    ( SELECT count(*) AS count
           FROM public.messages m
          WHERE (m.match_id = r.match_id)) AS evidence_messages,
    ( SELECT count(*) AS count
           FROM public.messages_archive a
          WHERE (a.match_id = r.match_id)) AS evidence_archived
   FROM (((public.reports r
     LEFT JOIN public.users ru ON ((ru.id = r.reporter_id)))
     LEFT JOIN public.users tu ON ((tu.id = r.reported_user_id)))
     LEFT JOIN LATERAL ( SELECT i.id,
            i.title
           FROM public.invitations i
          WHERE ((i.owner_id = tu.id) AND (i.status = 'active'::text))
          ORDER BY i.created_at DESC
         LIMIT 1) ai ON (true))
  WHERE (r.status <> ALL (ARRAY['resolved'::text, 'dismissed'::text]))
  ORDER BY r.created_at;


--
-- Name: v_otp_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_otp_stats AS
 SELECT ( SELECT (count(*))::integer AS count
           FROM public.call_otps
          WHERE (call_otps.expires_at > now())) AS pending_otps,
    ( SELECT COALESCE((round((EXTRACT(epoch FROM (now() - min(call_otps.created_at))) / (60)::numeric)))::integer, 0) AS "coalesce"
           FROM public.call_otps
          WHERE (call_otps.expires_at > now())) AS oldest_pending_min,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE (users.created_at > (now() - '24:00:00'::interval))) AS users_new24,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE ((users.created_at)::date = CURRENT_DATE)) AS users_today,
    ( SELECT COALESCE(json_agg(t.* ORDER BY t.d), '[]'::json) AS "coalesce"
           FROM ( SELECT (users.created_at)::date AS d,
                    (count(*))::integer AS n
                   FROM public.users
                  WHERE (users.created_at > (now() - '7 days'::interval))
                  GROUP BY ((users.created_at)::date)) t) AS reg_trend;


--
-- Name: v_pending_gift_links; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_pending_gift_links AS
 SELECT l.invitation_id,
    l.url,
    l.created_at,
    i.title,
    u.name AS owner_name
   FROM ((public.invitation_gift_links l
     JOIN public.invitations i ON ((i.id = l.invitation_id)))
     JOIN public.users u ON ((u.id = i.owner_id)))
  WHERE (l.status = 'pending'::text)
  ORDER BY l.created_at;


--
-- Name: v_pending_selfies; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_pending_selfies AS
 SELECT u.id AS user_id,
    u.name,
    u.age,
    ( SELECT c.name
           FROM public.cities c
          WHERE (c.id = u.city_id)) AS city,
    u.created_at AS registered_at,
    u.is_test_user,
    ( SELECT o.name
           FROM storage.objects o
          WHERE ((o.bucket_id = 'selfies'::text) AND (o.name ~~ ((u.id)::text || '/%'::text)))
          ORDER BY o.created_at DESC
         LIMIT 1) AS selfie_object,
    ( SELECT p.url
           FROM public.user_photos p
          WHERE ((p.user_id = u.id) AND p.is_primary)
          ORDER BY p.created_at DESC
         LIMIT 1) AS primary_photo_url
   FROM public.users u
  WHERE ((u.selfie_status = 'pending'::text) AND (u.is_deleted = false))
  ORDER BY u.created_at;


--
-- Name: v_product_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_product_stats AS
 SELECT ( SELECT (count(*))::integer AS count
           FROM public.invitations
          WHERE (invitations.created_at > (now() - '7 days'::interval))) AS inv7,
    ( SELECT (count(*))::integer AS count
           FROM public.applications
          WHERE (applications.created_at > (now() - '7 days'::interval))) AS app7,
    ( SELECT (count(*))::integer AS count
           FROM public.matches
          WHERE (matches.created_at > (now() - '7 days'::interval))) AS match7,
    ( SELECT (count(*))::integer AS count
           FROM public.invitations
          WHERE (invitations.status = 'active'::text)) AS inv_active,
    ( SELECT COALESCE(json_agg(t.* ORDER BY t.n DESC), '[]'::json) AS "coalesce"
           FROM ( SELECT invitations.category,
                    (count(*))::integer AS n
                   FROM public.invitations
                  WHERE (invitations.status = 'active'::text)
                  GROUP BY invitations.category
                  ORDER BY ((count(*))::integer) DESC
                 LIMIT 8) t) AS categories,
    ( SELECT COALESCE(json_agg(t.* ORDER BY t.d), '[]'::json) AS "coalesce"
           FROM ( SELECT (invitations.created_at)::date AS d,
                    (count(*))::integer AS n
                   FROM public.invitations
                  WHERE (invitations.created_at > (now() - '7 days'::interval))
                  GROUP BY ((invitations.created_at)::date)) t) AS inv_trend;


--
-- Name: v_push_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_push_stats AS
 SELECT ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE ((users.fcm_token IS NOT NULL) AND (NOT users.is_deleted))) AS fcm_have,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE (NOT users.is_deleted)) AS users_total,
    ( SELECT (count(*))::integer AS count
           FROM public.notifications
          WHERE (notifications.created_at > (now() - '24:00:00'::interval))) AS notif24,
    ( SELECT (count(*))::integer AS count
           FROM public.notifications
          WHERE (notifications.created_at > (now() - '7 days'::interval))) AS notif7,
    ( SELECT (count(*))::integer AS count
           FROM public.notifications
          WHERE (notifications.read_at IS NULL)) AS unread,
    ( SELECT COALESCE(json_agg(t.* ORDER BY t.d), '[]'::json) AS "coalesce"
           FROM ( SELECT (notifications.created_at)::date AS d,
                    (count(*))::integer AS n
                   FROM public.notifications
                  WHERE (notifications.created_at > (now() - '7 days'::interval))
                  GROUP BY ((notifications.created_at)::date)) t) AS trend,
    ( SELECT COALESCE(json_agg(t.* ORDER BY t.n DESC), '[]'::json) AS "coalesce"
           FROM ( SELECT notifications.type,
                    (count(*))::integer AS n
                   FROM public.notifications
                  WHERE (notifications.created_at > (now() - '7 days'::interval))
                  GROUP BY notifications.type
                  ORDER BY ((count(*))::integer) DESC
                 LIMIT 6) t) AS by_type;


--
-- Name: v_recent_payments; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_recent_payments AS
 SELECT p.created_at,
    p.paid_at,
    (p.amount)::integer AS amount,
    p.currency,
    p.status,
    p.source,
    p.purpose,
    p.charge_type,
    u.name AS user_name
   FROM (public.payments p
     LEFT JOIN public.users u ON ((u.id = p.user_id)))
  ORDER BY p.created_at DESC
 LIMIT 12;


--
-- Name: v_user_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_user_stats AS
 SELECT ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE (NOT users.is_deleted)) AS total,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE (users.created_at > (now() - '24:00:00'::interval))) AS new24,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE users.banned) AS banned,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE (users.is_test_user AND (NOT users.is_deleted))) AS test_users,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE (((users.subscription_status = 'active'::text) OR (users.premium_until > now())) AND (NOT users.is_deleted) AND (NOT users.is_test_user))) AS premium,
    ( SELECT (count(*))::integer AS count
           FROM public.users
          WHERE (users.verified AND (NOT users.is_deleted))) AS verified;


--
-- Name: v_users_all; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_users_all AS
 SELECT users.id,
    users.name,
    users.age,
    (users.city_id)::text AS city_id,
    users.created_at,
    users.verified,
    users.banned,
    users.warning_count,
    users.is_test_user,
    ((users.subscription_status = 'active'::text) OR (users.premium_until > now())) AS premium,
    users.last_seen_at
   FROM public.users
  WHERE (NOT users.is_deleted)
  ORDER BY users.created_at DESC;


--
-- Name: v_users_recent; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_users_recent AS
 SELECT users.id,
    users.name,
    users.age,
    (users.city_id)::text AS city_id,
    users.created_at,
    users.verified,
    users.banned,
    users.warning_count,
    users.is_test_user,
    ((users.subscription_status = 'active'::text) OR (users.premium_until > now())) AS premium
   FROM public.users
  WHERE (NOT users.is_deleted)
  ORDER BY users.created_at DESC
 LIMIT 15;


--
-- Name: invitation_create_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitation_create_log ALTER COLUMN id SET DEFAULT nextval('public.invitation_create_log_id_seq'::regclass);


--
-- Name: otp_send_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_send_log ALTER COLUMN id SET DEFAULT nextval('public.otp_send_log_id_seq'::regclass);


--
-- Name: test_invitation_variants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_invitation_variants ALTER COLUMN id SET DEFAULT nextval('public.test_invitation_variants_id_seq'::regclass);


--
-- Name: applications applications_invitation_id_applicant_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_invitation_id_applicant_id_key UNIQUE (invitation_id, applicant_id);


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: billing_config billing_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_config
    ADD CONSTRAINT billing_config_pkey PRIMARY KEY (id);


--
-- Name: billing_events billing_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_events
    ADD CONSTRAINT billing_events_pkey PRIMARY KEY (id);


--
-- Name: blocks blocks_blocker_id_blocked_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_blocker_id_blocked_id_key UNIQUE (blocker_id, blocked_id);


--
-- Name: blocks blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (id);


--
-- Name: call_otps call_otps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call_otps
    ADD CONSTRAINT call_otps_pkey PRIMARY KEY (id);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: city_keys city_keys_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.city_keys
    ADD CONSTRAINT city_keys_key_key UNIQUE (key);


--
-- Name: city_keys city_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.city_keys
    ADD CONSTRAINT city_keys_pkey PRIMARY KEY (city_id);


--
-- Name: city_requests city_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.city_requests
    ADD CONSTRAINT city_requests_pkey PRIMARY KEY (id);


--
-- Name: client_errors client_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_errors
    ADD CONSTRAINT client_errors_pkey PRIMARY KEY (id);


--
-- Name: cron_heartbeat cron_heartbeat_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cron_heartbeat
    ADD CONSTRAINT cron_heartbeat_pkey PRIMARY KEY (job);


--
-- Name: feature_flags feature_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_flags
    ADD CONSTRAINT feature_flags_pkey PRIMARY KEY (key);


--
-- Name: internal_secrets internal_secrets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internal_secrets
    ADD CONSTRAINT internal_secrets_pkey PRIMARY KEY (key);


--
-- Name: invitation_create_log invitation_create_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitation_create_log
    ADD CONSTRAINT invitation_create_log_pkey PRIMARY KEY (id);


--
-- Name: invitation_gift_links invitation_gift_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitation_gift_links
    ADD CONSTRAINT invitation_gift_links_pkey PRIMARY KEY (invitation_id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: matches matches_invitation_applicant_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_invitation_applicant_unique UNIQUE (invitation_id, user2_id);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: message_reactions message_reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_pkey PRIMARY KEY (message_id, user_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: otp_codes otp_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_codes
    ADD CONSTRAINT otp_codes_pkey PRIMARY KEY (id);


--
-- Name: otp_send_log otp_send_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_send_log
    ADD CONSTRAINT otp_send_log_pkey PRIMARY KEY (id);


--
-- Name: payments payments_operation_order_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_operation_order_key UNIQUE (operation_id, order_id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: places places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_pkey PRIMARY KEY (id);


--
-- Name: push_log push_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_log
    ADD CONSTRAINT push_log_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: test_invitation_variants test_invitation_variants_owner_id_seq_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_invitation_variants
    ADD CONSTRAINT test_invitation_variants_owner_id_seq_key UNIQUE (owner_id, seq);


--
-- Name: test_invitation_variants test_invitation_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_invitation_variants
    ADD CONSTRAINT test_invitation_variants_pkey PRIMARY KEY (id);


--
-- Name: test_rotation_state test_rotation_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_rotation_state
    ADD CONSTRAINT test_rotation_state_pkey PRIMARY KEY (owner_id);


--
-- Name: user_devices user_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_pkey PRIMARY KEY (id);


--
-- Name: user_photos user_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_photos
    ADD CONSTRAINT user_photos_pkey PRIMARY KEY (id);


--
-- Name: user_prompts user_prompts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_prompts
    ADD CONSTRAINT user_prompts_pkey PRIMARY KEY (id);


--
-- Name: user_prompts user_prompts_user_id_question_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_prompts
    ADD CONSTRAINT user_prompts_user_id_question_key_key UNIQUE (user_id, question_key);


--
-- Name: user_stats user_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_pkey PRIMARY KEY (user_id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_applications_applicant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_applications_applicant ON public.applications USING btree (applicant_id);


--
-- Name: idx_applications_invitation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_applications_invitation ON public.applications USING btree (invitation_id);


--
-- Name: idx_billing_events_sub; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_billing_events_sub ON public.billing_events USING btree (subscription_id, created_at);


--
-- Name: idx_billing_events_sub_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_billing_events_sub_event ON public.billing_events USING btree (subscription_id, event, created_at DESC);


--
-- Name: idx_billing_events_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_billing_events_user ON public.billing_events USING btree (user_id, created_at);


--
-- Name: idx_blocks_blocked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_blocked ON public.blocks USING btree (blocked_id);


--
-- Name: idx_blocks_blocker; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blocks_blocker ON public.blocks USING btree (blocker_id);


--
-- Name: idx_call_otps_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_call_otps_phone ON public.call_otps USING btree (phone);


--
-- Name: idx_city_requests_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_city_requests_user ON public.city_requests USING btree (user_id);


--
-- Name: idx_client_errors_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_errors_created ON public.client_errors USING btree (created_at DESC);


--
-- Name: idx_client_errors_error; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_errors_error ON public.client_errors USING btree ("left"(error, 80), created_at DESC);


--
-- Name: idx_invitations_city_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invitations_city_status ON public.invitations USING btree (city_id, status);


--
-- Name: idx_invitations_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invitations_expires ON public.invitations USING btree (expires_at);


--
-- Name: idx_invitations_feed_rank_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invitations_feed_rank_created ON public.invitations USING btree (status, feed_rank, created_at DESC);


--
-- Name: idx_invitations_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invitations_owner ON public.invitations USING btree (owner_id);


--
-- Name: idx_invitations_place; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invitations_place ON public.invitations USING btree (place_id);


--
-- Name: idx_matches_user1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_user1 ON public.matches USING btree (user1_id);


--
-- Name: idx_matches_user2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_user2 ON public.matches USING btree (user2_id);


--
-- Name: idx_message_reactions_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reactions_match ON public.message_reactions USING btree (match_id);


--
-- Name: idx_message_reactions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reactions_user ON public.message_reactions USING btree (user_id);


--
-- Name: idx_messages_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_match ON public.messages USING btree (match_id, created_at);


--
-- Name: idx_messages_match_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_match_created ON public.messages USING btree (match_id, created_at DESC);


--
-- Name: idx_messages_sender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_sender ON public.messages USING btree (sender_id);


--
-- Name: idx_notifications_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC);


--
-- Name: idx_notifications_user_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id) WHERE (read_at IS NULL);


--
-- Name: idx_payments_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_status ON public.payments USING btree (status);


--
-- Name: idx_payments_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_subscription ON public.payments USING btree (subscription_id);


--
-- Name: idx_payments_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_user ON public.payments USING btree (user_id);


--
-- Name: idx_push_log_dedupe; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_log_dedupe ON public.push_log USING btree (user_id, type, ref, sent_at DESC);


--
-- Name: idx_reports_invitation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_invitation ON public.reports USING btree (invitation_id);


--
-- Name: idx_reports_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_match ON public.reports USING btree (match_id);


--
-- Name: idx_reports_reported_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_reported_user ON public.reports USING btree (reported_user_id);


--
-- Name: idx_reports_reporter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_reporter ON public.reports USING btree (reporter_id);


--
-- Name: idx_subscriptions_billing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subscriptions_billing ON public.subscriptions USING btree (next_billing_at) WHERE ((status = ANY (ARRAY['active'::text, 'past_due'::text])) AND auto_renew);


--
-- Name: idx_subscriptions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subscriptions_user ON public.subscriptions USING btree (user_id);


--
-- Name: idx_user_devices_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_devices_user ON public.user_devices USING btree (user_id);


--
-- Name: idx_user_photos_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_photos_user ON public.user_photos USING btree (user_id);


--
-- Name: idx_users_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_city ON public.users USING btree (city_id);


--
-- Name: idx_users_is_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_is_deleted ON public.users USING btree (is_deleted) WHERE (is_deleted = true);


--
-- Name: idx_users_last_seen_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_last_seen_at ON public.users USING btree (last_seen_at DESC NULLS LAST);


--
-- Name: invitation_create_log_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX invitation_create_log_owner_idx ON public.invitation_create_log USING btree (owner_id, created_at);


--
-- Name: messages_archive_match_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_archive_match_idx ON public.messages_archive USING btree (match_id);


--
-- Name: messages_archive_users_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_archive_users_idx ON public.messages_archive USING btree (user1_id, user2_id);


--
-- Name: otp_codes_phone_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX otp_codes_phone_idx ON public.otp_codes USING btree (phone);


--
-- Name: otp_send_log_phone_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX otp_send_log_phone_idx ON public.otp_send_log USING btree (phone, created_at);


--
-- Name: places_city_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_city_kind ON public.places USING btree (city_key, kind);


--
-- Name: places_name_en_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_name_en_trgm ON public.places USING gin (lower(COALESCE(name_en, ''::text)) public.gin_trgm_ops);


--
-- Name: places_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX places_name_trgm ON public.places USING gin (lower(name) public.gin_trgm_ops);


--
-- Name: places_osm_ref_uq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX places_osm_ref_uq ON public.places USING btree (osm_ref, city_key) WHERE ((osm_ref IS NOT NULL) AND (osm_ref <> ''::text));


--
-- Name: subscriptions_tochka_sub_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX subscriptions_tochka_sub_id_key ON public.subscriptions USING btree (tochka_subscription_id) WHERE (tochka_subscription_id IS NOT NULL);


--
-- Name: matches trg_archive_messages_before_match_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_archive_messages_before_match_delete BEFORE DELETE ON public.matches FOR EACH ROW EXECUTE FUNCTION public.archive_messages_before_match_delete();


--
-- Name: applications trg_block_withdraw_after_decision; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_block_withdraw_after_decision BEFORE UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.block_withdraw_after_decision();


--
-- Name: invitations trg_check_active_invitation_limit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_active_invitation_limit BEFORE INSERT OR UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.check_active_invitation_limit();


--
-- Name: invitations trg_clamp_expires_before_event; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_clamp_expires_before_event BEFORE INSERT OR UPDATE OF expires_at, event_date ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.clamp_expires_before_event();


--
-- Name: applications trg_enforce_application_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_application_rules BEFORE INSERT OR UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.enforce_application_rules();


--
-- Name: invitation_gift_links trg_enforce_gift_link; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_gift_link BEFORE INSERT OR UPDATE ON public.invitation_gift_links FOR EACH ROW EXECUTE FUNCTION public.enforce_gift_link();


--
-- Name: invitations trg_enforce_invitation_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_invitation_rules BEFORE INSERT OR UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.enforce_invitation_rules();


--
-- Name: messages trg_enforce_message_allowed; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_message_allowed BEFORE INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.enforce_message_allowed();


--
-- Name: call_otps trg_enforce_otp_daily_cap; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_otp_daily_cap BEFORE INSERT ON public.call_otps FOR EACH ROW EXECUTE FUNCTION public.enforce_otp_daily_cap();


--
-- Name: users trg_enforce_profile_text_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_profile_text_rules BEFORE INSERT OR UPDATE OF name, bio, job, education, gender ON public.users FOR EACH ROW EXECUTE FUNCTION public.enforce_profile_text_rules();


--
-- Name: user_prompts trg_enforce_prompt_text_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_prompt_text_rules BEFORE INSERT OR UPDATE ON public.user_prompts FOR EACH ROW EXECUTE FUNCTION public.enforce_prompt_text_rules();


--
-- Name: invitations trg_log_invitation_create; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_log_invitation_create AFTER INSERT ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.log_invitation_create();


--
-- Name: applications trg_mark_free_application; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mark_free_application AFTER INSERT ON public.applications FOR EACH ROW EXECUTE FUNCTION public.mark_free_application_used();


--
-- Name: matches trg_matches_snapshot_category; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_matches_snapshot_category BEFORE INSERT ON public.matches FOR EACH ROW EXECUTE FUNCTION public.matches_snapshot_category();


--
-- Name: applications trg_not_suspended_applications; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_not_suspended_applications BEFORE INSERT ON public.applications FOR EACH ROW EXECUTE FUNCTION public.enforce_not_suspended();


--
-- Name: invitations trg_not_suspended_invitations; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_not_suspended_invitations BEFORE INSERT ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.enforce_not_suspended();


--
-- Name: messages trg_not_suspended_messages; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_not_suspended_messages BEFORE INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.enforce_not_suspended();


--
-- Name: applications trg_notify_application_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_application_status AFTER UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.notify_application_status();


--
-- Name: invitations trg_notify_invitation_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_invitation_updated AFTER UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.notify_invitation_updated();


--
-- Name: applications trg_notify_new_application; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_new_application AFTER INSERT OR UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.notify_new_application();


--
-- Name: matches trg_notify_new_match; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_new_match AFTER INSERT ON public.matches FOR EACH ROW EXECUTE FUNCTION public.notify_new_match();


--
-- Name: messages trg_notify_new_message; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_new_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.notify_new_message();


--
-- Name: users trg_notify_selfie_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_selfie_status AFTER UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.notify_selfie_status();


--
-- Name: users trg_notify_suspension; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_suspension AFTER UPDATE OF suspended_at ON public.users FOR EACH ROW EXECUTE FUNCTION public.notify_suspension();


--
-- Name: blocks trg_on_block_inserted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_on_block_inserted AFTER INSERT ON public.blocks FOR EACH ROW EXECUTE FUNCTION public.on_block_inserted();


--
-- Name: invitations trg_prevent_invitations_tamper; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_invitations_tamper BEFORE UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.prevent_invitations_tamper();


--
-- Name: matches trg_prevent_matches_tamper; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_matches_tamper BEFORE UPDATE ON public.matches FOR EACH ROW EXECUTE FUNCTION public.prevent_matches_tamper();


--
-- Name: messages trg_prevent_messages_tamper; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_messages_tamper BEFORE UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.prevent_messages_tamper();


--
-- Name: user_photos trg_prevent_photos_tamper; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_photos_tamper BEFORE UPDATE ON public.user_photos FOR EACH ROW EXECUTE FUNCTION public.prevent_photos_tamper();


--
-- Name: users trg_prevent_users_insert_escalation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_users_insert_escalation BEFORE INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.prevent_users_insert_escalation();


--
-- Name: users trg_prevent_users_privilege_escalation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_users_privilege_escalation BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.prevent_users_privilege_escalation();


--
-- Name: reports trg_reports_snapshot; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_reports_snapshot BEFORE INSERT ON public.reports FOR EACH ROW EXECUTE FUNCTION public.reports_snapshot();


--
-- Name: reports trg_reports_snapshot_match_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_reports_snapshot_match_id BEFORE INSERT OR UPDATE OF match_id ON public.reports FOR EACH ROW EXECUTE FUNCTION public.reports_snapshot_match_id();


--
-- Name: applications trg_reset_created_at_on_reapply; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_reset_created_at_on_reapply BEFORE UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.reset_created_at_on_reapply();


--
-- Name: user_photos trg_selfie_pending; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_selfie_pending AFTER INSERT ON public.user_photos FOR EACH ROW EXECUTE FUNCTION public.mark_selfie_pending();


--
-- Name: invitations trg_set_invitation_feed_rank; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_invitation_feed_rank BEFORE INSERT OR UPDATE OF owner_id, feed_rank ON public.invitations FOR EACH ROW EXECUTE FUNCTION public.set_invitation_feed_rank();


--
-- Name: users trg_sync_feed_rank_on_user_flag; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_feed_rank_on_user_flag AFTER UPDATE OF is_test_user ON public.users FOR EACH ROW EXECUTE FUNCTION public.sync_feed_rank_on_user_flag();


--
-- Name: reports trg_tg_new_report; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tg_new_report AFTER INSERT ON public.reports FOR EACH ROW EXECUTE FUNCTION ops.trg_tg_new_report();


--
-- Name: user_photos trg_tg_new_selfie; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tg_new_selfie AFTER INSERT ON public.user_photos FOR EACH ROW EXECUTE FUNCTION ops.trg_tg_new_selfie();


--
-- Name: payments trg_tg_payment_paid; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tg_payment_paid AFTER INSERT OR UPDATE OF status ON public.payments FOR EACH ROW EXECUTE FUNCTION ops.trg_tg_payment_paid();


--
-- Name: users trg_users_fill_phone_from_auth; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_fill_phone_from_auth BEFORE INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.users_fill_phone_from_auth();


--
-- Name: user_photos user_photos_url_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_photos_url_change BEFORE UPDATE OF url ON public.user_photos FOR EACH ROW EXECUTE FUNCTION public.reset_face_focus_on_url_change();


--
-- Name: subscriptions zz_anchor_next_billing; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_anchor_next_billing BEFORE INSERT OR UPDATE OF next_billing_at ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.fn_subscriptions_anchor_billing();


--
-- Name: users zz_flag_test_phone; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_flag_test_phone BEFORE INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.zz_flag_test_phone();


--
-- Name: applications applications_applicant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: applications applications_invitation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_invitation_id_fkey FOREIGN KEY (invitation_id) REFERENCES public.invitations(id) ON DELETE CASCADE;


--
-- Name: billing_events billing_events_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_events
    ADD CONSTRAINT billing_events_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id) ON DELETE SET NULL;


--
-- Name: billing_events billing_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_events
    ADD CONSTRAINT billing_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: blocks blocks_blocked_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: blocks blocks_blocker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocks
    ADD CONSTRAINT blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: city_keys city_keys_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.city_keys
    ADD CONSTRAINT city_keys_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- Name: city_requests city_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.city_requests
    ADD CONSTRAINT city_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: invitation_gift_links invitation_gift_links_invitation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitation_gift_links
    ADD CONSTRAINT invitation_gift_links_invitation_id_fkey FOREIGN KEY (invitation_id) REFERENCES public.invitations(id) ON DELETE CASCADE;


--
-- Name: invitations invitations_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- Name: invitations invitations_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: invitations invitations_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(id) ON DELETE SET NULL;


--
-- Name: matches matches_invitation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_invitation_id_fkey FOREIGN KEY (invitation_id) REFERENCES public.invitations(id) ON DELETE SET NULL;


--
-- Name: matches matches_user1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_user1_id_fkey FOREIGN KEY (user1_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: matches matches_user2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_user2_id_fkey FOREIGN KEY (user2_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: message_reactions message_reactions_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: notification_preferences notification_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payments payments_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id) ON DELETE SET NULL;


--
-- Name: payments payments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: push_log push_log_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_log
    ADD CONSTRAINT push_log_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_invitation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_invitation_id_fkey FOREIGN KEY (invitation_id) REFERENCES public.invitations(id) ON DELETE SET NULL;


--
-- Name: reports reports_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE SET NULL;


--
-- Name: reports reports_reported_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: reports reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: subscriptions subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: test_invitation_variants test_invitation_variants_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_invitation_variants
    ADD CONSTRAINT test_invitation_variants_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: test_rotation_state test_rotation_state_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_rotation_state
    ADD CONSTRAINT test_rotation_state_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_devices user_devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_photos user_photos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_photos
    ADD CONSTRAINT user_photos_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_prompts user_prompts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_prompts
    ADD CONSTRAINT user_prompts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_stats user_stats_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: notifications Service role all notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role all notifications" ON public.notifications USING ((auth.role() = 'service_role'::text));


--
-- Name: reports Users create own reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users create own reports" ON public.reports FOR INSERT WITH CHECK ((reporter_id = auth.uid()));


--
-- Name: notifications Users delete own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users delete own notifications" ON public.notifications FOR DELETE USING ((user_id = auth.uid()));


--
-- Name: blocks Users manage own blocks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own blocks" ON public.blocks USING ((blocker_id = auth.uid()));


--
-- Name: notifications Users see own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users see own notifications" ON public.notifications FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: reports Users see own reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users see own reports" ON public.reports FOR SELECT USING ((reporter_id = auth.uid()));


--
-- Name: notifications Users update own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING ((user_id = auth.uid()));


--
-- Name: applications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;

--
-- Name: applications applications_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY applications_insert ON public.applications FOR INSERT WITH CHECK ((applicant_id = auth.uid()));


--
-- Name: applications applications_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY applications_select ON public.applications FOR SELECT USING (((applicant_id = auth.uid()) OR (invitation_id IN ( SELECT invitations.id
   FROM public.invitations
  WHERE (invitations.owner_id = auth.uid())))));


--
-- Name: applications applications_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY applications_update ON public.applications FOR UPDATE USING (((applicant_id = auth.uid()) OR (invitation_id IN ( SELECT invitations.id
   FROM public.invitations
  WHERE (invitations.owner_id = auth.uid()))))) WITH CHECK ((((applicant_id = auth.uid()) AND (status = ANY (ARRAY['withdrawn'::text, 'pending'::text]))) OR ((invitation_id IN ( SELECT invitations.id
   FROM public.invitations
  WHERE (invitations.owner_id = auth.uid()))) AND (status = ANY (ARRAY['accepted'::text, 'rejected'::text])))));


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_read ON public.audit_log FOR SELECT TO ops_moderator USING (true);


--
-- Name: billing_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.billing_config ENABLE ROW LEVEL SECURITY;

--
-- Name: billing_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.billing_events ENABLE ROW LEVEL SECURITY;

--
-- Name: blocks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

--
-- Name: blocks blocks_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blocks_insert ON public.blocks FOR INSERT WITH CHECK ((blocker_id = auth.uid()));


--
-- Name: blocks blocks_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blocks_select ON public.blocks FOR SELECT USING ((blocker_id = auth.uid()));


--
-- Name: call_otps; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.call_otps ENABLE ROW LEVEL SECURITY;

--
-- Name: cities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

--
-- Name: cities cities_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cities_select ON public.cities FOR SELECT USING (true);


--
-- Name: city_keys; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.city_keys ENABLE ROW LEVEL SECURITY;

--
-- Name: city_keys city_keys_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY city_keys_read ON public.city_keys FOR SELECT TO authenticated USING (true);


--
-- Name: city_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.city_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: client_errors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.client_errors ENABLE ROW LEVEL SECURITY;

--
-- Name: city_requests cr_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cr_insert ON public.city_requests FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: city_requests cr_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cr_select_own ON public.city_requests FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: cron_heartbeat; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cron_heartbeat ENABLE ROW LEVEL SECURITY;

--
-- Name: feature_flags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

--
-- Name: feature_flags feature_flags_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY feature_flags_select ON public.feature_flags FOR SELECT TO authenticated USING (true);


--
-- Name: invitation_gift_links gift_link_owner_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY gift_link_owner_write ON public.invitation_gift_links USING ((invitation_id IN ( SELECT invitations.id
   FROM public.invitations
  WHERE (invitations.owner_id = auth.uid())))) WITH CHECK ((invitation_id IN ( SELECT invitations.id
   FROM public.invitations
  WHERE (invitations.owner_id = auth.uid()))));


--
-- Name: internal_secrets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.internal_secrets ENABLE ROW LEVEL SECURITY;

--
-- Name: invitation_create_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.invitation_create_log ENABLE ROW LEVEL SECURITY;

--
-- Name: invitation_gift_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.invitation_gift_links ENABLE ROW LEVEL SECURITY;

--
-- Name: invitations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;

--
-- Name: invitations invitations_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY invitations_delete ON public.invitations FOR DELETE USING ((owner_id = auth.uid()));


--
-- Name: invitations invitations_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY invitations_insert ON public.invitations FOR INSERT WITH CHECK ((owner_id = auth.uid()));


--
-- Name: invitations invitations_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY invitations_select ON public.invitations FOR SELECT USING ((((status = 'active'::text) AND (owner_id <> '385ea0eb-2089-4fd2-8883-8a47a39da29a'::uuid) AND ((( SELECT u.gender
   FROM public.users u
  WHERE (u.id = auth.uid())) IS NULL) OR (( SELECT o.gender
   FROM public.users o
  WHERE (o.id = invitations.owner_id)) IS DISTINCT FROM ( SELECT u.gender
   FROM public.users u
  WHERE (u.id = auth.uid()))))) OR (owner_id = auth.uid()) OR public.has_application_to(id)));


--
-- Name: invitations invitations_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY invitations_update ON public.invitations FOR UPDATE USING ((owner_id = auth.uid()));


--
-- Name: matches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

--
-- Name: matches matches_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY matches_delete ON public.matches FOR DELETE USING (((user1_id = auth.uid()) OR (user2_id = auth.uid())));


--
-- Name: matches matches_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY matches_insert ON public.matches FOR INSERT TO authenticated WITH CHECK (((user1_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.invitations i
  WHERE ((i.id = matches.invitation_id) AND (i.owner_id = auth.uid())))) AND (EXISTS ( SELECT 1
   FROM public.applications a
  WHERE ((a.invitation_id = matches.invitation_id) AND (a.applicant_id = matches.user2_id) AND (a.status = ANY (ARRAY['pending'::text, 'selected'::text, 'accepted'::text])))))));


--
-- Name: matches matches_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY matches_select ON public.matches FOR SELECT USING (((user1_id = auth.uid()) OR (user2_id = auth.uid())));


--
-- Name: matches matches_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY matches_update ON public.matches FOR UPDATE USING (((user1_id = auth.uid()) OR (user2_id = auth.uid())));


--
-- Name: message_reactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: messages_archive; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages_archive ENABLE ROW LEVEL SECURITY;

--
-- Name: messages messages_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY messages_insert ON public.messages FOR INSERT WITH CHECK (((sender_id = auth.uid()) AND (match_id IN ( SELECT matches.id
   FROM public.matches
  WHERE (((matches.user1_id = auth.uid()) OR (matches.user2_id = auth.uid())) AND (matches.user1_id IS NOT NULL) AND (matches.user2_id IS NOT NULL))))));


--
-- Name: messages messages_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY messages_select ON public.messages FOR SELECT USING ((match_id IN ( SELECT matches.id
   FROM public.matches
  WHERE ((matches.user1_id = auth.uid()) OR (matches.user2_id = auth.uid())))));


--
-- Name: messages messages_update_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY messages_update_read ON public.messages FOR UPDATE USING (((sender_id IS DISTINCT FROM auth.uid()) AND (match_id IN ( SELECT matches.id
   FROM public.matches
  WHERE ((matches.user1_id = auth.uid()) OR (matches.user2_id = auth.uid())))))) WITH CHECK (((sender_id IS DISTINCT FROM auth.uid()) AND (match_id IN ( SELECT matches.id
   FROM public.matches
  WHERE ((matches.user1_id = auth.uid()) OR (matches.user2_id = auth.uid()))))));


--
-- Name: message_reactions mr_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mr_delete ON public.message_reactions FOR DELETE USING ((user_id = auth.uid()));


--
-- Name: message_reactions mr_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mr_insert ON public.message_reactions FOR INSERT WITH CHECK (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.matches m
  WHERE ((m.id = message_reactions.match_id) AND ((m.user1_id = auth.uid()) OR (m.user2_id = auth.uid())))))));


--
-- Name: message_reactions mr_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mr_select ON public.message_reactions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.matches m
  WHERE ((m.id = message_reactions.match_id) AND ((m.user1_id = auth.uid()) OR (m.user2_id = auth.uid()))))));


--
-- Name: message_reactions mr_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mr_update ON public.message_reactions FOR UPDATE USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));


--
-- Name: notification_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: otp_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: otp_send_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.otp_send_log ENABLE ROW LEVEL SECURITY;

--
-- Name: payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

--
-- Name: payments payments_own_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payments_own_read ON public.payments FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_photos photos_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY photos_delete ON public.user_photos FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: user_photos photos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY photos_insert ON public.user_photos FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: user_photos photos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY photos_select ON public.user_photos FOR SELECT TO authenticated USING (((moderation_status <> 'rejected'::text) OR (user_id = auth.uid())));


--
-- Name: user_photos photos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY photos_update ON public.user_photos FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: places; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;

--
-- Name: places places_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY places_read ON public.places FOR SELECT TO authenticated USING (is_active);


--
-- Name: user_prompts prompts_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prompts_insert_own ON public.user_prompts FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: user_prompts prompts_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prompts_select_all ON public.user_prompts FOR SELECT TO authenticated USING (true);


--
-- Name: user_prompts prompts_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY prompts_update_own ON public.user_prompts FOR UPDATE TO authenticated USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));


--
-- Name: push_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.push_log ENABLE ROW LEVEL SECURITY;

--
-- Name: reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

--
-- Name: billing_config service_manage_billing_config; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_manage_billing_config ON public.billing_config USING ((auth.role() = 'service_role'::text));


--
-- Name: billing_events service_manage_billing_events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_manage_billing_events ON public.billing_events USING ((auth.role() = 'service_role'::text));


--
-- Name: call_otps service_manage_call_otps; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_manage_call_otps ON public.call_otps USING ((auth.role() = 'service_role'::text));


--
-- Name: cron_heartbeat service_manage_cron_heartbeat; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_manage_cron_heartbeat ON public.cron_heartbeat USING ((auth.role() = 'service_role'::text));


--
-- Name: user_stats service_manage_stats; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_manage_stats ON public.user_stats USING ((auth.role() = 'service_role'::text));


--
-- Name: subscriptions service_manage_subscriptions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_manage_subscriptions ON public.subscriptions USING ((auth.role() = 'service_role'::text));


--
-- Name: subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: test_invitation_variants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.test_invitation_variants ENABLE ROW LEVEL SECURITY;

--
-- Name: test_rotation_state; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.test_rotation_state ENABLE ROW LEVEL SECURITY;

--
-- Name: user_devices; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

--
-- Name: user_photos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_photos ENABLE ROW LEVEL SECURITY;

--
-- Name: user_prompts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_prompts ENABLE ROW LEVEL SECURITY;

--
-- Name: user_stats; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_stats ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_insert ON public.users FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: user_devices users_manage_own_devices; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_manage_own_devices ON public.user_devices USING ((auth.uid() = user_id));


--
-- Name: notification_preferences users_manage_own_preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_manage_own_preferences ON public.notification_preferences USING ((auth.uid() = user_id));


--
-- Name: user_stats users_read_own_stats; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_read_own_stats ON public.user_stats FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: subscriptions users_read_own_subscription; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_read_own_subscription ON public.subscriptions FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: users users_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_select ON public.users FOR SELECT TO authenticated USING (true);


--
-- Name: users users_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_update ON public.users FOR UPDATE USING ((auth.uid() = id));


--
-- PostgreSQL database dump complete
--

