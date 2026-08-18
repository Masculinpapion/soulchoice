-- 18.08.2026 — Anti-fraud sertleştirme (kullanıcı→kullanıcı dolandırıcılık denetimi)
-- Kapsam: eşleşme kaçırma (matches UPDATE), engelleme = kanıt imhası, hediye çiftçiliği,
-- yem-değiştir, sınırsız/filtresiz metin alanları, davet açmada selfie kapısı, şikayet kanıtı.
-- Geriye uyumluluk: mağazadaki istemciler (RuStore 708/724, Play 724, iOS 115 incelemede)
-- ve demo/test hesapları (is_test_user) etkilenmez — filtre/soğuma test kullanıcısına uygulanmaz,
-- eski "engelle = eşleşmeyi sil" akışı çalışmaya devam eder (mesajlar artık arşivlenir).
-- Tümü tek transaction; geri alma: bu dosyanın altındaki ROLLBACK notu.

begin;

-- ---------------------------------------------------------------------------
-- 0) Ortak: temas bilgisi regex'i (link / messenger / @handle / telefon)
-- ---------------------------------------------------------------------------
create or replace function public.contains_contact_info(p text)
returns boolean language sql immutable as $$
  select coalesce(p, '') ~* '(https?://|www\.|t\.me|wa\.me|vk\.com|telegram|whatsapp|телеграм|ватсап|вацап|@[a-z0-9_]{4,}|\+?\d[\d\s\-()]{8,}\d)'
$$;

create or replace function public.is_test_or_service(p_user uuid)
returns boolean language sql stable security definer as $$
  select coalesce(auth.role(), 'service_role') = 'service_role'
      or exists (select 1 from public.users where id = p_user and is_test_user)
$$;

-- ---------------------------------------------------------------------------
-- 1) matches — kimlik + yaptırım sütunları kilidi, kategori anlık görüntüsü, engel bayrağı
-- ---------------------------------------------------------------------------
alter table public.matches
  add column if not exists invitation_category text,
  add column if not exists blocked_by uuid,
  add column if not exists blocked_at timestamptz;

update public.matches m
   set invitation_category = i.category
  from public.invitations i
 where i.id = m.invitation_id and m.invitation_category is null;

create or replace function public.matches_snapshot_category()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.invitation_category is null and new.invitation_id is not null then
    select category into new.invitation_category from public.invitations where id = new.invitation_id;
  end if;
  return new;
end $$;
drop trigger if exists trg_matches_snapshot_category on public.matches;
create trigger trg_matches_snapshot_category
  before insert on public.matches for each row execute function public.matches_snapshot_category();

-- Katılımcı: user1/user2/invitation/created_at/kategori DEĞİŞTİREMEZ (eşleşme kaçırma);
-- meeting_confirmed_* ve no_show_reported_by yalnız confirm_meeting (GUC soulchoice.match_ok);
-- blocked_* yalnız kendi id'siyle, bir kez, geri alınamaz.
create or replace function public.prevent_matches_tamper()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  match_ok boolean := coalesce(current_setting('soulchoice.match_ok', true), '') = '1';
begin
  if coalesce(auth.role(), 'service_role') <> 'service_role' then
    new.id := old.id;
    new.user1_id := old.user1_id;
    new.user2_id := old.user2_id;
    new.invitation_id := old.invitation_id;
    new.created_at := old.created_at;
    new.invitation_category := old.invitation_category;
    if not match_ok then
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
drop trigger if exists trg_prevent_matches_tamper on public.matches;
create trigger trg_prevent_matches_tamper
  before update on public.matches for each row execute function public.prevent_matches_tamper();

-- ---------------------------------------------------------------------------
-- 2) Kanıt: eşleşme silinmeden önce mesajlar arşive (eski istemci "engelle" = delete)
-- ---------------------------------------------------------------------------
create table if not exists public.messages_archive (
  id uuid,
  match_id uuid,
  sender_id uuid,
  content text,
  created_at timestamptz,
  read_at timestamptz,
  archived_at timestamptz not null default now(),
  deleted_by uuid,
  user1_id uuid,
  user2_id uuid,
  invitation_id uuid,
  invitation_category text
);
create index if not exists messages_archive_match_idx on public.messages_archive (match_id);
create index if not exists messages_archive_users_idx on public.messages_archive (user1_id, user2_id);
alter table public.messages_archive enable row level security;   -- politika YOK: yalnız service_role/ops
revoke all on public.messages_archive from anon, authenticated;

create or replace function public.archive_messages_before_match_delete()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.messages_archive
    (id, match_id, sender_id, content, created_at, read_at, deleted_by, user1_id, user2_id, invitation_id, invitation_category)
  select m.id, m.match_id, m.sender_id, m.content, m.created_at, m.read_at, auth.uid(),
         old.user1_id, old.user2_id, old.invitation_id, old.invitation_category
    from public.messages m where m.match_id = old.id;
  return old;
end $$;
drop trigger if exists trg_archive_messages_before_match_delete on public.matches;
create trigger trg_archive_messages_before_match_delete
  before delete on public.matches for each row execute function public.archive_messages_before_match_delete();

-- ---------------------------------------------------------------------------
-- 3) Engel: engelli çiftte mesaj / başvuru / seçim yok (sunucu tarafı)
-- ---------------------------------------------------------------------------
create or replace function public.users_blocked_pair(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.blocks
                  where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;

create or replace function public.enforce_message_allowed()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
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
drop trigger if exists trg_enforce_message_allowed on public.messages;
create trigger trg_enforce_message_allowed
  before insert on public.messages for each row execute function public.enforce_message_allowed();

-- ---------------------------------------------------------------------------
-- 4) Davet kuralları: selfie kapısı (INSERT), başvuru varken kategori/akış kilidi (UPDATE),
--    hediye soğuması (silinen davetler de sayılır — ayrı log), temas filtresi
-- ---------------------------------------------------------------------------
create table if not exists public.invitation_create_log (
  id bigserial primary key,
  owner_id uuid not null,
  category text,
  created_at timestamptz not null default now()
);
create index if not exists invitation_create_log_owner_idx on public.invitation_create_log (owner_id, created_at);
alter table public.invitation_create_log enable row level security;
revoke all on public.invitation_create_log from anon, authenticated;
insert into public.invitation_create_log (owner_id, category, created_at)
  select owner_id, category, created_at from public.invitations where created_at > now() - interval '7 days';

create or replace function public.log_invitation_create()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.invitation_create_log (owner_id, category) values (new.owner_id, new.category);
  return new;
end $$;
drop trigger if exists trg_log_invitation_create on public.invitations;
create trigger trg_log_invitation_create
  after insert on public.invitations for each row execute function public.log_invitation_create();

create or replace function public.enforce_invitation_rules()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
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
drop trigger if exists trg_enforce_invitation_rules on public.invitations;
create trigger trg_enforce_invitation_rules
  before insert or update on public.invitations for each row execute function public.enforce_invitation_rules();

-- Başvurusu olan davette başlık/mekân/tarih/açıklama değişirse bekleyen başvuranlara bildirim
create or replace function public.notify_invitation_updated()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare r record;
begin
  if coalesce(auth.role(), 'service_role') = 'service_role' then return new; end if;
  if (new.title, new.venue_name, new.event_date, new.description)
     is not distinct from (old.title, old.venue_name, old.event_date, old.description) then
    return new;
  end if;
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
        headers := '{"Content-Type": "application/json"}'::jsonb);
    exception when others then null;
    end;
  end loop;
  return new;
end $$;
drop trigger if exists trg_notify_invitation_updated on public.invitations;
create trigger trg_notify_invitation_updated
  after update on public.invitations for each row execute function public.notify_invitation_updated();

-- ---------------------------------------------------------------------------
-- 5) Başvuru + seçim: engelli çift reddi
-- ---------------------------------------------------------------------------
create or replace function public.enforce_application_rules()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
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

create or replace function public.match_and_select(p_application_id uuid, p_invitation_id uuid)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_applicant_id uuid;
  v_status       text;
  v_match_id     uuid;
begin
  if not exists (select 1 from invitations where id = p_invitation_id and owner_id = auth.uid()) then
    raise exception 'not_authorized';
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
  insert into matches (invitation_id, user1_id, user2_id)
    values (p_invitation_id, auth.uid(), v_applicant_id)
    on conflict (invitation_id, user2_id) do update set invitation_id = excluded.invitation_id
    returning id into v_match_id;
  update applications set status = 'accepted', selected_at = now(), responded_at = now()
    where id = p_application_id;
  return v_match_id;
end $$;

-- ---------------------------------------------------------------------------
-- 6) confirm_meeting — 24 saat asgari kapı (tarihsiz/geri tarihli hediye eşleşmesinde
--    anında askı silahı kapanır), hediye tespiti anlık görüntüden (davet silinse de),
--    matches yazımı GUC ile kilit dışı
-- ---------------------------------------------------------------------------
create or replace function public.confirm_meeting(p_match_id uuid, p_attended boolean)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
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

-- ---------------------------------------------------------------------------
-- 7) Metin sınırları + temas filtresi (profil, prompt, mesaj uzunluğu)
-- ---------------------------------------------------------------------------
alter table public.users
  drop constraint if exists users_name_len_check,
  add constraint users_name_len_check check (name is null or char_length(name) <= 30),
  drop constraint if exists users_job_len_check,
  add constraint users_job_len_check check (job is null or char_length(job) <= 60),
  drop constraint if exists users_education_len_check,
  add constraint users_education_len_check check (education is null or char_length(education) <= 60);
alter table public.invitations
  drop constraint if exists invitations_venue_name_len_check,
  add constraint invitations_venue_name_len_check check (venue_name is null or char_length(venue_name) <= 80);
alter table public.user_prompts
  drop constraint if exists user_prompts_answer_len_check,
  add constraint user_prompts_answer_len_check check (answer is null or char_length(answer) <= 150);
alter table public.messages
  drop constraint if exists messages_content_len_check,
  add constraint messages_content_len_check check (char_length(content) <= 2000);

create or replace function public.enforce_profile_text_rules()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
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
drop trigger if exists trg_enforce_profile_text_rules on public.users;
create trigger trg_enforce_profile_text_rules
  before insert or update of name, bio, job, education, gender on public.users
  for each row execute function public.enforce_profile_text_rules();

create or replace function public.enforce_prompt_text_rules()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if public.is_test_or_service(new.user_id) then return new; end if;
  if public.contains_contact_info(new.answer) then
    raise exception 'CONTACT_INFO_NOT_ALLOWED';
  end if;
  return new;
end $$;
drop trigger if exists trg_enforce_prompt_text_rules on public.user_prompts;
create trigger trg_enforce_prompt_text_rules
  before insert or update on public.user_prompts for each row execute function public.enforce_prompt_text_rules();

-- ---------------------------------------------------------------------------
-- 8) Hediye serbest-metin dalı: para/kart/СБП/sertifika/temas reddi
-- ---------------------------------------------------------------------------
create or replace function public.enforce_gift_link()
returns trigger language plpgsql as $$
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
    host := lower(regexp_replace(btrim(new.url), '^https?://([^/?#]+).*$', '\1'));
    host := regexp_replace(host, '^.*@', '');
    host := regexp_replace(host, ':[0-9]+$', '');
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
  else
    if length(btrim(new.url)) < 2 or length(new.url) > 200 then
      raise exception 'GIFT_TEXT_INVALID';
    end if;
    -- 18.08: metin dalında para/kart/СБП/sertifika/temas isteği yasak (yalnız ürün adı)
    if new.url ~* '(\d\s*(₽|руб|р\.)|\y(карт[аеуы]|сбп|перевод[а-я]*|сертификат[а-я]*|номер|телефон[а-я]*|деньги|денег)\y|t\.me|wa\.me|@|https?:|www\.)' then
      raise exception 'GIFT_TEXT_INVALID';
    end if;
  end if;

  new.status := 'pending';
  new.updated_at := now();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 9) Şikayet: bağlam sütunları (eşleşme/davet), kuyruk taraf silinince kaybolmasın
-- ---------------------------------------------------------------------------
alter table public.reports
  add column if not exists match_id uuid references public.matches(id) on delete set null,
  add column if not exists invitation_id uuid references public.invitations(id) on delete set null,
  add column if not exists reported_name_snapshot text;

create or replace function public.reports_snapshot()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  select name into new.reported_name_snapshot from public.users where id = new.reported_user_id;
  return new;
end $$;
drop trigger if exists trg_reports_snapshot on public.reports;
create trigger trg_reports_snapshot
  before insert on public.reports for each row execute function public.reports_snapshot();

create or replace view public.v_open_reports as
 select r.id, r.created_at, r.reason, r.description, r.status,
        r.reporter_id, ru.name as reporter_name,
        r.reported_user_id, coalesce(tu.name, r.reported_name_snapshot) as reported_name,
        tu.banned as reported_banned, tu.warning_count as reported_warning_count,
        tu.is_test_user as reported_is_test_user,
        ai.id as reported_active_invitation_id, ai.title as reported_active_invitation_title,
        (select p.url from public.user_photos p where p.user_id = tu.id and p.is_primary limit 1) as reported_photo_url,
        (select p.id  from public.user_photos p where p.user_id = tu.id and p.is_primary limit 1) as reported_primary_photo_id,
        r.match_id, r.invitation_id,
        (select count(*) from public.messages m where m.match_id = r.match_id) as evidence_messages,
        (select count(*) from public.messages_archive a where a.match_id = r.match_id) as evidence_archived
   from public.reports r
   left join public.users ru on ru.id = r.reporter_id
   left join public.users tu on tu.id = r.reported_user_id
   left join lateral (select i.id, i.title from public.invitations i
                       where i.owner_id = tu.id and i.status = 'active'
                       order by i.created_at desc limit 1) ai on true
  where r.status <> all (array['resolved'::text, 'dismissed'::text])
  order by r.created_at;

-- Ops: şikayet bağlamındaki sohbeti oku (canlı + arşiv). Yalnız service_role çağırır (panel).
create or replace function public.ops_report_messages(p_report_id uuid)
returns table (source text, sender_id uuid, content text, created_at timestamptz)
language sql stable security definer set search_path = public, pg_temp as $$
  select 'live', m.sender_id, m.content, m.created_at
    from public.reports r join public.messages m on m.match_id = r.match_id where r.id = p_report_id
  union all
  select 'archive', a.sender_id, a.content, a.created_at
    from public.reports r join public.messages_archive a on a.match_id = r.match_id where r.id = p_report_id
  order by 4
$$;
revoke all on function public.ops_report_messages(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 10) Bakım: arşiv 90 gün, oluşturma logu 30 gün
-- ---------------------------------------------------------------------------
select cron.unschedule(jobid) from cron.job where jobname in ('cleanup-messages-archive', 'cleanup-invitation-create-log');
select cron.schedule('cleanup-messages-archive', '35 3 * * *',
  $$delete from public.messages_archive where archived_at < now() - interval '90 days'$$);
select cron.schedule('cleanup-invitation-create-log', '40 3 * * *',
  $$delete from public.invitation_create_log where created_at < now() - interval '30 days'$$);

commit;

-- ROLLBACK (gerekirse, sıra önemli):
--   drop trigger trg_prevent_matches_tamper / trg_matches_snapshot_category / trg_archive_messages_before_match_delete on matches;
--   drop trigger trg_enforce_message_allowed on messages; drop trigger trg_enforce_invitation_rules,
--   trg_notify_invitation_updated, trg_log_invitation_create on invitations; drop trigger trg_enforce_profile_text_rules on users;
--   drop trigger trg_enforce_prompt_text_rules on user_prompts; drop trigger trg_reports_snapshot on reports;
--   confirm_meeting / enforce_application_rules / match_and_select / enforce_gift_link / v_open_reports →
--   /root/backups/schema-pre-antifraud-20260818.sql içindeki önceki tanımlar; CHECK'ler drop constraint ile.
