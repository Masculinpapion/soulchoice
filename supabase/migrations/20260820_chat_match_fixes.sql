-- 20.08.2026 — Kısa tur denetimi (sohbet/eşleşme) sunucu düzeltmeleri:
-- (1) match_and_select meeting_date kopyalamıyordu → anket/no-show ölüydü (+ 2 satır backfill)
-- (2) confirm_meeting engelli eşleşmede çalışıyordu → engellenen, engelleyeni askıya aldırabilirdi
-- (3) cleanup_closed_invitations 15.07 'expired' + çift-null match adımlarını kaybetmişti
-- (4) reports.match_id SET NULL olunca şikâyet mesajları bulunamıyordu → match_id_snapshot + ops fn
-- Prod: supabase_admin.

begin;

CREATE OR REPLACE FUNCTION public.match_and_select(p_application_id uuid, p_invitation_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  insert into matches (invitation_id, user1_id, user2_id, meeting_date)
    values (p_invitation_id, auth.uid(), v_applicant_id,
            (select event_date from invitations where id = p_invitation_id))
    on conflict (invitation_id, user2_id) do update set invitation_id = excluded.invitation_id
    returning id into v_match_id;
  update applications set status = 'accepted', selected_at = now(), responded_at = now()
    where id = p_application_id;
  return v_match_id;
end $function$;

CREATE OR REPLACE FUNCTION public.confirm_meeting(p_match_id uuid, p_attended boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

create or replace function public.cleanup_closed_invitations()
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
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

-- Şikâyet kanıt zinciri: match silinse de (eski istemci engel=DELETE) mesaj arşivi bulunsun
alter table public.reports add column if not exists match_id_snapshot uuid;
update public.reports set match_id_snapshot = match_id where match_id is not null and match_id_snapshot is null;
create or replace function public.reports_snapshot_match_id()
returns trigger language plpgsql as $$
begin
  if new.match_id is not null then new.match_id_snapshot := new.match_id; end if;
  return new;
end $$;
drop trigger if exists trg_reports_snapshot_match_id on public.reports;
create trigger trg_reports_snapshot_match_id
  before insert or update of match_id on public.reports
  for each row execute function public.reports_snapshot_match_id();

create or replace function public.ops_report_messages(p_report_id uuid)
returns table(source text, sender_id uuid, content text, created_at timestamptz)
language sql stable security definer
set search_path to 'public', 'pg_temp'
as $$
  select 'live', m.sender_id, m.content, m.created_at
    from public.reports r join public.messages m on m.match_id = coalesce(r.match_id, r.match_id_snapshot) where r.id = p_report_id
  union all
  select 'archive', a.sender_id, a.content, a.created_at
    from public.reports r join public.messages_archive a on a.match_id = coalesce(r.match_id, r.match_id_snapshot) where r.id = p_report_id
  order by 4
$$;

-- backfill: RPC ile açılmış, ilanı tarihli ama meeting_date boş eşleşmeler
update public.matches m
   set meeting_date = i.event_date
  from public.invitations i
 where i.id = m.invitation_id and m.meeting_date is null and i.event_date is not null;

commit;

-- ops paneli rolü (CREATE OR REPLACE sonrası yetki teyidi)
grant execute on function public.ops_report_messages(uuid) to ops_moderator;
