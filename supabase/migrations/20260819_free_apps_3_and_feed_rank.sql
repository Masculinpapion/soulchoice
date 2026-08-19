-- 19.08.2026 — ÜCRETSİZ BAŞVURU HAKKI 1 → 3 (Mustafa kararı) + FEED SIRALAMASI: gerçek kartlar üstte.
-- (1) users.free_applications_used sayaç (0..3). Eski bayrak free_application_used KORUNUR ve
--     artık "3 hakkın tamamı bitti" anlamına gelir (eski istemciler bozulmaz; paywall kararı
--     zaten can_user_apply RPC'sinde). Geçiş: bayrağı true olan mevcut kullanıcılar sayaç=1
--     (2 hakları kalır), bayrak false'a döner. Test kartına başvuru da hak yakar (Mustafa 19.08).
-- (2) invitations.feed_rank smallint: 0 = gerçek kullanıcı kartı, 1 = vitrin (is_test_user);
--     trigger'la sahibinden türetilir, istemci değiştiremez; feed/Обзор `feed_rank asc,
--     created_at desc` sıralar (istemci değişikliği sonraki pakette; eski istemci karışık sırada).
-- Kapsam dokümanı: product-logic §4/§5. Prod: supabase_admin ile koş.

begin;

-- ── (1) 3 ücretsiz hak ─────────────────────────────────────────────────────
alter table public.users
  add column if not exists free_applications_used integer not null default 0
  check (free_applications_used >= 0);

-- geçiş: eski bayrak true → 1 kullanılmış; bayrak artık "hepsi bitti" (>=3) anlamında
update public.users
   set free_applications_used = 1
 where free_application_used = true and free_applications_used = 0;
update public.users
   set free_application_used = (free_applications_used >= 3)
 where free_application_used <> (free_applications_used >= 3);

create or replace function public.can_user_apply(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_used int;
  v_premium boolean;
begin
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'not_authorized';
  end if;
  select free_applications_used,
         (subscription_status = 'active' or premium_until > now())
    into v_used, v_premium
    from public.users where id = p_user_id;
  if not found then return false; end if;
  return coalesce(v_premium, false) or coalesce(v_used, 0) < 3;
end $$;

create or replace function public.mark_free_application_used()
returns trigger
language plpgsql
as $$
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

-- users UPDATE guard: sayaç yalnız trigger bağlamında +1
CREATE OR REPLACE FUNCTION public.prevent_users_privilege_escalation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$;



-- users INSERT guard: ilk kayıtta sayaç 0
create or replace function public.prevent_users_insert_escalation()
returns trigger
language plpgsql
security definer
as $$
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

-- ops paneli kullanıcı detayı: sayaç alanı
CREATE OR REPLACE FUNCTION public.ops_user_detail(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;



-- ── (2) feed_rank: gerçek kartlar üstte ────────────────────────────────────
alter table public.invitations
  add column if not exists feed_rank smallint not null default 0;

create or replace function public.set_invitation_feed_rank()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  select case when u.is_test_user then 1 else 0 end into new.feed_rank
    from public.users u where u.id = new.owner_id;
  new.feed_rank := coalesce(new.feed_rank, 0);
  return new;
end $$;

drop trigger if exists trg_set_invitation_feed_rank on public.invitations;
create trigger trg_set_invitation_feed_rank
  before insert or update of owner_id, feed_rank on public.invitations
  for each row execute function public.set_invitation_feed_rank();

-- is_test_user değişirse (nadir) kartlar da güncellensin
create or replace function public.sync_feed_rank_on_user_flag()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  if new.is_test_user is distinct from old.is_test_user then
    update public.invitations set feed_rank = case when new.is_test_user then 1 else 0 end
     where owner_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists trg_sync_feed_rank_on_user_flag on public.users;
create trigger trg_sync_feed_rank_on_user_flag
  after update of is_test_user on public.users
  for each row execute function public.sync_feed_rank_on_user_flag();

-- geriye dönük doldurma
update public.invitations i
   set feed_rank = case when u.is_test_user then 1 else 0 end
  from public.users u
 where u.id = i.owner_id
   and i.feed_rank <> case when u.is_test_user then 1 else 0 end;

create index if not exists idx_invitations_feed_rank_created
  on public.invitations (status, feed_rank, created_at desc);

-- kanıt
do $chk$
declare a int; b int; c int; d int;
begin
  select count(*) into a from public.users where not is_test_user and not is_deleted and free_applications_used = 1;
  select count(*) into b from public.users where free_application_used and free_applications_used < 3;
  select count(*) into c from public.invitations i join public.users u on u.id=i.owner_id where u.is_test_user and i.feed_rank <> 1;
  select count(*) into d from public.invitations i join public.users u on u.id=i.owner_id where not u.is_test_user and i.feed_rank <> 0;
  raise notice 'users used=1: %, bayrak tutarsız: %, test feed_rank<>1: %, gerçek feed_rank<>0: %', a, b, c, d;
  if b <> 0 or c <> 0 or d <> 0 then raise exception 'CHECK FAILED'; end if;
end $chk$;

commit;

-- Ek (aynı gün): istemci kalan hak göstergesi için sayaç sütunu okunabilir olsun
-- (eski bayrakla aynı seviye — 20260731_users_column_privacy listesine paralel).
grant select (free_applications_used) on public.users to authenticated, anon;
