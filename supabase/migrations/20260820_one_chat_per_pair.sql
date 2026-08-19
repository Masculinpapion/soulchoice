-- 20.08.2026 — BİR ÇİFT = BİR SOHBET (Mustafa kararı, kısa tur B5): aynı iki kişi ikinci kez
-- eşleşince yeni sohbet açılmaz, mevcut sohbet yeni plana bağlanıp devam eder (önceden
-- istemci dedup'ı en yenisini gösteriyor, eski sohbet (ör. 90 mesaj) listeden kayboluyordu).
-- + Tek seferlik birleştirme: Mustafa↔Наталья iki eşleşmesi (44bee2a6 eski/90 msg, b3d8c29e
--   yeni/6 msg) tek sohbette: mesajlar eskiye taşınır, eskinin planı yeniye çekilir, yeni silinir.
-- Not: prevent_matches_tamper service/definer bağlamında invitation_id değişimine izin verir
-- (auth.role() null → service_role); RPC security definer → auth.uid() sahibi.

begin;

CREATE OR REPLACE FUNCTION public.prevent_matches_tamper()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

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
    update matches
       set invitation_id = p_invitation_id,
           invitation_category = (select category from invitations where id = p_invitation_id),
           meeting_date = (select event_date from invitations where id = p_invitation_id),
           meeting_confirmed_user1 = null,
           meeting_confirmed_user2 = null,
           user1_hidden_at = null,
           user2_hidden_at = null
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
end $function$;

-- tek seferlik birleştirme (yalnız bu iki kayıt; idempotent)
do $m$
declare v_old uuid := '44bee2a6-0000-0000-0000-000000000000'; v_new uuid := 'b3d8c29e-0000-0000-0000-000000000000';
begin
  select id into v_old from matches where id::text like '44bee2a6%';
  select id into v_new from matches where id::text like 'b3d8c29e%';
  if v_old is null or v_new is null then raise notice 'merge: kayıt yok, atlandı'; return; end if;
  update messages set match_id = v_old where match_id = v_new;
  update matches o
     set invitation_id = n.invitation_id,
         invitation_category = coalesce(n.invitation_category, o.invitation_category),
         meeting_date = n.meeting_date,
         meeting_confirmed_user1 = null, meeting_confirmed_user2 = null,
         user1_hidden_at = null, user2_hidden_at = null,
         user1_cleared_at = null, user2_cleared_at = null
    from matches n where o.id = v_old and n.id = v_new;
  delete from matches where id = v_new;
  raise notice 'merge: tamam (% -> %)', v_new, v_old;
end $m$;

commit;
