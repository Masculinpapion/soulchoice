-- 20.08.2026 — Kısa tur denetimi (moderasyon) H2+H3: askı/ban kapıları.
-- H3: can_user_apply askıyı bilmiyordu → 3 hakkı biten askıdaki kullanıcı /paywall'a gidip
--     ödeyebiliyor, sonra yine ACCOUNT_SUSPENDED alıyordu (§13 para mağduriyeti).
-- H2: match_and_select askıyı kontrol etmiyordu → askıdaki sahip başvuranı kabul edip match +
--     "Seçildin" push üretebiliyordu; karşı taraf yazar, askıdaki cevaplayamaz.
-- İstemci: guard_errors.dart ACCOUNT_SUSPENDED → /suspended (mevcut). Prod: supabase_admin.

begin;

create or replace function public.can_user_apply(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
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
  insert into matches (invitation_id, user1_id, user2_id)
    values (p_invitation_id, auth.uid(), v_applicant_id)
    on conflict (invitation_id, user2_id) do update set invitation_id = excluded.invitation_id
    returning id into v_match_id;
  update applications set status = 'accepted', selected_at = now(), responded_at = now()
    where id = p_application_id;
  return v_match_id;
end $function$;

commit;
