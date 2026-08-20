-- 20.08.2026 — Mustafa vakası: "bir çift = bir sohbet" rebind'i eski eşleşmenin
-- user1/user2 yönünü koruyordu; istemciler ise "user1 = ilan sahibi,
-- user2 = başvuran" kuralına göre sorgular (invitation_detail._openChat ve
-- decision_screen `eq('user2_id', ...)`). Ters yönlü rebind'de istemci
-- eşleşmeyi bulamayıp `push('/messages')` yedek yoluna düşüyor — shell-dalı
-- route'unu root'a push etmek karanlık ekran + Mesajlar sekmesi kilidi üretti
-- (build 724, S24'te kanıtlı). Düzeltme: rebind mevcut eşleşmeyi kural yönüne
-- çevirir (kişi-bazlı kolonlar gerekiyorsa takasla) → sahadaki ESKİ istemciler
-- de düzelir. Önceki tanım: /root/backups/fn_match_and_select_pre_orient_20260820.sql

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
end $function$;

-- Veri düzeltmesi: 20.08 rebind'inde ters kalan tek gerçek eşleşme (Mustafa↔Наталья).
-- Kişi-bazlı kolonların tamamı NULL (kanıtlı) → yalnız id takası yeterli.
do $$
begin
  perform set_config('soulchoice.match_relink_ok', '1', true);
  update matches
     set user1_id = 'ef551aec-72d1-439d-9ab3-ce900b6b5cfe',  -- Наталья (ilan sahibi)
         user2_id = '279e44e0-f09e-4b31-ad20-94966aa6f6bb'   -- Mustafa (başvuran)
   where id = '44bee2a6-e650-49ce-b71e-5a225309b5aa'
     and user1_id = '279e44e0-f09e-4b31-ad20-94966aa6f6bb';
  perform set_config('soulchoice.match_relink_ok', '', true);
end $$;
