-- 20260714_ops_moderation.sql
-- Ops panel Moderasyon altyapısı: audit_log + kuyruk view'leri + SECURITY DEFINER RPC'ler + ops_moderator rolü.
-- Panel service_role KULLANMAZ; her yazma RPC içinden audit_log'a düşer (panel atlayamaz).
-- NOT: ops_moderator şifresi bu dosyada YOK — sunucuda ayrıca `alter role ... password` ile atanır.

begin;

-- ---------- 1. audit_log ----------
create table if not exists public.audit_log (
  id          bigint generated always as identity primary key,
  ts          timestamptz not null default now(),
  actor       text not null,
  action      text not null,
  target_type text not null,
  target_id   uuid,
  reason      text,
  meta        jsonb not null default '{}'::jsonb
);
comment on table public.audit_log is
  'Ops panel yazma günlüğü — sadece SECURITY DEFINER RPC''ler yazar';
alter table public.audit_log enable row level security;

-- ---------- 2. Kuyruk view'leri (owner: supabase_admin; ops_moderator sadece SELECT) ----------
create or replace view public.v_pending_selfies as
select u.id  as user_id,
       u.name, u.age, u.city_id,
       u.created_at as registered_at,
       u.is_test_user,
       (select o.name from storage.objects o
         where o.bucket_id = 'selfies' and o.name like u.id::text || '/%'
         order by o.created_at desc limit 1) as selfie_object,
       (select p.url from public.user_photos p
         where p.user_id = u.id and p.is_primary
         order by p.created_at desc limit 1) as primary_photo_url
from public.users u
where u.selfie_status = 'pending' and u.is_deleted = false
order by u.created_at;

create or replace view public.v_open_reports as
select r.id, r.created_at, r.reason, r.description, r.status,
       r.reporter_id,       ru.name as reporter_name,
       r.reported_user_id,  tu.name as reported_name,
       tu.banned            as reported_banned,
       tu.warning_count     as reported_warning_count,
       tu.is_test_user      as reported_is_test_user,
       ai.id    as reported_active_invitation_id,
       ai.title as reported_active_invitation_title,
       (select p.url from public.user_photos p
         where p.user_id = tu.id and p.is_primary limit 1) as reported_photo_url
from public.reports r
join public.users ru on ru.id = r.reporter_id
join public.users tu on tu.id = r.reported_user_id
left join lateral (
  select i.id, i.title from public.invitations i
  where i.owner_id = tu.id and i.status = 'active'
  order by i.created_at desc limit 1
) ai on true
where r.status not in ('resolved', 'dismissed')
order by r.created_at;

-- ---------- 3. RPC'ler (hepsi audit yazar; koşul tutmazsa exception) ----------
create or replace function public.ops_approve_selfie(p_user uuid, p_actor text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.users
     set selfie_status = 'approved', verified = true, verified_at = now(),
         selfie_rejected_reason = null
   where id = p_user and selfie_status = 'pending';
  if not found then raise exception 'selfie pending durumda değil: %', p_user; end if;
  insert into public.audit_log(actor, action, target_type, target_id)
  values (p_actor, 'approve_selfie', 'user', p_user);
end $$;

create or replace function public.ops_reject_selfie(p_user uuid, p_reason text, p_actor text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if coalesce(trim(p_reason), '') = '' then raise exception 'red sebebi zorunlu'; end if;
  update public.users
     set selfie_status = 'rejected', selfie_rejected_reason = p_reason, verified = false
   where id = p_user and selfie_status = 'pending';
  if not found then raise exception 'selfie pending durumda değil: %', p_user; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'reject_selfie', 'user', p_user, p_reason);
end $$;

create or replace function public.ops_resolve_report(p_report uuid, p_actor text, p_note text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.reports set status = 'resolved'
   where id = p_report and status not in ('resolved', 'dismissed');
  if not found then raise exception 'açık şikayet bulunamadı: %', p_report; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'resolve_report', 'report', p_report, p_note);
end $$;

create or replace function public.ops_close_invitation(p_invitation uuid, p_actor text, p_note text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.invitations set status = 'closed'
   where id = p_invitation and status = 'active';
  if not found then raise exception 'aktif davet bulunamadı: %', p_invitation; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'close_invitation', 'invitation', p_invitation, p_note);
end $$;

create or replace function public.ops_remove_photo(p_photo uuid, p_actor text, p_note text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid; v_url text;
begin
  delete from public.user_photos where id = p_photo returning user_id, url into v_user, v_url;
  if not found then raise exception 'fotoğraf bulunamadı: %', p_photo; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason, meta)
  values (p_actor, 'remove_photo', 'user_photo', p_photo, p_note,
          jsonb_build_object('user_id', v_user, 'url', v_url));
end $$;

create or replace function public.ops_warn_user(p_user uuid, p_actor text, p_note text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if coalesce(trim(p_note), '') = '' then raise exception 'uyarı notu zorunlu'; end if;
  update public.users set warning_count = warning_count + 1 where id = p_user and is_deleted = false;
  if not found then raise exception 'kullanıcı bulunamadı: %', p_user; end if;
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'warn_user', 'user', p_user, p_note);
end $$;

create or replace function public.ops_ban_user(p_user uuid, p_actor text, p_note text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if coalesce(trim(p_note), '') = '' then raise exception 'ban notu zorunlu'; end if;
  update public.users
     set banned = true, suspended_at = now(), suspension_reason = p_note
   where id = p_user and banned = false and is_deleted = false;
  if not found then raise exception 'kullanıcı zaten banlı ya da yok: %', p_user; end if;
  update public.invitations set status = 'closed' where owner_id = p_user and status = 'active';
  insert into public.audit_log(actor, action, target_type, target_id, reason)
  values (p_actor, 'ban_user', 'user', p_user, p_note);
end $$;

-- ---------- 4. ops_moderator rolü (şifre AYRICA atanır, repo'da yok) ----------
do $$ begin
  if not exists (select from pg_roles where rolname = 'ops_moderator') then
    create role ops_moderator login;
  end if;
end $$;

grant connect on database postgres to ops_moderator;
grant usage on schema public to ops_moderator;
grant select on public.v_pending_selfies, public.v_open_reports to ops_moderator;
grant select on public.audit_log to ops_moderator;
grant execute on function
  public.ops_approve_selfie(uuid, text),
  public.ops_reject_selfie(uuid, text, text),
  public.ops_resolve_report(uuid, text, text),
  public.ops_close_invitation(uuid, text, text),
  public.ops_remove_photo(uuid, text, text),
  public.ops_warn_user(uuid, text, text),
  public.ops_ban_user(uuid, text, text)
to ops_moderator;

commit;
